class_name SkillFloater
extends SkillBase
## Permanent trait: the lemming opens a parachute (LemmingStateMachine.State.FLOATING)
## instead of FALLING whenever it walks off a ledge, descending slowly and
## surviving any fall. Handled by LemmingController's fall handling.


func _init() -> void:
	id = &"floater"
	display_name = "Paraquedas"


func can_apply_to(lemming: LemmingController) -> bool:
	return lemming.state_machine.can_receive_skill() and not lemming.has_floater_skill


func apply_to(lemming: LemmingController) -> void:
	lemming.has_floater_skill = true
	# The trait only takes effect when a fall starts, so a lemming handed the
	# parachute already falling kept falling and died on landing, even though
	# the tool was accepted and its charge spent. It opens right away instead.
	if lemming.state_machine.current_state == LemmingStateMachine.State.FALLING:
		lemming.state_machine.change_state(LemmingStateMachine.State.FLOATING)


func occupies_skill_slot() -> bool:
	return false
