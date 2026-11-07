extends Node
## Saved games in the roguelike: the mode opens on its saved games; a new
## game opens the character screen; a run is saved between stages and,
## after closing the mode, loading the game goes back to that point (the
## stage about to be played, or the shop) with the run as it was (coins,
## relics, tool bar, troop); a finished run leaves only the profile. The
## run state survives the trip through a file. Works in a folder of its
## own; never touches the player's saves. Run via:
##   godot --headless res://modes/roguelike/tests/test_saved_run.tscn
## Exits 0 when every check passes, 1 otherwise.

const RUN_SCENE := preload("res://modes/roguelike/scenes/roguelike_run.tscn")
const TEST_ROOT := "user://test_saved_run/"
const MODE := RoguelikeRunController.SAVE_MODE

var _failures: Array[String] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	FolderUtils.delete_folder(TEST_ROOT)
	SaveSlots.root = TEST_ROOT
	_check_state_round_trip()

	var run := await _open_mode()
	_check(run.find_child(RoguelikeRunController.MENU_NAME, true, false) != null, "the mode opens on its menu")
	await _pick_slot(run, 0, true)
	_check(_current_title(run) == "Escolha seu personagem", "a new game opens the character screen (%s)" % _current_title(run))
	run._on_character_chosen(RoguelikeCharacters.STARTER)
	await get_tree().process_frame
	_check(_has_session(run), "choosing a character starts stage 1")
	_check(SaveSlots.get_info(MODE, 0).summary.contains("fase 1"), "the game is saved at the stage, '%s'" % SaveSlots.get_info(MODE, 0).summary)

	# Between stages, in the shop, with things to keep.
	run.state.coins = 17
	run.state.stage_index = 2
	run.state.add_relic(RoguelikeRelics.GREED)
	run.state.inventory.add_charges("digger", 3)
	run._show_shop()
	await get_tree().process_frame
	run.queue_free()
	await get_tree().process_frame

	run = await _open_mode()
	await _pick_slot(run, 0)
	_check(run.state != null and run.state.coins == 17 and run.state.stage_index == 2, "loading goes back to the run (coins and stage)")
	_check(run.state != null and run.state.get_relic_level(RoguelikeRelics.GREED) == 1, "with its relics")
	_check(run.state != null and run.state.inventory.get_charges("digger") == 3, "and its tool bar")
	_check(_current_screen(run) is RoguelikeShopScreen, "in the shop, where it was saved")
	_check(_current_screen(run) != null and _current_screen(run).find_child("SaveButton", true, false) != null, "the shop has a Save button")

	# Leaving the shop: saved at the stage; a stage under way starts over.
	(_current_screen(run) as RoguelikeShopScreen).closed.emit()
	await get_tree().process_frame
	run.queue_free()
	await get_tree().process_frame
	run = await _open_mode()
	await _pick_slot(run, 0)
	_check(_has_session(run) and run.state.stage_index == 2, "saved at the stage: loading starts that stage")

	# In the stage, the menu (Esc) loads a game: the stage is left for it.
	run.open_game_menu()
	await get_tree().process_frame
	var menu := run.find_child(RoguelikeRunController.MENU_NAME, true, false) as GameMenu
	_check(menu != null and menu.get_button("Save") != null and GameManager.is_paused, "in the stage the menu opens over the paused game, with Save")
	await _pick_slot(run, 0)
	_check(_has_session(run) and not GameManager.is_paused and run.state.stage_index == 2, "loading from the stage's menu starts the saved stage")

	# The run lost: only the profile is left.
	run._on_stage_finished([] as Array[StringName], run.state.troop.duplicate())
	await get_tree().process_frame
	_check(not FileAccess.file_exists(SaveSlots._slot_directory(MODE, 0).path_join(RoguelikeRunController.RUN_FILE)), "a finished run is no longer in the save")
	_check(SaveSlots.get_info(MODE, 0).summary.begins_with("Sem run"), "the summary shows no run, '%s'" % SaveSlots.get_info(MODE, 0).summary)
	run.queue_free()
	await get_tree().process_frame

	SaveSlots.close()
	FolderUtils.delete_folder(TEST_ROOT)
	SaveSlots.root = SaveSlots.ROOT
	print("Saved run: %s" % ("PASS" if _failures.is_empty() else "FAIL (%d)" % _failures.size()))
	get_tree().quit(0 if _failures.is_empty() else 1)


func _check_state_round_trip() -> void:
	var state := RoguelikeRunState.new_run(RoguelikeCharacters.STARTER)
	state.stage_index = 4
	state.coins = 9
	state.score = 120
	state.revive_tokens = 1
	state.fallen.append(RoguelikeCharacters.STARTER)
	state.add_relic(RoguelikeRelics.EXTRA_POCKET)
	state.add_relic(RoguelikeRelics.GREED)
	state.add_relic(RoguelikeRelics.GREED)
	state.inventory.add_charges("builder", 2)
	state.inventory.add_charges("basher", 1)
	var file := ConfigFile.new()
	file.set_value("run", "state", state.to_dictionary())
	var path := TEST_ROOT.path_join("round_trip.cfg")
	DirAccess.make_dir_recursive_absolute(TEST_ROOT)
	file.save(path)
	var read := ConfigFile.new()
	read.load(path)
	var back := RoguelikeRunState.from_dictionary(read.get_value("run", "state"))
	_check(back.to_dictionary() == state.to_dictionary(), "the run state survives a file: %s" % [back.to_dictionary()])
	_check(back.inventory.max_slots == state.inventory.max_slots and back.inventory.get_tool_ids() == state.inventory.get_tool_ids(), "the tool bar keeps its slots and order")


func _open_mode() -> RoguelikeRunController:
	var run: RoguelikeRunController = RUN_SCENE.instantiate()
	add_child(run)
	await get_tree().process_frame
	return run


func _pick_slot(run: RoguelikeRunController, slot: int, new_game: bool = false) -> void:
	var menu := run.find_child(RoguelikeRunController.MENU_NAME, true, false) as GameMenu
	if menu == null:
		_check(false, "no menu")
		return
	if new_game:
		menu.new_game_chosen.emit(slot)
	else:
		menu.load_chosen.emit(slot)
	menu.queue_free()
	await get_tree().process_frame


func _has_session(run: Node) -> bool:
	for child in run.get_children():
		if child is RoguelikeStageSession:
			return true
	return false


func _current_screen(run: Node) -> RoguelikeOverlayScreen:
	for child in run.get_children():
		if child is RoguelikeOverlayScreen and not child.is_queued_for_deletion():
			return child
	return null


func _current_title(run: Node) -> String:
	var screen := _current_screen(run)
	if screen == null:
		return "(no screen)"
	return (screen.content.get_child(0) as Label).text


func _check(condition: bool, description: String) -> void:
	print("  [%s] %s" % ["ok" if condition else "FAIL", description])
	if not condition:
		_failures.append(description)
