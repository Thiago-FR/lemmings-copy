class_name SkillSideDigger
extends SkillBase
## Shared behaviour of the tools that dig straight ahead (the pickaxe and the
## jackhammer): the shovel's digging turned sideways. At a wall the lemming
## digs a tunnel one block tall at its own height, one dig stage (a slice of
## a block) at a time, walking into each slice as it clears it, until it
## breaks through into open space or reaches something it cannot break.
## Then it walks on.
##
## Removing a block a slice at a time, rather than all at once, makes the
## dig and the walk forward read as one action instead of the lemming
## jumping a whole block per swing.
##
## Given to a walking lemming, the tool is carried until the lemming walks
## into a wall and used there (see LemmingController.pending_wall_tool): a
## lemming turns around the instant it touches a wall, so it is never
## standing against one for the player to click.
##
## Subclasses set the id, name, state, speed and whether concrete breaks.

## How fast the lemming advances while digging, in pixels per second.
@export var dig_speed: float = 20.0
## Whether this tool breaks concrete as well as earth.
@export var breaks_concrete: bool = false

## A hair past the leading edge, so the probe lands inside what is ahead
## rather than on its surface.
const PROBE_INSET := 0.5
## Debris flies up and back towards the digger.
const DEBRIS_THROW := Vector2(-0.6, -0.8)
## How fast a lemming drops onto a tunnel floor just under its feet, in
## pixels per second.
const SETTLE_SPEED := 120.0

## The state the lemming is in while digging (picks its animation).
var dig_state: LemmingStateMachine.State = LemmingStateMachine.State.MINING
## Sound played for every slice dug (see AudioManager.play_sound).
var dig_sound: StringName = &"pickaxe_hit"

var _advance_remaining: float = 0.0
## No block being dug yet.
const NO_CELL := Vector2i(-1048576, -1048576)

## The block being dug, to tell one that another lemming in the same tunnel
## finished off (walk on into it) from open space (stop there).
var _current_cell := NO_CELL
## Where the current block is being dug (see _body_rows_y).
var _dig_rows_y: Array[float] = []


func can_apply_to(lemming: LemmingController) -> bool:
	return lemming.state_machine.current_state == LemmingStateMachine.State.WALKING \
		and lemming.pending_wall_tool == null


## Carried, not used yet: the digging starts at the next wall.
func apply_to(lemming: LemmingController) -> void:
	lemming.pending_wall_tool = self


func occupies_skill_slot() -> bool:
	return false


## Probed where walking sees the wall (get_forward_position), which is a
## couple of pixels ahead: the lemming has not touched the wall yet when it
## decides to turn, so a probe right at its leading edge found nothing.
## A wall this tool cannot break is turned away from like any other.
func can_start_at_wall(lemming: LemmingController) -> bool:
	var ahead := lemming.get_forward_position()
	return lemming.terrain.is_solid_at(ahead) and (breaks_concrete or not lemming.terrain.is_concrete_at(ahead))


## Lines the leading edge up with the wall's face first, so each slice
## cleared is exactly the room the body walks into.
func start_at_wall(lemming: LemmingController) -> void:
	lemming.velocity = Vector2.ZERO
	var face := lemming.terrain.cell_rect_at(lemming.get_forward_position())
	var face_x := face.position.x if lemming.direction > 0 else face.end.x
	lemming.global_position.x += face_x - _leading_edge(lemming)
	lemming.state_machine.change_state(dig_state)


