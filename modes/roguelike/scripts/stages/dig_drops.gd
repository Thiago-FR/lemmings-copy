class_name RoguelikeDigDrops
extends RefCounted
## What breaking a block gives in a run (the table the user approved): coins
## most of the time, then a charge of a tool in the bar, an hourglass, a bag
## and, rarely, a phoenix feather. Earth 4%, concrete 12%. Greed adds to the
## coins when they are picked up, like the coins on the map; the Prospector
## relic raises the chances (PROSPECTOR_*_PER_LEVEL).
##
## The chances and weights can be tuned in the developer compendium; the
## tuned values are kept in their own file (DEFAULT_PATH), apart from the
## player's profile, so the next stages use them and deleting the file
## brings the approved table back.

const DEFAULT_EARTH_CHANCE := 0.04
const DEFAULT_CONCRETE_CHANCE := 0.12
const COIN_WEIGHT := 60.0
const TOOL_WEIGHT := 22.0
const HOURGLASS_WEIGHT := 10.0
const BAG_WEIGHT := 6.0
const REVIVE_WEIGHT := 2.0
## What can turn up, in the order the compendium lists it.
const KINDS: Array[ItemSpec.Kind] = [
	ItemSpec.Kind.COINS, ItemSpec.Kind.TOOL, ItemSpec.Kind.TIME,
	ItemSpec.Kind.CHARGE_BAG, ItemSpec.Kind.REVIVE,
]
const DEFAULT_WEIGHTS := {
	ItemSpec.Kind.COINS: COIN_WEIGHT,
	ItemSpec.Kind.TOOL: TOOL_WEIGHT,
	ItemSpec.Kind.TIME: HOURGLASS_WEIGHT,
	ItemSpec.Kind.CHARGE_BAG: BAG_WEIGHT,
	ItemSpec.Kind.REVIVE: REVIVE_WEIGHT,
}
## One coin per find: the coins laid on the map give two.
const COINS_PER_FIND := 1
## Prospector: added to each chance per level (II: earth 8%, concrete 20%).
## Concrete gets more because it is harder to break.
const PROSPECTOR_EARTH_PER_LEVEL := 0.02
const PROSPECTOR_CONCRETE_PER_LEVEL := 0.04

const DEFAULT_PATH := "user://roguelike_dig_drops.cfg"
const SECTION := "dig_drops"

var earth_chance := DEFAULT_EARTH_CHANCE
var concrete_chance := DEFAULT_CONCRETE_CHANCE
## ItemSpec.Kind -> weight (any scale: only the shares matter).
var weights: Dictionary = DEFAULT_WEIGHTS.duplicate()
var _path := DEFAULT_PATH


## The table a stage of the run uses: the saved values (or the approved
## ones), with the Prospector's level on top.
static func table(prospector_level: int = 0, path: String = DEFAULT_PATH) -> DigDropTable:
	return load_from(path).make_table(prospector_level)


## The values on disk, or the approved ones when there is no file. path is
## for tests, which must not touch the developer's file.
static func load_from(path: String = DEFAULT_PATH) -> RoguelikeDigDrops:
	var drops := RoguelikeDigDrops.new()
	drops._path = path
	var file := ConfigFile.new()
	if file.load(path) != OK:
		return drops
	drops.earth_chance = clampf(float(file.get_value(SECTION, "earth_chance", DEFAULT_EARTH_CHANCE)), 0.0, 1.0)
	drops.concrete_chance = clampf(float(file.get_value(SECTION, "concrete_chance", DEFAULT_CONCRETE_CHANCE)), 0.0, 1.0)
	for kind in KINDS:
		drops.weights[kind] = maxf(float(file.get_value(SECTION, _weight_key(kind), DEFAULT_WEIGHTS[kind])), 0.0)
	return drops


func save() -> void:
	var file := ConfigFile.new()
	file.set_value(SECTION, "earth_chance", earth_chance)
	file.set_value(SECTION, "concrete_chance", concrete_chance)
	for kind in KINDS:
		file.set_value(SECTION, _weight_key(kind), float(weights[kind]))
	file.save(_path)


## Back to the approved table (not saved until save()).
func restore_defaults() -> void:
	earth_chance = DEFAULT_EARTH_CHANCE
	concrete_chance = DEFAULT_CONCRETE_CHANCE
	weights = DEFAULT_WEIGHTS.duplicate()


## A kind's share of the finds, 0 to 1.
func get_share(kind: ItemSpec.Kind) -> float:
	var total := 0.0
	for each in KINDS:
		total += float(weights[each])
	return float(weights[kind]) / total if total > 0.0 else 0.0


func make_table(prospector_level: int = 0) -> DigDropTable:
	var drops := DigDropTable.new()
	drops.earth_chance = minf(earth_chance + PROSPECTOR_EARTH_PER_LEVEL * prospector_level, 1.0)
	drops.concrete_chance = minf(concrete_chance + PROSPECTOR_CONCRETE_PER_LEVEL * prospector_level, 1.0)
	var entries: Array[Dictionary] = []
	for kind in KINDS:
		entries.append({"kind": kind, "weight": float(weights[kind]), "amount": _amount_of(kind)})
	drops.entries = entries
	return drops


static func _amount_of(kind: ItemSpec.Kind) -> int:
	match kind:
		ItemSpec.Kind.COINS:
			return COINS_PER_FIND
		ItemSpec.Kind.TIME:
			return DigDropTable.DROPPED_HOURGLASS_SECONDS
	return 1


static func _weight_key(kind: ItemSpec.Kind) -> String:
	return "weight_%s" % String(ItemSpec.Kind.find_key(kind)).to_lower()
