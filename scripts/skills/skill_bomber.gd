class_name SkillBomber
extends SkillBase
## Arms a fuse on the lemming; once it runs out, destroys terrain in a
## radius around it and removes the lemming. Unlike other skills, it can be
## assigned in any alive state (including mid-skill) and doesn't interrupt
## whatever the lemming was already doing until the fuse actually goes off
## (see LemmingController.armed_bomber) — this also doubles as the way to
## deliberately remove excess lemmings.

var _elapsed_seconds: float = 0.0


func can_apply_to(lemming: LemmingController) -> bool:
	return lemming.state_machine.is_alive() and lemming.armed_bomber == null


func apply_to(lemming: LemmingController) -> void:
	lemming.armed_bomber = self


func physics_process(lemming: LemmingController, delta: float) -> bool:
	_elapsed_seconds += delta
	if _elapsed_seconds < Constants.BOMBER_FUSE_SECONDS:
		return true

	var terrain: TerrainDestructible = lemming.get_tree().get_first_node_in_group("terrain")
	if terrain != null:
		terrain.destroy_circle(lemming.global_position, Constants.BOMBER_EXPLOSION_RADIUS)

	lemming.die()
	return false


func occupies_skill_slot() -> bool:
	return false
