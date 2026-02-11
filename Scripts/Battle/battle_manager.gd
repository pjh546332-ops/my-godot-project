class_name BattleManager
extends Node
## 라운드당 1회 행동, 속도 재굴림, 계획(아군 UI/적 자동) → 실행. 승패까지 반복.

enum State {
	ROUND_START,
	PLAN,
	ALLY_SELECT_ACTION,
	ALLY_SELECT_TARGET,
	EXECUTE,
	ROUND_END
}

var ally_units_sorted: Array[BattleUnit] = []
var enemy_units: Array[BattleUnit] = []
var plan_order: Array[BattleUnit] = []
var current_plan_index: int = 0
var selected_enemy: BattleUnit = null
var plans: Dictionary = {}
var enemy_intent_lines: Array[String] = []
var current_round: int = 0

var _state: State = State.ROUND_START

signal state_changed(s: State)
signal plan_stored(unit: BattleUnit, action: BattleAction)
signal current_planning_unit_changed(unit: BattleUnit)
signal enemy_intent_updated(lines: Array)
signal resolve_done
signal reaction_needed(attacker: BattleUnit, target: BattleUnit, base_damage: int)
signal unit_damaged(unit: BattleUnit, amount: int)
signal unit_died(unit: BattleUnit)
signal battle_ended(ally_won: bool)

## 3D 연출용 고수준 이벤트
signal turn_started(unit_id: String)
signal action_resolved(attacker_id: String, target_id: String, amount: int)
signal unit_defeated(unit_id: String)

var _execute_index: int = 0

func _ready() -> void:
	_ensure_input_map()
	_init_units()
	_start_round()

func _ensure_input_map() -> void:
	if not InputMap.has_action("attack"):
		InputMap.add_action("attack")
		var ev := InputEventKey.new()
		ev.physical_keycode = KEY_A
		InputMap.action_add_event("attack", ev)
	if not InputMap.has_action("defend"):
		InputMap.add_action("defend")
		var ev := InputEventKey.new()
		ev.physical_keycode = KEY_D
		InputMap.action_add_event("defend", ev)

func _init_units() -> void:
	ally_units_sorted.clear()
	enemy_units.clear()
	var a1 := BattleUnit.new("1", BattleUnit.Team.ALLY)
	a1.cell = Vector2i(1, 2)
	var a2 := BattleUnit.new("2", BattleUnit.Team.ALLY)
	a2.cell = Vector2i(2, 2)
	var a3 := BattleUnit.new("3", BattleUnit.Team.ALLY)
	a3.cell = Vector2i(3, 2)
	var a4 := BattleUnit.new("4", BattleUnit.Team.ALLY)
	a4.cell = Vector2i(1, 3)
	var a5 := BattleUnit.new("5", BattleUnit.Team.ALLY)
	a5.cell = Vector2i(2, 3)
	ally_units_sorted.assign([a1, a2, a3, a4, a5])
	var e1 := BattleUnit.new("E1", BattleUnit.Team.ENEMY)
	e1.cell = Vector2i(6, 2)
	var e2 := BattleUnit.new("E2", BattleUnit.Team.ENEMY)
	e2.cell = Vector2i(7, 2)
	var e3 := BattleUnit.new("E3", BattleUnit.Team.ENEMY)
	e3.cell = Vector2i(6, 3)
	var e4 := BattleUnit.new("E4", BattleUnit.Team.ENEMY)
	e4.cell = Vector2i(7, 3)
	var e5 := BattleUnit.new("E5", BattleUnit.Team.ENEMY)
	e5.cell = Vector2i(8, 3)
	enemy_units.assign([e1, e2, e3, e4, e5])

static func _speed_bonus(cell: Vector2i) -> int:
	if cell.y == 0:
		return 2
	if cell.y == 1:
		return 1
	return 0

