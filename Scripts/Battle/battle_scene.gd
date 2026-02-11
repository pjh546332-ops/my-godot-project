class_name BattleSceneScript
extends Node2D
## 전투 씬: BattleManager 단일, 그리드·유닛·UI. 라운드/속도 재굴림/계획·실행·승패.

signal battle_finished(victory: bool)

@export_range(80, 140) var stage_y_offset: float = 110.0
@export var ui_band_ratio: float = 0.28
@export var side_margin_px: float = 24.0
@export var gap_px: float = 64.0
@export var board_bottom_margin_px: float = 18.0
@export var stage_near_width: float = 900.0
@export var stage_far_width: float = 650.0
@export var stage_depth: float = 260.0

@onready var battle_manager: BattleManager = $BattleManager
var stage_node: Node2D = null
var stage_polygon: Polygon2D = null
var board_root: Node2D = null
var ally_board_root: Node2D = null
var enemy_board_root: Node2D = null
var ally_grid: GridDisplay = null
var enemy_grid: GridDisplay = null
var ally_units_root: Node2D = null
var enemy_units_root: Node2D = null
var units_layer: Node2D = null
var turn_track: TurnTrack = null
var stats_panel: StatsPanel = null
var deselect_overlay: Control = null
var character_list: CharacterList = null
var action_panel: ActionPanel = null
var enemy_intent_ui: EnemyIntentUI = null
var reaction_panel: ReactionPanel = null
var bottom_ui: ColorRect = null

var selected_unit: BattleUnit = null
var _reaction_target: BattleUnit = null  # 피격 강조 해제용

const ACTION_PANEL_WIDTH: float = 180.0
const ACTION_PANEL_MARGIN: float = 16.0
const TURN_TRACK_BOTTOM: float = 40.0
const REACTION_PANEL_EST_W: float = 280.0
const REACTION_PANEL_EST_H: float = 100.0
const REACTION_PANEL_OFFSET_Y: float = -60.0

const TARGET_W: float = 1920.0
const TARGET_H: float = 1080.0
const BOARD_COLS: int = 10
const BOARD_ROWS: int = 5
const TURN_TRACK_TOP_MARGIN: float = 8.0
const ENEMY_INTENT_PANEL_WIDTH: float = 220.0

func _ready() -> void:
	if not battle_manager:
		return

	# 안전하게 노드 참조 초기화
	stage_node = get_node_or_null("Stage")
	stage_polygon = get_node_or_null("Stage/StagePolygon")
	board_root = get_node_or_null("BoardRoot")
	ally_board_root = get_node_or_null("BoardRoot/AllyBoardRoot")
	enemy_board_root = get_node_or_null("BoardRoot/EnemyBoardRoot")
	ally_grid = get_node_or_null("BoardRoot/AllyBoardRoot/Grid")
	enemy_grid = get_node_or_null("BoardRoot/EnemyBoardRoot/Grid")
	ally_units_root = get_node_or_null("BoardRoot/AllyBoardRoot/UnitsRoot")
	enemy_units_root = get_node_or_null("BoardRoot/EnemyBoardRoot/UnitsRoot")
	units_layer = get_node_or_null("UnitsLayer")
	turn_track = get_node_or_null("CanvasLayer/TurnTrack")
	stats_panel = get_node_or_null("CanvasLayer/StatsPanel")
	deselect_overlay = get_node_or_null("CanvasLayer/DeselectOverlay")
	character_list = get_node_or_null("CanvasLayer/Margin/VBox/CharacterList")
	action_panel = get_node_or_null("CanvasLayer/ActionPanel")
	enemy_intent_ui = get_node_or_null("CanvasLayer/EnemyIntentUI")
	reaction_panel = get_node_or_null("CanvasLayer/Margin/VBox/ReactionPanel")
	bottom_ui = get_node_or_null("CanvasLayer/BottomUI")

	# 보드 그리드는 일단 원근 모드를 끄고 정사각 그리드로 고정
	if ally_grid:
		ally_grid.perspective_enabled = false
	if enemy_grid:
		enemy_grid.perspective_enabled = false

	if turn_track:
		turn_track.setup(battle_manager)
	if character_list:
		character_list.setup(battle_manager)
	if action_panel:
		action_panel.setup(battle_manager)
	if enemy_intent_ui:
		enemy_intent_ui.setup(battle_manager)
	if reaction_panel:
		reaction_panel.setup(battle_manager)
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
	if has_node("CanvasLayer/Margin"):
		var margin_node: Control = get_node("CanvasLayer/Margin")
		margin_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if deselect_overlay:
		deselect_overlay.visible = false
		deselect_overlay.gui_input.connect(_on_deselect_overlay_gui_input)
	if action_panel:
		action_panel.attack_pressed.connect(battle_manager.on_attack_pressed)
		action_panel.defend_pressed.connect(battle_manager.on_defend_pressed)
	battle_manager.state_changed.connect(_on_state_changed)
	battle_manager.current_planning_unit_changed.connect(_on_current_planning_unit)
	battle_manager.resolve_done.connect(_on_resolve_done)
	battle_manager.battle_ended.connect(_on_battle_ended)
	battle_manager.reaction_needed.connect(_on_reaction_needed)
	battle_manager.unit_damaged.connect(_on_unit_damaged)
	battle_manager.unit_died.connect(_on_unit_died)
	get_viewport().size_changed.connect(_layout_board_and_ui)
	_layout_board_and_ui()
	_spawn_unit_sprites()

