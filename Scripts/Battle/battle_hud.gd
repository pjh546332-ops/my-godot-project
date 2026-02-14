extends Control

## 전투 HUD: 라운드/턴/AP/모드, Move/Attack/End Turn, Overdrive 버튼.

@onready var label_round: Label = $TopLeft/LabelRound
@onready var label_turn: Label = $TopLeft/LabelTurn
@onready var label_ap: Label = $TopLeft/LabelAP
@onready var label_mode: Label = $TopLeft/LabelMode
@onready var label_strain: Label = $TopLeft/LabelStrain
@onready var label_overheat: Label = $TopLeft/LabelOverheat
@onready var btn_move: Button = $BottomRight/BtnMove
@onready var btn_attack: Button = $BottomRight/BtnAttack
@onready var btn_push: Button = $BottomRight/BtnPush
@onready var btn_end_turn: Button = $BottomRight/BtnEndTurn
@onready var btn_overdrive_ap: Button = $BottomRight/BtnOverdriveAP
@onready var btn_overdrive_def: Button = $BottomRight/BtnOverdriveDEF

signal request_move_mode
signal request_attack_mode
signal request_push_mode
signal request_end_turn
signal request_overdrive_ap
signal request_overdrive_def


func _ready() -> void:
	if btn_move:
		btn_move.pressed.connect(_on_move_pressed)
	if btn_attack:
		btn_attack.pressed.connect(_on_attack_pressed)
	if btn_push:
		btn_push.pressed.connect(_on_push_pressed)
	if btn_end_turn:
		btn_end_turn.pressed.connect(_on_end_turn_pressed)
	if btn_overdrive_ap:
		btn_overdrive_ap.pressed.connect(_on_overdrive_ap_pressed)
	if btn_overdrive_def:
		btn_overdrive_def.pressed.connect(_on_overdrive_def_pressed)


func _on_move_pressed() -> void:
	request_move_mode.emit()


func _on_attack_pressed() -> void:
	request_attack_mode.emit()


func _on_push_pressed() -> void:
	request_push_mode.emit()


func _on_end_turn_pressed() -> void:
	request_end_turn.emit()


func _on_overdrive_ap_pressed() -> void:
	request_overdrive_ap.emit()


func _on_overdrive_def_pressed() -> void:
	request_overdrive_def.emit()


func set_round(n: int) -> void:
	if label_round:
		label_round.text = "Round: %d" % n


func set_turn(unit_name_or_id: String) -> void:
	if label_turn:
		label_turn.text = "Turn: %s" % unit_name_or_id


func set_ap(ap_val: int, max_ap_val: int) -> void:
	if label_ap:
		label_ap.text = "AP: %d / %d" % [ap_val, max_ap_val]


func set_mode(mode_name: String) -> void:
	if label_mode:
		label_mode.text = "Mode: %s" % mode_name


func set_strain(strain_val: int, max_strain_val: int) -> void:
	if label_strain:
		label_strain.text = "Strain: %d / %d" % [strain_val, max_strain_val]
		label_strain.visible = true


func set_overheat(show: bool) -> void:
	if label_overheat:
		label_overheat.text = "Overheated!"
		label_overheat.visible = show


func set_overdrive_buttons_enabled(enabled: bool) -> void:
	if btn_overdrive_ap:
		btn_overdrive_ap.disabled = not enabled
	if btn_overdrive_def:
		btn_overdrive_def.disabled = not enabled


func set_overdrive_ap_available(available: bool) -> void:
	## Overdrive +AP 턴당 1회 제한: available=false면 비활성화
	if btn_overdrive_ap:
		if not available:
			btn_overdrive_ap.disabled = true
		## available=true일 때는 set_overdrive_buttons_enabled 결과 유지(별도 호출 안 함)
