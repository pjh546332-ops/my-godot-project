class_name RoomView
extends Control
## 방 UI: 현재 방 ID 표시 (자동 이동 구조)

var manager: ExploreManager = null

@onready var room_label: Label = $VBoxContainer/RoomLabel


func _ready() -> void:
	print("[RoomView] _ready. manager:", manager)


func update_room(room_id: int, can_move_left: bool, can_move_right: bool) -> void:
	_play_enter_effect()

	if room_label:
		room_label.text = "현재 방: Room%d" % room_id

	print("[RoomView] update_room - id:", room_id, " can_left:", can_move_left, " can_right:", can_move_right)


func _play_enter_effect() -> void:
	modulate.a = 0.0
	visible = true
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.25)
