class_name SkillExplosive
extends SkillBase
## Shared behaviour of the explosives (dynamite and TNT): the lemming puts a
## charge down where it stands and walks on. When the fuse runs out the
## charge blows up every terrain cell within its reach, floor included, and
## concrete as well as earth, and kills every lemming the blast touches.
##
## Placing the charge, rather than the lemming blowing itself up as in the
## original game, was the user's choice: the explosives are tools the lemming
## uses, not a way to get rid of it.
##
## Subclasses set the id, name and blast_radius_tiles.

## Seconds between putting the charge down and the explosion.
@export var fuse_seconds: float = 3.0
## How far the blast reaches, in blocks, from the block the charge sits in.
## The blast takes every block whose offset (dx, dy) from it satisfies
## dx² + dy² <= r² + 1: a 3x3 square for 1, a 5x5 square without its
## corners for 2.
@export var blast_radius_tiles: int = 1
## How the charge looks while its fuse burns.
var charge_look: ExplosiveCharge.Look = ExplosiveCharge.Look.DYNAMITE


func can_apply_to(lemming: LemmingController) -> bool:
	return lemming.state_machine.current_state == LemmingStateMachine.State.WALKING


func occupies_skill_slot() -> bool:
	return false


## Leaves a charge at the lemming's feet; the lemming itself just carries on.
func apply_to(lemming: LemmingController) -> void:
	var body := lemming.get_body_rect()
	var charge := ExplosiveCharge.new()
	charge.terrain = lemming.terrain
	charge.fuse_seconds = fuse_seconds
	charge.blast_radius_tiles = blast_radius_tiles
	charge.look = charge_look
	lemming.get_parent().add_child(charge)
	charge.global_position = Vector2(body.get_center().x, body.end.y)
