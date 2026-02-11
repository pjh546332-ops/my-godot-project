extends Area3D
class_name ItemPickup

@export var item_id: String = ""
@export var amount: int = 1

@onready var sprite: Sprite3D = $Sprite3D


func _ready() -> void:
	if sprite:
		sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED


func pickup(room: Node) -> void:
	if item_id == "":
		queue_free()
		return

	if room and room.has_method("add_item"):
		room.add_item(item_id, amount)

	queue_free()

