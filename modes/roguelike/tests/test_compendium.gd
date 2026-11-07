extends Node
## The player's compendium and what unlocks its entries. Run via:
##   godot --headless --path . res://modes/roguelike/tests/test_compendium.tscn
## Exits 0 when every check passes, 1 otherwise.
##
## Checked:
##   - a fresh profile knows only the starter; discoveries are saved and
##     loaded back; an unlocked character counts as discovered;
##   - every id the game records (stage items, tools, cards, relics,
##     abilities, characters) has its entry in the compendium;
##   - given the profile, an undiscovered entry is a black silhouette with
##     "???", a discovered one shows its name; without it everything shows;
##   - a card offered records its kind and its relic or tool;
##   - the character screen has a compendium button that opens it;
##   - the dig-drop tab: read-only out of the developer mode; in it, a
##     change is saved and used by the next table, the shares follow the
##     weights, and the restore button puts the approved table back.

const PROFILE_PATH := "user://test_compendium_profile.cfg"
const DIG_DROPS_PATH := "user://test_compendium_dig_drops.cfg"

var _failures: Array[String] = []


func _ready() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PROFILE_PATH))
	var profile := RoguelikeProfile.load_from(PROFILE_PATH)
	_expect(profile.is_discovered(RoguelikeDiscovery.character(RoguelikeCharacters.WIZARD)), "the starter is not discovered")
	_expect(not profile.is_discovered(RoguelikeDiscovery.character(RoguelikeCharacters.MINER)), "a locked character is discovered")
	_expect(not profile.is_discovered("relic_greed"), "a fresh profile has discoveries")
	_expect(profile.discover("relic_greed"), "a new discovery was not new")
	_expect(not profile.discover("relic_greed"), "the same discovery counted twice")
	profile.discover_all(RoguelikeDiscovery.for_card(RoguelikeCard.make(RoguelikeCard.Kind.NEW_TOOL, "bridge", 2)))
	var reloaded := RoguelikeProfile.load_from(PROFILE_PATH)
	_expect(reloaded.is_discovered("relic_greed"), "a discovery was not saved")
	_expect(reloaded.is_discovered("card_new_tool") and reloaded.is_discovered("tool_bridge"), "a card offered did not record its kind and its tool")
	reloaded.vault_coins = RoguelikeCharacters.get_price(RoguelikeCharacters.MINER)
	reloaded.buy(RoguelikeCharacters.MINER)
	_expect(reloaded.is_discovered(RoguelikeDiscovery.character(RoguelikeCharacters.MINER)), "an unlocked character is not discovered")

	var full := RoguelikeCompendiumScreen.new()
	add_child(full)
	for entry_id in _every_recorded_id():
		_expect(full.find_child(entry_id, true, false) != null, "the compendium has no entry '%s'" % entry_id)
	_expect(_entry_name(full, "relic_hourglass") == RoguelikeRelics.get_title(RoguelikeRelics.HOURGLASS), "without a profile an entry is hidden")
	full.queue_free()

	var player := RoguelikeCompendiumScreen.new(reloaded.is_discovered)
	add_child(player)
	_expect(_entry_name(player, "relic_greed") == RoguelikeRelics.get_title(RoguelikeRelics.GREED), "a discovered relic does not show its name")
	_expect(_entry_name(player, "relic_hourglass") == RoguelikeCompendiumScreen.UNKNOWN_NAME, "an undiscovered relic shows its name")
	var icon := _entry_icon(player, "relic_hourglass")
	_expect(icon != null and icon.self_modulate == RoguelikeCompendiumScreen.SILHOUETTE, "an undiscovered relic is not a silhouette")
	_expect(_entry_name(player, RoguelikeDiscovery.ability(RoguelikeAbilities.TELEPORT)) == RoguelikeCompendiumScreen.UNKNOWN_NAME, "an ability never used shows its name")
	player.queue_free()

	var select := RoguelikeCharacterSelectScreen.new(reloaded)
	add_child(select)
	var button := select.find_child("Compendium", true, false) as Button
	_expect(button != null, "the character screen has no compendium button")
	if button != null:
		button.pressed.emit()
		_expect(select.find_child("CompendiumScreen", true, false) != null, "the compendium button did not open it")
	select.queue_free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PROFILE_PATH))
	_check_dig_drops()
	_report()


