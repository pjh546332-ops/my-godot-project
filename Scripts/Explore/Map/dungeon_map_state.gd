extends Resource
class_name DungeonMapState

const W := 5
const H := 5

var revealed: Array = [] # [H][W] bool
var visited: Array = []  # [H][W] bool
var current: Vector2i = Vector2i(2, 2)


func init_grid() -> void:
	revealed.resize(H)
	visited.resize(H)
	for y in range(H):
		revealed[y] = []
		revealed[y].resize(W)
		visited[y] = []
		visited[y].resize(W)
		for x in range(W):
			revealed[y][x] = false
			visited[y][x] = false

	current = Vector2i(2, 2)
	_set_cell(current.x, current.y, true, true)
	reveal_neighbors()


func _in_bounds(x: int, y: int) -> bool:
	return x >= 0 and x < W and y >= 0 and y < H


func _set_cell(x: int, y: int, rev: bool, vis: bool) -> void:
	if not _in_bounds(x, y):
		return
	if rev:
		revealed[y][x] = true
	if vis:
		visited[y][x] = true


func move(dir: Vector2i) -> bool:
	var next := current + dir
	if not _in_bounds(next.x, next.y):
		return false
	current = next
	_set_cell(current.x, current.y, true, true)
	reveal_neighbors()
	return true


func reveal_neighbors() -> void:
	var dirs: Array[Vector2i] = [
		Vector2i(1, 0),
		Vector2i(-1, 0),
		Vector2i(0, 1),
		Vector2i(0, -1),
	]
	for d: Vector2i in dirs:
		var p: Vector2i = current + d
		if _in_bounds(p.x, p.y):
			revealed[p.y][p.x] = true


func get_current() -> Vector2i:
	return current


func is_revealed(x: int, y: int) -> bool:
	if not _in_bounds(x, y):
		return false
	return bool(revealed[y][x])


func is_visited(x: int, y: int) -> bool:
	if not _in_bounds(x, y):
		return false
	return bool(visited[y][x])
