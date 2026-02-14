extends Node2D
## 유닛 위치에 원 그리기 (MVP)

@export var fill_color: Color = Color.WHITE

func _draw() -> void:
	draw_circle(Vector2.ZERO, 20.0, fill_color)
	draw_arc(Vector2.ZERO, 20.0, 0.0, TAU, 32, Color.BLACK)
