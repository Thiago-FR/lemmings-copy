class_name RoguelikePickupSpec
extends Resource
## An item placed in a stage: what it gives and the cell it lies on. It is
## put on top of that floor cell, at body height, so a lemming walking by
## collects it.

enum Kind {
	## `amount` charges of the tool `tool_id`.
	TOOL,
	## One rescue: brings back a lemming lost in the run (see RoguelikeRunState).
	REVIVE,
	## `amount` extra seconds on the stage clock.
	TIME,
	## One extra charge of every tool already in the bar.
	CHARGE_BAG,
}

@export var kind: Kind = Kind.TOOL
@export var column: int = 0
## The floor row it lies on (lemmings walk on top of that row).
@export var row: int = 0
@export var tool_id: String = ""
@export var amount: int = 1


## Player-facing description, shown on hover and when collected.
func describe() -> String:
	match kind:
		Kind.TOOL:
			return "+%d %s" % [amount, SkillManager.get_display_name(tool_id)]
		Kind.REVIVE:
			return "Pena da fênix (+1 resgate)"
		Kind.TIME:
			return "Ampulheta (+%ds)" % amount
		Kind.CHARGE_BAG:
			return "Bolsa (+1 em cada ferramenta)"
	return ""
