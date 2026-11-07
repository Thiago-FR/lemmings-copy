class_name Rope
extends Node2D
## A rope hanging down from a ledge (SkillRope). Every lemming that drops
## off the ledge past it takes hold and slides down
## (LemmingController._try_grab_rope), so one rope gets the whole group down
## a drop that would kill them.
##
## Owned by the terrain (TerrainDestructible.place_rope), which answers
## which rope a body reaches. The node's origin is the rope's top: where it
## hangs straight down from, just clear of the ledge's face so a body on it
## does not overlap the rock. It hangs straight from the tip of a short
## beam laid on the ledge and pinned to it by a stake, the beam's tip
## sticking out over the edge to that line: the rope is seen held by the
## block, not floating beside it, and does not bend (a rope run over the
## edge and slanting out to the line looked odd). It grows downwards while
## it is being let down.

const ROPE_WIDTH := 3.0
const ROPE_COLOUR := Color(0.78, 0.62, 0.36)
const ROPE_SHADE := Color(0.5, 0.36, 0.18)
## Twists drawn along the rope, one every this many pixels.
const TWIST_SPACING := 6.0
const STAKE_SIZE := Vector2(6, 10)
const STAKE_COLOUR := Color(0.42, 0.28, 0.14)
const KNOT_RADIUS := 3.0
## How far back from the edge the beam lies on the ledge.
const BEAM_BACK := 10.0
## How far the beam's tip goes past the rope.
const BEAM_TIP := 2.0
const BEAM_HEIGHT := 4.0
const BEAM_COLOUR := Color(0.55, 0.37, 0.19)
## How deep the stake through the beam's back end goes into the ledge.
const STAKE_SUNK := 3.0
## How far below the top a body's top has to be to take hold: the hands,
## above the head (rope_slide frames), are then on the rope, below the beam.
const GRIP_BELOW_TOP := 8.0

## From the rope's top to the ledge's edge, along x (negative when the
## edge is to the left). Zero draws no beam, just the stake.
var anchor_offset: float = 0.0:
	set(value):
		anchor_offset = value
		queue_redraw()

## How far down the rope reaches, in pixels.
var length: float = 0.0:
	set(value):
		length = maxf(value, 0.0)
		queue_redraw()


## The rope's top, in world space.
func get_top() -> Vector2:
	return global_position


## The rope's bottom end, in world space.
func get_bottom() -> Vector2:
	return global_position + Vector2(0, length)


## Whether a body is close enough to take hold: the rope runs through the
## body's width, and the body is somewhere along its length.
func is_reachable_by(body: Rect2) -> bool:
	var x := global_position.x
	if x < body.position.x + ROPE_WIDTH or x > body.end.x - ROPE_WIDTH:
		return false
	return body.position.y >= global_position.y + GRIP_BELOW_TOP and body.get_center().y < get_bottom().y


func _draw() -> void:
	var back := signf(anchor_offset)
	var beam_back_x := anchor_offset + back * BEAM_BACK
	var beam_tip_x := -back * BEAM_TIP
	var beam := Rect2(Vector2(minf(beam_back_x, beam_tip_x), -BEAM_HEIGHT), Vector2(absf(beam_tip_x - beam_back_x), BEAM_HEIGHT))
	if back != 0.0:
		draw_rect(beam, BEAM_COLOUR)
		draw_line(Vector2(beam.position.x, beam.position.y + 0.5), Vector2(beam.end.x, beam.position.y + 0.5), ROPE_SHADE, 1.0)
	var stake_x := beam_back_x + (-back * STAKE_SIZE.x / 2.0 if back != 0.0 else 0.0)
	draw_rect(Rect2(Vector2(stake_x - STAKE_SIZE.x / 2.0, STAKE_SUNK - STAKE_SIZE.y), STAKE_SIZE), STAKE_COLOUR)
	# Tied round the beam's tip.
	draw_rect(Rect2(Vector2(-ROPE_WIDTH / 2.0 - 0.5, -BEAM_HEIGHT - 1.0), Vector2(ROPE_WIDTH + 1.0, BEAM_HEIGHT + 2.0)), ROPE_COLOUR)
	if length <= 0.0:
		return
	draw_line(Vector2.ZERO, Vector2(0, length), ROPE_COLOUR, ROPE_WIDTH)
	var y := TWIST_SPACING / 2.0
	while y < length:
		draw_line(Vector2(-ROPE_WIDTH / 2.0, y), Vector2(ROPE_WIDTH / 2.0, y + 2.0), ROPE_SHADE, 1.0)
		y += TWIST_SPACING
	draw_circle(Vector2(0, length), KNOT_RADIUS, ROPE_SHADE)
