extends Node2D
## 탐색 모드 씬. ExploreManager/RoomView/CorridorView를 포함한다.

signal request_enter_room(door_side: String)

@export var door_side: String = "RIGHT" # "LEFT" 또는 "RIGHT"

@onready var manager: ExploreManager = $ExploreManager

var _corridor_arrived: bool = false
var _current_door_side: String = "RIGHT"
var _map_state: DungeonMapState = null
@onready var minimap: DungeonMiniMap = $DungeonMiniMap


func _ready() -> void:
	print("ExploreScene entered")
	if not manager:
		push_error("[ExploreScene] ExploreManager 경로 오류: $ExploreManager")
		return

	manager.corridor_arrived.connect(_on_corridor_arrived)

	# 외부(GameRoot)에서 door_side/set_start_side를 세팅할 수 있도록
	# 한 프레임 늦게 복도 이동을 시작한다.
	call_deferred("_start_corridor_from_door_side")


func set_map_state(state: DungeonMapState) -> void:
	_map_state = state
	if minimap:
		minimap.set_map_state(state)


func _unhandled_input(event: InputEvent) -> void:
	if not _corridor_arrived:
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_E:
		if _map_state:
			var dir := Vector2i.ZERO
			if _current_door_side == "LEFT":
				dir = Vector2i(-1, 0)
			else:
				dir = Vector2i(1, 0)
			var ok := _map_state.move(dir)
			print("[Map] move", _current_door_side, "->", _map_state.get_current(), "ok=", ok)
			if minimap:
				minimap.queue_redraw()
		print("[ExploreScene] request_enter_room:", _current_door_side)
		request_enter_room.emit(_current_door_side)
		_corridor_arrived = false


func _on_corridor_arrived(direction: ExploreManager.Direction) -> void:
	_corridor_arrived = true
	if direction == ExploreManager.Direction.LEFT:
		_current_door_side = "LEFT"
	else:
		_current_door_side = "RIGHT"
	print("[ExploreScene] corridor arrived, direction=", direction, " door_side=", _current_door_side)


func set_start_side(side: String) -> void:
	door_side = side.to_upper()
	_current_door_side = door_side
	_corridor_arrived = false


func _start_corridor_from_door_side() -> void:
	if not manager:
		return
	var side := door_side.to_upper()
	_current_door_side = side
	match side:
		"LEFT":
			print("[ExploreScene] start corridor with side =", side)
			manager.start_move_to_left()
		_:
			print("[ExploreScene] start corridor with side =", side)
			manager.start_move_to_right()
