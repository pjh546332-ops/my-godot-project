extends Area3D
class_name DoorPortal

signal enter_requested(door_side: String)

@export var door_side: String = "RIGHT"

@onready var prompt_label: Label3D = $PromptLabel3D

var player_inside: bool = false


func _ready() -> void:
	if prompt_label:
		prompt_label.visible = false

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

	print("[DoorPortal] ready:", name, " layer=", collision_layer, " mask=", collision_mask, " monitoring=", monitoring)


func try_interact() -> void:
	if not player_inside:
		return
	print("[DoorPortal] interact requested, side=", door_side)
	enter_requested.emit(door_side)


func _on_body_entered(body: Node) -> void:
	if body is PlayerFPS:
		player_inside = true
		print("[DoorPortal] player entered")
		if prompt_label:
			prompt_label.visible = true


func _on_body_exited(body: Node) -> void:
	if body is PlayerFPS:
		player_inside = false
		print("[DoorPortal] player exited")
		if prompt_label:
			prompt_label.visible = false
