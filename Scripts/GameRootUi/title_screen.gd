extends Control
## 메인(타이틀) 화면 UI. 버튼 클릭 시 print만 수행하고,
## "새 게임" 버튼은 GameRoot로 시작 신호를 보낸다.

signal new_game_requested


func _ready() -> void:
	_connect_buttons()


func _connect_buttons() -> void:
	var box := $CenterContainer/PanelContainer/VBoxContainer
	for child in box.get_children():
		if child is Button:
			child.pressed.connect(_on_button_pressed.bind(child.name))


func _on_button_pressed(button_name: String) -> void:
	print("TitleScreen: ", button_name, " pressed")
	if button_name == "NewGameButton":
		new_game_requested.emit()
