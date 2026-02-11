class_name ExploreManager
extends Node
## 방/복도 상태 머신 및 전환 관리

signal corridor_arrived(direction: Direction)

enum Direction {
	LEFT,
	RIGHT,
}

const ROOMS: Array[int] = [0, 1, 2]

var current_room_index: int = 0
var target_room_index: int = 0
var in_corridor: bool = false
var direction: Direction = Direction.RIGHT

var progress: float = 0.0
var move_speed: float = 0.45
var stress: int = 0

var _state: String = "STOPPED" # MOVING / STOPPED / ARRIVED
var _move_log_cooldown: float = 0.0
var _arrival_pending: bool = false

@onready var room_view: RoomView = $"../RoomView"
@onready var corridor_view = $"../CorridorView"


func _ready() -> void:
	print("[ExploreManager] _ready")
	if not room_view or not corridor_view:
		push_error("[ExploreManager] RoomView 또는 CorridorView 경로 오류")
		return

	room_view.manager = self
	corridor_view.manager = self


func _process(delta: float) -> void:
	if not in_corridor:
		return

	if _move_log_cooldown > 0.0:
		_move_log_cooldown -= delta

	var forward_input := 0.0
	var backward_input := 0.0

	if direction == Direction.LEFT:
		# LEFT 방향: A=전진, D=후퇴
		if Input.is_action_pressed("ui_left"):
			forward_input = 1.0
		if Input.is_action_pressed("ui_right"):
			backward_input = 1.0
	else:
		# RIGHT 방향: D=전진, A=후퇴
		if Input.is_action_pressed("ui_right"):
			forward_input = 1.0
		if Input.is_action_pressed("ui_left"):
			backward_input = 1.0

	var delta_progress := 0.0

	if forward_input > 0.0:
		delta_progress += move_speed * delta

	if backward_input > 0.0:
		delta_progress -= move_speed * delta

	var forward_pressed := forward_input > 0.0
	var back_pressed := backward_input > 0.0

	if delta_progress != 0.0 and not _arrival_pending:
		var old_progress := progress
		progress += delta_progress

		# 후퇴로 인한 progress 감소 프레임마다 스트레스 증가
		if progress < old_progress:
			stress += 1
			print("[ExploreManager] progress 감소 -> stress 증가: ", stress)

		# 범위 클램프
		progress = clamp(progress, 0.0, 1.0)

		# 이동 로그 (0.2초 쿨타임)
		if _move_log_cooldown <= 0.0:
			print("[ExploreManager] 이동 입력 - dir:", direction, " fwd:", forward_pressed, " back:", back_pressed, " progress:", progress, " stress:", stress)
			_move_log_cooldown = 0.2

		if progress >= 1.0 and not _arrival_pending:
			_on_reached_end()
	else:
		if not _arrival_pending:
			_state = "STOPPED"

	_update_corridor_view(forward_pressed, back_pressed)


func start_move_to_left() -> void:
	if not _can_move(-1):
		print("[ExploreManager] 왼쪽 방 없음, 이동 불가")
		return
	target_room_index = current_room_index - 1
	direction = Direction.LEFT
	_start_corridor()


func start_move_to_right() -> void:
	if not _can_move(1):
		print("[ExploreManager] 오른쪽 방 없음, 이동 불가")
		return
	target_room_index = current_room_index + 1
	direction = Direction.RIGHT
	_start_corridor()


func _can_move(delta_index: int) -> bool:
	var next_index := current_room_index + delta_index
	return next_index >= 0 and next_index < ROOMS.size()


func _start_corridor() -> void:
	print("[ExploreManager] 복도 이동 시작. current_room:", ROOMS[current_room_index], " -> target_room:", ROOMS[target_room_index], " direction:", direction)
	in_corridor = true
	progress = 0.0
	_state = "STOPPED"
	_arrival_pending = false
	room_view.visible = false
	if corridor_view and corridor_view.has_method("begin_travel"):
		corridor_view.begin_travel(int(direction), ROOMS[current_room_index], ROOMS[target_room_index])
	else:
		corridor_view.visible = true
	_update_corridor_view(false, false)


func _on_reached_end() -> void:
	_state = "ARRIVED"
	_arrival_pending = false
	progress = 1.0
	in_corridor = false
	print("[Corridor] ARRIVED at room %d" % ROOMS[target_room_index])
	_update_corridor_view(false, false)
	if corridor_view and corridor_view.has_method("show_arrived"):
		corridor_view.show_arrived(true)

	corridor_arrived.emit(direction)


func _enter_room_view() -> void:
	print("[ExploreManager] RoomView 진입. current_room:", ROOMS[current_room_index], " stress:", stress)
	room_view.visible = true
	corridor_view.visible = false
	room_view.update_room(ROOMS[current_room_index], _can_move(-1), _can_move(1))


func _update_corridor_view(forward_pressed: bool, back_pressed: bool) -> void:
	if corridor_view:
		corridor_view.update_corridor(direction, progress, stress, forward_pressed, back_pressed, _state)
