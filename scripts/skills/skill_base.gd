class_name SkillBase
extends Resource
## Base for a lemming skill (Strategy). Each concrete skill is self-contained:
## it carries its own identity, its player-facing name and every tuning
## value it needs as exported properties, and it touches the world only
## through the lemming it is applied to (body geometry, facing, state) and
## that lemming's terrain. Nothing here reads global constants or looks
## nodes up in the scene tree, so a skill can be reused in any level, test
## or game mode, tuned per use by changing its properties.
##
## A configured skill is a template. SkillManager hands each assignment its
## own copy (create_instance), so per-lemming progress such as a builder's
## step count is never shared between lemmings.

## Identifier used by LevelData.available_skills / skill_counts.
@export var id: StringName = &""

## Name the player reads on the skill button.
@export var display_name: String = ""


## A fresh copy of this template with the same tuning and no progress.
## Exported properties are copied; private progress fields start over.
func create_instance() -> SkillBase:
	return duplicate()


## Whether this skill can be assigned to the lemming in its current state.
func can_apply_to(lemming: LemmingController) -> bool:
	return lemming.state_machine.can_receive_skill()


## Called once when the skill is assigned; moves the lemming into the
## matching LemmingStateMachine.State.
func apply_to(_lemming: LemmingController) -> void:
	pass


## Called every physics frame while the lemming is in this skill's state.
## Return true while the skill is still active, false once it has finished
## (LemmingController then returns the lemming to WALKING).
func physics_process(_lemming: LemmingController, _delta: float) -> bool:
	return false


## Whether this skill takes exclusive control of the lemming through
## LemmingController.current_skill (the default for "action" skills like
## Digger/Builder/Basher/Miner/Blocker). Climber and Floater are permanent
## traits handled by LemmingController's core movement, and Bomber ticks
## alongside whatever else the lemming is doing, so those return false.
func occupies_skill_slot() -> bool:
	return true
