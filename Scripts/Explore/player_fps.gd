extends CharacterBody3D
class_name PlayerFPS

@export var move_speed: float = 4.0
@export var mouse_sensitivity: float = 0.002

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var ray: RayCast3D = $Head/RayCast3D

var _yaw: float = 0.0
var _pitch: float = 0.0
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity") as float
var _debug_timer: float = 0.0
var _ray_log_cooldown: float = 0.0


func _ready() -> void:
	_ensure_input_actions()
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	ray.enabled = true
	ray.collide_with_areas = true
	print("Player ready")


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_yaw -= event.relative.x * mouse_sensitivity
		_pitch -= event.relative.y * mouse_sensitivity
		_pitch = clamp(_pitch, deg_to_rad(-80.0), deg_to_rad(80.0))

		rotation.y = _yaw
		head.rotation.x = _pitch

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		# 문 상호작용을 우선 처리, 실패 시 아이템 픽업
		if not _try_interact():
			_try_pick_item()

	if event is InputEventKey and event.pressed and event.keycode == KEY_E:
		_try_interact()


func _physics_process(delta: float) -> void:
	# 중력 적용 (항상 아래 방향)
	velocity.y -= _gravity * delta

	if _ray_log_cooldown > 0.0:
		_ray_log_cooldown -= delta

	var input_dir: Vector3 = Vector3.ZERO

	# WASD / 방향키 입력: move_* 액션 + 키 폴백
	var forward_pressed := Input.is_action_pressed("move_forward") \
		or Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP)
	var backward_pressed := Input.is_action_pressed("move_backward") \
		or Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN)
	var left_pressed := Input.is_action_pressed("move_left") \
		or Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT)
	var right_pressed := Input.is_action_pressed("move_right") \
		or Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT)

	if forward_pressed:
		input_dir -= transform.basis.z
	if backward_pressed:
		input_dir += transform.basis.z
	if left_pressed:
		input_dir -= transform.basis.x
	if right_pressed:
		input_dir += transform.basis.x

	# y축 이동은 무시 (점프 없음)
	input_dir.y = 0.0

	var dir: Vector3 = Vector3.ZERO
	if input_dir != Vector3.ZERO:
		dir = input_dir.normalized()

		# 이동 방향 디버그 로그
		if Input.is_action_just_pressed("move_forward") or Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
			print("Moving forward")
		if Input.is_action_just_pressed("move_backward") or Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
			print("Moving backward")

	# 수평 속도만 입력으로 갱신, 수직은 중력 유지
	var hvel := dir * move_speed
	velocity.x = hvel.x
	velocity.z = hvel.z

	move_and_slide()

	# 진단 로그 (1초에 한 번)
	_debug_timer += delta
	if _debug_timer >= 1.0:
		_debug_timer = 0.0
		print("[PlayerFPS] F:%s B:%s L:%s R:%s vel=(%.2f, %.2f)" % [
			str(forward_pressed),
			str(backward_pressed),
			str(left_pressed),
			str(right_pressed),
			velocity.x,
			velocity.z,
		])


func _ensure_input_actions() -> void:
	_add_action_if_missing("move_forward")
	_add_action_if_missing("move_backward")
	_add_action_if_missing("move_left")
	_add_action_if_missing("move_right")

	_add_key_to_action("move_forward", KEY_W)
	_add_key_to_action("move_forward", KEY_UP)
	_add_key_to_action("move_backward", KEY_S)
	_add_key_to_action("move_backward", KEY_DOWN)
	_add_key_to_action("move_left", KEY_A)
	_add_key_to_action("move_left", KEY_LEFT)
	_add_key_to_action("move_right", KEY_D)
	_add_key_to_action("move_right", KEY_RIGHT)


func _add_action_if_missing(action: StringName) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)


func _add_key_to_action(action: StringName, keycode: Key) -> void:
	var events := InputMap.action_get_events(action)
	for ev in events:
		if ev is InputEventKey and ev.keycode == keycode:
			return
	var ev := InputEventKey.new()
	ev.keycode = keycode
	InputMap.action_add_event(action, ev)


func _try_pick_item() -> void:
	if not ray:
		return
	ray.force_raycast_update()
	var collider := ray.get_collider()
	if collider and collider is ItemPickup:
		var room := get_parent()
		(collider as ItemPickup).pickup(room)


func _try_interact() -> bool:
	if not ray:
		return false
	ray.force_raycast_update()
	var collider := ray.get_collider()
	if not collider:
		return false

	if _ray_log_cooldown <= 0.0:
		print("[Player] ray hit:", collider, " class=", collider.get_class())
		_ray_log_cooldown = 0.2

	var node: Node = collider
	while node:
		if node is DoorPortal:
			(node as DoorPortal).try_interact()
			return true
		node = node.get_parent()

	return false
