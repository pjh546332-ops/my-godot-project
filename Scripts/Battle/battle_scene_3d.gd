extends Node

## 3D 전투 씬 오케스트레이션:
## - BattleManager에서 유닛 목록을 받아 3D 스테이지에 배치
## - 2D 전투 씬과 동일한 UI(BattleUI)를 BattleManager에 연결

@onready var battle_manager: BattleManager = $BattleManager
@onready var stage_3d: Node3D = $World3D/BattleStage3D

var turn_track: TurnTrack = null
var stats_panel: Control = null
var deselect_overlay: ColorRect = null
var character_list: Control = null
var action_panel: Node = null
var enemy_intent_ui: Control = null
var reaction_panel: Control = null
var bottom_ui: ColorRect = null

var selected_unit: BattleUnit = null


func _ready() -> void:
	_init_ui()
	## BattleManager와 Stage가 모두 _ready 된 뒤에 3D 유닛 배치를 수행하기 위해 지연 호출.
	call_deferred("_setup_3d_units")


func _setup_3d_units() -> void:
	if battle_manager == null:
		return
	if stage_3d == null:
		return
	if stage_3d.has_method("spawn_units_from_manager"):
		stage_3d.spawn_units_from_manager(battle_manager)


func _init_ui() -> void:
	if battle_manager == null:
		return

	var ui_root: Node = get_node_or_null("CanvasLayer/BattleUI")
	if ui_root == null:
		return

	turn_track = ui_root.get_node_or_null("TurnTrack")
	stats_panel = ui_root.get_node_or_null("StatsPanel")
	deselect_overlay = ui_root.get_node_or_null("DeselectOverlay")
	character_list = ui_root.get_node_or_null("Margin/VBox/CharacterList")
	action_panel = ui_root.get_node_or_null("ActionPanel")
	enemy_intent_ui = ui_root.get_node_or_null("EnemyIntentUI")
	reaction_panel = ui_root.get_node_or_null("Margin/VBox/ReactionPanel")
	bottom_ui = ui_root.get_node_or_null("BottomUI")

	# 각 UI 위젯에 BattleManager 주입
	if turn_track:
		turn_track.setup(battle_manager)
	if character_list and character_list.has_method("setup"):
		character_list.setup(battle_manager)
	if action_panel and action_panel.has_method("setup"):
		action_panel.setup(battle_manager)
		# 버튼 시그널을 BattleManager에 연결 (중복 연결 방지)
		if not action_panel.attack_pressed.is_connected(battle_manager.on_attack_pressed):
			action_panel.attack_pressed.connect(battle_manager.on_attack_pressed)
		if not action_panel.defend_pressed.is_connected(battle_manager.on_defend_pressed):
			action_panel.defend_pressed.connect(battle_manager.on_defend_pressed)
	if enemy_intent_ui and enemy_intent_ui.has_method("setup"):
		enemy_intent_ui.setup(battle_manager)
	if reaction_panel and reaction_panel.has_method("setup"):
		reaction_panel.setup(battle_manager)

	# 기본 UI 상태 및 마우스 필터 설정 (2D 전투 씬과 동일하게)
	if stats_panel:
		stats_panel.visible = false
		stats_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if character_list:
		character_list.visible = false
	if turn_track:
		turn_track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if enemy_intent_ui:
		enemy_intent_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if reaction_panel:
		reaction_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if action_panel:
		_set_action_panel_mouse_filter(action_panel, Control.MOUSE_FILTER_STOP)
	if deselect_overlay:
		deselect_overlay.visible = false
		deselect_overlay.gui_input.connect(_on_deselect_overlay_gui_input)

	# BattleManager 신호를 UI에 연결
	battle_manager.state_changed.connect(_on_state_changed)
	battle_manager.current_planning_unit_changed.connect(_on_current_planning_unit)


func _set_action_panel_mouse_filter(node: Node, filter: Control.MouseFilter) -> void:
	if node is Control:
		(node as Control).mouse_filter = filter
	for child in node.get_children():
		_set_action_panel_mouse_filter(child, filter)


func _on_state_changed(s: BattleManager.State) -> void:
	var show_panel := (
		s == BattleManager.State.ALLY_SELECT_ACTION
		and battle_manager._current_planning_unit()
		and battle_manager._current_planning_unit().is_ally()
	)
	if action_panel and action_panel.has_method("set_enabled"):
		action_panel.set_enabled(show_panel)


func _on_current_planning_unit(unit: BattleUnit) -> void:
	if turn_track:
		turn_track.set_active_unit_by_ref(unit)
	if action_panel and action_panel.has_method("set_enabled"):
		action_panel.set_enabled(unit != null and unit.is_ally())


func set_selected_unit(unit: BattleUnit) -> void:
	selected_unit = unit
	if stats_panel:
		stats_panel.visible = false  # MVP: 스탯 창 비표시 (2D와 동일)
		stats_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if unit and stats_panel.has_method("update"):
			stats_panel.update(unit)
	if deselect_overlay:
		deselect_overlay.visible = (unit != null)


func _on_deselect_overlay_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var e: InputEventMouseButton = event
		if e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			set_selected_unit(null)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		set_selected_unit(null)
		get_viewport().set_input_as_handled()
