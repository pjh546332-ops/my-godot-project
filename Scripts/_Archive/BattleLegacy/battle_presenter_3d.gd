extends Node

## BattleManager 이벤트를 받아 3D 스테이지 연출로 위임하는 프레젠터.

@onready var stage_3d: Node3D = get_parent().get_node_or_null("World3D/BattleStage3D")


func on_turn_started(unit_id: String) -> void:
	if stage_3d and stage_3d.has_method("play_turn_started"):
		stage_3d.play_turn_started(unit_id)


func on_action_resolved(attacker_id: String, target_id: String, amount: int) -> void:
	if stage_3d and stage_3d.has_method("play_action_resolved"):
		stage_3d.play_action_resolved(attacker_id, target_id, amount)


func on_unit_defeated(unit_id: String) -> void:
	if stage_3d and stage_3d.has_method("play_unit_defeated"):
		stage_3d.play_unit_defeated(unit_id)

