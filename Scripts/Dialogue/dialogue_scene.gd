extends Control
## 표준 미연시 스타일 대화창 MVP. GameRoot에서 ModeHost로 로드됨.

signal dialogue_finished

@export var dialogue_file_path: String = "res://Data/Dialogue/intro.json"

@onready var portrait_left: TextureRect = $"DialogueScene#CharacterLayer/DialogueScene_CharacterLayer#PortraitLeft"
@onready var portrait_right: TextureRect = $"DialogueScene#CharacterLayer/DialogueScene_CharacterLayer#PortraitRight"
@onready var name_label: Label = $"DialogueScene#DialogueUI/DialogueScene_DialogueUI_TextBox#NameLabel"
@onready var dialogue_text: RichTextLabel = $"DialogueScene#DialogueUI/DialogueScene_DialogueUI_TextBox#DialogueText"
@onready var next_indicator: Label = $"DialogueScene#DialogueUI/DialogueScene_DialogueUI#NextIndicator"

var _lines: Array = []
var _index: int = 0
var _finished: bool = false


func _ready() -> void:
	set_process_unhandled_input(true)

	# UI 바인딩 확인
	if name_label == null:
		push_error("DialogueScene: NameLabel 바인딩 실패 (경로 확인 필요)")
	if dialogue_text == null:
		push_error("DialogueScene: DialogueText 바인딩 실패 (경로 확인 필요)")

	print("[Dialogue] path =", dialogue_file_path)
	_load_from_file(dialogue_file_path)
	print("[Dialogue] lines =", _lines.size())

	if _lines.size() == 0:
		push_error("DialogueScene: lines 가 비어 있습니다. path=%s" % dialogue_file_path)
		_finished = true
		return

	_index = 0
	_show_line(0)


func _unhandled_input(event: InputEvent) -> void:
	if _finished:
		return

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_next_line()
	elif event is InputEventKey and event.pressed and (event.keycode == KEY_SPACE or event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER):
		_next_line()


func _show_current_line() -> void:
	if _index < 0 or _index >= _lines.size():
		_on_dialogue_finished()
		return

	var line: Dictionary = _lines[_index]
	var name: String = str(line.get("name", ""))
	var text: String = str(line.get("text", ""))
	var side: String = str(line.get("side", "left")).to_lower()

	if name_label:
		name_label.text = name
		# 테마/알파 영향 제거를 위해 강제 설정
		name_label.modulate = Color(1, 1, 1, 1)
	if dialogue_text:
		dialogue_text.text = text
		# RichTextLabel 타이핑/표시 설정 강제
		dialogue_text.visible_characters = -1
		# Godot 4에서는 percent_visible 대신 visible_ratio 사용
		dialogue_text.visible_ratio = 1.0
		# 테마/알파 영향 제거를 위해 강제 설정
		dialogue_text.modulate = Color(1, 1, 1, 1)

	_update_portraits(side)

	print("[Dialogue] show line idx=", _index, " name=", name, " text=", text)


func _show_line(idx: int) -> void:
	_index = idx
	_show_current_line()


func _update_portraits(side: String) -> void:
	var left_active := side == "left"

	if portrait_left:
		var c_left := portrait_left.modulate
		c_left.a = 1.0 if left_active else 0.3
		portrait_left.modulate = c_left
	if portrait_right:
		var c_right := portrait_right.modulate
		c_right.a = 0.3 if left_active else 1.0
		portrait_right.modulate = c_right


func _next_line() -> void:
	if _finished:
		return
	_show_line(_index + 1)


func _on_dialogue_finished() -> void:
	if _finished:
		return
	_finished = true
	if next_indicator:
		next_indicator.visible = false
	print("Dialogue finished")
	dialogue_finished.emit()


func _debug_message(msg: String) -> void:
	print(msg)
	var label := get_node_or_null("DebugLabel") as Label
	if label:
		label.text = msg


func _load_from_file(path: String) -> void:
	_lines.clear()
	_index = 0
	_finished = false

	if path.is_empty():
		var msg := "DialogueScene: dialogue_file_path is empty"
		push_error(msg)
		_debug_message(msg)
		_finished = true
		return

	if not FileAccess.file_exists(path):
		var msg2 := "DialogueScene: file not found: %s" % path
		push_error(msg2)
		_debug_message(msg2)
		_finished = true
		return

	var text: String = FileAccess.get_file_as_string(path)
	if text.is_empty():
		var msg3 := "DialogueScene: empty file: %s" % path
		push_error(msg3)
		_debug_message(msg3)
		_finished = true
		return

	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		var msg4 := "DialogueScene: invalid JSON in %s" % path
		push_error(msg4)
		_debug_message(msg4)
		_finished = true
		return

	var data: Dictionary = parsed
	if not data.has("lines"):
		var msg5 := "DialogueScene: 'lines' key missing in %s" % path
		push_error(msg5)
		_debug_message(msg5)
		_finished = true
		return

	var arr = data["lines"]
	if not (arr is Array):
		var msg6 := "DialogueScene: 'lines' is not Array in %s" % path
		push_error(msg6)
		_debug_message(msg6)
		_finished = true
		return

	for e in arr:
		if e is Dictionary:
			_lines.append(e)

	if _lines.is_empty():
		var msg7 := "DialogueScene: no lines in %s" % path
		push_error(msg7)
		_debug_message(msg7)
		_finished = true
