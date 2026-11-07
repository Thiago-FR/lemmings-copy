class_name ItemCollector
extends Node
## A level whose tools come from items (LevelData.tools_from_items): it lays
## the level's items (LevelData.items), keeps the tool bar (ToolInventory and
## ToolInventoryBar) and SkillManager's charges in step, and applies what is
## picked up. The bar starts with LevelData.skill_counts, the tool to get
## going; the rest has to be found.
##
## The core applies tools, hourglasses and bags itself. Any other kind is
## announced through item_collected for whoever knows what it does.
##
## A level with the classic fixed bar (LevelData.drops_on_fixed_bar) gets
## one too, for what turns up in broken blocks: the fixed bar (SkillPanel)
## stays, and the inventory only keeps its charges in step.

signal item_collected(spec: ItemSpec, lemming: LemmingController, where: Vector2)

## What was picked up flies out of the item as icons, one per charge (up to
## MAX_POPS): the user wants animation, not text messages.
const MAX_POPS := 5
const POP_SPACING := 14.0

var inventory := ToolInventory.new()
## Horizontal offsets, in pixels, of the items sharing one spot.
const STACK_OFFSETS: Array[float] = [0.0, 14.0, -14.0, 28.0, -28.0]
var _items_per_cell: Dictionary = {}

var _level: LevelManager


func _init(level: LevelManager) -> void:
	assert(level != null, "An item collector needs its level")
	_level = level


func _ready() -> void:
	var fixed_bar := not _level.level_data.tools_from_items
	if fixed_bar:
		# Every tool offered keeps its slot: none is ever pushed out.
		inventory.max_slots = maxi(inventory.max_slots, _level.level_data.available_skills.size())
	for tool_id in _level.level_data.skill_counts:
		var charges := int(_level.level_data.skill_counts[tool_id])
		if charges > 0:
			inventory.add_charges(tool_id, charges)
	for spec in _level.level_data.items:
		add_item(spec)
	if not fixed_bar:
		_level.add_child.call_deferred(ToolInventoryBar.new(inventory))
	inventory.changed.connect(_sync_charges)
	if _level.dig_dropper != null:
		_level.dig_dropper.inventory = inventory
		_level.dig_dropper.item_dropped.connect(_take_dropped)
	SkillManager.skill_assigned.connect(_on_skill_assigned)
	SkillManager.skill_refunded.connect(_on_skill_refunded)
	_sync_charges()


func _exit_tree() -> void:
	if SkillManager.skill_assigned.is_connected(_on_skill_assigned):
		SkillManager.skill_assigned.disconnect(_on_skill_assigned)
	if SkillManager.skill_refunded.is_connected(_on_skill_refunded):
		SkillManager.skill_refunded.disconnect(_on_skill_refunded)


## Lays an item in the level (one from the start, or one that turned up
## later) and listens for it being picked up.
func add_item(spec: ItemSpec) -> ItemPickup:
	var pickup := ItemPickup.make(spec)
	# Items on the same spot lie side by side instead of on top of each
	# other: the nth one a little to the right or left of the first.
	var cell := Vector2i(spec.column, spec.row)
	var stacked := int(_items_per_cell.get(cell, 0))
	_items_per_cell[cell] = stacked + 1
	pickup.position.x += STACK_OFFSETS[stacked % STACK_OFFSETS.size()]
	pickup.collected.connect(_on_collected)
	_level.add_child.call_deferred(pickup)
	return pickup


## An item found in a broken block is picked up like the others.
func _take_dropped(pickup: ItemPickup) -> void:
	pickup.collected.connect(_on_collected)


func _sync_charges() -> void:
	var counts := inventory.to_counts()
	for tool_id in counts:
		SkillManager.set_remaining_count(tool_id, int(counts[tool_id]))


func _on_skill_assigned(_lemming: LemmingController, tool_id: String) -> void:
	inventory.spend(tool_id)


## A tool a lemming dropped unused for a newer one goes back to the bar.
func _on_skill_refunded(tool_id: String) -> void:
	inventory.add_charges(tool_id, 1)


func _on_collected(pickup: ItemPickup, lemming: LemmingController) -> void:
	var spec := pickup.spec
	var where := pickup.global_position
	match spec.kind:
		ItemSpec.Kind.TOOL:
			_pop_icons(where, spec.tool_id, spec.amount)
			inventory.add_charges(spec.tool_id, spec.amount)
		ItemSpec.Kind.TIME:
			_level.time_remaining += spec.amount
			_pop_icons(where, "hud_clock", 1)
		ItemSpec.Kind.CHARGE_BAG:
			inventory.add_one_to_each()
			for tool_id in inventory.get_tool_ids().slice(0, MAX_POPS):
				_pop_icons(where, tool_id, 1)
		_:
			item_collected.emit(spec, lemming, where)
			return
	AudioManager.play_sound(&"select_tool")


func _pop_icons(where: Vector2, icon_id: String, count: int) -> void:
	var shown := clampi(count, 1, MAX_POPS)
	for index in shown:
		var offset := (float(index) - (shown - 1) / 2.0) * POP_SPACING
		IconPop.spawn(_level, where + Vector2(offset, 0), icon_id)
