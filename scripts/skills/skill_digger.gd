class_name SkillDigger
extends SkillBase
## Digs straight down through destructible terrain, one step at a time,
## until it breaks through into open space, then hands control back so the
## lemming resumes as WALKING/FALLING.

var _time_since_last_dig: float = 0.0


func apply_to(lemming: LemmingController) -> void:
	lemming.velocity = Vector2.ZERO
	lemming.state_machine.change_state(LemmingStateMachine.State.DIGGING)


func physics_process(lemming: LemmingController, delta: float) -> bool:
	lemming.velocity = Vector2.ZERO

	_time_since_last_dig += delta
	if _time_since_last_dig < Constants.DIGGER_DIG_INTERVAL_SECONDS:
		return true
	_time_since_last_dig = 0.0

	var terrain: TerrainDestructible = lemming.get_tree().get_first_node_in_group("terrain")
	if terrain == null:
		return false

	# Clear the lemming's full width, not just a single point, so the hole
	# is actually wide enough for a body to fall through instead of other
	# lemmings bridging over a hole narrower than they are.
	var feet := lemming.get_feet_position()
	var half_width := lemming.get_half_extents().x
	var destroyed_center := terrain.destroy_cell_at(feet)
	terrain.destroy_cell_at(feet + Vector2(-half_width, 0))
	terrain.destroy_cell_at(feet + Vector2(half_width, 0))
	if not destroyed_center:
		return false

	lemming.global_position.y += Constants.DIGGER_STEP_HEIGHT
	return true
