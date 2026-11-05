class_name ItemSpec
extends Resource
## An item placed in a level: what it gives and the cell it lies on. It is
## put on top of that floor cell, at body height, so a lemming walking by
## collects it. What a kind does is up to whoever collects it: the core
## (ItemCollector) handles tools, time and the bag; the rest belong to the
## mode that hands them out.

enum Kind {
	## `amount` charges of the tool `tool_id`.
	TOOL,
	## One rescue: brings back a lemming lost earlier (a mode's own rule).
	REVIVE,
	## `amount` extra seconds on the stage clock.
	TIME,
	## One extra charge of every tool already in the bar.
	CHARGE_BAG,
	## `amount` coins for the shop (more with the Greed relic).
	COINS,
	## `amount` more charges of the character's ability (a mode's own rule).
	ABILITY_CHARGE,
}

@export var kind: Kind = Kind.TOOL
@export var column: int = 0
## The floor row it lies on (lemmings walk on top of that row).
@export var row: int = 0
@export var tool_id: String = ""
@export var amount: int = 1
## Icon drawn on the item instead of its kind's own (a mode's item: the
## roguelike's ability charge).
@export var icon_id: String = ""


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
		Kind.COINS:
			return "+%d moedas" % amount
		Kind.ABILITY_CHARGE:
			return "+%d carga da habilidade" % amount
	return ""
