extends Node

## 3D 전투 씬 오케스트레이션:
## - BattleManager에서 유닛 목록을 받아 3D 스테이지에 배치
## - 2D 전투 씬과 동일한 UI(BattleUI)를 BattleManager에 연결

const ReactionTypes = preload("res://Scripts/Reaction/reaction_types.gd")
const ReactionResolver = preload("res://Scripts/Reaction/reaction_resolver.gd")

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
var targeting_arrow_2d: Node2D = null


func _ready() -> void:
	_init_ui()
	## BattleManager와 Stage가 모두 _ready 된 뒤에 3D 유닛 배치를 수행하기 위해 지연 호출.
	if battle_manager and stage_3d:
		if battle_manager.has_signal("unit_damaged"):
			battle_manager.unit_damaged.connect(_on_unit_damaged)
		if battle_manager.has_signal("unit_died"):
			battle_manager.unit_died.connect(_on_unit_died)
	call_deferred("_setup_3d_units")


func _setup_3d_units() -> void:
	if battle_manager == null:
		return
	if stage_3d == null:
		return
	if stage_3d.has_method("spawn_units_from_manager"):
		stage_3d.spawn_units_from_manager(battle_manager)
		# 2D 타겟팅 화살표 노드 참조
		targeting_arrow_2d = get_node_or_null("CanvasLayer/TargetingArrow2D") as Node2D
		# 당분간 StatsPanel 완전 OFF: unit_clicked 연결하지 않음 (유닛 클릭해도 스탯창 미표시)
		# 유닛 스폰 이후 현재 계획 유닛을 다시 3D 스테이지에 반영
		if battle_manager.has_method("get_current_planning_unit") and stage_3d.has_method("set_active_unit"):
			var u: BattleUnit = battle_manager.get_current_planning_unit()
			if u:
				stage_3d.set_active_unit(u.name)
		# 초기 HP 표시 동기화
		if stage_3d.has_method("update_hp_label"):
			for u_hp in battle_manager.get_all_units():
				if u_hp:
					stage_3d.update_hp_label(u_hp.name)


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

	# 3D 피킹을 막지 않도록 배경성 Control은 입력을 무시하게 강제
	if ui_root is Control:
		(ui_root as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	if bottom_ui:
		bottom_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if deselect_overlay:
		deselect_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE

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
	if battle_manager.has_signal("reaction_needed"):
		battle_manager.reaction_needed.connect(_on_reaction_needed)


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
	# 조작 턴이 아닌 상태(EXECUTE/ROUND_END 등)에서는 3D active 강조 해제
	if stage_3d and stage_3d.has_method("clear_active_unit"):
		if s == BattleManager.State.EXECUTE or s == BattleManager.State.ROUND_END:
			stage_3d.clear_active_unit()
	# 타겟 선택 모드에서 벗어나면 타겟 Outline 해제
	if s != BattleManager.State.ALLY_SELECT_TARGET and stage_3d and stage_3d.has_method("clear_target_unit"):
		stage_3d.clear_target_unit()


func _on_current_planning_unit(unit: BattleUnit) -> void:
	if turn_track:
		turn_track.set_active_unit_by_ref(unit)
	if action_panel and action_panel.has_method("set_enabled"):
		action_panel.set_enabled(unit != null and unit.is_ally())
	# 현재 계획/행동 중인 유닛을 3D 스테이지에서 강조
	if stage_3d and stage_3d.has_method("set_active_unit"):
		if unit != null:
			stage_3d.set_active_unit(unit.name)
		else:
			if stage_3d.has_method("clear_active_unit"):
				stage_3d.clear_active_unit()


func _on_reaction_needed(attacker: BattleUnit, target: BattleUnit, base_damage: int) -> void:
	# 리액션 선택이 끝나야 EXECUTE 단계가 계속 진행되므로, 비동기 처리 후 continue_execute_phase 호출
	if not reaction_panel or not battle_manager:
		battle_manager.continue_execute_phase()
		return
	_handle_reaction_async(attacker, target, base_damage)


func _handle_reaction_async(attacker: BattleUnit, target: BattleUnit, base_damage: int) -> void:
	if not reaction_panel or not battle_manager:
		battle_manager.continue_execute_phase()
		return

	var reaction: ReactionTypes.Reaction = await reaction_panel.choose_reaction(attacker, target)
	var result: Dictionary = ReactionResolver.resolve(attacker, target, base_damage, reaction)
	battle_manager.apply_reaction_damage(attacker, target, result)
	battle_manager.continue_execute_phase()


func _on_unit_damaged(unit: BattleUnit, _amount: int) -> void:
	if stage_3d and stage_3d.has_method("update_hp_label") and unit:
		stage_3d.update_hp_label(unit.name)


func _on_unit_died(unit: BattleUnit) -> void:
	if stage_3d and stage_3d.has_method("update_hp_label") and unit:
		stage_3d.update_hp_label(unit.name)


func _on_unit_clicked(unit: BattleUnit) -> void:
	# 3D 유닛 클릭을 공통 선택 처리로 위임
	set_selected_unit(unit)


func _process(_delta: float) -> void:
	if not battle_manager or not stage_3d or not targeting_arrow_2d:
		return

	var targeting: bool = (battle_manager._state == BattleManager.State.ALLY_SELECT_TARGET)
	if not targeting:
		if targeting_arrow_2d.has_method("set_enabled"):
			targeting_arrow_2d.set_enabled(false)
		return

	if not stage_3d.has_method("get_active_unit_head_world_pos"):
		return
	var head_world: Vector3 = stage_3d.get_active_unit_head_world_pos()
	if head_world == Vector3.ZERO:
		if targeting_arrow_2d.has_method("set_enabled"):
			targeting_arrow_2d.set_enabled(false)
		return

	var cam: Camera3D = get_viewport().get_camera_3d()
	if cam == null:
		return
	var start_screen: Vector2 = cam.unproject_position(head_world)
	var mouse_pos: Vector2 = get_viewport().get_mouse_position()

	if targeting_arrow_2d.has_method("set_enabled"):
		targeting_arrow_2d.set_enabled(true)
	if targeting_arrow_2d.has_method("set_points"):
		targeting_arrow_2d.set_points(start_screen, mouse_pos)


func set_selected_unit(unit: BattleUnit) -> void:
	# 토글: 같은 유닛을 다시 클릭하면 스탯창 닫기
	if unit == null:
		selected_unit = null
		if stats_panel:
			stats_panel.visible = false
			stats_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if deselect_overlay:
			deselect_overlay.visible = false
		return

	if selected_unit == unit and stats_panel and stats_panel.visible:
		selected_unit = null
		stats_panel.visible = false
		if deselect_overlay:
			deselect_overlay.visible = false
		return

	# 새 유닛 선택
	selected_unit = unit
	if stats_panel:
		if stats_panel.has_method("update"):
			stats_panel.update(unit)
		stats_panel.visible = true
		stats_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if deselect_overlay:
		deselect_overlay.visible = true


func _on_deselect_overlay_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var e: InputEventMouseButton = event
		if e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			set_selected_unit(null)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		set_selected_unit(null)
		get_viewport().set_input_as_handled()
