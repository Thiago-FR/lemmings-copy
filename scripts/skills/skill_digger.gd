class_name SkillDigger
extends SkillBase
## Digs straight down through earth, one dig stage (a slice of a tile) at a
## time, sinking smoothly onto what is left, until there is nothing solid
## under the feet or only concrete, which the shovel cannot dig.
## Then it hands control back so the lemming resumes walking or falls out of
## the bottom of the shaft.

## How fast the lemming sinks while digging, in pixels per second. Each
## stage is removed in one go, and the lemming lowers itself onto the new
## surface at this rate, so the shovel animation and the descent read as the
## same action.
@export var dig_speed: float = 20.0

## Clods of earth fly up and to the side the lemming faces.
const DEBRIS_THROW := Vector2(0.5, -0.85)

var _descent_remaining: float = 0.0


func _init() -> void:
	id = &"digger"
	display_name = "Pá"


func apply_to(lemming: LemmingController) -> void:
	lemming.velocity = Vector2.ZERO
	# Every shaft comes out exactly one column wide only if the body is
	# centred first. Without it the same tool dug a one-tile hole from one
	# standing position and a two-tile hole from another, half a tile away.
	lemming.snap_to_column_centre()
	lemming.state_machine.change_state(LemmingStateMachine.State.DIGGING)


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
	# Standing on a brick (a diagonal ladder or bridge piece): it goes in one
	# go, being one stage thick. The shovel used to find no earth there, stop
	# at once and waste the charge. The lemming sinks onto whatever was right
	# under the brick and digs on; with nothing there, the next dig finds
	# open space and it drops.
	if lemming.terrain.remove_bricks_in(slice) > 0:
		AudioManager.play_sound(&"dig_earth")
		_descent_remaining = _drop_to_ground_below(lemming)
		return true
	var material := lemming.terrain.material_at(feet)
	if lemming.terrain.dig_stage_in_rect(slice) == 0:
		return false
	DebrisBurst.spawn(lemming.get_parent(), Vector2(body.get_center().x, body.end.y), Vector2(DEBRIS_THROW.x * lemming.direction, DEBRIS_THROW.y), material)
	AudioManager.play_sound(&"dig_earth")
	_descent_remaining = lemming.terrain.solid_top_y_at(feet) - body.end.y
	return true


## Distance down to solid ground just under the feet, looking no further
## than the thickest brick (a soil ramp's half block) and a stage more;
## zero if there is none that close. Looking only two stages down missed the
## ground under a 16px soil ramp by a pixel: the shovel stopped there and the
## charge was wasted.
func _drop_to_ground_below(lemming: LemmingController) -> float:
	const PROBE_INSET := 0.5
	var body := lemming.get_body_rect()
	var reach := int(lemming.terrain.get_cell_size().y / 2.0 + lemming.terrain.get_dig_stage_height())
	for depth in range(reach):
		if lemming.terrain.is_solid_at(Vector2(body.get_center().x, body.end.y + depth + PROBE_INSET)):
			return float(depth)
	return 0.0
