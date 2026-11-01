class_name SkillBase
extends RefCounted
## Strategy base for a lemming skill. Concrete skills (skill_digger.gd,
## skill_builder.gd, ...) override the hooks below. LemmingController holds
## at most one active skill instance per lemming and delegates to it instead
## of branching on skill type itself.

## Identifier matching LevelData.available_skills / skill_counts (e.g. "digger").
var skill_id: String = ""

## Whether this skill can be assigned to the lemming in its current state.
func can_apply_to(lemming: LemmingController) -> bool:
	return lemming.state_machine.can_receive_skill()

## Called once when the skill is assigned; must move the lemming into the
## matching LemmingStateMachine.State.
func apply_to(_lemming: LemmingController) -> void:
	pass

## Called every physics frame while the lemming's state matches this skill.
## Return true while the skill is still active, false once it has finished
## (LemmingController then returns the lemming to WALKING).
func physics_process(_lemming: LemmingController, _delta: float) -> bool:
	return false

## Whether this skill takes exclusive control of the lemming through
## LemmingController.current_skill (the default for "action" skills like
## Digger/Builder/Basher/Miner/Blocker). Climber and Floater are permanent
## traits handled directly by LemmingController's core state logic, and
## Bomber ticks down independently alongside whatever else the lemming is
## doing, so all three override this to false.
func occupies_skill_slot() -> bool:
	return true
