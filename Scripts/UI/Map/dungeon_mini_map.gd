extends Control
class_name DungeonMiniMap

var map_state: DungeonMapState = null

@export var tile_px: float = 14.0


func set_map_state(state: DungeonMapState) -> void:
	map_state = state
	queue_redraw()


func _ready() -> void:
	set_process(false)


func _draw() -> void:
	if not map_state:
		return

	var cols := DungeonMapState.W
	var rows := DungeonMapState.H
	var gap := 2.0
	var tile_size := Vector2(tile_px, tile_px)

	var total_w := cols * tile_size.x + (cols - 1) * gap
	var total_h := rows * tile_size.y + (rows - 1) * gap
	var origin: Vector2 = size - Vector2(total_w, total_h) * 0.5

	for y in range(rows):
		for x in range(cols):
			if not map_state.is_revealed(x, y):
				continue

			var pos: Vector2 = origin + Vector2(
				x * (tile_size.x + gap),
				y * (tile_size.y + gap)
			)
			var rect := Rect2(pos, tile_size)

			var color := Color(0.15, 0.15, 0.18, 1.0)
			if map_state.is_visited(x, y):
				color = Color(0.5, 0.7, 1.0, 1.0)

			var cur := map_state.get_current()
			if cur.x == x and cur.y == y:
				var outer := rect.grow(2.0)
				draw_rect(outer, Color(1.0, 0.8, 0.2, 1.0), false, 2.0)

			draw_rect(rect, color, true)
