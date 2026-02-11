extends Node

## BattleManager의 전투 이벤트를 BattlePresenter로 전달하는 어댑터.

@onready var battle_manager: BattleManager = get_parent().get_node_or_null("BattleManager")
@onready var presenter: Node = get_parent().get_node_or_null("BattlePresenter")


func _ready() -> void:
	if not battle_manager or not presenter:
		return

	battle_manager.turn_started.connect(_on_turn_started)
	battle_manager.action_resolved.connect(_on_action_resolved)
	battle_manager.unit_defeated.connect(_on_unit_defeated)


func _on_turn_started(unit_id: String) -> void:
	if presenter and presenter.has_method("on_turn_started"):
		presenter.on_turn_started(unit_id)


func _on_action_resolved(attacker_id: String, target_id: String, amount: int) -> void:
	if presenter and presenter.has_method("on_action_resolved"):
		presenter.on_action_resolved(attacker_id, target_id, amount)


func _on_unit_defeated(unit_id: String) -> void:
	if presenter and presenter.has_method("on_unit_defeated"):
		presenter.on_unit_defeated(unit_id)

