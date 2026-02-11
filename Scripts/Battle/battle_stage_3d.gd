extends Node3D

## 3D 전투 무대에서 Units 아래에 Sprite3D를 스폰하고,
## 마우스 클릭으로 유닛 선택을 처리하는 컨트롤러.

signal unit_clicked(unit: BattleUnit)

const ALLY_SLOTS: Array[Vector3] = [
	Vector3(-6.0, 0.5, 1.4),  # 위-바깥
	Vector3(-4.8, 0.5, 0.7),  # 위-안쪽
	Vector3(-3.6, 0.5, 0.0),  # 화살촉(가장 오른쪽)
	Vector3(-4.8, 0.5, -0.7), # 아래-안쪽
	Vector3(-6.0, 0.5, -1.4), # 아래-바깥
]

const ENEMY_SLOTS: Array[Vector3] = [
	Vector3(6.0, 0.5, 1.4),   # 위-바깥
	Vector3(4.8, 0.5, 0.7),   # 위-안쪽
	Vector3(3.6, 0.5, 0.0),   # 화살촉(가장 왼쪽)
	Vector3(4.8, 0.5, -0.7),  # 아래-안쪽
	Vector3(6.0, 0.5, -1.4),  # 아래-바깥
]

@onready var units_root: Node3D = $StageRoot3D/Units
@onready var camera_3d: Camera3D = $Camera3D

var _placeholders_created: bool = false
var _ally_texture: Texture2D
var _enemy_texture: Texture2D

var _selected_unit: BattleUnit = null
var _selection_ring: MeshInstance3D = null
var _unit_nodes: Dictionary = {}
var _manager: BattleManager = null
var _active_unit_id: String = ""
var _target_unit_id: String = ""


func _ready() -> void:
	## 카메라를 약 45도 내려다보는 시점으로 설정
	if camera_3d:
		camera_3d.global_position = Vector3(0.0, 9.0, 9.0)
		camera_3d.look_at(Vector3(0.0, 0.8, 0.0), Vector3.UP)
		camera_3d.fov = 55.0


func spawn_units_from_manager(manager: BattleManager) -> void:
	## 기존 유닛 로직(BattleManager.get_all_units)에서 목록을 받아 3D 스테이지에 배치.
	if not units_root or manager == null:
		return

	_manager = manager

	_clear_units()
	_clear_selection()
	_ensure_placeholder_textures()

	var allies: Array = []
	var enemies: Array = []

	for u in manager.get_all_units():
		if not u.is_alive():
			continue
		if u.is_ally():
			allies.append(u)
		elif u.is_enemy():
			enemies.append(u)

	var idx := 0
	for u in allies:
		if idx >= ALLY_SLOTS.size():
			break
		_spawn_unit_sprite(u, ALLY_SLOTS[idx], _ally_texture, Color(0.5, 0.9, 0.5, 1.0))
		idx += 1

	idx = 0
	for u in enemies:
		if idx >= ENEMY_SLOTS.size():
			break
		_spawn_unit_sprite(u, ENEMY_SLOTS[idx], _enemy_texture, Color(0.95, 0.5, 0.5, 1.0))
		idx += 1

	# 유닛 스폰 이전에 활성화 요청이 들어온 경우(pending)를 처리
	if _active_unit_id != "":
		set_active_unit(_active_unit_id)


func _clear_units() -> void:
	clear_active_unit()
	clear_target_unit()
	for c in units_root.get_children():
		c.queue_free()
	_unit_nodes.clear()


func _ensure_placeholder_textures() -> void:
	if _placeholders_created:
		return

	_ally_texture = _make_placeholder_texture(Color(0.3, 0.7, 0.3, 1.0))
	_enemy_texture = _make_placeholder_texture(Color(0.7, 0.3, 0.3, 1.0))
	_placeholders_created = true


