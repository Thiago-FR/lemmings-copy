class_name SkillClimber
extends SkillBase
## Permanent trait: the lemming climbs vertical walls instead of turning
## around when it hits one. The actual climb (LemmingStateMachine.State.CLIMBING)
## is driven by LemmingController's own state handling, not by this script's
## physics_process, since the trait persists for the lemming's whole life
## instead of occupying its single "active skill" slot.


func can_apply_to(lemming: LemmingController) -> bool:
	return lemming.state_machine.can_receive_skill() and not lemming.has_climber_skill


func apply_to(lemming: LemmingController) -> void:
	lemming.has_climber_skill = true


func occupies_skill_slot() -> bool:
	return false
