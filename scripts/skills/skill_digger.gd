class_name SkillDigger
extends SkillBase
## Digs straight down, one dig stage (a slice of a tile) at a time, sinking
## smoothly onto what is left, until there is nothing solid under the feet.
## Then it hands control back so the lemming resumes walking or falls out of
## the bottom of the shaft.

## How fast the lemming sinks while digging, in pixels per second. Each
## stage is removed in one go, and the lemming lowers itself onto the new
## surface at this rate, so the shovel animation and the descent read as the
## same action.
@export var dig_speed: float = 20.0

var _descent_remaining: float = 0.0


func _init() -> void:
	id = &"digger"
	display_name = "Escavador"


func apply_to(lemming: LemmingController) -> void:
	lemming.velocity = Vector2.ZERO
	_centre_body_on_column(lemming)
	lemming.state_machine.change_state(LemmingStateMachine.State.DIGGING)


## The body is narrower than a tile, so once centred it only ever overlaps
## one column and every shaft comes out the same width. Without this the
## same skill dug a one-tile hole from one standing position and a two-tile
## hole from another, half a tile away.
func _centre_body_on_column(lemming: LemmingController) -> void:
	# Centre the collision box, not the node: the shape sits at a small
	# offset from the node origin, and snapping the origin would leave the
	# body itself off-centre inside the shaft.
	var body_centre := lemming.get_body_rect().get_center()
	var shape_offset := lemming.global_position.x - body_centre.x
	lemming.global_position.x = lemming.terrain.column_centre_x(body_centre) + shape_offset


func physics_process(lemming: LemmingController, delta: float) -> bool:
	lemming.velocity = Vector2.ZERO

	if _descent_remaining <= 0.0 and not _dig_next_stage(lemming):
		# Nothing solid left below: broken through into open space.
		return false

	var step := minf(dig_speed * delta, _descent_remaining)
	lemming.global_position.y += step
	_descent_remaining -= step
	return true


## Removes one dig stage (a fraction of a tile, see
## TerrainDestructible.dig_stage_in_rect) from the cell under the feet and
## sets how far the lemming has to sink to stand on what is left.
##
## Digging a stage at a time instead of the whole tile keeps the ground just
## below the digger's feet: when the full tile was erased up front, the hole
## sat open for over a second while the digger sank into it, and lemmings
## walking past fell in ahead of him.
##
## The descent is measured to the new surface rather than a fixed amount, so
## the feet stay on it even if physics left the body resting a fraction of a
## pixel off the ground when the skill started.
func _dig_next_stage(lemming: LemmingController) -> bool:
	var body := lemming.get_body_rect()
	var feet := lemming.get_feet_position()
	var slice := Rect2(body.position.x, feet.y, body.size.x, 1.0)
	if lemming.terrain.dig_stage_in_rect(slice) == 0:
		return false
	_descent_remaining = lemming.terrain.solid_top_y_at(feet) - body.end.y
	return true
