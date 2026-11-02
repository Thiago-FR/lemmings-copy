class_name RoguelikeCardPool
extends RefCounted
## Draws the three reward cards offered after a stage. Each card comes from
## a different family when possible (more charges, a new tool, a recruit, a
## relic, a rescue), so the choice is between kinds of help rather than
## between three versions of the same one.

const OFFER_SIZE := 3
## Offered instead after a stage cleared without losing anyone.
const PERFECT_OFFER_SIZE := 4
const CHARGES_AMOUNT := 3
const NEW_TOOL_AMOUNT := 2
## Tools a card can bring into the bar.
const TOOL_POOL: Array[String] = [
	"digger", "builder", "ladder_vertical", "bridge", "floater", "climber",
	"block", "dynamite", "tnt", "basher", "miner",
]


static func draw_offer(state: RoguelikeRunState, rng: RandomNumberGenerator, size: int = OFFER_SIZE) -> Array[RoguelikeCard]:
	var families: Array = _candidate_families(state)
	_shuffle(families, rng)
	var offer: Array[RoguelikeCard] = []
	for family: Array in families:
		if offer.size() >= size:
			break
		if not family.is_empty():
			offer.append(family[rng.randi_range(0, family.size() - 1)])
	return offer


## Lists of candidate cards, one list per family.
static func _candidate_families(state: RoguelikeRunState) -> Array:
	var charges: Array[RoguelikeCard] = []
	for tool_id in state.inventory.get_tool_ids():
		charges.append(RoguelikeCard.make(RoguelikeCard.Kind.CHARGES, tool_id, CHARGES_AMOUNT))

	var new_tools: Array[RoguelikeCard] = []
	for tool_id in TOOL_POOL:
		if not state.inventory.has_tool(tool_id):
			new_tools.append(RoguelikeCard.make(RoguelikeCard.Kind.NEW_TOOL, tool_id, NEW_TOOL_AMOUNT))

	var recruits: Array[RoguelikeCard] = []
	for character in state.unlocked_characters:
		recruits.append(RoguelikeCard.make(RoguelikeCard.Kind.RECRUIT, character))

	var relics: Array[RoguelikeCard] = []
	for relic_id in RoguelikeRelics.DEFINITIONS:
		if not state.relics.has(relic_id):
			relics.append(RoguelikeCard.make(RoguelikeCard.Kind.RELIC, relic_id))

	var rescue: Array[RoguelikeCard] = [RoguelikeCard.make(RoguelikeCard.Kind.REVIVE)]
	return [charges, new_tools, recruits, relics, rescue]


## Fisher-Yates with the run's own generator, so a seeded run is repeatable.
static func _shuffle(items: Array, rng: RandomNumberGenerator) -> void:
	for index in range(items.size() - 1, 0, -1):
		var other := rng.randi_range(0, index)
		var held = items[index]
		items[index] = items[other]
		items[other] = held