func _layout_board_and_ui() -> void:
	var vp_rect: Rect2 = get_viewport().get_visible_rect()
	var origin: Vector2 = vp_rect.position
	var screen_size: Vector2 = vp_rect.size
	var screen_w: float = screen_size.x
	var screen_h: float = screen_size.y

	# 보드 픽셀: board_w = tile_size*10, board_h = tile_size*5
	var tile_size: float = float(GridDisplay.CELL_SIZE)
	var board_w: float = tile_size * float(BOARD_COLS)
	var board_h: float = tile_size * float(BOARD_ROWS)

	# 1) BoardRoot: 화면 정중앙 배치 (아래 고정 제거)
	# x = origin.x + (screen_size.x - board_w)/2, y = origin.y + (screen_size.y - board_h)/2
	var board_x: float = origin.x + (screen_size.x - board_w) * 0.5
	var board_y: float = origin.y + (screen_size.y - board_h) * 0.5
	if board_root:
		board_root.position = Vector2(board_x, board_y)
		board_root.scale = Vector2(1.0, 1.0)
	# 자식: 아군 5열(0~4), 적 5열(5~9) → 각 5x5 그리드
	if ally_board_root:
		ally_board_root.position = Vector2(0.0, 0.0)
	if enemy_board_root:
		enemy_board_root.position = Vector2(tile_size * 5.0, 0.0)

	# Stage(선택): 무대가 있으면 보드 위쪽에 맞춤
	if stage_node and stage_polygon:
		var half_near: float = stage_near_width * 0.5
		var half_far: float = stage_far_width * 0.5
		stage_polygon.polygon = PackedVector2Array([
			Vector2(-half_far, 0.0), Vector2(half_far, 0.0),
			Vector2(half_near, stage_depth), Vector2(-half_near, stage_depth)
		])
		stage_node.position = Vector2(origin.x + screen_w * 0.5, board_y - stage_depth)

	# 2) TurnTrack: 보드와 같은 x 중앙 정렬, y는 상단 여백 유지
	if turn_track:
		turn_track.custom_minimum_size.x = board_w
		turn_track.position.x = origin.x + (screen_size.x - board_w) * 0.5
		turn_track.position.y = origin.y + TURN_TRACK_TOP_MARGIN

	# 3) EnemyIntentUI: 오른쪽에 딱 붙게. TurnTrack 아래부터 (앵커/offset은 씬에서 우측 고정)
	if enemy_intent_ui:
		enemy_intent_ui.offset_left = -ENEMY_INTENT_PANEL_WIDTH
		enemy_intent_ui.offset_right = 0
		enemy_intent_ui.offset_top = 48.0

	# ActionPanel: 하단 우측 (viewport origin 반영)
	var ui_h: float = 200.0
	if bottom_ui and bottom_ui.size.y > 0.0:
		ui_h = bottom_ui.size.y
	var panel_bottom_y: float = origin.y + screen_h - ui_h
	if action_panel:
		action_panel.position.x = origin.x + screen_w - ACTION_PANEL_WIDTH - ACTION_PANEL_MARGIN
		action_panel.position.y = panel_bottom_y + ui_h * 0.2

	# ReactionPanel: 두 보드 영역 중앙 위
	_position_reaction_panel(origin.x + screen_w, origin.y + screen_h, board_x, board_y, board_w, board_h)

	# 원근 그리드는 레이아웃 후 복원
	if ally_grid:
		ally_grid.perspective_enabled = true
	if enemy_grid:
		enemy_grid.perspective_enabled = true

