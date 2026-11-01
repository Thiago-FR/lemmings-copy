class_name SkillMiner
extends SkillBase
## Digs diagonally downward in the lemming's facing direction, one tile at a
## time, until there is nothing left to remove (open space ahead and below),
## then hands control back so the lemming resumes walking or falling.

## Seconds between two consecutive diagonal steps.
@export var dig_interval_seconds: float = 0.2

var _time_since_last_dig: float = 0.0


func _init() -> void:
	id = &"miner"
	display_name = "Minerador"


func apply_to(lemming: LemmingController) -> void:
	lemming.velocity = Vector2.ZERO
	lemming.state_machine.change_state(LemmingStateMachine.State.MINING)


func physics_process(lemming: LemmingController, delta: float) -> bool:
	lemming.velocity = Vector2.ZERO

	_time_since_last_dig += delta
	if _time_since_last_dig < dig_interval_seconds:
		return true
	_time_since_last_dig = 0.0

	var terrain := lemming.terrain
	var destroyed_forward := terrain.destroy_cell_at(lemming.get_forward_feet_position())
	var destroyed_feet := terrain.destroy_cell_at(lemming.get_feet_position())
	if not destroyed_forward and not destroyed_feet:
		return false

	var tile := terrain.get_cell_size()
	lemming.global_position += Vector2(tile.x * lemming.direction, tile.y)
	return true
