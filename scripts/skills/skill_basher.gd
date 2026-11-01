class_name SkillBasher
extends SkillBase
## Digs horizontally through terrain in the lemming's facing direction, one
## step at a time, until it breaks into open space, loses its footing, or a
## safety time limit is reached (real terrain is always finite, but this
## guards against pathological cases).

var _time_since_last_bash: float = 0.0
var _elapsed_seconds: float = 0.0


func apply_to(lemming: LemmingController) -> void:
	lemming.velocity.x = 0.0
	lemming.state_machine.change_state(LemmingStateMachine.State.BASHING)


func physics_process(lemming: LemmingController, delta: float) -> bool:
	lemming.velocity.x = 0.0

	_elapsed_seconds += delta
	if _elapsed_seconds >= Constants.BASHER_MAX_DURATION_SECONDS:
		return false

	var terrain: TerrainDestructible = lemming.get_tree().get_first_node_in_group("terrain")
	if terrain == null:
		return false

	# is_on_floor() would work here in theory, but LemmingController skips
	# move_and_slide() entirely while a skill (like this one) is driving the
	# lemming directly, so the flag never refreshes once bashing starts and
	# stays frozen at whatever it was the instant before — checking the
	# terrain directly avoids relying on it.
	if not terrain.is_solid_at(lemming.get_feet_position()):
		return false

	_time_since_last_bash += delta
	if _time_since_last_bash < Constants.BASHER_DIG_INTERVAL_SECONDS:
		return true
	_time_since_last_bash = 0.0

	# Clear a full lemming-height tunnel, not just one row, so the lemming
	# (and anyone following it) actually has headroom to walk through.
	var forward := lemming.get_forward_position()
	var destroyed_center := terrain.destroy_cell_at(forward)
	terrain.destroy_cell_at(forward + Vector2(0, -Constants.TERRAIN_TILE_SIZE))
	if not destroyed_center:
		return false

	lemming.global_position.x += Constants.BASHER_STEP_WIDTH * lemming.direction
	return true
