extends Node
class_name BattleTurnController

## 턴 시스템: 라운드/유닛 순서, begin_turn, next_turn, 사망 제거.

signal round_changed(round: int)
signal turn_changed(unit: Node)
signal battle_end(ally_won: bool)

var units: Array = []  ## 유닛 노드 references (ally 먼저, enemy 나중)
var round_num: int = 1
var turn_index: int = 0
var current_unit: Node = null

const TEAM_ALLY := 0
const TEAM_ENEMY := 1


func start_battle(unit_list: Array) -> void:
	units.clear()
	for u in unit_list:
		if is_instance_valid(u) and u.has_method("is_alive") and u.is_alive():
			units.append(u)
		if u.has_signal("died"):
			if not u.died.is_connected(_on_unit_died):
				u.died.connect(_on_unit_died)
	round_num = 1
	turn_index = 0
	round_changed.emit(round_num)
	_advance_to_valid_turn()


func _advance_to_valid_turn() -> void:
	var limit: int = units.size() * 2
	var count: int = 0
	while count < limit:
		if units.is_empty():
			return
		turn_index = turn_index % units.size()
		current_unit = units[turn_index]
		if is_instance_valid(current_unit) and current_unit.has_method("is_alive") and current_unit.is_alive():
			current_unit.begin_turn()
			turn_changed.emit(current_unit)
			return
		units.remove_at(turn_index)
		count += 1
	current_unit = null


func next_turn() -> void:
	if units.is_empty():
		return
	turn_index += 1
	if turn_index >= units.size():
		turn_index = 0
		round_num += 1
		round_changed.emit(round_num)
	_advance_to_valid_turn()
	_check_battle_end()


func remove_unit(unit: Node) -> void:
	var i: int = units.find(unit)
	if i >= 0:
		if turn_index > i:
			turn_index -= 1
		units.remove_at(i)
		if turn_index >= units.size() and units.size() > 0:
			turn_index = units.size() - 1
		if current_unit == unit:
			current_unit = null
			_advance_to_valid_turn()
	_check_battle_end()


func _on_unit_died(unit: Node) -> void:
	remove_unit(unit)


func _check_battle_end() -> void:
	var allies: int = 0
	var enemies: int = 0
	for u in units:
		if not is_instance_valid(u):
			continue
		if u.team == TEAM_ALLY:
			allies += 1
		elif u.team == TEAM_ENEMY:
			enemies += 1
	if allies <= 0:
		print("[BattleTurnController] Battle end: Enemy wins")
		battle_end.emit(false)
	elif enemies <= 0:
		print("[BattleTurnController] Battle end: Ally wins")
		battle_end.emit(true)
