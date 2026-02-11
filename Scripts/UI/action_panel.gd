class_name ActionPanel
extends Control
## 공격/방어/스킬 패널 (UI 전용)

signal attack_pressed
signal defend_pressed
signal skill_pressed(index: int)

var _battle_manager: Node = null

@onready var attack_button: Button = $HBox/AttackButton
@onready var defend_button: Button = $HBox/DefendButton
@onready var skill1_button: Button = $SkillRow/Skill1Button
@onready var skill2_button: Button = $SkillRow/Skill2Button
@onready var skill3_button: Button = $SkillRow/Skill3Button

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	if attack_button:
		attack_button.pressed.connect(_on_attack_button_pressed)
		attack_button.mouse_filter = Control.MOUSE_FILTER_STOP
	if defend_button:
		defend_button.pressed.connect(_on_defend_button_pressed)
		defend_button.mouse_filter = Control.MOUSE_FILTER_STOP
	if skill1_button:
		skill1_button.pressed.connect(_on_skill1_button_pressed)
		skill1_button.mouse_filter = Control.MOUSE_FILTER_STOP
	if skill2_button:
		skill2_button.pressed.connect(_on_skill2_button_pressed)
		skill2_button.mouse_filter = Control.MOUSE_FILTER_STOP
	if skill3_button:
		skill3_button.pressed.connect(_on_skill3_button_pressed)
		skill3_button.mouse_filter = Control.MOUSE_FILTER_STOP
	if skill1_button and skill1_button.get_parent():
		skill1_button.get_parent().mouse_filter = Control.MOUSE_FILTER_STOP

func setup(battle_manager: Node) -> void:
	_battle_manager = battle_manager

func set_enabled(on: bool) -> void:
	if attack_button:
		attack_button.disabled = not on
	if defend_button:
		defend_button.disabled = not on
	if skill1_button:
		skill1_button.disabled = not on
	if skill2_button:
		skill2_button.disabled = not on
	if skill3_button:
		skill3_button.disabled = not on

func _on_attack_button_pressed() -> void:
	attack_pressed.emit()

func _on_defend_button_pressed() -> void:
	defend_pressed.emit()

func _on_skill1_button_pressed() -> void:
	_emit_skill(0)

func _on_skill2_button_pressed() -> void:
	_emit_skill(1)

func _on_skill3_button_pressed() -> void:
	_emit_skill(2)

func _emit_skill(index: int) -> void:
	print("TODO: Skill pressed", index)
	skill_pressed.emit(index)
