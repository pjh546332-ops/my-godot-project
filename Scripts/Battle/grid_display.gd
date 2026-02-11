class_name GridDisplay
extends Node2D
## 전투 그리드 시각화. 10x5 전체 보드 대신, 5x5 등 가변 크기를 지원한다.

const CELL_SIZE: int = 64
const GRID_W: int = 10 ## 기본값(하위 호환용, 사용은 지양)
const GRID_H: int = 5  ## 기본값(하위 호환용, 사용은 지양)

@export var grid_w: int = 5
@export var grid_h: int = 5
@export var grid_alpha: float = 0.18
@export var perspective_enabled: bool = true
@export var near_width: float = 360.0    # 아래쪽(카메라 가까운 쪽) 폭
@export var far_width: float = 260.0     # 위쪽(카메라 먼 쪽) 폭
@export var depth: float = 260.0         # 보드 세로(깊이)
@export var top_y_offset: float = 0.0    # 필요 시 위쪽 위치 미세 조정

func _draw() -> void:
	var vertical_color: Color = Color(1, 1, 1, clampf(grid_alpha * 1.2, 0.0, 1.0))
	var horizontal_color: Color = Color(1, 1, 1, clampf(grid_alpha * 0.8, 0.0, 1.0))

	if not perspective_enabled:
		# 기존 정사각 그리드 모드
		for x in range(grid_w + 1):
			var from: Vector2 = Vector2(x * CELL_SIZE, 0)
			var to: Vector2 = Vector2(x * CELL_SIZE, grid_h * CELL_SIZE)
			draw_line(from, to, vertical_color)

		for y in range(grid_h + 1):
			var from: Vector2 = Vector2(0, y * CELL_SIZE)
			var to: Vector2 = Vector2(grid_w * CELL_SIZE, y * CELL_SIZE)
			draw_line(from, to, horizontal_color)
		return

	# 원근 그리드 모드: 사다리꼴 위에 그리드를 그림
	for row in range(grid_h + 1):
		var v: float = float(row) / float(grid_h)
		var a: Vector2 = _map_uv(0.0, v)
		var b: Vector2 = _map_uv(1.0, v)
		# 가로선(깊이 방향)
		draw_line(a, b, horizontal_color)

	for col in range(grid_w + 1):
		var u: float = float(col) / float(grid_w)
		var a2: Vector2 = _map_uv(u, 0.0)
		var b2: Vector2 = _map_uv(u, 1.0)
		# 세로선(좌우 방향)
		draw_line(a2, b2, vertical_color)

func cell_to_position(cell: Vector2i) -> Vector2:
	if not perspective_enabled:
		return Vector2(
			cell.x * CELL_SIZE + CELL_SIZE / 2,
			cell.y * CELL_SIZE + CELL_SIZE / 2
		)

	var u: float = (float(cell.x) + 0.5) / float(grid_w)
	var v: float = (float(cell.y) + 0.5) / float(grid_h)
	return _map_uv(u, v)


func _map_uv(u: float, v: float) -> Vector2:
	# 보드 4 꼭짓점 계산 (로컬 좌표계)
	var half_near: float = near_width * 0.5
	var half_far: float = far_width * 0.5

	var bottom_left: Vector2 = Vector2(-half_near, depth + top_y_offset)
	var bottom_right: Vector2 = Vector2(half_near, depth + top_y_offset)
	var top_left: Vector2 = Vector2(-half_far, 0.0 + top_y_offset)
	var top_right: Vector2 = Vector2(half_far, 0.0 + top_y_offset)

	var top: Vector2 = top_left.lerp(top_right, u)
	var bottom: Vector2 = bottom_left.lerp(bottom_right, u)
	return top.lerp(bottom, v)
