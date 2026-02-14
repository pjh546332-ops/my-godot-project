extends Node3D

## 맵 기반 전투 스테이지: 턴/AP/이동/공격/사망/UI.

enum InputMode { NONE, MOVE, ATTACK }

@export var unit_scene: PackedScene = preload("res://Scenes/Battle/Units/UnitSprite3D.tscn")
const TurnControllerScript = preload("res://Scripts/Battle/battle_turn_controller.gd")

const MOVE_TWEEN_DURATION: float = 0.3
const TEAM_ALLY := 0
const TEAM_ENEMY := 1

@onready var map: BattleMap3D = $StageRoot3D/Map
@onready var units_root: Node3D = $StageRoot3D/Units
@onready var range_highlights: Node3D = $StageRoot3D/RangeHighlights
@onready var cam: Camera3D = $CameraRig/Camera3D
@onready var hud: Control = $CanvasLayer/HUD

var turn_controller: Node
var mode: InputMode = InputMode.NONE
var selected_unit: Node = null
var reachable_cells: Array[Vector2i] = []
var attackable_units: Array = []
var unit_cell: Dictionary = {}
var all_units: Array = []


func _ready() -> void:
	turn_controller = TurnControllerScript.new()
	add_child(turn_controller)
	turn_controller.round_changed.connect(_on_round_changed)
	turn_controller.turn_changed.connect(_on_turn_changed)
	turn_controller.battle_end.connect(_on_battle_end)
	if hud and hud.has_signal("request_move_mode"):
		hud.request_move_mode.connect(set_mode_move)
		hud.request_attack_mode.connect(set_mode_attack)
		hud.request_end_turn.connect(end_turn)
	if hud and hud.has_signal("request_overdrive_ap"):
		hud.request_overdrive_ap.connect(use_overdrive_ap)
		hud.request_overdrive_def.connect(use_overdrive_def)
	if map:
		map.rebuild_visuals()
	spawn_from_spawnpoints()
	_setup_camera()
	for u in units_root.get_children():
		if u.has_signal("clicked"):
			u.clicked.connect(_on_unit_clicked)
		if u.has_signal("died"):
			u.died.connect(_on_unit_died.bind(u))
	all_units.assign(units_root.get_children())
	turn_controller.start_battle(all_units)
	_update_ui()


func _setup_camera() -> void:
	if cam:
		cam.global_position = Vector3(6.0, 10.0, 6.0)
		cam.look_at(Vector3(6.0, 0.0, 3.0), Vector3.UP)
		cam.fov = 55.0


func spawn_from_spawnpoints() -> void:
	if not map or not map.map_data or not units_root or not unit_scene:
		return
	var ally_spawns: Array[UnitSpawnPoint] = map.get_spawn_points(TEAM_ALLY)
	var enemy_spawns: Array[UnitSpawnPoint] = map.get_spawn_points(TEAM_ENEMY)
	for i in range(ally_spawns.size()):
		var sp: UnitSpawnPoint = ally_spawns[i]
		var u: Node = unit_scene.instantiate()
		u.team = TEAM_ALLY
		u.unit_id = i
		u.unit_name = "Ally%d" % i
		u.max_hp = 10
		u.hp = 10
		u.atk = 3
		u.base_def = 0
		u.move_range = 5
		u.atk_range = 2
		u.max_ap = 2
		u.ap = 2
		u.max_strain = 10
		u.strain = 0
		u.strain_per_overdrive = 3
		u.overdrive_ap_bonus = 1
		u.overdrive_def_bonus = 2
		units_root.add_child(u)
		u.global_position = sp.get_world_pos(map.map_data)
		u.global_transform = Transform3D(sp.get_facing_basis(), u.global_position)
		unit_cell[u] = sp.grid
		_set_unit_color(u, Color(0.4, 0.7, 0.4, 1))
	for i in range(enemy_spawns.size()):
		var sp: UnitSpawnPoint = enemy_spawns[i]
		var u: Node = unit_scene.instantiate()
		u.team = TEAM_ENEMY
		u.unit_id = i
		u.unit_name = "Enemy%d" % i
		u.max_hp = 8
		u.hp = 8
		u.atk = 2
		u.base_def = 0
		u.move_range = 4
		u.atk_range = 2
		u.max_ap = 2
		u.ap = 2
		u.max_strain = 10
		u.strain = 0
		units_root.add_child(u)
		u.global_position = sp.get_world_pos(map.map_data)
		u.global_transform = Transform3D(sp.get_facing_basis(), u.global_position)
		unit_cell[u] = sp.grid
		_set_unit_color(u, Color(0.8, 0.4, 0.4, 1))


