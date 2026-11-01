class_name SkillClimber
extends SkillBase
## Permanent trait: the lemming climbs vertical walls instead of turning
## around when it hits one. The climb itself (LemmingStateMachine.State.CLIMBING)
## is driven by LemmingController's core movement, since the trait lasts the
## lemming's whole life instead of occupying its single action slot.


func _init() -> void:
	id = &"climber"
	display_name = "Garras"


func can_apply_to(lemming: LemmingController) -> bool:
	return lemming.state_machine.can_receive_skill() and not lemming.has_climber_skill


func apply_to(lemming: LemmingController) -> void:
	lemming.has_climber_skill = true


func occupies_skill_slot() -> bool:
	return false
