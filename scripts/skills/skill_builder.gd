class_name SkillBuilder
extends SkillBase
## Builds a staircase of blocks in the lemming's facing direction, moving it
## up and forward one step at a time, up to a fixed number of steps, then
## hands control back so the lemming resumes as WALKING.

var _steps_built: int = 0
var _time_since_last_step: float = 0.0


func apply_to(lemming: LemmingController) -> void:
	lemming.velocity = Vector2.ZERO
	lemming.state_machine.change_state(LemmingStateMachine.State.BUILDING)


func physics_process(lemming: LemmingController, delta: float) -> bool:
	lemming.velocity = Vector2.ZERO

	if _steps_built >= Constants.BUILDER_MAX_STEPS:
		return false

	_time_since_last_step += delta
	if _time_since_last_step < Constants.BUILDER_STEP_INTERVAL_SECONDS:
		return true
	_time_since_last_step = 0.0

	var terrain: TerrainDestructible = lemming.get_tree().get_first_node_in_group("terrain")
	if terrain == null:
		return false

	var step_position := lemming.get_forward_position() + Vector2(0, lemming.get_half_extents().y + Constants.GROUND_PROBE_EPSILON)
	terrain.build_cell_at(step_position)

	lemming.global_position += Vector2(Constants.BUILDER_STEP_WIDTH * lemming.direction, -Constants.BUILDER_STEP_HEIGHT)
	_steps_built += 1
	return true