func _set_unit_color(u: Node, col: Color) -> void:
	if u.get_node_or_null("Sprite") is MeshInstance3D:
		var mat: StandardMaterial3D = (u.get_node("Sprite") as MeshInstance3D).material_override
		if mat:
			mat = mat.duplicate()
			mat.albedo_color = col
			(u.get_node("Sprite") as MeshInstance3D).material_override = mat


func _update_selection_visuals() -> void:
	for u in unit_cell:
		if is_instance_valid(u) and u.has_method("set_selected"):
			u.set_selected(u == selected_unit)


func _on_unit_died(unit: Node) -> void:
	unit_cell.erase(unit)


func _on_round_changed(_r: int) -> void:
	_update_ui()


func _on_turn_changed(unit: Node) -> void:
	mode = InputMode.NONE
	selected_unit = null
	_clear_highlights()
	_update_ui()
	if unit and unit.team == TEAM_ENEMY:
		call_deferred("_run_enemy_ai")


func _on_battle_end(ally_won: bool) -> void:
	_update_ui()
	if hud and hud.has_method("set_mode"):
		hud.set_mode("Battle End - %s" % ("Victory" if ally_won else "Defeat"))


func _update_ui() -> void:
	if not hud:
		return
	hud.set_round(turn_controller.round_num)
	var cu: Node = turn_controller.current_unit
	if cu:
		hud.set_turn(cu.unit_name if "unit_name" in cu else str(cu.unit_id))
		hud.set_ap(cu.ap if "ap" in cu else 0, cu.max_ap if "max_ap" in cu else 0)
		hud.set_strain(cu.strain if "strain" in cu else 0, cu.max_strain if "max_strain" in cu else 10)
		hud.set_overheat(cu.has_method("is_overheated") and cu.is_overheated())
		var ally_turn: bool = cu.team == TEAM_ALLY
		hud.set_overdrive_buttons_enabled(ally_turn)
	else:
		hud.set_turn("-")
		hud.set_ap(0, 0)
		hud.set_strain(0, 10)
		hud.set_overheat(false)
		hud.set_overdrive_buttons_enabled(false)
	var mode_str: String = "None"
	match mode:
		InputMode.MOVE: mode_str = "Move"
		InputMode.ATTACK: mode_str = "Attack"
	hud.set_mode(mode_str)
	_update_selection_visuals()


func set_mode_move() -> void:
	if turn_controller.current_unit and turn_controller.current_unit.team != TEAM_ALLY:
		return
	mode = InputMode.MOVE
	selected_unit = turn_controller.current_unit
	_clear_highlights()
	if selected_unit:
		_update_move_highlights()
	_update_ui()


func set_mode_attack() -> void:
	if turn_controller.current_unit and turn_controller.current_unit.team != TEAM_ALLY:
		return
	mode = InputMode.ATTACK
	selected_unit = turn_controller.current_unit
	_clear_highlights()
	if selected_unit:
		_update_attack_highlights()
	_update_ui()


