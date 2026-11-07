extends Node
## Saved games (SaveSlots) with the campaign: a new game takes its slot at
## once, a win is saved automatically, with the automatic save off nothing
## reaches the slot until Save, loading a slot brings its progress back, a
## slot can be deleted, the progress kept before there were slots becomes
## slot 1, and the mode's menu (entering it and in the middle of a game)
## offers all of it. Works in folders of
## its own; never touches the player's saves. Run via:
##   godot --headless res://tests/test_save_slots.tscn
## Exits 0 on success, 1 otherwise.

const TEST_ROOT := "user://test_save_slots/"
const LEGACY_PATH := "user://test_save_slots_legacy.cfg"
const MODE := Campaign.SAVE_MODE

var _failures: Array[String] = []


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	FolderUtils.delete_folder(TEST_ROOT)
	SaveSlots.root = TEST_ROOT
	_check_new_game_and_auto_save()
	_check_auto_save_off()
	_check_slots_are_separate()
	_check_delete()
	_check_legacy()
	await _check_screen()
	SaveSlots.close()
	FolderUtils.delete_folder(TEST_ROOT)
	DirAccess.remove_absolute(LEGACY_PATH)
	SaveSlots.root = SaveSlots.ROOT
	Campaign.save_path = Campaign.SAVE_PATH
	_finish()


func _check_new_game_and_auto_save() -> void:
	Campaign.use_save_slot(0)
	_expect(SaveSlots.is_used(MODE, 0), "a new game takes its slot at once")
	_expect(SaveSlots.get_info(MODE, 0).summary == "Fase 1 de %d" % Campaign.LEVEL_COUNT, "a new game's summary is level 1, got '%s'" % SaveSlots.get_info(MODE, 0).summary)
	Campaign.record_win(0, 1.0)
	_expect(SaveSlots.get_info(MODE, 0).summary == "Fase 2 de %d" % Campaign.LEVEL_COUNT, "a win is saved automatically, got '%s'" % SaveSlots.get_info(MODE, 0).summary)
	Campaign.use_save_slot(0)
	_expect(Campaign.is_cleared(0) and not Campaign.is_cleared(1), "loading the slot brings the win back")


func _check_auto_save_off() -> void:
	SaveSlots.set_auto_save(MODE, false)
	Campaign.use_save_slot(0)
	Campaign.record_win(1, 1.0)
	_expect(Campaign.is_cleared(1), "the win counts in the game being played")
	Campaign.use_save_slot(0)
	_expect(not Campaign.is_cleared(1), "with the automatic save off, the slot keeps what it had")
	Campaign.record_win(1, 1.0)
	_expect(SaveSlots.save(), "Save writes the game")
	Campaign.use_save_slot(0)
	_expect(Campaign.is_cleared(1), "after Save the slot has the win")
	SaveSlots.set_auto_save(MODE, true)


func _check_slots_are_separate() -> void:
	Campaign.use_save_slot(2)
	_expect(not Campaign.is_cleared(0), "another slot is a game of its own")
	Campaign.use_save_slot(0)
	_expect(Campaign.is_cleared(0), "and leaves the first one alone")


func _check_delete() -> void:
	SaveSlots.delete(MODE, 2)
	_expect(not SaveSlots.is_used(MODE, 2), "a deleted slot is empty")
	_expect(SaveSlots.is_used(MODE, 0), "deleting one slot leaves the others")


func _check_legacy() -> void:
	var legacy := ConfigFile.new()
	legacy.set_value(Campaign.SECTION, "level_01", 1.0)
	legacy.save(LEGACY_PATH)
	SaveSlots.adopt_legacy_file("legacy_test", LEGACY_PATH, Campaign.SAVE_FILE, "old")
	_expect(SaveSlots.is_used("legacy_test", 0) and SaveSlots.get_info("legacy_test", 0).summary == "old", "the old save becomes slot 1")
	SaveSlots.delete("legacy_test", 0)
	SaveSlots.adopt_legacy_file("legacy_test", LEGACY_PATH, Campaign.SAVE_FILE, "old")
	_expect(not SaveSlots.is_used("legacy_test", 0), "only once: not again after the mode has saves")


func _check_screen() -> void:
	var menu := GameMenu.new(MODE, "Fases", false)
	add_child(menu)
	await get_tree().process_frame
	for button_name in ["NewGame", "Load", "Settings", "MainMenu"]:
		_expect(menu.get_button(button_name) != null, "entering a mode the menu has %s" % button_name)
	_expect(menu.get_button("Continue") == null and menu.get_button("Save") == null, "and no Continue or Save")
	menu.get_button("Load").pressed.emit()
	await get_tree().process_frame
	_expect(not menu.get_button("Pick").disabled, "a taken slot can be loaded")
	_expect(menu.get_button("Delete") != null, "and deleted")
	var second := menu.find_child("Slot2", true, false)
	_expect(second != null and (second.find_child("Pick", true, false) as Button).disabled, "an empty slot cannot be loaded")
	menu.get_button("Back").pressed.emit()
	await get_tree().process_frame
	menu.get_button("NewGame").pressed.emit()
	await get_tree().process_frame
	var chosen := []
	menu.new_game_chosen.connect(func(slot: int) -> void: chosen.append(slot))
	(menu.find_child("Slot2", true, false).find_child("Pick", true, false) as Button).pressed.emit()
	_expect(chosen == [1], "a new game in an empty slot starts at once")
	await get_tree().process_frame

	var in_game := GameMenu.new(MODE, "Fases", true)
	add_child(in_game)
	await get_tree().process_frame
	for button_name in ["Continue", "Save", "Load", "Settings", "MainMenu"]:
		_expect(in_game.get_button(button_name) != null, "in a game the menu has %s" % button_name)
	_expect(in_game.get_button("NewGame") == null, "and no New game")
	_expect(GameManager.is_paused, "the menu pauses the game")
	in_game.get_button("Continue").pressed.emit()
	await get_tree().process_frame
	_expect(not GameManager.is_paused, "Continue resumes it")

	var settings := SettingsMenu.new()
	settings.save_mode = MODE
	add_child(settings)
	var auto_save := settings.find_child("AutoSaveCheckBox", true, false) as CheckBox
	_expect(auto_save != null, "the mode's settings have the automatic save")
	if auto_save != null:
		auto_save.button_pressed = false
		_expect(not SaveSlots.is_auto_save_on(MODE), "the switch turns the automatic save off")
		auto_save.button_pressed = true
	settings.close()


func _expect(condition: bool, description: String) -> void:
	if not condition:
		_failures.append(description)


func _finish() -> void:
	if _failures.is_empty():
		print("test_save_slots: OK")
		get_tree().quit(0)
	else:
		for failure in _failures:
			print("FAIL: ", failure)
		get_tree().quit(1)