func _position_reaction_panel(_screen_w: float, _screen_h: float, board_left: float, board_top: float, board_w: float, board_h: float) -> void:
	if not reaction_panel:
		return
	var center_x: float = board_left + board_w * 0.5
	var center_y: float = board_top + board_h * 0.5
	var panel_w: float = REACTION_PANEL_EST_W
	var panel_h: float = REACTION_PANEL_EST_H
	if reaction_panel.visible:
		var sz: Vector2 = reaction_panel.get_combined_minimum_size()
		if sz.x > 0:
			panel_w = sz.x
		if sz.y > 0:
			panel_h = sz.y
	reaction_panel.position.x = center_x - panel_w * 0.5
	reaction_panel.position.y = center_y - panel_h * 0.5 + REACTION_PANEL_OFFSET_Y

func _set_action_panel_mouse_filter(node: Node, filter: Control.MouseFilter) -> void:
	if node is Control:
		(node as Control).mouse_filter = filter
	for child in node.get_children():
		_set_action_panel_mouse_filter(child, filter)

func is_target_select_mode() -> bool:
	return battle_manager != null and battle_manager._state == BattleManager.State.ALLY_SELECT_TARGET

func set_selected_unit(unit: BattleUnit) -> void:
	selected_unit = unit
	if stats_panel:
		stats_panel.visible = false  # MVP: 스탯 창 비표시
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

func _on_state_changed(s: BattleManager.State) -> void:
	var show_panel := (s == BattleManager.State.ALLY_SELECT_ACTION and battle_manager._current_planning_unit() and battle_manager._current_planning_unit().is_ally())
	if action_panel:
		action_panel.set_enabled(show_panel)

func _on_current_planning_unit(unit: BattleUnit) -> void:
	if turn_track:
		turn_track.set_active_unit_by_ref(unit)
	if action_panel:
		action_panel.set_enabled(unit != null and unit.is_ally())
	_apply_planning_highlight(unit)

func _on_resolve_done() -> void:
	_spawn_unit_sprites()
	refresh_hp_ui()

func _on_battle_ended(ally_won: bool) -> void:
	if action_panel:
		action_panel.set_enabled(false)
	battle_finished.emit(ally_won)

func _on_unit_damaged(_unit: BattleUnit, _amount: int) -> void:
	refresh_hp_ui()

func _on_unit_died(_unit: BattleUnit) -> void:
	refresh_hp_ui()

func _on_reaction_needed(attacker: BattleUnit, target: BattleUnit, base_damage: int) -> void:
	var vp_rect: Rect2 = get_viewport().get_visible_rect()
	var origin: Vector2 = vp_rect.position
	var screen_size: Vector2 = vp_rect.size
	var board_w: float = float(GridDisplay.CELL_SIZE) * float(BOARD_COLS)
	var board_h: float = float(GridDisplay.CELL_SIZE) * float(BOARD_ROWS)
	var board_left: float = origin.x + (screen_size.x - board_w) * 0.5
	var board_top: float = origin.y + (screen_size.y - board_h) * 0.5
	_position_reaction_panel(origin.x + screen_size.x, origin.y + screen_size.y, board_left, board_top, board_w, board_h)
	_apply_target_highlight(target)
	_handle_reaction_async(attacker, target, base_damage)

func _handle_reaction_async(attacker: BattleUnit, target: BattleUnit, base_damage: int) -> void:
	if not reaction_panel or not battle_manager:
		battle_manager.continue_execute_phase()
		return
	var reaction: ReactionTypes.Reaction = await reaction_panel.choose_reaction(attacker, target)
	var result: Dictionary = ReactionResolver.resolve(attacker, target, base_damage, reaction)
	battle_manager.apply_reaction_damage(attacker, target, result)
	_clear_target_highlight()
	battle_manager.continue_execute_phase()

func _apply_planning_highlight(unit: BattleUnit) -> void:
	for root in [ally_units_root, enemy_units_root]:
		if not root:
			continue
		for c in root.get_children():
			if c.get("unit") != null and c.has_method("set_highlight"):
				c.set_highlight(false)
	if unit and unit.visual_node and is_instance_valid(unit.visual_node):
		if unit.visual_node.has_method("set_highlight"):
			unit.visual_node.set_highlight(true)

func _apply_target_highlight(target: BattleUnit) -> void:
	_reaction_target = target
	if target and target.visual_node and is_instance_valid(target.visual_node) and target.visual_node.has_method("set_highlight"):
		target.visual_node.set_highlight(true)

func _clear_target_highlight() -> void:
	if _reaction_target and _reaction_target.visual_node and is_instance_valid(_reaction_target.visual_node) and _reaction_target.visual_node.has_method("set_highlight"):
		_reaction_target.visual_node.set_highlight(false)
	_reaction_target = null

