class_name ExitPoint
extends Area2D
## Level exit: any lemming that walks into it is saved. It walks on into
## the doorway first (LemmingController.enter_exit), and counts as saved
## once it is through.
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

## The doorway art (docs/art_pipeline.md, "Entrada e saída"): its bottom
## centre, pixel (22, 56), sits on the floor, which is 24px below the origin
## (the middle of the 32x48 collision box).
const ART_OFFSET := Vector2(-22, -32)
const ART_ANIMATIONS := {
	&"idle": ["exit_idle", 4, 6.0, true],
}

## The exit's floor is this far below its origin (the middle of the 32x48
## collision box); a lemming's feet must be within FLOOR_TOLERANCE of it.
const FLOOR_BELOW_ORIGIN := 24.0
const FLOOR_TOLERANCE := 6.0

@onready var _label: Label = $Label

## Lemmings inside the doorway's box but not on its floor yet.
var _waiting: Array[LemmingController] = []


func _ready() -> void:
	add_to_group("exit_points")
	collision_layer = 0
	collision_mask = detected_layers
	_label.text = label_text
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	var art := PortalSprite.make(ART_ANIMATIONS, ART_OFFSET)
	art.z_index = -1
	add_child(art)
	art.play(&"idle")


## Touching the doorway is not enough: a lemming walking on a block beside
## the exit, level with its top, used to go in from up there instead of
## dropping down in front of it first. It goes in once it walks on the
## exit's own floor; until then it is kept and checked every frame.
func _on_body_entered(body: Node2D) -> void:
	var lemming := body as LemmingController
	if lemming == null or _waiting.has(lemming):
		return
	_waiting.append(lemming)
	_try_take_in(lemming)


func _on_body_exited(body: Node2D) -> void:
	_waiting.erase(body)


func _physics_process(_delta: float) -> void:
	for lemming in _waiting.duplicate():
		_try_take_in(lemming)


func _try_take_in(lemming: LemmingController) -> void:
	if not is_instance_valid(lemming) or not lemming.state_machine.is_alive() or lemming.is_entering_exit:
		_waiting.erase(lemming)
		return
	if not _stands_on_exit_floor(lemming):
		return
	_waiting.erase(lemming)
	lemming.exited.connect(func() -> void: lemming_exited.emit(lemming), CONNECT_ONE_SHOT)
	lemming.enter_exit(global_position.x)


func _stands_on_exit_floor(lemming: LemmingController) -> bool:
	if lemming.state_machine.current_state != LemmingStateMachine.State.WALKING:
		return false
	var floor_y := global_position.y + FLOOR_BELOW_ORIGIN
	return absf(lemming.get_feet_position().y - floor_y) <= FLOOR_TOLERANCE
