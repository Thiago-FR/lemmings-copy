class_name RoguelikeCharacters
extends RefCounted
## Every character a run can be played with: name, ability text, colour,
## unlock price and the trait that implements the ability. Adding a character is one entry here
## and one RoguelikeCharacterTrait subclass.

const WIZARD := &"wizard"
const MINER := &"miner"
const ENGINEER := &"engineer"
const SCOUT := &"scout"
const TINKERER := &"tinkerer"

const DEFINITIONS := {
	WIZARD: {
		"name": "Mago",
		"ability": "Teleporte (em breve): atravessa uma parede ou um chão de 1 bloco.",
		"short": "Teleporte (em breve).",
		"colour": Color(0.62, 0.45, 1.0),
		"price": 0,
		"trait": preload("res://modes/roguelike/scripts/characters/traits/wizard_trait.gd"),
	},
	MINER: {
		"name": "Mineiro",
		"ability": "Cava duas vezes mais rápido com Pá, Picareta e Britadeira.",
		"short": "Cava duas vezes mais rápido.",
		"colour": Color(0.95, 0.55, 0.2),
		"price": 25,
		"trait": preload("res://modes/roguelike/scripts/characters/traits/miner_trait.gd"),
	},
	ENGINEER: {
		"name": "Engenheiro",
		"ability": "Pontes e escadas dele têm 4 peças a mais.",
		"short": "+4 peças em pontes e escadas.",
		"colour": Color(1.0, 0.85, 0.2),
		"price": 35,
		"trait": preload("res://modes/roguelike/scripts/characters/traits/engineer_trait.gd"),
	},
	SCOUT: {
		"name": "Batedor",
		"ability": "Pernas fortes: aguenta quedas duas vezes mais altas.",
		"short": "Aguenta quedas duas vezes mais altas.",
		"colour": Color(0.35, 0.85, 0.4),
		"price": 45,
		"trait": preload("res://modes/roguelike/scripts/characters/traits/scout_trait.gd"),
	},
	TINKERER: {
		"name": "Inventor",
		"ability": "Uma vez por fase, clique nele sem ferramenta escolhida para repetir a última que ele usou, sem gastar carga.",
		"short": "Repete a última ferramenta uma vez por fase.",
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


static func get_ability(character_id: StringName) -> String:
	return DEFINITIONS[character_id].ability


## The ability in a few words, for the small text panel of a card.
static func get_short_ability(character_id: StringName) -> String:
	return DEFINITIONS[character_id].short


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
