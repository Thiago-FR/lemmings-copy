class_name SkillMiner
extends SkillBase
## Pickaxe ("Picareta"): the shovel's digging turned sideways. At a wall,
## the lemming digs a tunnel one block tall straight ahead, one dig stage (a
## slice of a block) at a time, walking into each slice as it clears it,
## until it breaks through into open space. Then it walks on.
##
## Like the shovel, a block is removed a slice at a time rather than all at
## once, so the dig and the walk forward read as one action instead of the
## lemming jumping a whole block per swing.
##
## Given to a walking lemming, it is carried until the lemming walks into a
## wall and used there (see LemmingController.pending_wall_tool): a lemming
## turns around the instant it touches a wall, so it is never standing
## against one for the player to click.

## How fast the lemming advances while digging, in pixels per second. Same
## pace as the shovel's descent.
@export var dig_speed: float = 20.0

## A hair past the leading edge, so the probe lands inside what is ahead
## rather than on its surface.
const PROBE_INSET := 0.5

var _advance_remaining: float = 0.0


func _init() -> void:
	id = &"miner"
	display_name = "Picareta"


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
func can_start_at_wall(lemming: LemmingController) -> bool:
	return lemming.terrain.is_solid_at(lemming.get_forward_position())


## Lines the leading edge up with the wall's face first, so each slice
## cleared is exactly the room the body walks into.
func start_at_wall(lemming: LemmingController) -> void:
	lemming.velocity = Vector2.ZERO
	var face := lemming.terrain.cell_rect_at(lemming.get_forward_position())
	var face_x := face.position.x if lemming.direction > 0 else face.end.x
	var body := lemming.get_body_rect()
	var leading_edge := body.end.x if lemming.direction > 0 else body.position.x
	lemming.global_position.x += face_x - leading_edge
	lemming.state_machine.change_state(LemmingStateMachine.State.MINING)


func physics_process(lemming: LemmingController, delta: float) -> bool:
	lemming.velocity = Vector2.ZERO

	if _advance_remaining <= 0.0:
		# Nothing to stand on any more (dug out from under it) or nothing
		# left ahead (broken through): walk or fall from here.
		if not lemming.terrain.is_solid_at(lemming.get_feet_position()):
			return false
		if not lemming.terrain.dig_side_stage_at(_point_ahead(lemming), lemming.direction):
			return false
		_advance_remaining = lemming.terrain.get_dig_stage_height()

	var step := minf(dig_speed * delta, _advance_remaining)
	lemming.global_position.x += step * lemming.direction
	_advance_remaining -= step
	return true


## Just past the leading edge, at the middle of the body: the block the
## tunnel goes through, one block tall at the height the lemming walks.
func _point_ahead(lemming: LemmingController) -> Vector2:
	var body := lemming.get_body_rect()
	var leading_edge := body.end.x if lemming.direction > 0 else body.position.x
	return Vector2(leading_edge + PROBE_INSET * lemming.direction, body.get_center().y)
