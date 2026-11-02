class_name RoguelikeCharacters
extends RefCounted
## Every character a run can be played with: name, passive bonus, special
## ability (RoguelikeAbilities, its own slot in the tool bar), colour, unlock
## price and the trait that implements the passive. Adding a character is
## one entry here, one RoguelikeCharacterTrait subclass and, for a new
## ability, one RoguelikeAbility.

const WIZARD := &"wizard"
const MINER := &"miner"
const ENGINEER := &"engineer"
const SCOUT := &"scout"
const TINKERER := &"tinkerer"

const DEFINITIONS := {
	WIZARD: {
		"name": "Mago",
		"passive": "",
		"special": RoguelikeAbilities.TELEPORT,
		"short_passive": "",
		"colour": Color(0.62, 0.45, 1.0),
		"price": 0,
		"trait": preload("res://modes/roguelike/scripts/characters/traits/wizard_trait.gd"),
	},
	MINER: {
		"name": "Mineiro",
		"passive": "Cava duas vezes mais rápido com Pá, Picareta e Britadeira.",
		"special": RoguelikeAbilities.BREAK_CONCRETE,
		"short_passive": "Cava 2x mais rápido.",
		"colour": Color(0.95, 0.55, 0.2),
		"price": 25,
		"trait": preload("res://modes/roguelike/scripts/characters/traits/miner_trait.gd"),
	},
	ENGINEER: {
		"name": "Engenheiro",
		"passive": "Pontes e escadas dele têm 4 peças a mais.",
		"special": RoguelikeAbilities.PLATFORM,
		"short_passive": "+4 peças em pontes e escadas.",
		"colour": Color(1.0, 0.85, 0.2),
		"price": 35,
		"trait": preload("res://modes/roguelike/scripts/characters/traits/engineer_trait.gd"),
	},
	SCOUT: {
		"name": "Batedor",
		"passive": "Pernas fortes: aguenta quedas duas vezes mais altas.",
		"special": RoguelikeAbilities.LEAP,
		"short_passive": "Aguenta quedas 2x mais altas.",
		"colour": Color(0.35, 0.85, 0.4),
		"price": 45,
		"trait": preload("res://modes/roguelike/scripts/characters/traits/scout_trait.gd"),
	},
	TINKERER: {
		"name": "Inventor",
		"passive": "",
		"special": RoguelikeAbilities.REPEAT,
		"short_passive": "",
		"colour": Color(0.3, 0.8, 1.0),
		"price": 60,
		"trait": preload("res://modes/roguelike/scripts/characters/traits/tinkerer_trait.gd"),
	},
}

## The character unlocked from the start (price 0).
const STARTER := WIZARD
## The ones bought with the coin vault (RoguelikeProfile), cheapest first.
const UNLOCK_ORDER: Array[StringName] = [MINER, ENGINEER, SCOUT, TINKERER]
## Every character, in the order the character screen shows them.
const ALL: Array[StringName] = [WIZARD, MINER, ENGINEER, SCOUT, TINKERER]
## Each character's portrait (64x64, tools/build_card_art.py).
const PORTRAIT_PATH := "res://assets/sprites/ui/cards/character_%s.png"


static func get_display_name(character_id: StringName) -> String:
	return DEFINITIONS[character_id].name


## What the character does: its passive bonus, if any, then its ability.
static func get_ability(character_id: StringName) -> String:
	var special := get_special(character_id)
	var text := "%s: %s" % [RoguelikeAbilities.get_display_name(special), RoguelikeAbilities.get_description(special)]
	var passive: String = DEFINITIONS[character_id].passive
	return text if passive == "" else "%s %s" % [passive, text]


## The id of the character's special ability (RoguelikeAbilities).
static func get_special(character_id: StringName) -> StringName:
	return DEFINITIONS[character_id].special


## The ability in a few words, for the small text panel of a card.
static func get_short_ability(character_id: StringName) -> String:
	var ability := RoguelikeAbilities.get_display_name(get_special(character_id)) + "."
	var passive := get_short_passive(character_id)
	return ability if passive == "" else "%s %s" % [passive, ability]


## The passive bonus in a few words, "" for a character without one.
static func get_short_passive(character_id: StringName) -> String:
	return DEFINITIONS[character_id].short_passive


## Coins from the vault that unlock the character (RoguelikeProfile.buy).
static func get_price(character_id: StringName) -> int:
	return int(DEFINITIONS[character_id].price)


static func get_portrait(character_id: StringName) -> Texture2D:
	return load(PORTRAIT_PATH % character_id)


static func get_colour(character_id: StringName) -> Color:
	return DEFINITIONS[character_id].colour


## Turns a freshly spawned lemming into the given character.
static func apply_to(lemming: LemmingController, character_id: StringName) -> RoguelikeCharacterTrait:
	assert(DEFINITIONS.has(character_id), "Unknown character '%s'" % character_id)
	var definition: Dictionary = DEFINITIONS[character_id]
	var character_trait: RoguelikeCharacterTrait = definition.trait.new()
	character_trait.name = "CharacterTrait"
	character_trait.character_id = character_id
	character_trait.colour = definition.colour
	lemming.add_child(character_trait)
	character_trait.attach(lemming)
	return character_trait


static func get_trait(lemming: LemmingController) -> RoguelikeCharacterTrait:
	return lemming.get_node_or_null("CharacterTrait") as RoguelikeCharacterTrait