func use_overdrive_ap() -> void:
	var cu: Node = turn_controller.current_unit
	if not cu or cu.team != TEAM_ALLY:
		return
	if cu.has_method("use_overdrive") and cu.use_overdrive(0):
		print("[BattleStage3D] %s used Overdrive +AP" % cu.unit_name)
	_update_ui()


func use_overdrive_def() -> void:
	var cu: Node = turn_controller.current_unit
	if not cu or cu.team != TEAM_ALLY:
		return
	if cu.has_method("use_overdrive") and cu.use_overdrive(1):
		print("[BattleStage3D] %s used Overdrive +DEF" % cu.unit_name)
	_update_ui()


func end_turn() -> void:
	mode = InputMode.NONE
	selected_unit = null
	_clear_highlights()
	turn_controller.next_turn()
	_update_ui()


func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		var ek: InputEventKey = event
		if ek.pressed:
			if ek.keycode == KEY_ESCAPE:
				mode = InputMode.NONE
				selected_unit = null
				_clear_highlights()
				_update_ui()
			elif ek.keycode == KEY_E:
				end_turn()


func _on_unit_clicked(unit: Node) -> void:
	if not is_instance_valid(unit) or not unit.has_method("is_alive") or not unit.is_alive():
		return
	if unit.team != TEAM_ALLY:
		if mode == InputMode.ATTACK and selected_unit:
			_try_attack(selected_unit, unit)
		return
	if turn_controller.current_unit != unit:
		return
	match mode:
		InputMode.NONE:
			selected_unit = unit
			_update_ui()
		InputMode.ATTACK:
			_try_attack(selected_unit, unit)


func _try_attack(attacker: Node, target: Node) -> void:
	if not attacker or not target:
		return
	if attacker.team == target.team:
		return
	var dist: int = _grid_distance(unit_cell.get(attacker, Vector2i(0, 0)), unit_cell.get(target, Vector2i(0, 0)))
	if dist > attacker.atk_range:
		return
	if not attacker.spend_ap(1):
		return
	var def_val: int = target.get_def() if target.has_method("get_def") else 0
	var dmg: int = maxi(0, attacker.atk - def_val)
	target.take_damage(dmg)
	mode = InputMode.NONE
	selected_unit = null
	_clear_highlights()
	_update_ui()
	print("[BattleStage3D] %s attacked %s for %d damage (DEF %d)" % [attacker.unit_name, target.unit_name, dmg, def_val])


func _grid_distance(a: Vector2i, b: Vector2i) -> int:
	return abs(a.x - b.x) + abs(a.y - b.y)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			var grid: Vector2i = _get_grid_at_cursor()
			if grid.x >= 0 and grid.y >= 0:
				_on_grid_clicked(grid)


func _on_grid_clicked(grid: Vector2i) -> void:
	if mode != InputMode.MOVE or not selected_unit:
		return
	for cell in reachable_cells:
		if cell.x == grid.x and cell.y == grid.y:
			if selected_unit.spend_ap(1):
				_move_unit_to(selected_unit, grid)
			mode = InputMode.NONE
			selected_unit = null
			_clear_highlights()
			_update_ui()
			return


func _get_unit_at_cursor() -> Node:
	if not cam:
		return null
	var from: Vector3 = cam.project_ray_origin(get_viewport().get_mouse_position())
	var dir: Vector3 = cam.project_ray_normal(get_viewport().get_mouse_position())
	var to: Vector3 = from + dir * 1000.0
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to)
	query.collide_with_areas = true
	query.collide_with_bodies = false
	query.collision_mask = 1
	var result: Dictionary = space.intersect_ray(query)
	var collider: Object = result.get("collider", null)
	if collider == null:
		return null
	var node: Node = collider
	while node:
		if node.has_signal("clicked") and node.has_method("is_alive") and node.is_alive():
			return node
		node = node.get_parent()
	return null


