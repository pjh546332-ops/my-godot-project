extends Node2D
## 유닛 강조 시 노란 테두리. 부모(UnitNode)가 set_highlight(true) 시 보이도록 함.

func _draw() -> void:
	if not visible:
		return
	var size := 48.0
	var half := size / 2.0
	draw_rect(Rect2(-half, -half, size, size), Color(1.0, 0.9, 0.0), false, 4.0)
