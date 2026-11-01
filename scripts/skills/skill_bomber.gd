class_name SkillBomber
extends SkillBase
## Arms a fuse on the lemming; once it runs out, destroys terrain in a
## radius around it and kills the lemming. Unlike other skills, it can be
## assigned in any alive state (including mid-skill) and doesn't interrupt
## whatever the lemming was already doing until the fuse goes off (see
## LemmingController.armed_bomber). This doubles as the way to deliberately
## remove excess lemmings.

## Seconds between assignment and the explosion.
@export var fuse_seconds: float = 5.0
## Terrain within this many pixels of the lemming is destroyed.
@export var explosion_radius: float = 24.0

var _elapsed_seconds: float = 0.0


func _init() -> void:
	id = &"bomber"
	display_name = "Explosivo"


func can_apply_to(lemming: LemmingController) -> bool:
	return lemming.state_machine.is_alive() and lemming.armed_bomber == null


func apply_to(lemming: LemmingController) -> void:
	lemming.armed_bomber = self


func physics_process(lemming: LemmingController, delta: float) -> bool:
	_elapsed_seconds += delta
	if _elapsed_seconds < fuse_seconds:
		return true

	lemming.terrain.destroy_circle(lemming.global_position, explosion_radius)
	lemming.die(LemmingController.DeathCause.EXPLOSION)
	return false


func occupies_skill_slot() -> bool:
	return false
