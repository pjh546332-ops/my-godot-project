extends Node3D

## 유닛 3D 스프라이트: HP/AP/ATK/DEF, Overdrive/Strain, 클릭 시그널, 턴/사망 처리.

signal clicked(unit: Node)
signal died(unit: Node)
signal stats_changed(unit: Node)

@export var team: int = 0  ## 0=ALLY, 1=ENEMY
@export var unit_id: int = 0
@export var unit_name: String = "Unit"
@export var max_hp: int = 10
@export var hp: int = 10
@export var atk: int = 3
@export var base_def: int = 0
@export var move_range: int = 5
@export var atk_range: int = 2
@export var max_ap: int = 2
@export var ap: int = 2
## Overdrive / Strain
@export var max_strain: int = 10
@export var strain: int = 0
@export var strain_per_overdrive: int = 3
@export var overdrive_ap_bonus: int = 1
@export var overdrive_def_bonus: int = 2
@export var temp_def_bonus: int = 0  ## 턴 종료 시 초기화
@export var overdrive_used_this_turn: int = 0

@onready var sprite: MeshInstance3D = $Sprite
@onready var click_area: Area3D = $ClickArea
@onready var base_ring: MeshInstance3D = $BaseRing if has_node("BaseRing") else null
@onready var team_icon: Node3D = $TeamIcon if has_node("TeamIcon") else null

var grid: Vector2i = Vector2i.ZERO  ## 현재 그리드 셀 (이동/스폰 시 갱신)

var _is_dead: bool = false
var _overheated: bool = false  ## 다음 턴 AP-1 페널티 예약
var _selected: bool = false


func set_grid(g: Vector2i) -> void:
	grid = g


func is_adjacent_to(other: Node) -> bool:
	if not other or not "grid" in other:
		return false
	return _manhattan_distance(grid, other.grid) == 1


func get_adjacent_enemies(all_units: Array) -> Array:
	var out: Array = []
	for u in all_units:
		if not is_instance_valid(u) or u == self:
			continue
		if not u.has_method("is_alive") or not u.is_alive():
			continue
		if u.team == team:
			continue
		if is_adjacent_to(u):
			out.append(u)
	return out


func _manhattan_distance(a: Vector2i, b: Vector2i) -> int:
	return abs(a.x - b.x) + abs(a.y - b.y)


func _ready() -> void:
	if click_area:
		click_area.input_event.connect(_on_click_area_input)
	_update_visuals()


func _process(_delta: float) -> void:
	if sprite:
		var cam: Camera3D = get_viewport().get_camera_3d()
		if cam:
			var target := Vector3(cam.global_position.x, global_position.y, cam.global_position.z)
			sprite.look_at(target, Vector3.UP)


func get_def() -> int:
	return base_def + temp_def_bonus


func set_selected(v: bool) -> void:
	_selected = v
	_update_visuals()


func begin_turn() -> void:
	ap = max_ap
	temp_def_bonus = 0
	overdrive_used_this_turn = 0
	if _overheated:
		ap = maxi(0, ap - 1)
		_overheated = false
		strain = maxi(0, strain - 4)
	stats_changed.emit(self)


func use_overdrive(mode: int) -> bool:
	## mode 0=+AP, 1=+DEF
	if ap < 0:
		return false
	## Overdrive +AP는 턴에 한 번만
	if mode == 0 and overdrive_used_this_turn > 0:
		return false
	## strain 초과 허용, 리스크로 처리
	if mode == 0:
		ap += overdrive_ap_bonus
	elif mode == 1:
		temp_def_bonus += overdrive_def_bonus
	strain += strain_per_overdrive
	overdrive_used_this_turn += 1
	_apply_strain_risk_if_needed()
	stats_changed.emit(self)
	return true


func _apply_strain_risk_if_needed() -> void:
	## 확장 가능: 추후 불이익 규칙 추가
	if strain >= max_strain:
		_overheated = true


func is_overheated() -> bool:
	return _overheated


func _update_visuals() -> void:
	if base_ring:
		var mat: Material = base_ring.material_override
		if mat:
			mat = mat.duplicate()
			if team == 0:  ## ALLY
				(mat as StandardMaterial3D).albedo_color = Color(0.2, 0.8, 0.5, 0.9)
			else:
				(mat as StandardMaterial3D).albedo_color = Color(0.9, 0.2, 0.2, 0.95)
			base_ring.material_override = mat
		if _selected:
			base_ring.scale = Vector3(1.2, 1.0, 1.2)
		else:
			base_ring.scale = Vector3(1.0, 1.0, 1.0)
	if team_icon and team_icon is MeshInstance3D:
		var mi: MeshInstance3D = team_icon as MeshInstance3D
		var m: Material = mi.material_override
		if m:
			m = m.duplicate()
			if team == 0:
				(m as StandardMaterial3D).albedo_color = Color(0.3, 1.0, 0.6, 1.0)
			else:
				(m as StandardMaterial3D).albedo_color = Color(1.0, 0.3, 0.3, 1.0)
			mi.material_override = m


func spend_ap(cost: int) -> bool:
	if ap >= cost:
		ap -= cost
		stats_changed.emit(self)
		return true
	return false


func take_damage(dmg: int) -> void:
	hp = clampi(hp - dmg, 0, max_hp)
	stats_changed.emit(self)
	if hp <= 0:
		die()


func die() -> void:
	if _is_dead:
		return
	_is_dead = true
	died.emit(self)
	queue_free()


func is_alive() -> bool:
	return not _is_dead


func _on_click_area_input(_cam: Node, event: InputEvent, _pos: Vector3, _normal: Vector3, _shape: int) -> void:
	if _is_dead:
		return
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			clicked.emit(self)
