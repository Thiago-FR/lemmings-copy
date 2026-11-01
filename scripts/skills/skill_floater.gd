class_name SkillFloater
extends SkillBase
## Permanent trait: the lemming opens a parachute (LemmingStateMachine.State.FLOATING)
## instead of FALLING whenever it walks off a ledge, descending slowly and
## surviving any fall. Handled directly by LemmingController's fall handling.


func can_apply_to(lemming: LemmingController) -> bool:
	return lemming.state_machine.can_receive_skill() and not lemming.has_floater_skill


func apply_to(lemming: LemmingController) -> void:
	lemming.has_floater_skill = true


func occupies_skill_slot() -> bool:
	return false
