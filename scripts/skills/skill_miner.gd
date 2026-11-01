class_name SkillMiner
extends SkillBase
## Digs diagonally downward in the lemming's facing direction, one step at a
## time, until there is nothing left to remove (open space ahead and below),
## then hands control back so the lemming resumes as WALKING/FALLING.

var _time_since_last_dig: float = 0.0


func apply_to(lemming: LemmingController) -> void:
	lemming.velocity = Vector2.ZERO
	lemming.state_machine.change_state(LemmingStateMachine.State.MINING)


func physics_process(lemming: LemmingController, delta: float) -> bool:
	lemming.velocity = Vector2.ZERO

	_time_since_last_dig += delta
	if _time_since_last_dig < Constants.MINER_DIG_INTERVAL_SECONDS:
		return true
	_time_since_last_dig = 0.0

	var terrain: TerrainDestructible = lemming.get_tree().get_first_node_in_group("terrain")
	if terrain == null:
		return false

	var forward_position := lemming.get_forward_position() + Vector2(0, lemming.get_half_extents().y + Constants.GROUND_PROBE_EPSILON)
	var destroyed_forward := terrain.destroy_cell_at(forward_position)
	var destroyed_feet := terrain.destroy_cell_at(lemming.get_feet_position())
	if not destroyed_forward and not destroyed_feet:
		return false

	lemming.global_position += Vector2(Constants.MINER_STEP_WIDTH * lemming.direction, Constants.MINER_STEP_HEIGHT)
	return true
