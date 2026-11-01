class_name SkillDigger
extends SkillBase
## Digs straight down through destructible terrain, one step at a time,
## until it breaks through into open space, then hands control back so the
## lemming resumes as WALKING/FALLING.

var _time_since_last_dig: float = 0.0


func apply_to(lemming: LemmingController) -> void:
	lemming.velocity = Vector2.ZERO

	# Line the body up with the terrain column before the first carve. The
	# body is narrower than a tile, so once centred it only ever overlaps
	# one column and every shaft comes out the same width. Without this the
	# same skill dug a one-tile hole from one standing position and a
	# two-tile hole from another, half a tile away.
	var terrain: TerrainDestructible = lemming.get_tree().get_first_node_in_group("terrain")
	if terrain != null:
		# Centre the collision box on the column, not the node: the shape sits
		# at a small offset from the node origin, and snapping the origin
		# would leave the body itself off-centre inside the shaft.
		var body_centre := lemming.get_body_rect().get_center()
		var shape_offset := lemming.global_position.x - body_centre.x
		lemming.global_position.x = terrain.column_centre_x(body_centre) + shape_offset

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

	# One step's worth of terrain directly beneath the feet, as wide as the
	# body. apply_to() has already centred the body in its column, so this
	# resolves to exactly that one column every tick.
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
