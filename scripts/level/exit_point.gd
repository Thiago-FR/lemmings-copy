class_name ExitPoint
extends Area2D
## Marks a lemming as successfully saved when it reaches this area.

signal lemming_exited(lemming: LemmingController)


func _ready() -> void:
	add_to_group("exit_points")
	collision_layer = 0
	collision_mask = Constants.LEMMING_COLLISION_LAYER
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if body is LemmingController:
		lemming_exited.emit(body)
		body.exit()
