class_name SkillAnimation
extends RefCounted
## Keeps a construction tool's animation on the frames that match what the
## tool is doing at the moment.
##
## The vertical ladder, the diagonal ladder and the bridge alternate two
## phases inside one state: working on a piece (fitting a ladder segment,
## laying and hammering a plank) and then moving onto it (climbing the
## segment, walking onto the plank). Their animations hold both: the first
## WORK_FRAMES frames are the work, the rest the move (see
## tools/build_construction_frames.py). Left to loop on its own the animation
## drifts out of step, because the move takes a different time on each
## piece (the first step, a step cut against a wall, the walk to a gap's
## edge), so each tool calls hold() every physics frame with the phase it is
## in.

## Frames of the work phase, at the start of each construction animation.
const WORK_FRAMES := 4


## Moves the sprite into the run of frames for the phase, from its start,
## when it is outside it. Within the run it plays on undisturbed. Does
## nothing while the sprite shows another animation (the state is changed
## before LemmingController switches the animation over).
static func hold(sprite: AnimatedSprite2D, animation: StringName, working: bool) -> void:
	if sprite == null or sprite.animation != animation:
		return
	if working and sprite.frame >= WORK_FRAMES:
		sprite.frame = 0
	elif not working and sprite.frame < WORK_FRAMES:
		sprite.frame = WORK_FRAMES
