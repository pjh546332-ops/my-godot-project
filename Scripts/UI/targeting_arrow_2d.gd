extends Node2D

## 2D HUD용 타겟팅 곡선 화살표

var _line: Line2D
var _head: Sprite2D


func _ready() -> void:
	_line = get_node_or_null("Line2D")
	if _line == null:
		_line = Line2D.new()
		_line.name = "Line2D"
		_line.width = 4.0
		_line.default_color = Color(1.0, 0.9, 0.3, 1.0)
		add_child(_line)

	_head = get_node_or_null("Head")
	if _head == null:
		_head = Sprite2D.new()
		_head.name = "Head"
		_head.modulate = Color(1.0, 0.9, 0.3, 1.0)
		add_child(_head)

	visible = false


func set_enabled(on: bool) -> void:
	visible = on


func set_points(start: Vector2, end: Vector2) -> void:
	if _line == null or _head == null:
		return

	var mid: Vector2 = (start + end) * 0.5 + Vector2(0, -120.0)
	_line.points = PackedVector2Array([start, mid, end])

	_head.position = end
	var dir: Vector2 = end - start
	if dir.length() > 0.001:
		_head.rotation = dir.angle()
