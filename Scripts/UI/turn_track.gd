class_name TurnTrack
extends Control
## 고정 슬롯(13개). 가장 빠른 유닛이 중앙, 다음이 중앙 오른쪽·왼쪽… 순으로 배치. 나머지 슬롯은 숨김.

var battle_manager: BattleManager
var _track_items: Dictionary = {}  # BattleUnit -> PanelContainer
var _active_unit: BattleUnit = null
var _ally_slots: Array[Control] = []
var _enemy_slots: Array[Control] = []
var _ally_container: HBoxContainer = null
var _enemy_container: HBoxContainer = null

const PORTRAIT_SIZE := 24
const SLOT_COUNT_SIDE := 7

func set_active_unit_by_ref(unit: BattleUnit) -> void:
	_apply_highlight(_active_unit, false)
	_active_unit = unit
	_apply_highlight(unit, true)

func set_active_unit(unit_id: int) -> void:
	pass

func setup(p_battle_manager: BattleManager) -> void:
	battle_manager = p_battle_manager
	_build_fixed_slots()
	if battle_manager:
		battle_manager.state_changed.connect(_refresh)
		battle_manager.resolve_done.connect(_refresh)
		battle_manager.current_planning_unit_changed.connect(set_active_unit_by_ref)
	_refresh()

func _build_fixed_slots() -> void:
	# 기존 자식 제거 후 상단 중앙 배치용 루트 컨테이너와 좌/우 슬롯 컨테이너 생성
	for c in get_children():
		c.queue_free()
	_ally_slots.clear()
	_enemy_slots.clear()

	# 상단 중앙 배치
	anchor_left = 0.5
	anchor_right = 0.5
	anchor_top = 0.0
	anchor_bottom = 0.0
	offset_left = -300.0
	offset_right = 300.0
	offset_top = 10.0
	offset_bottom = 50.0

	var root := HBoxContainer.new()
	root.name = "TrackRoot"
	root.anchor_left = 0.0
	root.anchor_top = 0.0
	root.anchor_right = 1.0
	root.anchor_bottom = 1.0
	root.offset_left = 0.0
	root.offset_top = 0.0
	root.offset_right = 0.0
	root.offset_bottom = 0.0
	root.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_theme_constant_override("separation", 40)
	add_child(root)

	_ally_container = HBoxContainer.new()
	_ally_container.name = "AllySlots"
	_ally_container.alignment = BoxContainer.ALIGNMENT_END
	_ally_container.add_theme_constant_override("separation", 4)
	root.add_child(_ally_container)

	var spacer := Control.new()
	spacer.name = "CenterSpacer"
	spacer.custom_minimum_size = Vector2(40, PORTRAIT_SIZE + 4)
	root.add_child(spacer)

	_enemy_container = HBoxContainer.new()
	_enemy_container.name = "EnemySlots"
	_enemy_container.alignment = BoxContainer.ALIGNMENT_BEGIN
	_enemy_container.add_theme_constant_override("separation", 4)
	root.add_child(_enemy_container)

	for i in SLOT_COUNT_SIDE:
		var a_slot: Control = PanelContainer.new()
		a_slot.name = "AllySlot_%d" % i
		a_slot.custom_minimum_size = Vector2(PORTRAIT_SIZE + 28, PORTRAIT_SIZE + 4)
		a_slot.visible = false
		_ally_container.add_child(a_slot)
		_ally_slots.append(a_slot)

	for j in SLOT_COUNT_SIDE:
		var e_slot: Control = PanelContainer.new()
		e_slot.name = "EnemySlot_%d" % j
		e_slot.custom_minimum_size = Vector2(PORTRAIT_SIZE + 28, PORTRAIT_SIZE + 4)
		e_slot.visible = false
		_enemy_slots.append(e_slot)
		_enemy_container.add_child(e_slot)

