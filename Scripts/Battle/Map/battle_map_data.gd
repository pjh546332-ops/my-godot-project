extends Resource
class_name BattleMapData

## 맵 크기 및 타일 정보 저장용 Resource.
## blocked: 막힌 칸 인덱스 (idx = y*width + x)

@export var width: int = 10
@export var height: int = 6
@export var cell_size: float = 1.0
@export var origin: Vector3 = Vector3.ZERO
@export var blocked: PackedInt32Array = []  ## 막힌 칸 인덱스 목록


func to_index(x: int, y: int) -> int:
	return y * width + x


func in_bounds(x: int, y: int) -> bool:
	return x >= 0 and x < width and y >= 0 and y < height


func is_blocked(x: int, y: int) -> bool:
	if not in_bounds(x, y):
		return true
	var idx := to_index(x, y)
	return blocked.has(idx)


func set_blocked(x: int, y: int, v: bool) -> void:
	if not in_bounds(x, y):
		return
	var idx := to_index(x, y)
	var i: int = blocked.find(idx)
	if v and i < 0:
		blocked.append(idx)
		blocked.sort()
	elif not v and i >= 0:
		blocked.remove_at(i)


func grid_to_world(x: int, y: int) -> Vector3:
	return origin + Vector3(float(x) * cell_size, 0.0, float(y) * cell_size)


func world_to_grid(p: Vector3) -> Vector2i:
	var ox: float = origin.x
	var oz: float = origin.z
	var cs: float = cell_size
	if cs <= 0.0:
		cs = 1.0
	var gx: int = int(roundf((p.x - ox) / cs))
	var gy: int = int(roundf((p.z - oz) / cs))
	return Vector2i(gx, gy)