func _spawn_unit_sprites() -> void:
	if ally_units_root:
		for c in ally_units_root.get_children():
			c.queue_free()
	if enemy_units_root:
		for c in enemy_units_root.get_children():
			c.queue_free()
	if not battle_manager or not ally_grid or not enemy_grid:
		return

	for u in battle_manager.get_all_units():
		if not u.is_alive():
			continue

		# 각 보드의 UnitsRoot 아래에 붙이고, 로컬 좌표만 사용
		var local_cell: Vector2i
		var parent_root: Node2D
		var grid: GridDisplay
		if u.is_ally():
			local_cell = Vector2i(u.cell.x, u.cell.y)
			parent_root = ally_units_root
			grid = ally_grid
		else:
			local_cell = Vector2i(u.cell.x - 5, u.cell.y)
			parent_root = enemy_units_root
			grid = enemy_grid

		var pos: Vector2 = grid.cell_to_position(local_cell)
		pos.y += 12.0  # 발이 타일에 붙어 보이도록

		var node: Node2D = Node2D.new()
		node.set_script(load("res://Scripts/Battle/unit_node.gd") as GDScript)
		node.unit = u
		node.battle_manager = battle_manager
		node.unit_clicked_callback = _on_unit_clicked_for_selection
		node.position = pos
		node.name = "Unit_%s" % u.name
		u.visual_node = node
		# 스프라이트
		var color: Color = Color.GREEN if u.is_ally() else Color.RED
		var spr: Node2D = _make_unit_sprite(color)
		node.add_child(spr)
		# 유닛 원 안 이름 (중앙 정렬, 아군 1~5 / 적 E1~E4)
		var name_lbl: Label = Label.new()
		name_lbl.text = u.unit_name if u.unit_name else u.name
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		name_lbl.position = Vector2(-24, -10)
		name_lbl.size = Vector2(48, 20)
		name_lbl.add_theme_font_size_override("font_size", 12)
		node.add_child(name_lbl)
		# 유닛 머리 위 HP 텍스트 + ProgressBar
		var hp_text: Label = Label.new()
		hp_text.name = "HPText"
		hp_text.text = "%d/%d" % [u.hp, u.max_hp]
		hp_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hp_text.position = Vector2(-24, -50)
		hp_text.size = Vector2(48, 12)
		hp_text.add_theme_font_size_override("font_size", 10)
		node.add_child(hp_text)
		var hp_bar: ProgressBar = ProgressBar.new()
		hp_bar.custom_minimum_size = Vector2(44, 10)
		hp_bar.position = Vector2(-22, -38)
		hp_bar.show_percentage = false
		hp_bar.min_value = 0
		hp_bar.max_value = float(u.max_hp)
		hp_bar.value = float(u.hp)
		hp_bar.name = "HPBar"
		node.add_child(hp_bar)
		parent_root.add_child(node)

func refresh_hp_ui() -> void:
	for root in [ally_units_root, enemy_units_root]:
		if not root:
			continue
		for c in root.get_children():
			var un: Node = c
			if not un.get("unit"):
				continue
			var u: BattleUnit = un.unit
			if not u or not u.is_alive():
				continue
			var bar: ProgressBar = un.get_node_or_null("HPBar")
			if bar:
				bar.max_value = float(u.max_hp)
				bar.value = float(u.hp)
			var lbl: Label = un.get_node_or_null("HPText")
			if lbl:
				lbl.text = "%d/%d" % [u.hp, u.max_hp]

func _on_unit_clicked_for_selection(unit: BattleUnit) -> void:
	if is_target_select_mode():
		return
	set_selected_unit(unit)

func _make_unit_sprite(color: Color) -> Node2D:
	var node: Node2D = Node2D.new()
	node.set_script(load("res://Scripts/Battle/unit_sprite.gd") as GDScript)
	node.fill_color = color
	return node


func _stage_map_uv(u: float, v: float) -> Vector2:
	var half_near: float = stage_near_width * 0.5
	var half_far: float = stage_far_width * 0.5
	var tl: Vector2 = Vector2(-half_far, 0.0)
	var tr: Vector2 = Vector2(half_far, 0.0)
	var bl: Vector2 = Vector2(-half_near, stage_depth)
	var br: Vector2 = Vector2(half_near, stage_depth)
	var top: Vector2 = tl.lerp(tr, u)
	var bottom: Vector2 = bl.lerp(br, u)
	return top.lerp(bottom, v)
