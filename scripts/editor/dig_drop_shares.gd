class_name DigDropShares
extends RefCounted
## A DigDropTable as the editor shows it: whether blocks give anything at
## all, the chance per material in whole percents, and how the finds split
## between the items the core hands out (tool charge, hourglass, bag), also
## in whole percents that always add up to 100. Raising one item takes the
## difference from the others, largest first; lowering one gives it back to
## the others in proportion (evenly when they are all at zero).

## The items the core knows how to give (ItemCollector), in panel order.
const KINDS: Array[ItemSpec.Kind] = [ItemSpec.Kind.TOOL, ItemSpec.Kind.TIME, ItemSpec.Kind.CHARGE_BAG]
const FULL := 100

## False: nothing ever comes out of the blocks (the table is null).
var enabled := true
var earth_percent := 0
var concrete_percent := 0
## ItemSpec.Kind -> percent of the finds; the values add up to FULL.
var shares: Dictionary = {}


## The shares of a table, or of the campaign's table, switched off, for
## null (so switching back on starts from the usual mix).
static func from_table(table: DigDropTable) -> DigDropShares:
	var result := DigDropShares.new()
	result.enabled = table != null
	var source := table if table != null else DigDropTable.for_campaign()
	result.earth_percent = roundi(source.earth_chance * FULL)
	result.concrete_percent = roundi(source.concrete_chance * FULL)
	var weights := {}
	for kind in KINDS:
		weights[kind] = 0.0
	for entry in source.entries:
		var kind := int(entry.kind)
		if weights.has(kind):
			weights[kind] += maxf(0.0, float(entry.weight))
	if _sum(weights) <= 0.0:
		weights = _weights_of(DigDropTable.for_campaign())
	result.shares = _whole_percents(weights)
	return result


## The table these shares stand for, or null when switched off. Items at
## zero are left out.
func to_table() -> DigDropTable:
	if not enabled:
		return null
	var table := DigDropTable.new()
	table.earth_chance = float(earth_percent) / FULL
	table.concrete_chance = float(concrete_percent) / FULL
	for kind in KINDS:
		if int(shares[kind]) > 0:
			table.entries.append({"kind": kind, "weight": float(shares[kind]), "amount": _amount_of(kind)})
	return table


## Sets one item's share and rebalances the others so the total stays
## FULL. Returns the other kinds whose share changed.
func set_share(kind: ItemSpec.Kind, percent: int) -> Array[ItemSpec.Kind]:
	assert(shares.has(kind), "Not an item the editor offers")
	var others: Array[ItemSpec.Kind] = []
	for other in KINDS:
		if other != kind:
			others.append(other)
	var room := 0
	for other in others:
		room += int(shares[other])
	var wanted := clampi(percent, 0, FULL)
	var delta := wanted - int(shares[kind])
	delta = mini(delta, room)
	var before := shares.duplicate()
	if delta > 0:
		_take_from(others, delta)
	elif delta < 0:
		_give_to(others, -delta)
	shares[kind] = int(shares[kind]) + delta
	var changed: Array[ItemSpec.Kind] = []
	for other in others:
		if int(shares[other]) != int(before[other]):
			changed.append(other)
	return changed


## One percent at a time from whichever has most.
func _take_from(others: Array[ItemSpec.Kind], amount: int) -> void:
	for _point in amount:
		var largest := others[0]
		for other in others:
			if int(shares[other]) > int(shares[largest]):
				largest = other
		shares[largest] = int(shares[largest]) - 1


func _give_to(others: Array[ItemSpec.Kind], amount: int) -> void:
	var weights := {}
	for other in others:
		weights[other] = float(shares[other])
	if _sum(weights) <= 0.0:
		for other in others:
			weights[other] = 1.0
	var gifts := _whole_split(weights, amount)
	for other in others:
		shares[other] = int(shares[other]) + int(gifts[other])


static func _amount_of(kind: ItemSpec.Kind) -> int:
	return DigDropTable.DROPPED_HOURGLASS_SECONDS if kind == ItemSpec.Kind.TIME else 1


static func _weights_of(table: DigDropTable) -> Dictionary:
	var weights := {}
	for kind in KINDS:
		weights[kind] = 0.0
	for entry in table.entries:
		if weights.has(int(entry.kind)):
			weights[int(entry.kind)] += float(entry.weight)
	return weights


static func _whole_percents(weights: Dictionary) -> Dictionary:
	return _whole_split(weights, FULL)


## Splits `total` in whole parts in proportion to the weights, the parts
## left over going to the largest remainders (so 22:10:6 is 58/26/16).
static func _whole_split(weights: Dictionary, total: int) -> Dictionary:
	var weight_sum := _sum(weights)
	var parts := {}
	var remainders: Array = []
	var given := 0
	for key in weights:
		var exact: float = float(weights[key]) * total / weight_sum
		parts[key] = floori(exact)
		given += int(parts[key])
		remainders.append([exact - floorf(exact), key])
	remainders.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
	for index in total - given:
		var key = remainders[index % remainders.size()][1]
		parts[key] = int(parts[key]) + 1
	return parts


static func _sum(weights: Dictionary) -> float:
	var total := 0.0
	for key in weights:
		total += float(weights[key])
	return total