func _make_placeholder_texture(base_color: Color) -> Texture2D:
	var size := 64
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	for y in range(size):
		for x in range(size):
			var border := (x < 4 or x >= size - 4 or y < 4 or y >= size - 4)
			if border:
				img.set_pixel(x, y, Color(0.1, 0.1, 0.1, 1.0))
			else:
				img.set_pixel(x, y, base_color)

	var tex := ImageTexture.new()
	tex.set_image(img)
	return tex


func _spawn_unit_sprite(unit: BattleUnit, local_pos: Vector3, tex: Texture2D, tint: Color) -> void:
	## 단일 유닛 컨테이너 노드 (트랜스폼/선택 링 기준점)
	var holder := Node3D.new()
	holder.position = local_pos
	holder.set_meta("unit_ref", unit)
	# 원본 스케일/높이를 메타로 보관 (강조/복원에 사용)
	holder.set_meta("base_scale", holder.scale)
	holder.set_meta("base_y", holder.position.y)
	units_root.add_child(holder)
	_unit_nodes[unit.name] = holder

	## 클릭 판정을 위한 Area3D + CollisionShape3D
	var area := Area3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.8, 1.6, 0.8)
	shape.shape = box
	shape.position = Vector3(0, 0.8, 0)
	area.collision_layer = 2
	area.collision_mask = 0
	area.add_child(shape)
	holder.add_child(area)

	# 유닛 정의에 스프라이트가 있으면 우선 사용
	var sprite_tex: Texture2D = tex
	if unit.definition and unit.definition.sprite_3d:
		sprite_tex = unit.definition.sprite_3d

	## 아웃라인 Sprite3D (노란 테두리, 기본 비활성)
	var outline := Sprite3D.new()
	outline.name = "Outline"
	outline.texture = sprite_tex
	outline.modulate = Color(1.0, 1.0, 0.2, 1.0)
	outline.pixel_size = 0.01
	outline.position = Vector3(0, 0.8, 0)
	outline.scale = Vector3(1.12, 1.12, 1.0)
	outline.visible = false
	holder.add_child(outline)

	## 실제 표시용 Sprite3D (아웃라인 위에 렌더되도록 나중에 추가)
	var sprite := Sprite3D.new()
	sprite.name = "Sprite"
	sprite.texture = sprite_tex
	sprite.modulate = tint
	sprite.pixel_size = 0.01
	sprite.position = Vector3(0, 0.8, 0)
	holder.add_child(sprite)

	## HP 텍스트 Label3D
	var hp_label := Label3D.new()
	hp_label.name = "HPLabel"
	hp_label.position = Vector3(0, 2.0, 0)
	hp_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	if "max_hp" in unit:
		hp_label.text = "HP: %d/%d" % [unit.hp, unit.max_hp]
	else:
		hp_label.text = "HP: %d" % unit.hp
	hp_label.pixel_size = 0.01
	holder.add_child(hp_label)


func _process(_delta: float) -> void:
	## 매 프레임 카메라를 향하도록 회전 (billboard 효과)
	if not camera_3d or not units_root:
		return
	var cam_pos: Vector3 = camera_3d.global_position
	for c in units_root.get_children():
		if c is Node3D:
			var n := c as Node3D
			n.look_at(cam_pos, Vector3.UP)


func _unhandled_input(event: InputEvent) -> void:
	## UI 위 클릭은 무시하고, 월드 영역만 처리
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if not mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT:
			return

		var hovered := get_viewport().gui_get_hovered_control()
		if hovered != null and hovered is Control and (hovered as Control).mouse_filter == Control.MOUSE_FILTER_STOP:
			return

		_perform_unit_pick(mb.position)


