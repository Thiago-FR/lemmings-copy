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

	# One step's worth of terrain directly beneath the feet, exactly as wide
	# as the body. Taking the width from the body rather than from a
	# constant is what guarantees the shaft is always wide enough to descend
	# into: a fixed-width carve left the lemming wedged against the side of
	# its own tunnel whenever its body straddled a cell boundary.
	var body := lemming.get_body_rect()
	var slice := Rect2(
		Vector2(body.position.x, body.end.y),
		Vector2(body.size.x, Constants.DIGGER_STEP_HEIGHT)
	)

	if terrain.destroy_rect(slice) == 0:
		# Nothing solid left below — broken through into open space, so hand
		# control back and let LemmingController resume walking or falling.
		return false

	lemming.global_position.y += Constants.DIGGER_STEP_HEIGHT
	return true
