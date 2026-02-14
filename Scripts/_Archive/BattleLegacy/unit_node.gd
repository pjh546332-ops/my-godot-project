extends Node2D
## 그리드 위 유닛 노드. 자식 Area2D로 적 클릭 시 BattleManager에 전달.
## set_highlight(on) 시 노란색 테두리로 강조.

var unit: BattleUnit
var battle_manager: BattleManager
var unit_clicked_callback: Callable = Callable()
var _highlight: bool = false

func set_highlight(on: bool) -> void:
	if _highlight == on:
		return
	_highlight = on
	var border: Node2D = get_node_or_null("HighlightBorder")
	if border:
		border.visible = on
		border.queue_redraw()

func _ready() -> void:
	var area := Area2D.new()
	area.name = "ClickArea"
	area.input_pickable = true
	var shape := CircleShape2D.new()
	shape.radius = 28.0
	var col := CollisionShape2D.new()
	col.shape = shape
	area.add_child(col)
	area.input_event.connect(_on_area_input)
	add_child(area)
	# 테두리는 자식들 위에 그려지도록 마지막에 추가
	var border := Node2D.new()
	border.name = "HighlightBorder"
	border.visible = false
	border.set_script(load("res://Scripts/_Archive/BattleLegacy/unit_highlight_border.gd") as GDScript)
	add_child(border)

func _on_area_input(_viewport: Viewport, event: InputEvent, _shape_idx: int) -> void:
	if not unit or not battle_manager:
		return
	if event is InputEventMouseButton:
		var e: InputEventMouseButton = event
		if not e.pressed or e.button_index != MOUSE_BUTTON_LEFT:
			return
		var target_mode: bool = battle_manager._state == BattleManager.State.ALLY_SELECT_TARGET
		if unit.is_enemy() and unit.is_alive() and target_mode:
			battle_manager.on_enemy_clicked(unit)
			return
		if unit_clicked_callback.is_valid():
			unit_clicked_callback.call(unit)