func _perform_unit_pick(screen_pos: Vector2) -> void:
	if not camera_3d:
		return

	var from: Vector3 = camera_3d.project_ray_origin(screen_pos)
	var dir: Vector3 = camera_3d.project_ray_normal(screen_pos)
	var to: Vector3 = from + dir * 1000.0

	var space_state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to)
	query.collide_with_areas = true
	query.collide_with_bodies = false
	query.collision_mask = 2
	var result: Dictionary = space_state.intersect_ray(query)
	var hit_collider: Object = result.get("collider", null)
	print("[PICK] collider=", str(result.get("collider")))
	if result.is_empty():
		_clear_selection()
		clear_target_unit()
		return

	var collider: Object = hit_collider
	if collider == null:
		_clear_selection()
		return

	var unit: BattleUnit = null
	if collider.has_meta("unit_ref"):
		unit = collider.get_meta("unit_ref")
	elif collider.get_parent() and collider.get_parent().has_meta("unit_ref"):
		unit = collider.get_parent().get_meta("unit_ref")

	if unit == null:
		_clear_selection()
		return

	var holder: Node3D = null
	if collider is Node3D and collider.has_meta("unit_ref"):
		holder = collider
	elif collider.get_parent() and collider.get_parent() is Node3D:
		holder = collider.get_parent()

	if holder == null:
		_clear_selection()
		return

	# 타겟 선택 모드: 적 클릭 시 BattleManager 전달 + 선택 링 + 타겟 Outline 강조
	if _manager != null and _manager._state == BattleManager.State.ALLY_SELECT_TARGET:
		if unit.is_enemy() and unit.is_alive():
			_manager.on_enemy_clicked(unit)
			_set_selection(unit, holder.global_position)
			set_target_unit(unit.name)
			return

	# 그 외 상태에서도 현재는 StatsPanel 기능을 완전히 OFF 하기 위해
	# unit_clicked 시그널을 emit 하지 않는다. 선택 링만 갱신.
	_set_selection(unit, holder.global_position)


func _ensure_selection_ring() -> void:
	if _selection_ring and is_instance_valid(_selection_ring):
		return

	var mesh := PlaneMesh.new()
	mesh.size = Vector2(0.9, 0.9)

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 1.0, 0.3, 0.7)
	mat.flags_unshaded = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	_selection_ring = MeshInstance3D.new()
	_selection_ring.mesh = mesh
	_selection_ring.material_override = mat
	_selection_ring.rotation_degrees = Vector3(-90, 0, 0)
	_selection_ring.visible = false
	add_child(_selection_ring)


func _set_selection(unit: BattleUnit, world_pos: Vector3) -> void:
	_ensure_selection_ring()
	_selected_unit = unit
	_selection_ring.global_position = Vector3(world_pos.x, 0.01, world_pos.z)
	_selection_ring.visible = true


func _clear_selection() -> void:
	_selected_unit = null
	if _selection_ring and is_instance_valid(_selection_ring):
		_selection_ring.visible = false


func _get_unit_node(unit_id: String) -> Node3D:
	if not _unit_nodes.has(unit_id):
		return null
	var node: Node3D = _unit_nodes[unit_id]
	if not is_instance_valid(node):
		_unit_nodes.erase(unit_id)
		return null
	return node


func _set_outline_color(holder: Node3D, c: Color) -> void:
	var outline: Sprite3D = holder.get_node_or_null("Outline")
	if outline:
		outline.modulate = c


func _set_outline_visible(holder: Node3D, on: bool) -> void:
	var outline: Sprite3D = holder.get_node_or_null("Outline")
	if outline:
		outline.visible = on


func _clear_all_outlines() -> void:
	for id in _unit_nodes.keys():
		var h: Node3D = _get_unit_node(id)
		if h:
			_set_outline_visible(h, false)


func update_hp_label(unit_id: String) -> void:
	var holder := _get_unit_node(unit_id)
	if holder == null:
		return
	if not holder.has_meta("unit_ref"):
		return
	var unit: BattleUnit = holder.get_meta("unit_ref")
	if unit == null:
		return
	var hp_label: Label3D = holder.get_node_or_null("HPLabel")
	if hp_label == null:
		return
	if "max_hp" in unit:
		hp_label.text = "HP: %d/%d" % [unit.hp, unit.max_hp]
	else:
		hp_label.text = "HP: %d" % unit.hp


