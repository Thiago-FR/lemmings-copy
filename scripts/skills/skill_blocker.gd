class_name SkillBlocker
extends SkillBase
## Stops the lemming in place and turns it into an obstacle: other walking
## lemmings that touch its BlockerZone (see LemmingController) turn around.
## A blocker stays blocking indefinitely, matching the original game, until
## removed by another skill (e.g. Bomber).


func _init() -> void:
	id = &"blocker"
	display_name = "Escudo"


func can_apply_to(lemming: LemmingController) -> bool:
	return lemming.state_machine.current_state == LemmingStateMachine.State.WALKING


func apply_to(lemming: LemmingController) -> void:
	lemming.velocity.x = 0.0
	lemming.state_machine.change_state(LemmingStateMachine.State.BLOCKING)
	lemming.set_blocker_zone_active(true)


func physics_process(lemming: LemmingController, _delta: float) -> bool:
	lemming.velocity.x = 0.0
	return true
