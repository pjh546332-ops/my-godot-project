extends Control

## 개발용 씬 테스트 메뉴.
## 실제 씬 전환은 GameRoot가 담당하고, 이 메뉴는 시그널만 발행한다.

signal request_test_battle_3d
signal request_test_first_person_room
signal request_test_hub
signal request_test_explore_2d

@onready var battle3d_button: Button = $CenterContainer/PanelContainer/VBox/Battle3DButton
@onready var fp_room_button: Button = $CenterContainer/PanelContainer/VBox/FirstPersonRoomButton
@onready var hub_button: Button = $CenterContainer/PanelContainer/VBox/HubButton
@onready var explore2d_button: Button = $CenterContainer/PanelContainer/VBox/Explore2DButton


func _ready() -> void:
	if battle3d_button:
		battle3d_button.pressed.connect(_on_battle3d_pressed)
	if fp_room_button:
		fp_room_button.pressed.connect(_on_fp_room_pressed)
	if hub_button:
		hub_button.pressed.connect(_on_hub_pressed)
	if explore2d_button:
		explore2d_button.pressed.connect(_on_explore2d_pressed)


func _on_battle3d_pressed() -> void:
	request_test_battle_3d.emit()


func _on_fp_room_pressed() -> void:
	request_test_first_person_room.emit()


func _on_hub_pressed() -> void:
	request_test_hub.emit()


func _on_explore2d_pressed() -> void:
	request_test_explore_2d.emit()