func get_active_unit_head_world_pos() -> Vector3:
	if _active_unit_id == "":
		return Vector3.ZERO
	var holder := _get_unit_node(_active_unit_id)
	if holder == null:
		return Vector3.ZERO
	return holder.global_position + Vector3(0, 2.0, 0)


func set_active_unit(unit_id: String) -> void:
	if unit_id == _active_unit_id:
		return

	var holder_pending := _get_unit_node(unit_id)
	if holder_pending == null:
		_active_unit_id = unit_id
		return

	# 턴이 돌아와도 강조가 남지 않도록 전체 Outline 초기화 후 active/target만 재적용
	_clear_all_outlines()

	_active_unit_id = unit_id
	var holder: Node3D = holder_pending
	_set_outline_visible(holder, true)
	_set_outline_color(holder, Color(1.0, 1.0, 0.2, 1.0))

	# Attack 상태에서 선택된 타겟이 있으면 타겟 Outline 복원
	if _target_unit_id != "":
		var target_holder: Node3D = _get_unit_node(_target_unit_id)
		if target_holder:
			_set_outline_visible(target_holder, true)
			_set_outline_color(target_holder, Color(1.0, 0.85, 0.15, 1.0))


func clear_active_unit() -> void:
	if _active_unit_id == "":
		return
	var holder := _get_unit_node(_active_unit_id)
	if holder:
		_set_outline_visible(holder, false)
	_active_unit_id = ""


func set_target_unit(unit_id: String) -> void:
	if unit_id == _target_unit_id:
		return
	if _target_unit_id != "":
		var prev: Node3D = _get_unit_node(_target_unit_id)
		if prev:
			_set_outline_visible(prev, false)
	_target_unit_id = unit_id
	var holder: Node3D = _get_unit_node(unit_id)
	if holder:
		_set_outline_visible(holder, true)
		_set_outline_color(holder, Color(1.0, 0.85, 0.15, 1.0))


func clear_target_unit() -> void:
	if _target_unit_id == "":
		return
	var holder := _get_unit_node(_target_unit_id)
	if holder:
		_set_outline_visible(holder, false)
	_target_unit_id = ""


func play_turn_started(unit_id: String) -> void:
	set_active_unit(unit_id)


func play_action_resolved(attacker_id: String, target_id: String, amount: int) -> void:
	if amount <= 0:
		return
	var holder: Node3D = _get_unit_node(target_id)
	if holder == null:
		return

	## 피격 플래시 (Sprite 색상 튕김)
	var sprite: Sprite3D = holder.get_node_or_null("Sprite")
	if sprite:
		var base_color: Color = sprite.modulate
		var tween_flash: Tween = create_tween()
		tween_flash.tween_property(sprite, "modulate", Color(1.0, 0.6, 0.6, 1.0), 0.05)
		tween_flash.tween_property(sprite, "modulate", base_color, 0.15)

	## 데미지 텍스트 (위로 튀면서 페이드 아웃)
	var label: Label3D = Label3D.new()
	label.text = str(-amount)
	label.modulate = Color(1.0, 0.9, 0.4, 1.0)
	label.pixel_size = 0.01
	label.position = Vector3(0, 1.6, 0)
	holder.add_child(label)

	var tween_text: Tween = create_tween()
	tween_text.tween_property(label, "position:y", label.position.y + 0.6, 0.4)
	tween_text.parallel().tween_property(label, "modulate:a", 0.0, 0.4)
	tween_text.tween_callback(label.queue_free)


func play_unit_defeated(unit_id: String) -> void:
	var holder: Node3D = _get_unit_node(unit_id)
	if holder == null:
		return
	# 스케일/포지션 tween 없이 짧은 지연 후 제거만 수행
	var id_for_callback: String = unit_id
	var t: Tween = create_tween()
	t.tween_interval(0.2)
	t.tween_callback(func() -> void:
		if is_instance_valid(holder):
			holder.queue_free()
		_unit_nodes.erase(id_for_callback)
	)
