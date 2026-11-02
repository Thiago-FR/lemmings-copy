class_name RoguelikeDiscovery
extends RefCounted
## The compendium's entry ids, in one place for the compendium that shows
## them and for the places that record a discovery (RoguelikeProfile.discover):
##   - a character: unlocked (the starter always is);
##   - a tool: picked up, received from a card, or used;
##   - a stage item: picked up;
##   - a card kind, a relic, the tool of a tool card: offered (the player
##     has read the card), and so also taken or bought;
##   - an ability: used once.

const STAGE_ITEM_IDS := {
	RoguelikePickupSpec.Kind.TOOL: "item_tool",
	RoguelikePickupSpec.Kind.REVIVE: "item_rescue",
	RoguelikePickupSpec.Kind.TIME: "item_time",
	RoguelikePickupSpec.Kind.CHARGE_BAG: "item_bag",
	RoguelikePickupSpec.Kind.COINS: "item_coins",
	RoguelikePickupSpec.Kind.ABILITY_CHARGE: "item_ability",
}


static func character(character_id: StringName) -> String:
	return "character_%s" % character_id


static func tool(tool_id: String) -> String:
	return "tool_%s" % tool_id


static func stage_item(kind: RoguelikePickupSpec.Kind) -> String:
	return STAGE_ITEM_IDS[kind]


static func ability(ability_id: StringName) -> String:
	return "ability_%s" % ability_id


static func card_kind(kind: RoguelikeCard.Kind) -> String:
	return "card_%s" % String(RoguelikeCard.Kind.keys()[kind]).to_lower()


static func relic(relic_id: StringName) -> String:
	return "relic_%s" % relic_id


## Everything a card shows the player: its kind, and the relic or the tool
## it is about.
static func for_card(card: RoguelikeCard) -> Array[String]:
	var ids: Array[String] = [card_kind(card.kind)]
	match card.kind:
		RoguelikeCard.Kind.CHARGES, RoguelikeCard.Kind.NEW_TOOL:
			ids.append(tool(card.subject))
		RoguelikeCard.Kind.RELIC:
			ids.append(relic(StringName(card.subject)))
	return ids


## What picking up an item shows: the item, and the tool of a tool item.
static func for_pickup(spec: RoguelikePickupSpec) -> Array[String]:
	var ids: Array[String] = [stage_item(spec.kind)]
	if spec.kind == RoguelikePickupSpec.Kind.TOOL:
		ids.append(tool(spec.tool_id))
	return ids
