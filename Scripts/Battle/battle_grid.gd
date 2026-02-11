class_name BattleGrid
extends RefCounted
## 10x5 전투 그리드: 아군 5x5 + 적군 5x5

const GRID_WIDTH: int = 10
const GRID_HEIGHT: int = 5

const ALLY_MIN_X: int = 0
const ALLY_MAX_X: int = 4
const ENEMY_MIN_X: int = 5
const ENEMY_MAX_X: int = 9

const CELL_SIZE: int = 64

static func is_valid_cell(c: Vector2i) -> bool:
	return c.x >= 0 and c.x < GRID_WIDTH and c.y >= 0 and c.y < GRID_HEIGHT

static func is_ally_cell(cell: Vector2i) -> bool:
	return is_valid_cell(cell) and cell.x >= ALLY_MIN_X and cell.x <= ALLY_MAX_X

static func is_enemy_cell(cell: Vector2i) -> bool:
	return is_valid_cell(cell) and cell.x >= ENEMY_MIN_X and cell.x <= ENEMY_MAX_X

static func clamp_to_board(cell: Vector2i) -> Vector2i:
	var x := clampi(cell.x, 0, GRID_WIDTH - 1)
	var y := clampi(cell.y, 0, GRID_HEIGHT - 1)
	return Vector2i(x, y)

static func to_world(cell: Vector2i) -> Vector2:
	return Vector2(cell.x * CELL_SIZE + CELL_SIZE / 2, cell.y * CELL_SIZE + CELL_SIZE / 2)

static func to_cell(pos: Vector2) -> Vector2i:
	return Vector2i(int(floor(pos.x / CELL_SIZE)), int(floor(pos.y / CELL_SIZE)))

static func get_front_row(side: int) -> int:
	## 아군은 y=0이 전열, 적은 y=4가 전열
	if side == BattleUnit.Team.ALLY:
		return 0
	return GRID_HEIGHT - 1

static func distance_to_front(cell: Vector2i, side: int) -> int:
	var front: int = get_front_row(side)
	return absi(cell.y - front)

static func get_speed_bonus(cell: Vector2i, side: int) -> int:
	## 적과 가까운 전열일수록 +0~+2. 여기서는 전열에서 가까울수록 2,1,0
	var d: int = distance_to_front(cell, side)
	if d == 0:
		return 2
	if d == 1:
		return 1
	return 0

static func clamp_speed(s: int) -> int:
	return clampi(s, 1, 12)