func _refresh(_arg: Variant = null) -> void:
	if not battle_manager:
		return
	_track_items.clear()

	# 모든 슬롯 비우고 숨김
	for slot in _ally_slots:
		for c in slot.get_children():
			c.queue_free()
		slot.visible = false
		_set_panel_style(slot as PanelContainer, false)
	for slot in _enemy_slots:
		for c in slot.get_children():
			c.queue_free()
		slot.visible = false
		_set_panel_style(slot as PanelContainer, false)

	# 아군 / 적 유닛을 별도로 speed 내림차순 정렬
	var allies: Array[BattleUnit] = []
	for a in battle_manager.ally_units_sorted:
		if a.is_alive():
			allies.append(a)
	allies.sort_custom(func(a: BattleUnit, b: BattleUnit) -> bool:
		if a.speed != b.speed:
			return a.speed > b.speed
		return a.name < b.name
	)

	var enemies: Array[BattleUnit] = []
	for e in battle_manager.enemy_units:
		if e.is_alive():
			enemies.append(e)
	enemies.sort_custom(func(a: BattleUnit, b: BattleUnit) -> bool:
		if a.speed != b.speed:
			return a.speed > b.speed
		return a.name < b.name
	)

	# 아군: 오른쪽(중앙 쪽) 슬롯부터 빠른 유닛 배치
	var ally_count: int = min(allies.size(), SLOT_COUNT_SIDE)
	for i in range(ally_count):
		var u: BattleUnit = allies[i]
		var slot_idx: int = SLOT_COUNT_SIDE - 1 - i
		var slot: Control = _ally_slots[slot_idx] as Control
		var panel: PanelContainer = _make_track_item(u)
		_track_items[u] = panel
		slot.add_child(panel)
		slot.visible = true

	# 적: 왼쪽(중앙 쪽) 슬롯부터 빠른 유닛 배치
	var enemy_count: int = min(enemies.size(), SLOT_COUNT_SIDE)
	for j in range(enemy_count):
		var eu: BattleUnit = enemies[j]
		var eslot: Control = _enemy_slots[j] as Control
		var epanel: PanelContainer = _make_track_item(eu)
		_track_items[eu] = epanel
		eslot.add_child(epanel)
		eslot.visible = true

	set_active_unit_by_ref(battle_manager._current_planning_unit())

func _make_track_item(u: BattleUnit) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = "Track_%s" % u.name
	panel.custom_minimum_size = Vector2(PORTRAIT_SIZE + 28, PORTRAIT_SIZE + 4)
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	var rect := ColorRect.new()
	rect.custom_minimum_size = Vector2(PORTRAIT_SIZE, PORTRAIT_SIZE)
	rect.color = Color.DARK_GREEN if u.is_ally() else Color.DARK_RED
	box.add_child(rect)
	var lbl := Label.new()
	lbl.text = "%s(%d)" % [u.name, u.speed]
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	box.add_child(lbl)
	panel.add_child(box)
	_set_panel_style(panel, false)
	return panel

func _set_panel_style(panel: PanelContainer, active: bool) -> void:
	if not panel:
		return
	var style := StyleBoxFlat.new()
	if active:
		style.bg_color = Color(0.35, 0.35, 0.2, 0.9)
		style.border_color = Color(1.0, 0.9, 0.3)
		style.set_border_width_all(2)
		style.corner_radius_top_left = 4
		style.corner_radius_top_right = 4
		style.corner_radius_bottom_right = 4
		style.corner_radius_bottom_left = 4
	else:
		style.bg_color = Color(0.2, 0.2, 0.2, 0.6)
		style.set_border_width_all(0)
		style.corner_radius_top_left = 4
		style.corner_radius_top_right = 4
		style.corner_radius_bottom_right = 4
		style.corner_radius_bottom_left = 4
	panel.add_theme_stylebox_override("panel", style)

func _apply_highlight(unit: BattleUnit, active: bool) -> void:
	if not unit:
		return
	var item: PanelContainer = _track_items.get(unit)
	if is_instance_valid(item):
		_set_panel_style(item, active)