func _update_move_highlights() -> void:
	if not selected_unit or not map or not map.map_data:
		return
	var start: Vector2i = unit_cell.get(selected_unit, Vector2i(0, 0))
	var max_dist: int = selected_unit.move_range if "move_range" in selected_unit else 5
	reachable_cells = _bfs_reachable(start, max_dist)
	_create_cell_highlights(reachable_cells, Color(0.2, 0.9, 0.3, 0.5))


func _update_attack_highlights() -> void:
	if not selected_unit or not map or not map.map_data:
		return
	var attacker_cell: Vector2i = unit_cell.get(selected_unit, Vector2i(0, 0))
	var atk_range_val: int = selected_unit.atk_range if "atk_range" in selected_unit else 2
	attackable_units.clear()
	for u in unit_cell:
		if not is_instance_valid(u) or not u.has_method("is_alive") or not u.is_alive():
			continue
		if u.team == TEAM_ENEMY:
			var tc: Vector2i = unit_cell.get(u, Vector2i(0, 0))
			if _grid_distance(attacker_cell, tc) <= atk_range_val:
				attackable_units.append(u)
	_create_unit_highlights(attackable_units)


func _create_cell_highlights(cells: Array[Vector2i], col: Color) -> void:
	if not range_highlights or not map.map_data:
		return
	var cs: float = map.map_data.cell_size
	var orig: Vector3 = map.map_data.origin
	var half: float = cs * 0.5
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	for cell in cells:
		var mi := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2(cs * 0.9, cs * 0.9)
		mi.mesh = q
		mi.position = orig + Vector3(float(cell.x) * cs + half, 0.05, float(cell.y) * cs + half)
		mi.rotation_degrees = Vector3(-90, 0, 0)
		mi.material_override = mat
		range_highlights.add_child(mi)


func _create_unit_highlights(units_to_highlight: Array) -> void:
	if not range_highlights or not map.map_data:
		return
	var cs: float = map.map_data.cell_size * 0.8
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.9, 0.2, 0.2, 0.7)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	for u in units_to_highlight:
		if not is_instance_valid(u):
			continue
		var mi := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2(cs, cs)
		mi.mesh = q
		mi.material_override = mat
		mi.rotation_degrees = Vector3(-90, 0, 0)
		range_highlights.add_child(mi)
		mi.global_position = u.global_position + Vector3(0, 1.2, 0)


func _clear_highlights() -> void:
	if range_highlights:
		for ch in range_highlights.get_children():
			ch.queue_free()
	reachable_cells.clear()
	attackable_units.clear()


