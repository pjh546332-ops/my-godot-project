class_name BattleMvpUi
extends Control
## 최소 표시: 현재 턴 유닛, 선택된 적 대상 이름/HP

@onready var turn_label: Label = $VBox/TurnLabel
@onready var target_label: Label = $VBox/TargetLabel

var battle_manager: BattleManager

func setup(p_battle_manager: BattleManager) -> void:
	battle_manager = p_battle_manager
	if battle_manager:
		battle_manager.state_changed.connect(_on_state_changed)
		battle_manager.plan_stored.connect(_on_plan_stored)
	_refresh()

func _on_state_changed(s: BattleManager.State) -> void:
	_refresh()

func _on_plan_stored(_u: BattleUnit, _a: BattleAction) -> void:
	_refresh()

func _refresh() -> void:
	if not battle_manager:
		return
	var cur: BattleUnit = battle_manager._current_ally()
	if turn_label:
		turn_label.text = "Turn: %s" % (cur.name if cur else "-")
	if battle_manager._state == BattleManager.State.ALLY_SELECT_TARGET:
		var sel: BattleUnit = battle_manager._selected_enemy()
		if target_label:
			target_label.text = "Target: %s HP=%d [SELECTED]" % [sel.name if sel else "-", sel.hp if sel else 0]
	else:
		if target_label:
			target_label.text = "Target: -"
