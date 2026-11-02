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
##   - the character screen has a compendium button that opens it.

const PROFILE_PATH := "user://test_compendium_profile.cfg"

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
	_report()


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