func _start_round() -> void:
	current_round += 1
	plans.clear()
	enemy_intent_lines.clear()
	for u in get_all_units():
		u.reaction_used_this_round = false
	for u in get_all_units():
		if not u.is_alive():
			continue
		u.speed = clampi(randi_range(1, 12) + _speed_bonus(u.cell) + u.speed_bonus, 1, 99)
		u.defending = false
	plan_order.clear()
	for u in get_all_units():
		if u.is_alive():
			plan_order.append(u)
	plan_order.sort_custom(func(a: BattleUnit, b: BattleUnit) -> bool:
		if a.speed != b.speed:
			return a.speed > b.speed
		return a.name < b.name
	)
	current_plan_index = 0
	_plan_all_enemies()
	_state = State.PLAN
	state_changed.emit(_state)
	enemy_intent_updated.emit(enemy_intent_lines)
	_advance_plan()

func _current_planning_unit() -> BattleUnit:
	if current_plan_index < 0 or current_plan_index >= plan_order.size():
		return null
	return plan_order[current_plan_index]

func get_current_planning_unit() -> BattleUnit:
	return _current_planning_unit()

## 아군 영역 x=0..4, 최전열(노란선에 가까움) x=4. dist = abs(4 - cell.x)
static func _ally_center_dist(cell: Vector2i) -> int:
	return abs(4 - cell.x)

func _plan_all_enemies() -> void:
	enemy_intent_lines.clear()
	for u in plan_order:
		if not u.is_alive():
			continue
		if not u.is_enemy():
			continue
		var allies_alive: Array[BattleUnit] = []
		for a in ally_units_sorted:
			if a.is_alive():
				allies_alive.append(a)
		if allies_alive.is_empty():
			plans[u] = BattleAction.make_defend(u)
			enemy_intent_lines.append("%s: DEFEND" % u.name)
		else:
			var min_dist: int = 999
			for a in allies_alive:
				var d: int = _ally_center_dist(a.cell)
				if d < min_dist:
					min_dist = d
			var candidates: Array[BattleUnit] = []
			for a in allies_alive:
				if _ally_center_dist(a.cell) == min_dist:
					candidates.append(a)
			var t: BattleUnit = candidates[randi() % candidates.size()]
			plans[u] = BattleAction.make_attack(u, t)
			enemy_intent_lines.append("%s: ATTACK -> %s" % [u.name, t.name])
		plan_stored.emit(u, plans[u])
		print("[BattleManager] plan_stored for enemy:", u.name)

func _advance_plan() -> void:
	while current_plan_index < plan_order.size():
		var u: BattleUnit = plan_order[current_plan_index]
		if not u.is_alive():
			current_plan_index += 1
			continue
		if u.is_enemy():
			current_plan_index += 1
			continue
		else:
			_state = State.ALLY_SELECT_ACTION
			selected_enemy = null
			state_changed.emit(_state)
			current_planning_unit_changed.emit(u)
			_update_highlights()
			return
	_execute_phase()

func _update_highlights() -> void:
	for u in get_all_units():
		u.set_highlight(false)
	var cur := _current_planning_unit()
	if cur:
		cur.set_highlight(true)
	if _state == State.ALLY_SELECT_TARGET and selected_enemy and selected_enemy.is_alive():
		selected_enemy.set_highlight(true)

func on_attack_pressed() -> void:
	if _state != State.ALLY_SELECT_ACTION:
		return
	_state = State.ALLY_SELECT_TARGET
	selected_enemy = null
	state_changed.emit(_state)
	_update_highlights()

func on_defend_pressed() -> void:
	if _state != State.ALLY_SELECT_ACTION:
		return
	var u := _current_planning_unit()
	if u:
		plans[u] = BattleAction.make_defend(u)
		plan_stored.emit(u, plans[u])
	current_plan_index += 1
	_advance_plan()

func on_enemy_clicked(unit: BattleUnit) -> void:
	if _state != State.ALLY_SELECT_TARGET or not unit.is_enemy() or not unit.is_alive():
		return
	selected_enemy = unit
	_update_highlights()

func on_confirm_target() -> void:
	if _state != State.ALLY_SELECT_TARGET or not selected_enemy or not selected_enemy.is_alive():
		return
	var u := _current_planning_unit()
	if u:
		plans[u] = BattleAction.make_attack(u, selected_enemy)
		plan_stored.emit(u, plans[u])
	current_plan_index += 1
	_advance_plan()

