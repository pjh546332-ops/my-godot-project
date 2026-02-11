class_name EnemyIntentUI
extends Control
## 적 행동 의도 표시 (예: E1: ATTACK -> 2).
## set_enemy_intents(intents)로 텍스트 라인 즉시 갱신.

var battle_manager: BattleManager

@onready var list_container: Control = $VBox

func setup(p_battle_manager: BattleManager) -> void:
	battle_manager = p_battle_manager
	if battle_manager:
		battle_manager.enemy_intent_updated.connect(_on_intent_updated)
		battle_manager.state_changed.connect(_on_state_changed)
	_refresh()

func set_enemy_intents(intents: Variant) -> void:
	if not list_container:
		return
	for c in list_container.get_children():
		c.queue_free()
	var lines: Array[String] = []
	if intents is Array:
		for x in intents:
			lines.append(str(x))
	elif intents is Dictionary:
		for k in intents:
			lines.append("%s: %s" % [str(k), str(intents[k])])
	for line in lines:
		var lbl := Label.new()
		lbl.text = line
		list_container.add_child(lbl)

func _on_intent_updated(_lines: Array) -> void:
	set_enemy_intents(_lines)

func _on_state_changed(_s: BattleManager.State) -> void:
	_refresh()

func _refresh() -> void:
	if not battle_manager:
		return
	set_enemy_intents(battle_manager.get_enemy_intent_lines())
