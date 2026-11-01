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

## The state the lemming is in while digging (picks its animation).
var dig_state: LemmingStateMachine.State = LemmingStateMachine.State.MINING

var _advance_remaining: float = 0.0


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
		# left ahead that this tool breaks: walk or fall from here.
		if not lemming.terrain.is_solid_at(lemming.get_feet_position()):
			return false
		var ahead := _point_ahead(lemming)
		var material := lemming.terrain.material_at(ahead)
		if not lemming.terrain.dig_side_stage_at(ahead, lemming.direction, breaks_concrete):
			return false
		DebrisBurst.spawn(lemming.get_parent(), ahead, Vector2(DEBRIS_THROW.x * lemming.direction, DEBRIS_THROW.y), material)
		_advance_remaining = lemming.terrain.get_dig_stage_height()

	var step := minf(dig_speed * delta, _advance_remaining)
	lemming.global_position.x += step * lemming.direction
	_advance_remaining -= step
	return true


## Just past the leading edge, at the middle of the body: the block the
## tunnel goes through, one block tall at the height the lemming walks.
func _point_ahead(lemming: LemmingController) -> Vector2:
	return Vector2(_leading_edge(lemming) + PROBE_INSET * lemming.direction, lemming.get_body_rect().get_center().y)


func _leading_edge(lemming: LemmingController) -> float:
	var body := lemming.get_body_rect()
	return body.end.x if lemming.direction > 0 else body.position.x
