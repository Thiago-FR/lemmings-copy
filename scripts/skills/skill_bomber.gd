class_name SkillBomber
extends SkillBase
## Arms a fuse on the lemming; once it runs out, destroys the terrain around
## it and kills the lemming. Unlike other skills, it can be assigned in any
## alive state (including mid-skill) and doesn't interrupt whatever the
## lemming was already doing until the fuse goes off (see
## LemmingController.armed_bomber). This doubles as the way to deliberately
## remove excess lemmings.

## Seconds between assignment and the explosion.
@export var fuse_seconds: float = 5.0
## How far past the edges of the body the blast reaches, in pixels. Every
## terrain cell the blast touches is destroyed whole. A bit over a tile, so
## the wall next to the lemming is opened even when the fuse runs out with
## the body a step or so away from it, as happens to a lemming that keeps
## walking while the fuse burns.
@export var blast_reach: float = 40.0

## The blast stops this far above the feet, so a body resting a fraction of
## a pixel into the floor does not pull the floor row into the blast.
const FLOOR_CLEARANCE := 1.0

var _elapsed_seconds: float = 0.0


func _init() -> void:
	id = &"bomber"
	display_name = "Bomba"


func can_apply_to(lemming: LemmingController) -> bool:
	return lemming.state_machine.is_alive() and lemming.armed_bomber == null


func apply_to(lemming: LemmingController) -> void:
	lemming.armed_bomber = self


func physics_process(lemming: LemmingController, delta: float) -> bool:
	_elapsed_seconds += delta
	if _elapsed_seconds < fuse_seconds:
		return true

	lemming.terrain.destroy_rect(_blast_rect(lemming))
	lemming.die(LemmingController.DeathCause.EXPLOSION)
	return false


## The body grown by blast_reach on every side except below the feet.
##
## The blast used to be a circle of 24px around the node's origin, erasing
## cells whose centre fell inside it. On a 32px grid that never reached the
## cell beside the lemming, so it could not open the wall it was standing
## against, which is the whole point of the tool. The floor is spared on
## purpose: the terrain is a grid of whole tiles, so a crater is a pit one
## tile deep with walls too tall to walk out of, trapping every lemming that
## comes along afterwards.
func _blast_rect(lemming: LemmingController) -> Rect2:
	var body := lemming.get_body_rect()
	var top_left := body.position - Vector2(blast_reach, blast_reach)
	var bottom_right := Vector2(body.end.x + blast_reach, body.end.y - FLOOR_CLEARANCE)
	return Rect2(top_left, bottom_right - top_left)
