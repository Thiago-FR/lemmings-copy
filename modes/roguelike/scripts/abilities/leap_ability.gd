class_name RoguelikeLeapAbility
extends RoguelikeAbility
## Scout ("Batedor"), Leap: jumps over a gap up to MAX_GAP_TILES blocks wide
## to ground at the same height, or up a step up to MAX_STEP_TILES blocks
## tall, whichever comes first within a block ahead. The jump is an arc
## (RoguelikeLeapMotion) checked against the terrain before it starts: one
## that would hit something, or land where the body does not fit, is
## refused, trying a flatter arc first under a low ceiling.

const MAX_GAP_TILES := 3
const MAX_STEP_TILES := 2
## Below this a "step" is one the lemming walks up anyway (the core's wall
## height, Constants.STEP_MAX_HEIGHT minus its probe margin).
const MIN_STEP_HEIGHT := 30.0
## How far onto the far side the body lands, past the edge.
const LANDING_MARGIN := 4.0
## Arc heights tried, highest first, above the higher of the two ends.
const ARC_HEIGHTS: Array[float] = [24.0, 14.0, 6.0, 2.0]
## Points along the arc checked for terrain.
const PATH_SAMPLES := 16
const DUST_COLOUR := Color(0.85, 0.8, 0.7)


func _init() -> void:
	id = RoguelikeAbilities.LEAP


func _use(lemming: LemmingController) -> bool:
	var landing := _find_landing(lemming)
	if is_nan(landing.x):
		return false
	var start := lemming.get_body_rect().get_center()
	for arc in ARC_HEIGHTS:
		var motion := RoguelikeLeapMotion.make(start, landing, arc)
		if _path_is_clear(lemming, motion):
			_jump(lemming, motion)
			return true
	return false


## Where the body's centre lands, or NAN: on top of a step, or across a gap.
func _find_landing(lemming: LemmingController) -> Vector2:
	var body := lemming.get_body_rect()
	var side := lemming.direction
	var tile := lemming.terrain.get_cell_size()
	var feet_y := roundf(body.end.y)
	var half_width := body.size.x / 2.0
	var x := floorf(front_edge(body, -side)) if side > 0 else ceilf(front_edge(body, -side))
	var limit := absf(front_edge(body, side) - x) + tile.x * REACH_TILES
	for _pixel in int(limit):
		var column_x := x + side * PROBE_INSET
		if lemming.terrain.is_terrain_solid_in_rect(Rect2(column_x - 0.25, feet_y - body.size.y + BODY_INSET, 0.5, body.size.y - BODY_INSET * 2.0)):
			return _step_landing(lemming, x, feet_y, half_width)
		if not lemming.terrain.is_solid_at(Vector2(column_x, feet_y + PROBE_INSET)):
			return _gap_landing(lemming, x, feet_y, half_width)
		x += side
	return Vector2(NAN, NAN)


## On top of the wall starting at wall_x, if it is a step low enough.
func _step_landing(lemming: LemmingController, wall_x: float, feet_y: float, half_width: float) -> Vector2:
	var side := lemming.direction
	var tile := lemming.terrain.get_cell_size()
	var probe_x := wall_x + side * PROBE_INSET
	var max_rise := int(tile.y * MAX_STEP_TILES) + 1
	for rise in range(1, max_rise + 1):
		if not lemming.terrain.is_solid_at(Vector2(probe_x, feet_y - rise - PROBE_INSET)):
			if rise < MIN_STEP_HEIGHT:
				return Vector2(NAN, NAN)
			var top_y := feet_y - rise
			return Vector2(wall_x + side * (half_width + LANDING_MARGIN), top_y - lemming.get_body_rect().size.y / 2.0)
	return Vector2(NAN, NAN)


## Across the gap starting at edge_x, on ground at the same height.
func _gap_landing(lemming: LemmingController, edge_x: float, feet_y: float, half_width: float) -> Vector2:
	var side := lemming.direction
	var max_width := int(lemming.terrain.get_cell_size().x * MAX_GAP_TILES) + 1
	for distance in range(1, max_width + 1):
		var x := edge_x + side * distance
		if lemming.terrain.is_solid_at(Vector2(x + side * PROBE_INSET, feet_y + PROBE_INSET)):
			return Vector2(x + side * (half_width + LANDING_MARGIN), feet_y - lemming.get_body_rect().size.y / 2.0)
	return Vector2(NAN, NAN)


## The landing spot fits the body and stands on ground, and nothing solid is
## in the way at any point of the arc (bricks left out: they only block from
## above, and the arc comes down onto them from above).
func _path_is_clear(lemming: LemmingController, motion: RoguelikeLeapMotion) -> bool:
	if not is_inside_stage(lemming.terrain, motion.end_centre) or not body_fits_at(lemming, motion.end_centre):
		return false
	var body := lemming.get_body_rect()
	for sample in range(1, PATH_SAMPLES + 1):
		var moved := body
		moved.position += motion.centre_at(float(sample) / PATH_SAMPLES) - body.get_center()
		if lemming.terrain.is_terrain_solid_in_rect(moved.grow(-BODY_INSET)):
			return false
	return true


func _jump(lemming: LemmingController, motion: RoguelikeLeapMotion) -> void:
	var body := lemming.get_body_rect()
	RoguelikeAbilityEffect.spawn(lemming.get_parent(), Vector2(body.get_center().x, body.end.y), RoguelikeAbilityEffect.Style.PUFF, DUST_COLOUR)
	motion.landed.connect(func() -> void:
		if is_instance_valid(lemming):
			var landed_body := lemming.get_body_rect()
			RoguelikeAbilityEffect.spawn(lemming.get_parent(), Vector2(landed_body.get_center().x, landed_body.end.y), RoguelikeAbilityEffect.Style.PUFF, DUST_COLOUR))
	lemming.velocity = Vector2.ZERO
	lemming.current_skill = motion
	lemming.state_machine.change_state(LemmingStateMachine.State.PERFORMING)
	AudioManager.play_sound(&"assign_tool")
