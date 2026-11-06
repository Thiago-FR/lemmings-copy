class_name RoguelikeDigDrops
extends RefCounted
## What breaking a block gives in a run (the table the user approved): coins
## most of the time, then a charge of a tool in the bar, an hourglass, a bag
## and, rarely, a phoenix feather. Earth 4%, concrete 12% (DigDropTable's
## own chances). Greed adds to the coins when they are
## picked up, like the coins on the map.

const COIN_WEIGHT := 60.0
const TOOL_WEIGHT := 22.0
const HOURGLASS_WEIGHT := 10.0
const BAG_WEIGHT := 6.0
const REVIVE_WEIGHT := 2.0
## One coin per find: the coins laid on the map give two.
const COINS_PER_FIND := 1


static func table() -> DigDropTable:
	var drops := DigDropTable.new()
	drops.entries = [
		{"kind": ItemSpec.Kind.COINS, "weight": COIN_WEIGHT, "amount": COINS_PER_FIND},
		{"kind": ItemSpec.Kind.TOOL, "weight": TOOL_WEIGHT, "amount": 1},
		{"kind": ItemSpec.Kind.TIME, "weight": HOURGLASS_WEIGHT, "amount": DigDropTable.DROPPED_HOURGLASS_SECONDS},
		{"kind": ItemSpec.Kind.CHARGE_BAG, "weight": BAG_WEIGHT, "amount": 1},
		{"kind": ItemSpec.Kind.REVIVE, "weight": REVIVE_WEIGHT, "amount": 1},
	]
	return drops
