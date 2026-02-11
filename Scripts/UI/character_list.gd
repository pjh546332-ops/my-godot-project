class_name CharacterList
extends Control
## 유닛 목록 표시 (이름, HP, 속도)

var battle_manager: BattleManager
var item_container: Control

func _ready() -> void:
	item_container = $VBox if has_node("VBox") else self

func setup(p_battle_manager: BattleManager) -> void:
	battle_manager = p_battle_manager
	if battle_manager:
		battle_manager.state_changed.connect(_refresh)
		battle_manager.unit_damaged.connect(_on_unit_damaged)
		battle_manager.unit_died.connect(_on_unit_died)
		battle_manager.resolve_done.connect(_refresh)
	_refresh()

func _refresh(_arg: Variant = null) -> void:
	if not battle_manager:
		return
	_clear_children()
	for u in battle_manager.get_all_units():
		if not u.is_alive():
			continue
		var line: Label = Label.new()
		var side_str: String = "Ally" if u.is_ally() else "Enemy"
		line.text = "%s %s | HP %d/%d | Atk %d | Spd %d" % [side_str, u.name, u.hp, u.max_hp, u.attack, u.speed]
		line.name = "Unit_%s" % u.name
		if item_container:
			item_container.add_child(line)

func _on_unit_damaged(_unit: BattleUnit, _amount: int) -> void:
	_refresh()

func _on_unit_died(_unit: BattleUnit) -> void:
	_refresh()

func _clear_children() -> void:
	if item_container:
		for c in item_container.get_children():
			c.queue_free()
