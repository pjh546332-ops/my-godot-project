extends Control
## 던전 준비/출발 씬. GameRoot의 ModeHost 아래에서 로드됨.

signal request_explore_start
signal request_back_to_hub

@onready var start_button: Button = $"CenterContainer/VBoxContainer/StartButton"
@onready var back_button: Button = $"CenterContainer/VBoxContainer/BackButton"


func _ready() -> void:
	print("[DungeonPrepScene] start_button is null? ", start_button == null)
	print("[DungeonPrepScene] back_button is null? ", back_button == null)

	if start_button == null:
		push_error("[DungeonPrepScene] StartButton 경로 오류: 기대 경로 = CenterContainer/VBoxContainer/StartButton")
	else:
		start_button.pressed.connect(_on_start_button_pressed)

	if back_button == null:
		push_error("[DungeonPrepScene] BackButton 경로 오류: 기대 경로 = CenterContainer/VBoxContainer/BackButton")
	else:
		back_button.pressed.connect(_on_back_button_pressed)


func _on_start_button_pressed() -> void:
	request_explore_start.emit()


func _on_back_button_pressed() -> void:
	request_back_to_hub.emit()
