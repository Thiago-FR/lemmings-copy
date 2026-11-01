class_name ExitPoint
extends Area2D
## Level exit: any lemming that walks into it is saved.
##
## Self-contained: it does not count anything or know the level's rules. It
## tells the lemming it has exited and emits lemming_exited, and whoever owns
## the level decides what that means. Which physics layer it watches and the
## label shown above it are exported, so it can be reused for other
## characters or other kinds of goal.

signal lemming_exited(lemming: LemmingController)

## Physics layers checked for arriving bodies.
@export_flags_2d_physics var detected_layers: int = Constants.LEMMING_COLLISION_LAYER
## Text shown above the exit.
@export var label_text: String = "SAÍDA"

@onready var _label: Label = $Label


func _ready() -> void:
	add_to_group("exit_points")
	collision_layer = 0
	collision_mask = detected_layers
	_label.text = label_text
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	var lemming := body as LemmingController
	if lemming == null or not lemming.state_machine.is_alive():
		return
	lemming_exited.emit(lemming)
	lemming.exit()
