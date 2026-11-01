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


## For tools the lemming carries until it walks into a wall (see
## LemmingController.pending_wall_tool): whether this wall is one the tool
## can be used on. Returning false makes the lemming turn around as usual
## and keep the tool for the next wall.
func can_start_at_wall(_lemming: LemmingController) -> bool:
	return false


## Called when the lemming walks into a wall that can_start_at_wall()
## accepted. The tool has already become the lemming's current_skill.
func start_at_wall(_lemming: LemmingController) -> void:
	pass


## For tools the lemming carries that start by themselves on the way rather
## than at a wall (the bridge, at the next gap ahead): checked on every frame
## the lemming walks with the tool.
func can_start_while_walking(_lemming: LemmingController) -> bool:
	return false


## Called when can_start_while_walking() said yes. The tool has already
## become the lemming's current_skill.
func start_while_walking(_lemming: LemmingController) -> void:
	pass


## Whether this skill takes exclusive control of the lemming through
## LemmingController.current_skill (the default for "action" skills like
## Digger/Builder/Basher/Miner/Blocker). Climber and Floater are permanent
## traits handled by LemmingController's core movement, and Bomber ticks
## alongside whatever else the lemming is doing, so those return false.
func occupies_skill_slot() -> bool:
	return true
