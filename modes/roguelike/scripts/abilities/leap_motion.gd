class_name RoguelikeLeapMotion
extends SkillBase
## The Leap's arc (RoguelikeLeapAbility), run as the lemming's current skill
## in the PERFORMING state: the lemming's own physics stays out of the way
## and this moves the body from one point to the other along a parabola,
## then hands the lemming back to walking. Not a tool: SkillManager never
## sees it, and nothing can be handed to the lemming while it is in the air.

signal landed

## Seconds in the air.
const DURATION_SECONDS := 0.5

## Share of the jump spent rising, across a gap and up a step: up a step
## the body rises for longer, so its feet clear the edge.
const PEAK_TIME_GAP := 0.5
const PEAK_TIME_STEP := 0.6

var start_centre := Vector2.ZERO
var end_centre := Vector2.ZERO
## How far the arc rises above the higher of its two ends.
var arc_height := 0.0

var _elapsed := 0.0


static func make(from_centre: Vector2, to_centre: Vector2, height: float) -> RoguelikeLeapMotion:
	var motion := RoguelikeLeapMotion.new()
	motion.id = &"leap_motion"
	motion.start_centre = from_centre
	motion.end_centre = to_centre
	motion.arc_height = height
	return motion


func is_step_up() -> bool:
	return end_centre.y < start_centre.y - 1.0


## The body's centre at t (0 to 1): up to the peak (arc_height above the
## higher end) and down to the end, each half a parabola. Up a step it moves
## forward slowly at first (ease in), so it rises before reaching the edge.
func centre_at(t: float) -> Vector2:
	var peak_time := PEAK_TIME_STEP if is_step_up() else PEAK_TIME_GAP
	var peak_y := minf(start_centre.y, end_centre.y) - arc_height
	var y: float
	if t < peak_time:
		var rising := 1.0 - t / peak_time
		y = start_centre.y + (peak_y - start_centre.y) * (1.0 - rising * rising)
	else:
		var falling := (t - peak_time) / (1.0 - peak_time)
		y = peak_y + (end_centre.y - peak_y) * falling * falling
	var forward := t * t if is_step_up() else t
	return Vector2(lerpf(start_centre.x, end_centre.x, forward), y)


func is_held_tool() -> bool:
	return false


func physics_process(lemming: LemmingController, delta: float) -> bool:
	lemming.velocity = Vector2.ZERO
	_elapsed = minf(_elapsed + delta, DURATION_SECONDS)
	var t := _elapsed / DURATION_SECONDS
	lemming.global_position += centre_at(t) - lemming.get_body_rect().get_center()
	if t < 1.0:
		return true
	landed.emit()
	return false
