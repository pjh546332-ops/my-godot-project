extends Control
class_name CorridorView
## 복도 이동 UI: 진행 방향, 진행률, 스트레스 표시

var manager = null

@export var debug_ui_enabled: bool = false

@onready var camera_frame: Control = $CameraFrame
@onready var world: Node2D = $CameraFrame/World
@onready var floor: ColorRect = $CameraFrame/World/Floor
@onready var bg: ColorRect = $CameraFrame/World/Bg
@onready var left_door_marker: ColorRect = $CameraFrame/World/LeftDoorMarker
@onready var right_door_marker: ColorRect = $CameraFrame/World/RightDoorMarker
@onready var party: ColorRect = $CameraFrame/Party

@onready var progress_bar: ProgressBar = $UIOverlay/VBoxContainer/ProgressBar
@onready var debug_label: Label = $UIOverlay/VBoxContainer/DebugLabel
@onready var arrived_label: Label = $UIOverlay/VBoxContainer/ArrivedLabel
@onready var stress_label: Label = $UIOverlay/VBoxContainer/StressLabel

var _world_offset: float = 0.0
var _party_time: float = 0.0
var _party_base_pos: Vector2
var _last_direction: int = 0
var _last_forward_pressed: bool = false
var _last_back_pressed: bool = false
var _current_progress: float = 0.0


func _apply_layout() -> void:
	# CorridorView 전체 화면 덮기
	anchor_left = 0.0
	anchor_top = 0.0
	anchor_right = 1.0
	anchor_bottom = 1.0
	offset_left = 0.0
	offset_top = 0.0
	offset_right = 0.0
	offset_bottom = 0.0

	# CameraFrame을 화면 중앙에 고정 (뷰포트 비율 기반)
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var w: float = viewport_size.x * 0.75
	var h: float = viewport_size.y * 0.45

	camera_frame.anchor_left = 0.5
	camera_frame.anchor_top = 0.5
	camera_frame.anchor_right = 0.5
	camera_frame.anchor_bottom = 0.5
	camera_frame.offset_left = -w * 0.5
	camera_frame.offset_right = w * 0.5
	camera_frame.offset_top = -h * 0.5
	camera_frame.offset_bottom = h * 0.5
	camera_frame.clip_contents = true

	# 파티 기준 위치 갱신 (프레임 중앙 근처)
	var frame_rect := camera_frame.get_rect()
	_party_base_pos = Vector2(frame_rect.size.x * 0.5, frame_rect.size.y * 0.55)
	party.position = _party_base_pos

	print("[CorridorView] CameraFrame global_pos=", camera_frame.global_position, " size=", frame_rect.size)


func _ready() -> void:
	print("[CorridorView] _ready. manager:", manager)
	_apply_layout()
	get_viewport().size_changed.connect(_apply_layout)
	if debug_label:
		debug_label.visible = debug_ui_enabled
	_update_ui(0, 0.0, 0, false, false, "STOPPED")


func _process(delta: float) -> void:
	_update_party_icon(delta)


func update_corridor(direction: int, progress: float, stress: int, forward_pressed: bool, back_pressed: bool, state: String) -> void:
	_last_direction = direction
	_last_forward_pressed = forward_pressed
	_last_back_pressed = back_pressed
	_current_progress = progress
	_update_ui(direction, progress, stress, forward_pressed, back_pressed, state)
	_update_world_from_progress()


func begin_travel(direction: int, from_room: int, to_room: int) -> void:
	visible = true
	_last_direction = direction
	_current_progress = 0.0
	_reset_travel_state()


func end_travel() -> void:
	_reset_travel_state()
	visible = false


func show_arrived(arrived: bool) -> void:
	if arrived_label:
		if arrived:
			arrived_label.visible = true
			var t := get_tree().create_timer(0.5)
			t.timeout.connect(func() -> void:
				if arrived_label:
					arrived_label.visible = false
			)
		else:
			arrived_label.visible = false

	if arrived and party:
		party.modulate = Color(1.0, 1.0, 1.0, 1.0)


func _update_ui(direction: int, progress: float, stress: int, forward_pressed: bool, back_pressed: bool, state: String) -> void:
	if progress_bar:
		progress_bar.value = clampf(progress * 100.0, 0.0, 100.0)

	if stress_label:
		stress_label.text = "Stress: %d" % stress

	if debug_label:
		debug_label.visible = debug_ui_enabled
		var dir_text := "?"
		var forward_key := "?"
		var back_key := "?"
		if direction == 0:
			dir_text = "LEFT"
			forward_key = "A"
			back_key = "D"
		elif direction == 1:
			dir_text = "RIGHT"
			forward_key = "D"
			back_key = "A"

		var progress_pct: float = clampf(progress * 100.0, 0.0, 100.0)
		var text := "dir=%s | fwd_key=%s | back_key=%s | fwd=%s | back=%s | progress=%.1f%% | stress=%d | state=%s | frame=%s | world=%s" % [
			dir_text,
			forward_key,
			back_key,
			str(forward_pressed),
			str(back_pressed),
			progress_pct,
			stress,
			state,
			str(camera_frame.get_rect().size),
			str(world.position),
		]
		debug_label.text = text

	# 문 마커 강조
	if left_door_marker and right_door_marker:
		var target := left_door_marker
		var other := right_door_marker
		if direction == 1:
			target = right_door_marker
			other = left_door_marker

		var scale_factor := 1.0 + 0.3 * progress
		target.scale = Vector2(scale_factor, scale_factor)
		target.modulate.a = 0.6 + 0.4 * progress

		other.scale = Vector2.ONE
		other.modulate.a = 0.4


func _update_party_icon(delta: float) -> void:
	if not party:
		return

	var moving := _last_forward_pressed or _last_back_pressed
	if moving:
		_party_time += delta
	else:
		_party_time = 0.0

	var amplitude := 6.0
	var freq := 4.0
	var bob := 0.0
	if moving:
		bob = sin(_party_time * freq) * amplitude

	var pos := _party_base_pos
	pos.y += bob
	party.position = pos

	# 후퇴 중이면 살짝 어둡게
	if _last_back_pressed:
		party.modulate = Color(0.6, 0.6, 0.8, 1.0)
	else:
		party.modulate = Color(0.9, 0.9, 1.0, 1.0)


func _reset_travel_state() -> void:
	_world_offset = 0.0
	if world:
		world.position = Vector2.ZERO
	if arrived_label:
		arrived_label.visible = false
	# 파티 위치를 중앙 기준으로 리셋
	var frame_rect := camera_frame.get_rect()
	_party_base_pos = Vector2(frame_rect.size.x * 0.5, frame_rect.size.y * 0.55)
	party.position = _party_base_pos


func _update_world_from_progress() -> void:
	if not world:
		return

	var t: float = clampf(_current_progress, 0.0, 1.0)
	var frame_size: Vector2 = camera_frame.get_rect().size
	var corridor_px: float = frame_size.x * 1.0

	var offset: float
	if _last_direction == 1: # RIGHT
		offset = lerpf(0.0, -corridor_px, t)
	else: # LEFT
		offset = lerpf(0.0, corridor_px, t)

	world.position.x = offset
