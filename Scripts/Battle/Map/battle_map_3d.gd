@tool
extends Node3D
class_name BattleMap3D

## BattleMap3D: 맵 시각화/스폰 포인트 제공. GridPlane = 레이캐스트 대상.

@export var map_data: BattleMapData
@export var show_debug_tiles: bool = true
@export var show_blocked_boxes: bool = true
## 에디터 전용: true면 에디터 클릭으로 blocked 토글
@export var editor_paint_blocked: bool = false
## 에디터 전용: true가 되면 rebuild_visuals 호출 후 false로 되돌림
@export var editor_rebuild_now: bool = false

@onready var grid_plane: MeshInstance3D = $GridPlane
@onready var tiles_root: Node3D = $Tiles
@onready var spawns_root: Node3D = $SpawnPoints
@onready var obstacles_root: Node3D = $Obstacles

var _spawn_points_by_team: Dictionary = {}  ## team (int) -> Array[UnitSpawnPoint]


func _ready() -> void:
	if not Engine.is_editor_hint():
		_build_grid_plane()
		_collect_spawn_points()
	else:
		rebuild_visuals()


func _process(_delta: float) -> void:
	if not Engine.is_editor_hint():
		return
	if editor_rebuild_now:
		editor_rebuild_now = false
		rebuild_visuals()


func _unhandled_input(event: InputEvent) -> void:
	if not Engine.is_editor_hint():
		return
	if not editor_paint_blocked:
		return
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if not mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT:
			return
		_editor_paint_blocked_at_cursor()


func _editor_paint_blocked_at_cursor() -> void:
	if map_data == null or not grid_plane:
		return
	var vp: Viewport = get_viewport()
	var cam: Camera3D = vp.get_camera_3d()
	if cam == null:
		return
	var from: Vector3 = cam.project_ray_origin(vp.get_mouse_position())
	var dir: Vector3 = cam.project_ray_normal(vp.get_mouse_position())
	# GridPlane은 XZ 평면(y=0, rotation -90 on X) -> 로컬에서 y=0 평면
	var plane_normal: Vector3 = -global_transform.basis.y
	var plane_origin: Vector3 = global_position
	var denom: float = plane_normal.dot(dir)
	if abs(denom) < 0.0001:
		return
	var t: float = (plane_origin - from).dot(plane_normal) / denom
	if t < 0.0:
		return
	var hit: Vector3 = from + dir * t
	var cell: Vector2i = map_data.world_to_grid(hit)
	if not map_data.in_bounds(cell.x, cell.y):
		return
	map_data.set_blocked(cell.x, cell.y, not map_data.is_blocked(cell.x, cell.y))
	rebuild_visuals()


func _build_grid_plane() -> void:
	if not grid_plane:
		return
	var w: float = 10.0
	var h: float = 6.0
	var cs: float = 1.0
	var orig: Vector3 = Vector3.ZERO
	if map_data:
		w = float(map_data.width) * map_data.cell_size
		h = float(map_data.height) * map_data.cell_size
		cs = map_data.cell_size
		orig = map_data.origin
	var plane := PlaneMesh.new()
	plane.size = Vector2(w, h)
	grid_plane.mesh = plane
	grid_plane.position = orig
	grid_plane.rotation_degrees = Vector3(-90, 0, 0)


func _collect_spawn_points() -> void:
	_spawn_points_by_team.clear()
	if not spawns_root:
		return
	for c in spawns_root.get_children():
		if c is UnitSpawnPoint:
			var t: int = c.team
			if not _spawn_points_by_team.has(t):
				_spawn_points_by_team[t] = []
			_spawn_points_by_team[t].append(c)
	for t in _spawn_points_by_team.keys():
		(_spawn_points_by_team[t] as Array).sort_custom(func(a, b) -> bool: return a.slot < b.slot)


func rebuild_visuals() -> void:
	_build_grid_plane()
	if tiles_root:
		for ch in tiles_root.get_children():
			ch.queue_free()
	if obstacles_root:
		for ch in obstacles_root.get_children():
			ch.queue_free()
	if map_data == null:
		return
	var cs: float = map_data.cell_size
	var orig: Vector3 = map_data.origin
	var half: float = cs * 0.5
	# 디버그 타일 (얇은 Quad)
	if show_debug_tiles and tiles_root:
		for y in range(map_data.height):
			for x in range(map_data.width):
				var mi := MeshInstance3D.new()
				var q := QuadMesh.new()
				q.size = Vector2(cs * 0.98, cs * 0.98)
				mi.mesh = q
				mi.position = orig + Vector3(float(x) * cs + half, 0.02, float(y) * cs + half)
				mi.rotation_degrees = Vector3(-90, 0, 0)
				var mat := StandardMaterial3D.new()
				mat.albedo_color = Color(0.35, 0.4, 0.45, 0.6)
				mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				mi.material_override = mat
				tiles_root.add_child(mi)
	# 막힌 칸 박스
	if show_blocked_boxes and obstacles_root:
		for idx in map_data.blocked:
			var gx: int = idx % map_data.width
			var gy: int = idx / map_data.width
			var mi := MeshInstance3D.new()
			var box := BoxMesh.new()
			box.size = Vector3(cs * 0.9, 0.3, cs * 0.9)
			mi.mesh = box
			mi.position = orig + Vector3(float(gx) * cs + half, 0.15, float(gy) * cs + half)
			var mat := StandardMaterial3D.new()
			mat.albedo_color = Color(0.7, 0.2, 0.2, 1.0)
			mi.material_override = mat
			obstacles_root.add_child(mi)


func get_spawn_points(team: int) -> Array[UnitSpawnPoint]:
	if _spawn_points_by_team.is_empty() and spawns_root:
		_collect_spawn_points()
	var arr: Array = _spawn_points_by_team.get(team, [])
	var out: Array[UnitSpawnPoint] = []
	for x in arr:
		if x is UnitSpawnPoint:
			out.append(x)
	return out


func get_spawn_world(team: int, slot: int) -> Array:
	## (Vector3 global_pos, Basis global_facing) 반환. 없으면 기본값.
	var default_pos := Vector3.ZERO
	var default_basis := Basis.IDENTITY
	var points: Array[UnitSpawnPoint] = get_spawn_points(team)
	for sp in points:
		if sp.slot == slot:
			var local_pos: Vector3 = sp.get_world_pos(map_data)
			var local_basis: Basis = sp.get_facing_basis()
			var local_t := Transform3D(local_basis, local_pos)
			var global_t: Transform3D = global_transform * local_t
			return [global_t.origin, global_t.basis]
	return [default_pos, default_basis]


func save_map_data(path: String) -> void:
	if map_data == null or path.is_empty():
		return
	ResourceSaver.save(map_data, path)


func load_map_data(path: String) -> void:
	if path.is_empty():
		return
	var res: Resource = load(path) as Resource
	if res is BattleMapData:
		map_data = res
		rebuild_visuals()