func physics_process(lemming: LemmingController, delta: float) -> bool:
	lemming.velocity = Vector2.ZERO

	if _advance_remaining <= 0.0:
		# Nothing to stand on any more (dug out from under it) or nothing
		# left ahead that this tool breaks: walk or fall from here. With the
		# floor gone under its middle it still finishes the block it is
		# part way through: stopping there left half a block in front of a
		# lemming resting on the ledge's corner, and it turned back instead
		# of walking on and dropping out of the tunnel (campaign level 18).
		var ahead := _point_ahead(lemming)
		var cell := lemming.terrain.local_to_map(lemming.terrain.to_local(ahead))
		if not lemming.terrain.is_solid_at(lemming.get_feet_position()):
			# Started from a diagonal ladder's step, the tunnel's floor is a
			# little below the feet: it settles onto it and digs on. It used
			# to stop there, a block in, with the tool spent (prints/bug21.png).
			if _settle_onto_tunnel_floor(lemming, delta):
				return true
			if cell.x != _current_cell.x:
				return false
		var material := lemming.terrain.material_at(ahead)
		if not _dig_slice_ahead(lemming, ahead, cell):
			# Two lemmings digging the same tunnel take its block twice as
			# fast: it is gone while this one is only part way in. That is
			# not open space, so it walks to the block's far side and digs
			# on (both used to stop there, in the middle of the wall).
			if cell.x != _current_cell.x or lemming.terrain.is_solid_at(ahead):
				return false
			_advance_remaining = _distance_to_far_side(lemming, cell)
			if _advance_remaining <= PROBE_INSET:
				_advance_remaining = 0.0
				return false
			_current_cell = NO_CELL
			return true
		_current_cell = cell
		DebrisBurst.spawn(lemming.get_parent(), ahead, Vector2(DEBRIS_THROW.x * lemming.direction, DEBRIS_THROW.y), material)
		AudioManager.play_sound(dig_sound)
		_advance_remaining = lemming.terrain.get_dig_stage_height()

	var step := minf(dig_speed * delta, _advance_remaining)
	lemming.global_position.x += step * lemming.direction
	_advance_remaining -= step
	return true


## Digs the slice ahead in every row the body reaches into. Standing on the
## grid that is one row (the tunnel is one block tall); standing on a
## diagonal ladder's step the body straddles two rows, and a tunnel of the
## middle row only left the head of every lemming behind against its
## ceiling, so they turned back at its mouth (prints/bug21.png).
func _dig_slice_ahead(lemming: LemmingController, ahead: Vector2, cell: Vector2i) -> bool:
	if cell.x != _current_cell.x:
		_dig_rows_y = _body_rows_y(lemming, ahead)
	var dug := false
	for y in _dig_rows_y:
		if lemming.terrain.dig_side_stage_at(Vector2(ahead.x, y), lemming.direction, breaks_concrete, id):
			dug = true
	return dug


## The middle of each row the body reaches into, decided when a block is
## started and kept until it is through: the lemming settles onto the
## tunnel floor part way into the first block, and digging only the rows
## it reached from there left the top of that block in place.
func _body_rows_y(lemming: LemmingController, ahead: Vector2) -> Array[float]:
	var body := lemming.get_body_rect()
	var rows: Array[float] = []
	for y in [ahead.y, body.position.y + PROBE_INSET, body.end.y - PROBE_INSET]:
		var row_middle := lemming.terrain.cell_rect_at(Vector2(ahead.x, y)).get_center().y
		if not rows.has(row_middle):
			rows.append(row_middle)
	return rows


## Lowers the lemming towards ground a short way under its feet, at falling
## pace. False when there is none that close (a real drop: the tool ends).
func _settle_onto_tunnel_floor(lemming: LemmingController, delta: float) -> bool:
	var feet := lemming.get_feet_position()
	var max_drop := lemming.terrain.get_cell_size().y
	for drop in range(1, int(max_drop)):
		if lemming.terrain.is_solid_at(feet + Vector2(0, drop)):
			lemming.global_position.y += minf(float(drop), SETTLE_SPEED * delta)
			return true
	return false


## Just past the leading edge, at the middle of the body: the block the
## tunnel goes through, one block tall at the height the lemming walks.
func _point_ahead(lemming: LemmingController) -> Vector2:
	return Vector2(_leading_edge(lemming) + PROBE_INSET * lemming.direction, lemming.get_body_rect().get_center().y)


func _distance_to_far_side(lemming: LemmingController, cell: Vector2i) -> float:
	var rect := lemming.terrain.cell_rect_at(lemming.terrain.to_global(lemming.terrain.map_to_local(cell)))
	var far_x := rect.end.x if lemming.direction > 0 else rect.position.x
	return absf(far_x - _leading_edge(lemming))


func _leading_edge(lemming: LemmingController) -> float:
	var body := lemming.get_body_rect()
	return body.end.x if lemming.direction > 0 else body.position.x
