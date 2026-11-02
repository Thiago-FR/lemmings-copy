class_name RoguelikeToolInventory
extends RefCounted
## The run's tool bar: which tools the troop carries and how many charges of
## each. It starts empty and gains a slot for every new tool picked up, up to
## max_slots.
##
## When a new tool arrives with every slot taken, one slot makes room for it:
## first a slot with no charges left, otherwise the tool touched (picked up
## or used) longest ago. A stage holds at most as many different tools as
## the bar starts with slots, so the tools picked up in a stage never push
## each other out, and a stage can always be finished with its own items.

signal changed

const DEFAULT_MAX_SLOTS := 4
const MAX_SLOTS_LIMIT := 7

var max_slots: int = DEFAULT_MAX_SLOTS

## Slots in bar order: {"id": String, "charges": int, "touched": int}.
var _slots: Array[Dictionary] = []
## Increases on every pick-up or use, so "longest ago" needs no clock.
var _touch_counter := 0


func get_tool_ids() -> Array[String]:
	var ids: Array[String] = []
	for slot in _slots:
		ids.append(slot.id)
	return ids


func has_tool(tool_id: String) -> bool:
	return _find(tool_id) >= 0


func get_charges(tool_id: String) -> int:
	var index := _find(tool_id)
	return _slots[index].charges if index >= 0 else 0


func is_full() -> bool:
	return _slots.size() >= max_slots


## Adds charges, taking a new slot for a tool not carried yet. Returns the id
## of the tool that lost its slot to make room, or "" if none did.
func add_charges(tool_id: String, amount: int) -> String:
	assert(tool_id != "" and amount > 0, "Adding charges needs a tool and a positive amount")
	var index := _find(tool_id)
	var evicted := ""
	if index < 0:
		if is_full():
			evicted = _evict()
		_slots.append({"id": tool_id, "charges": 0, "touched": 0})
		index = _slots.size() - 1
	_slots[index].charges += amount
	_touch(index)
	changed.emit()
	return evicted


## One charge more for every tool in the bar.
func add_one_to_each() -> void:
	for index in _slots.size():
		_slots[index].charges += 1
	changed.emit()


## Spends one charge. Returns false if there was none.
func spend(tool_id: String) -> bool:
	var index := _find(tool_id)
	if index < 0 or _slots[index].charges <= 0:
		return false
	_slots[index].charges -= 1
	_touch(index)
	changed.emit()
	return true


## Frees the slots left without charges. Called between stages, not during
## one, so a slot never vanishes from under the player's cursor.
func remove_empty_slots() -> void:
	var before := _slots.size()
	var kept: Array[Dictionary] = []
	kept.assign(_slots.filter(func(slot: Dictionary) -> bool: return slot.charges > 0))
	_slots = kept
	if _slots.size() != before:
		changed.emit()


func add_slot() -> void:
	max_slots = mini(max_slots + 1, MAX_SLOTS_LIMIT)
	changed.emit()


## Charges per tool id, the shape LevelData.skill_counts uses.
func to_counts() -> Dictionary:
	var counts := {}
	for slot in _slots:
		counts[slot.id] = slot.charges
	return counts


func _find(tool_id: String) -> int:
	for index in _slots.size():
		if _slots[index].id == tool_id:
			return index
	return -1


func _touch(index: int) -> void:
	_touch_counter += 1
	_slots[index].touched = _touch_counter


func _evict() -> String:
	var victim := -1
	for index in _slots.size():
		if victim < 0 or _is_better_victim(_slots[index], _slots[victim]):
			victim = index
	var evicted: String = _slots[victim].id
	_slots.remove_at(victim)
	return evicted


func _is_better_victim(candidate: Dictionary, current: Dictionary) -> bool:
	var candidate_empty: bool = candidate.charges <= 0
	var current_empty: bool = current.charges <= 0
	if candidate_empty != current_empty:
		return candidate_empty
	return candidate.touched < current.touched
