extends Node
## The ability slot on a real stage, with its tool bar. Run via:
##   godot --headless --path . res://modes/roguelike/tests/test_ability_session.tscn
## Exits 0 when every check passes, 1 otherwise.
##
## Checked:
##   - the tool bar ends with the character's ability in its own slot, after
##     a divider, showing its charges (the base plus the relic's level);
##   - pressing the slot arms the ability and lets go of the selected tool;
##     selecting a tool disarms it; arming the sacrifice disarms it, and
##     arming it disarms the sacrifice;
##   - clicking a lemming while armed uses the ability on it; a refused use
##     spends nothing; a use that works spends one charge and is recorded
##     in the profile;
##   - a recharge item adds a charge and is recorded, a tool used is recorded.

const PROFILE_PATH := "user://test_ability_session_profile.cfg"

var _failures: Array[String] = []


func _ready() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PROFILE_PATH))
	var profile := RoguelikeProfile.load_from(PROFILE_PATH)
	var state := RoguelikeRunState.new_run(RoguelikeCharacters.SCOUT)
	state.add_relic(RoguelikeRelics.ABILITY_CHARGES)
	state.inventory.add_charges("digger", 2)
	var session := RoguelikeStageSession.new()
	session.state = state
	session.profile = profile
	add_child(session)
	await get_tree().process_frame
	await get_tree().process_frame

	var expected := RoguelikeAbilities.get_base_charges(RoguelikeAbilities.LEAP) + RoguelikeRelics.ABILITY_CHARGES_PER_LEVEL
	var slot := session.ability_slot
	_expect(slot.get_ability_id() == RoguelikeAbilities.LEAP, "the Scout's slot holds %s, expected the leap" % slot.get_ability_id())
	_expect(slot.charges == expected, "the slot starts with %d charges, expected %d (base + relic I)" % [slot.charges, expected])
	var button := get_tree().root.find_child("AbilitySlot", true, false) as Button
	_expect(button != null, "the tool bar has no ability slot")
	_expect(get_tree().root.find_child("AbilityDivider", true, false) != null, "the ability slot is not set apart from the tools")
	if button == null:
		_report()
		return
	_expect((button.get_node("Count") as Label).text == str(expected), "the slot shows %s charges" % (button.get_node("Count") as Label).text)

	SkillManager.select_skill("digger")
	button.button_pressed = true
	_expect(slot.armed, "pressing the slot did not arm the ability")
	_expect(SkillManager.selected_skill_id == "", "arming the ability kept the tool selected")
	SkillManager.select_skill("digger")
	_expect(not slot.armed and not button.button_pressed, "selecting a tool did not disarm the ability")
	button.button_pressed = true
	session.set_sacrifice_armed(true)
	_expect(not slot.armed and not button.button_pressed, "arming the sacrifice did not disarm the ability")
	button.button_pressed = true
	_expect(slot.armed and not session.sacrifice_armed, "arming the ability did not disarm the sacrifice")

	var lemming := _first_lemming()
	_expect(lemming != null, "no lemming came out")
	if lemming != null:
		# Just out of the entrance, falling: not a moment it can jump.
		lemming.state_machine.change_state(LemmingStateMachine.State.FALLING)
		lemming.clicked.emit(lemming)
		_expect(slot.charges == expected, "a refused leap spent a charge")
		_expect(not profile.is_discovered(RoguelikeDiscovery.ability(RoguelikeAbilities.LEAP)), "a refused leap was recorded as used")
		_expect(slot.armed, "a refused use disarmed the ability")

		var recharge := _pickup(RoguelikePickupSpec.Kind.ABILITY_CHARGE, 1)
		session._on_pickup_collected(recharge, lemming)
		recharge.free()
		_expect(slot.charges == expected + 1, "a recharge item left %d charges, expected %d" % [slot.charges, expected + 1])
		_expect((button.get_node("Count") as Label).text == str(expected + 1), "the slot does not show the recharge")
		_expect(profile.is_discovered("item_ability"), "the recharge item was not recorded")

		SkillManager.skill_assigned.emit(lemming, "digger")
		_expect(profile.is_discovered("tool_digger"), "a tool used was not recorded")

	# A use that works: a stand-in ability that always does.
	var always := AlwaysWorks.new()
	always.id = RoguelikeAbilities.LEAP
	slot.ability = always
	if lemming != null:
		lemming.clicked.emit(lemming)
		_expect(slot.charges == expected, "a use that worked left %d charges, expected %d" % [slot.charges, expected])
		_expect(profile.is_discovered(RoguelikeDiscovery.ability(RoguelikeAbilities.LEAP)), "the ability used was not recorded")
	var reloaded := RoguelikeProfile.load_from(PROFILE_PATH)
	_expect(reloaded.is_discovered("item_ability") and reloaded.is_discovered("tool_digger"), "the discoveries were not saved")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PROFILE_PATH))
	_report()


class AlwaysWorks:
	extends RoguelikeAbility

	func try_use(_lemming: LemmingController) -> bool:
		return true


func _first_lemming() -> LemmingController:
	for node in get_tree().root.find_children("*", "CharacterBody2D", true, false):
		if node is LemmingController:
			return node
	return null


func _pickup(kind: RoguelikePickupSpec.Kind, amount: int) -> RoguelikePickup:
	var spec := RoguelikePickupSpec.new()
	spec.kind = kind
	spec.amount = amount
	var pickup := RoguelikePickup.new()
	pickup.spec = spec
	return pickup


func _expect(condition: bool, failure: String) -> void:
	if not condition:
		_failures.append(failure)


func _report() -> void:
	if _failures.is_empty():
		print("Ability session: PASS")
		get_tree().quit(0)
		return
	for failure in _failures:
		print("  FAIL: %s" % failure)
	print("Ability session: FAIL")
	get_tree().quit(1)