func _bfs_reachable(start: Vector2i, max_dist: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var visited: Dictionary = {}
	var queue: Array = [[start, 0]]
	visited[map.map_data.to_index(start.x, start.y)] = true
	var dirs: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	while queue.size() > 0:
		var cur: Vector2i = queue[0][0]
		var dist: int = queue[0][1]
		queue.pop_front()
		if dist > 0:
			out.append(cur)
		if dist >= max_dist:
			continue
		for d in dirs:
			var nx: int = cur.x + d.x
			var ny: int = cur.y + d.y
			if not map.map_data.in_bounds(nx, ny):
				continue
			if map.map_data.is_blocked(nx, ny):
				continue
			if _is_cell_occupied(nx, ny) and Vector2i(nx, ny) != start:
				continue
			var idx: int = map.map_data.to_index(nx, ny)
			if visited.has(idx):
				continue
			visited[idx] = true
			queue.append([Vector2i(nx, ny), dist + 1])
	return out


func _is_cell_occupied(gx: int, gy: int) -> bool:
	for u in unit_cell:
		if not is_instance_valid(u):
			continue
		var c: Vector2i = unit_cell[u]
		if c.x == gx and c.y == gy:
			return true
	return false


func _get_grid_at_cursor() -> Vector2i:
	if not map or not map.map_data or not cam:
		return Vector2i(-1, -1)
	var vp: Viewport = get_viewport()
	var from: Vector3 = cam.project_ray_origin(vp.get_mouse_position())
	var dir: Vector3 = cam.project_ray_normal(vp.get_mouse_position())
	var plane_normal: Vector3 = -map.global_transform.basis.y
	var plane_origin: Vector3 = map.global_position
	var denom: float = plane_normal.dot(dir)
	if abs(denom) < 0.0001:
		return Vector2i(-1, -1)
	var t: float = (plane_origin - from).dot(plane_normal) / denom
	if t < 0.0:
		return Vector2i(-1, -1)
	var hit: Vector3 = from + dir * t
	return map.map_data.world_to_grid(hit)


func _move_unit_to(unit: Node, target: Vector2i) -> void:
	if not map or not map.map_data:
		return
	var target_world: Vector3 = map.map_data.grid_to_world(target.x, target.y) + Vector3(0.0, 0.5, 0.0)
	unit_cell[unit] = target
	var tween: Tween = create_tween()
	tween.tween_property(unit, "global_position", target_world, MOVE_TWEEN_DURATION).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	print("[BattleStage3D] %s moved to grid %s" % [unit.unit_name if "unit_name" in unit else "unit", target])


func _run_enemy_ai() -> void:
	var enemy: Node = turn_controller.current_unit
	if not enemy or enemy.team != TEAM_ENEMY:
		end_turn()
		return
	var allies: Array = []
	for u in unit_cell:
		if is_instance_valid(u) and u.has_method("is_alive") and u.is_alive() and u.team == TEAM_ALLY:
			allies.append(u)
	if allies.is_empty():
		end_turn()
		return
	var ec: Vector2i = unit_cell.get(enemy, Vector2i(0, 0))
	var nearest: Node = null
	var nearest_dist: int = 999
	for a in allies:
		var d: int = _grid_distance(ec, unit_cell.get(a, Vector2i(0, 0)))
		if d < nearest_dist:
			nearest_dist = d
			nearest = a
	if nearest == null:
		end_turn()
		return
	var atk_range_val: int = enemy.atk_range if "atk_range" in enemy else 2
	if nearest_dist <= atk_range_val and enemy.ap >= 1:
		enemy.spend_ap(1)
		var def_val: int = nearest.get_def() if nearest.has_method("get_def") else 0
		var dmg: int = maxi(0, enemy.atk - def_val)
		nearest.take_damage(dmg)
		await get_tree().create_timer(0.4).timeout
		end_turn()
		return
	var reachable: Array[Vector2i] = _bfs_reachable(ec, enemy.move_range if "move_range" in enemy else 4)
	var best_cell: Vector2i = ec
	var best_dist: int = nearest_dist
	var nc: Vector2i = unit_cell.get(nearest, Vector2i(0, 0))
	for cell in reachable:
		if _is_cell_occupied(cell.x, cell.y):
			continue
		var d: int = _grid_distance(cell, nc)
		if d < best_dist and _grid_distance(cell, nc) <= atk_range_val:
			best_dist = d
			best_cell = cell
	if best_cell != ec and enemy.ap >= 1:
		enemy.spend_ap(1)
		unit_cell[enemy] = best_cell
		var tw: Vector3 = map.map_data.grid_to_world(best_cell.x, best_cell.y) + Vector3(0, 0.5, 0)
		var tween: Tween = create_tween()
		tween.tween_property(enemy, "global_position", tw, MOVE_TWEEN_DURATION)
		await tween.finished
		ec = best_cell
		nearest_dist = _grid_distance(ec, nc)
	if nearest_dist <= atk_range_val and enemy.ap >= 1 and is_instance_valid(nearest) and nearest.is_alive():
		enemy.spend_ap(1)
		var def_val: int = nearest.get_def() if nearest.has_method("get_def") else 0
		var dmg: int = maxi(0, enemy.atk - def_val)
		nearest.take_damage(dmg)
		await get_tree().create_timer(0.4).timeout
	end_turn()
