extends Node3D
class_name FirstPersonRoom

signal request_exit_room(door_side: String)

@onready var info_label: Label3D = $UI3D/InfoLabel3D
@onready var door_portals: Array = [
	$Room/DoorPortal_A,
	$Room/DoorPortal_B,
]
@onready var minimap: DungeonMiniMap = $DungeonMiniMap

var inventory: Dictionary = {}
var _map_state: DungeonMapState = null


func _ready() -> void:
	for p in door_portals:
		if p:
			p.enter_requested.connect(_on_portal_enter_requested)


func add_item(item_id: String, amount: int) -> void:
	var current: int = int(inventory.get(item_id, 0))
	inventory[item_id] = current + amount
	print("[FirstPersonRoom] picked '%s' x%d (total=%d)" % [item_id, amount, inventory[item_id]])
	_show_pickup_text("Picked up: %s (+%d)" % [item_id, amount])


func _show_pickup_text(text: String) -> void:
	if not info_label:
		return
	info_label.text = text
	info_label.modulate.a = 1.0
	var tween := create_tween()
	tween.tween_property(info_label, "modulate:a", 0.0, 0.8)


func _on_portal_enter_requested(door_side: String) -> void:
	print("[FirstPersonRoom] Portal enter requested, side=", door_side)
	request_exit_room.emit(door_side)


func set_map_state(state: DungeonMapState) -> void:
	_map_state = state
	if minimap:
		minimap.set_map_state(state)