func _check_dig_drops() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(DIG_DROPS_PATH))
	var was_developer := GameManager.developer_mode
	GameManager.developer_mode = false
	var player := RoguelikeCompendiumScreen.new(Callable(), DIG_DROPS_PATH)
	add_child(player)
	_expect(player.get_category_count() == RoguelikeCompendiumScreen.CATEGORIES.size(), "the compendium has no dig-drop tab")
	var coins_field := player.find_child("Weight_coins", true, false) as SpinBox
	_expect(coins_field != null and not coins_field.editable, "the dig-drop table can be changed out of the developer mode")
	_expect(coins_field != null and is_equal_approx(coins_field.value, RoguelikeDigDrops.COIN_WEIGHT), "the coin weight is not the approved one")
	_expect(_text(player, "Share_coins") == "60%", "the coins' share is '%s', expected 60%%" % _text(player, "Share_coins"))
	_expect(player.find_child("RestoreDefaults", true, false) == null, "the player sees the restore button")
	player.queue_free()

	GameManager.developer_mode = true
	var developer := RoguelikeCompendiumScreen.new(Callable(), DIG_DROPS_PATH)
	add_child(developer)
	var earth := developer.find_child("EarthChance", true, false) as SpinBox
	var revive := developer.find_child("Weight_revive", true, false) as SpinBox
	_expect(earth != null and earth.editable and revive != null and revive.editable, "the developer cannot change the dig-drop table")
	if earth != null and revive != null:
		earth.value = 50.0
		revive.value = 42.0
		var saved := RoguelikeDigDrops.load_from(DIG_DROPS_PATH)
		_expect(is_equal_approx(saved.earth_chance, 0.5), "the earth chance was not saved (%.2f)" % saved.earth_chance)
		_expect(is_equal_approx(float(saved.weights[ItemSpec.Kind.REVIVE]), 42.0), "the feather weight was not saved")
		_expect(_text(developer, "Share_revive") == "30%", "the feather's share is '%s', expected 42/140 = 30%%" % _text(developer, "Share_revive"))
		var table := RoguelikeDigDrops.table(1, DIG_DROPS_PATH)
		_expect(is_equal_approx(table.earth_chance, 0.5 + RoguelikeDigDrops.PROSPECTOR_EARTH_PER_LEVEL), "the next table does not use the saved chance plus the Prospector's")
		var restore := developer.find_child("RestoreDefaults", true, false) as Button
		_expect(restore != null, "the developer has no restore button")
		if restore != null:
			restore.pressed.emit()
			var restored := RoguelikeDigDrops.load_from(DIG_DROPS_PATH)
			_expect(is_equal_approx(restored.earth_chance, RoguelikeDigDrops.DEFAULT_EARTH_CHANCE) and is_equal_approx(float(restored.weights[ItemSpec.Kind.REVIVE]), RoguelikeDigDrops.REVIVE_WEIGHT), "restoring did not save the approved table")
			_expect(is_equal_approx(earth.value, 100.0 * RoguelikeDigDrops.DEFAULT_EARTH_CHANCE), "restoring did not show the approved chance")
			_expect(_text(developer, "Share_revive") == "2%", "restoring did not show the approved shares")
	developer.queue_free()
	GameManager.developer_mode = was_developer
	DirAccess.remove_absolute(ProjectSettings.globalize_path(DIG_DROPS_PATH))


func _text(screen: Node, node_name: String) -> String:
	var label := screen.find_child(node_name, true, false) as Label
	return label.text if label != null else ""


func _every_recorded_id() -> Array[String]:
	var ids: Array[String] = []
	for kind in RoguelikeDiscovery.STAGE_ITEM_IDS:
		ids.append(RoguelikeDiscovery.stage_item(kind))
	for tool_id in RoguelikeCardPool.TOOL_POOL:
		ids.append(RoguelikeDiscovery.tool(tool_id))
	for kind in [RoguelikeCard.Kind.CHARGES, RoguelikeCard.Kind.NEW_TOOL, RoguelikeCard.Kind.RECRUIT, RoguelikeCard.Kind.REVIVE]:
		ids.append(RoguelikeDiscovery.card_kind(kind))
	for relic_id in RoguelikeRelics.DEFINITIONS:
		ids.append(RoguelikeDiscovery.relic(relic_id))
	for ability_id in RoguelikeAbilities.ALL:
		ids.append(RoguelikeDiscovery.ability(ability_id))
	for character in RoguelikeCharacters.ALL:
		ids.append(RoguelikeDiscovery.character(character))
	return ids


func _entry_name(screen: Node, entry_id: String) -> String:
	var row := screen.find_child(entry_id, true, false)
	if row == null:
		return ""
	var labels := row.find_children("*", "Label", true, false)
	return (labels[0] as Label).text if not labels.is_empty() else ""


func _entry_icon(screen: Node, entry_id: String) -> TextureRect:
	var row := screen.find_child(entry_id, true, false)
	if row == null:
		return null
	var icons := row.find_children("*", "TextureRect", true, false)
	return icons[0] as TextureRect if not icons.is_empty() else null


func _expect(condition: bool, failure: String) -> void:
	if not condition:
		_failures.append(failure)


func _report() -> void:
	if _failures.is_empty():
		print("Compendium: PASS")
		get_tree().quit(0)
		return
	for failure in _failures:
		print("  FAIL: %s" % failure)
	print("Compendium: FAIL")
	get_tree().quit(1)
