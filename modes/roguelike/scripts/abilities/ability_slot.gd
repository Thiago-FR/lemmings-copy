class_name RoguelikeAbilitySlot
extends RefCounted
## The run character's ability during one stage: which one, the charges
## left, and whether it is armed (selected in the tool bar, so the next
## lemming clicked uses it). Charges are spent only when the ability works.

signal changed

var ability: RoguelikeAbility = null
var charges := 0
var armed := false


static func make(ability_id: StringName, starting_charges: int) -> RoguelikeAbilitySlot:
	var slot := RoguelikeAbilitySlot.new()
	slot.ability = RoguelikeAbilities.create(ability_id)
	slot.charges = maxi(starting_charges, 0)
	return slot


func get_ability_id() -> StringName:
	return ability.id


## Arming needs a charge left; disarming always works.
func set_armed(value: bool) -> void:
	value = value and charges > 0
	if value == armed:
		return
	armed = value
	changed.emit()


func add_charges(amount: int) -> void:
	assert(amount > 0, "Adding charges needs a positive amount")
	charges += amount
	changed.emit()


## Uses the ability on the lemming. False, and no charge spent, when there
## is none left or the ability refuses. The last charge disarms the slot.
func use_on(lemming: LemmingController) -> bool:
	if charges <= 0 or not ability.try_use(lemming):
		return false
	charges -= 1
	if charges == 0:
		armed = false
	changed.emit()
	return true
