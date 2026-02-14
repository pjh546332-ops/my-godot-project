extends Node3D
class_name UnitSpawnPoint

## 스폰 포인트: 팀/슬롯/그리드 좌표/방향.
## 0=ALLY, 1=ENEMY

@export var team: int = 0  ## 0=ALLY, 1=ENEMY
@export var slot: int = 0  ## 0..N
@export var grid: Vector2i = Vector2i.ZERO  ## 맵 그리드 좌표 (씬에서 지정)
@export var yaw_degrees: float = 0.0  ## 바닥 평면 회전 (도)


func get_world_pos(map_data: BattleMapData) -> Vector3:
	if map_data == null:
		return global_position
	return map_data.grid_to_world(grid.x, grid.y) + Vector3(0.0, 0.5, 0.0)


func get_facing_basis() -> Basis:
	return Basis.from_euler(Vector3(0.0, deg_to_rad(yaw_degrees), 0.0))
