extends Node
## Automated check of the roguelike's developer screen. Run via:
##   godot --headless res://modes/roguelike/tests/test_dev_screen.tscn
## Exits 0 when every check passes, 1 otherwise.
##
## Checked, pressing the screen's own buttons:
##   - choosing a character turns the whole troop into it (never a mixed
##     troop);
##   - with the Quantity field and the Add / Remove switch: lemmings in and
##     out (never below one), tool charges in and out, rescues, coins and
##     the vault in and out (never below zero);
##   - a relic button gives the relic, and takes it away when owned;
##   - the Compendium opens with an entry for every character;
##   - choosing a stage reports that stage;
##   - "Prontas" / "Procedurais" switch the run between the hand-made and the
##     generated stages.

const PROFILE_PATH := "user://test_dev_screen_profile.cfg"

var _failures: Array[String] = []


func _ready() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PROFILE_PATH))
	var profile := RoguelikeProfile.load_from(PROFILE_PATH)
	var state := RoguelikeRunState.new_run()
	var screen := RoguelikeDevScreen.new(state, profile)
	add_child(screen)
	var amount := screen.find_child("Amount", true, false) as SpinBox

	amount.value = 2
	_press(screen, "Troop")
	_press(screen, "Character_scout")
	_expect(state.character_id == RoguelikeCharacters.SCOUT, "choosing the Scout did not make it the run's character")
	_expect(state.troop == ([&"scout", &"scout", &"scout"] as Array[StringName]), "the troop is %s, expected three Scouts" % [state.troop])
	_press(screen, "RemoveMode")
	amount.value = 10
	_press(screen, "Troop")
	_expect(state.troop.size() == 1, "removing 10 took the troop to %d, expected it to stop at 1" % state.troop.size())

	_press(screen, "AddMode")
	amount.value = 5
	_press(screen, "Tool_miner")
	_expect(state.inventory.get_charges("miner") == 5, "adding 5 pickaxe charges gave %d" % state.inventory.get_charges("miner"))
	_press(screen, "RemoveMode")
	amount.value = 3
	_press(screen, "Tool_miner")
	_expect(state.inventory.get_charges("miner") == 2, "removing 3 pickaxe charges left %d, expected 2" % state.inventory.get_charges("miner"))

	_press(screen, "AddMode")
	amount.value = 7
	_press(screen, "Rescues")
	_press(screen, "Coins")
	_press(screen, "Vault")
	_expect(state.revive_tokens == 7 and state.coins == 7 and profile.vault_coins == 7, "adding 7 gave %d rescues, %d coins, %d in the vault" % [state.revive_tokens, state.coins, profile.vault_coins])
	_press(screen, "RemoveMode")
	amount.value = 20
	_press(screen, "Rescues")
	_press(screen, "Coins")
	_press(screen, "Vault")
	_expect(state.revive_tokens == 0 and state.coins == 0 and profile.vault_coins == 0, "removing 20 left %d rescues, %d coins, %d in the vault (expected zeros)" % [state.revive_tokens, state.coins, profile.vault_coins])

	_press(screen, "Relic_%s" % RoguelikeRelics.LONG_BRIDGE)
	_expect(state.relics.has(RoguelikeRelics.LONG_BRIDGE), "the relic button did not give the relic")
	_press(screen, "Relic_%s" % RoguelikeRelics.LONG_BRIDGE)
	_expect(not state.relics.has(RoguelikeRelics.LONG_BRIDGE), "pressing an owned relic did not take it away")

	_press(screen, "Compêndio")
	var compendium := screen.find_child("Compendium", true, false)
	_expect(compendium != null, "the Compendium did not open")
	if compendium != null:
		for character in RoguelikeCharacters.ALL:
			_expect(compendium.find_child("character_%s" % character, true, false) != null, "the Compendium has no entry for %s" % character)

	_press(screen, "Prontas")
	_expect(state.use_handmade_stages and not state.get_stage_definition().is_procedural, "Prontas did not switch the run to the hand-made stages")
	_press(screen, "Procedurais")
	_expect(not state.use_handmade_stages and state.get_stage_definition().is_procedural, "Procedurais did not switch the run back to generated stages")

	var chosen := [-1]
	screen.stage_chosen.connect(func(index: int) -> void: chosen[0] = index)
	_press(screen, "Stage_4")
	_expect(chosen[0] == 3, "choosing stage 4 reported index %d" % chosen[0])

	DirAccess.remove_absolute(ProjectSettings.globalize_path(PROFILE_PATH))
	if _failures.is_empty():
		print("Dev screen: PASS")
		get_tree().quit(0)
		return
	for failure in _failures:
		print("  FAIL: %s" % failure)
	print("Dev screen: FAIL")
	get_tree().quit(1)


## By node name, or by text for the row of text buttons at the bottom.
func _press(screen: Node, button_name: String) -> void:
	var button := screen.find_child(button_name, true, false) as Button
	if button == null:
		for node in screen.find_children("*", "Button", true, false):
			if (node as Button).text == button_name:
				button = node
				break
	if button == null:
		_failures.append("no button '%s'" % button_name)
		return
	button.pressed.emit()


func _expect(condition: bool, failure: String) -> void:
	if not condition:
		_failures.append(failure)