func _unhandled_input(event: InputEvent) -> void:
	# 마우스 우클릭으로 Attack 타겟 선택 취소
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_RIGHT:
			if _state == State.ALLY_SELECT_TARGET:
				selected_enemy = null
				_state = State.ALLY_SELECT_ACTION
				state_changed.emit(_state)
				current_planning_unit_changed.emit(_current_planning_unit())
				_update_highlights()
				get_viewport().set_input_as_handled()
			return
	if event is InputEventMouseMotion:
		return
	if _state == State.ALLY_SELECT_TARGET and Input.is_action_just_pressed("ui_accept"):
		on_confirm_target()
		get_viewport().set_input_as_handled()

func get_all_units() -> Array[BattleUnit]:
	var out: Array[BattleUnit] = []
	for u in ally_units_sorted:
		out.append(u)
	for u in enemy_units:
		out.append(u)
	return out

func get_enemy_intent_lines() -> Array:
	return enemy_intent_lines.duplicate()

func _execute_phase() -> void:
	_state = State.EXECUTE
	state_changed.emit(_state)
	print("[BattleManager] EXECUTE phase start, round %d" % current_round)
	for u in get_all_units():
		u.set_highlight(false)
	_execute_index = 0
	_execute_phase_loop()

func _execute_phase_loop() -> void:
	while _execute_index < plan_order.size():
		var u: BattleUnit = plan_order[_execute_index]
		_execute_index += 1
		if not u.is_alive():
			continue
		var act: BattleAction = plans.get(u)
		if not act:
			continue
		turn_started.emit(u.name)
		if act.type == BattleAction.ActionType.DEFEND:
			u.defending = true
			continue
		if act.type != BattleAction.ActionType.ATTACK or not act.target or not act.target.is_alive():
			continue
		var t: BattleUnit = act.target
		var base_damage: int = u.attack
		if t.defending:
			base_damage = ceili(float(base_damage) * 0.5)
		# 적이 아군을 공격할 때만 리액션 체크
		if u.is_enemy() and t.is_ally() and not t.reaction_used_this_round:
			reaction_needed.emit(u, t, base_damage)
			return
		# 리액션 없음: 기본 데미지 처리
		_apply_attack_damage(u, t, base_damage, 0)
	for u in get_all_units():
		u.defending = false
	plans.clear()
	_state = State.ROUND_END
	state_changed.emit(_state)
	var has_ally := false
	var has_enemy := false
	for u in ally_units_sorted:
		if u.is_alive():
			has_ally = true
			break
	for u in enemy_units:
		if u.is_alive():
			has_enemy = true
			break
	if not has_enemy:
		battle_ended.emit(true)
		return
	if not has_ally:
		battle_ended.emit(false)
		return
	resolve_done.emit()
	_start_round()

func _apply_attack_damage(attacker: BattleUnit, target: BattleUnit, damage_to_target: int, damage_to_attacker: int) -> void:
	if damage_to_target > 0:
		target.take_damage(damage_to_target)
		unit_damaged.emit(target, damage_to_target)
		print("[BattleManager] action_resolved:", attacker.name, "->", target.name, "damage", damage_to_target)
		action_resolved.emit(attacker.name, target.name, damage_to_target)
		if not target.is_alive():
			unit_died.emit(target)
			unit_defeated.emit(target.name)
	if damage_to_attacker > 0:
		attacker.take_damage(damage_to_attacker)
		unit_damaged.emit(attacker, damage_to_attacker)
		print("[BattleManager] action_resolved:", target.name, "->", attacker.name, "damage", damage_to_attacker)
		action_resolved.emit(target.name, attacker.name, damage_to_attacker)
		if not attacker.is_alive():
			unit_died.emit(attacker)
			unit_defeated.emit(attacker.name)

func apply_reaction_damage(attacker: BattleUnit, target: BattleUnit, result: Dictionary) -> void:
	var d_target: int = result.get("damage_to_target", 0)
	var d_attacker: int = result.get("damage_to_attacker", 0)
	_apply_attack_damage(attacker, target, d_target, d_attacker)

func continue_execute_phase() -> void:
	_execute_phase_loop()

func _current_ally() -> BattleUnit:
	return _current_planning_unit()
