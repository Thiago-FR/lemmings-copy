class_name SkillBuilder
extends SkillBase
## Builds a staircase in the lemming's facing direction, moving it up and
## forward one tile per step, up to max_steps, then hands control back so
## the lemming resumes walking.

## Steps laid before the builder stops.
@export var max_steps: int = 12
## Seconds between two consecutive steps.
@export var step_interval_seconds: float = 0.3

var _steps_built: int = 0
var _time_since_last_step: float = 0.0


func _init() -> void:
	id = &"builder"
	display_name = "Escada diagonal"


func apply_to(lemming: LemmingController) -> void:
	lemming.velocity = Vector2.ZERO
	lemming.state_machine.change_state(LemmingStateMachine.State.BUILDING)


func physics_process(lemming: LemmingController, delta: float) -> bool:
	lemming.velocity = Vector2.ZERO

	if _steps_built >= max_steps:
		return false

	_time_since_last_step += delta
	if _time_since_last_step < step_interval_seconds:
		return true
	_time_since_last_step = 0.0

	# One tile per step: a smaller step would place two consecutive steps in
	# the same cell, so the staircase climbed and the staircase built would
	# drift apart.
	var terrain := lemming.terrain
	terrain.build_cell_at(lemming.get_forward_feet_position())
	var tile := terrain.get_cell_size()
	lemming.global_position += Vector2(tile.x * lemming.direction, -tile.y)
	_steps_built += 1
	return true
