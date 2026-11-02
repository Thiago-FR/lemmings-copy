class_name RoguelikeAbilities
extends RefCounted
## Every character's special ability: name, what it does, its icon
## (tools/build_ability_art.py), how many charges it starts each stage with
## and the class that does it. Each character names its own in
## character_catalog.gd ("special").

const TELEPORT := &"teleport"
const BREAK_CONCRETE := &"break_concrete"
const PLATFORM := &"platform"
const LEAP := &"leap"
const REPEAT := &"repeat"

## Charges are few on purpose: an ability is a way out of a tight spot, not
## a second tool bar. The Repeat's single charge is its old "once per
## stage". More come from the relic RoguelikeRelics.ABILITY_CHARGES and the
## recharge items in the stages.
const DEFINITIONS := {
	TELEPORT: {
		"name": "Teleporte",
		"description": "Atravessa uma parede ou um chão de 1 bloco.",
		"charges": 2,
		"script": preload("res://modes/roguelike/scripts/abilities/teleport_ability.gd"),
	},
	BREAK_CONCRETE: {
		"name": "Quebra-concreto",
		"description": "Quebra 1 bloco de concreto na frente.",
		"charges": 2,
		"script": preload("res://modes/roguelike/scripts/abilities/break_concrete_ability.gd"),
	},
	PLATFORM: {
		"name": "Plataforma",
		"description": "Põe na hora uma tábua de 3 blocos onde o chão acaba.",
		"charges": 2,
		"script": preload("res://modes/roguelike/scripts/abilities/platform_ability.gd"),
	},
	LEAP: {
		"name": "Salto",
		"description": "Pula um vão de até 3 blocos ou sobe um degrau de até 2.",
		"charges": 3,
		"script": preload("res://modes/roguelike/scripts/abilities/leap_ability.gd"),
	},
	REPEAT: {
		"name": "Repetir",
		"description": "Dá de novo a última ferramenta que ele recebeu, sem gastar carga.",
		"charges": 1,
		"script": preload("res://modes/roguelike/scripts/abilities/repeat_ability.gd"),
	},
}

const ALL: Array[StringName] = [TELEPORT, BREAK_CONCRETE, PLATFORM, LEAP, REPEAT]
## The recharge item and the relic share this icon.
const CHARGE_ICON := "ability_charge"


static func create(ability_id: StringName) -> RoguelikeAbility:
	assert(DEFINITIONS.has(ability_id), "Unknown ability '%s'" % ability_id)
	return DEFINITIONS[ability_id].script.new()


static func get_display_name(ability_id: StringName) -> String:
	return DEFINITIONS[ability_id].name


static func get_description(ability_id: StringName) -> String:
	return DEFINITIONS[ability_id].description


static func get_base_charges(ability_id: StringName) -> int:
	return int(DEFINITIONS[ability_id].charges)


## The icon id for UiStyle.icon() ("ability_teleport").
static func get_icon_id(ability_id: StringName) -> String:
	return "ability_%s" % ability_id
