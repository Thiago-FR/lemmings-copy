class_name DigDropTable
extends Resource
## What breaking a block can give a level (LevelData.dig_drops), Bomberman
## style: a chance per material, and what turns up, by weight. Nothing marks
## the blocks that give something: the item only shows once the block is
## broken. What a level needs to be won never comes from here: these are
## always extras.
##
## Each entry is {"kind": ItemSpec.Kind, "weight": float, "amount": int}. A
## TOOL entry gives `amount` charges of a tool already in the bar, never of
## the one that broke the block (digging must not pay for itself).

## Chance of an item when an ordinary block breaks, by
## TerrainDestructible.TerrainMaterial (earth, concrete). Concrete takes the
## jackhammer or a blast, so it pays more.
@export var earth_chance: float = 0.04
@export var concrete_chance: float = 0.12
@export var entries: Array[Dictionary] = []

## Seconds an hourglass found in the rock gives (less than one laid on the
## map, which the level was timed around).
const DROPPED_HOURGLASS_SECONDS := 30


## The campaign's table: what the approved roguelike table gives, without
## the coins and the phoenix feather the campaign has no use for
## (22/38, 10/38 and 6/38 of it).
static func for_campaign() -> DigDropTable:
	var table := DigDropTable.new()
	table.entries = [
		{"kind": ItemSpec.Kind.TOOL, "weight": 22.0, "amount": 1},
		{"kind": ItemSpec.Kind.TIME, "weight": 10.0, "amount": DROPPED_HOURGLASS_SECONDS},
		{"kind": ItemSpec.Kind.CHARGE_BAG, "weight": 6.0, "amount": 1},
	]
	return table


## Chance of an item for a block of `material`.
func chance_for(material: TerrainDestructible.TerrainMaterial) -> float:
	return concrete_chance if material == TerrainDestructible.TerrainMaterial.CONCRETE else earth_chance


## What turns up when a block breaks, or null for nothing. bar_tools are
## the tools a TOOL entry may give; breaker is left out of them. An entry
## that cannot give anything (a tool with none to give) is skipped, so the
## find is something else instead.
func roll(rng: RandomNumberGenerator, material: TerrainDestructible.TerrainMaterial,
		bar_tools: Array[String], breaker: StringName) -> ItemSpec:
	if rng.randf() >= chance_for(material):
		return null
	var givable_tools := bar_tools.filter(func(tool_id: String) -> bool: return tool_id != String(breaker))
	var usable := entries.filter(func(entry: Dictionary) -> bool:
		return int(entry.kind) != ItemSpec.Kind.TOOL or not givable_tools.is_empty())
	var total := 0.0
	for entry in usable:
		total += float(entry.weight)
	if total <= 0.0:
		return null
	var pick := rng.randf() * total
	for entry in usable:
		pick -= float(entry.weight)
		if pick < 0.0:
			return _spec_of(entry, givable_tools, rng)
	return _spec_of(usable.back(), givable_tools, rng)


func _spec_of(entry: Dictionary, givable_tools: Array, rng: RandomNumberGenerator) -> ItemSpec:
	var spec := ItemSpec.new()
	spec.kind = int(entry.kind) as ItemSpec.Kind
	spec.amount = int(entry.get("amount", 1))
	if spec.kind == ItemSpec.Kind.TOOL:
		spec.tool_id = givable_tools[rng.randi() % givable_tools.size()]
	return spec
