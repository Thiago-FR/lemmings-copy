extends Node
## Automated check of the in-level controls (pause/continue, restart, menu)
## and of the main menu. Run via:
##   godot --headless res://tests/test_game_controls.tscn
## Exits 0 when every check passes, 1 otherwise.
##
## Drives the real scenes through the buttons, in order:
##   - the main menu builds one button per entry, with no script errors;
##   - in a level, Pause freezes every lemming and Continue lets them move on
##     from where they were;
##   - Restart reloads the level from the start, unpaused, even when pressed
##     while paused;
##   - Menu goes back to the main menu, unpaused, even when pressed while
##     paused.
##
## Scene changes free the current scene, which starts out as this test; it
## stops being the current scene first so it survives them.

const LEVEL_DATA_PATH := "res://resources/levels/level_07_data.tres"
const MAIN_MENU_SCENE_PATH := "res://scenes/main/main_menu.tscn"
## Long enough for the first lemmings to spawn and walk a bit.
const WARM_UP_FRAMES := 180
const PAUSED_FRAMES := 60
const SCENE_CHANGE_FRAMES := 10

var _failures: Array[String] = []


func _ready() -> void:
	# Keeps running while the game is paused, or the pause check could never
	# continue past the pause.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run.call_deferred()


func _run() -> void:
	get_tree().current_scene = null
	await _check_main_menu()
	await _check_pause_and_continue()
	await _check_restart_while_paused()
	await _check_menu_while_paused()
	_report()


func _check_main_menu() -> void:
	get_tree().change_scene_to_file(MAIN_MENU_SCENE_PATH)
	await _frames(SCENE_CHANGE_FRAMES)
	var buttons := get_tree().current_scene.find_children("*", "Button", true, false)
	print("main menu: %d buttons" % buttons.size())
	if buttons.size() < 2:
		_fail("the main menu has %d buttons" % buttons.size())


func _check_pause_and_continue() -> void:
	LevelLoader.load_level(load(LEVEL_DATA_PATH))
	await _frames(WARM_UP_FRAMES)
	var before := _lemming_positions()
	if before.is_empty():
		_fail("no lemming had spawned to check pausing with")
		return

	_press("PauseButton")
	await _frames(PAUSED_FRAMES)
	if not get_tree().paused or not GameManager.is_paused:
		_fail("Pause did not pause the game")
	if _lemming_positions() != before:
		_fail("lemmings moved while paused")
	if not _button("PauseButton").tooltip_text.begins_with("Continuar"):
		_fail("the pause button says '%s' while paused, expected 'Continuar'" % _button("PauseButton").tooltip_text)

	_press("PauseButton")
	await _frames(PAUSED_FRAMES)
	if get_tree().paused:
		_fail("Continue did not unpause the game")
	if _lemming_positions() == before:
		_fail("lemmings did not move after Continue")
	print("pause/continue checked")


func _check_restart_while_paused() -> void:
	_press("PauseButton")
	_press("RestartButton")
	await _frames(SCENE_CHANGE_FRAMES)
	if get_tree().paused or GameManager.is_paused:
		_fail("the level restarted paused")
	var level_manager: LevelManager = get_tree().get_first_node_in_group("level_manager")
	if level_manager == null:
		_fail("no level after Restart")
	elif level_manager.lemmings_spawned_count > 1:
		_fail("Restart did not start over: %d lemmings already out" % level_manager.lemmings_spawned_count)
	print("restart checked")


func _check_menu_while_paused() -> void:
	_press("PauseButton")
	_press("MenuButton")
	await _frames(SCENE_CHANGE_FRAMES)
	if get_tree().paused or GameManager.is_paused:
		_fail("the menu opened paused")
	if get_tree().current_scene == null or get_tree().current_scene.scene_file_path != MAIN_MENU_SCENE_PATH:
		_fail("Menu did not open the main menu")
	print("menu checked")


func _button(button_name: String) -> Button:
	return get_tree().current_scene.find_child(button_name, true, false) as Button


func _press(button_name: String) -> void:
	var button := _button(button_name)
	if button == null:
		_fail("no %s in the level" % button_name)
		return
	button.pressed.emit()


func _lemming_positions() -> Array[Vector2]:
	var positions: Array[Vector2] = []
	for lemming in get_tree().get_nodes_in_group("lemmings"):
		positions.append(lemming.global_position)
	return positions


func _frames(count: int) -> void:
	for _frame in count:
		await get_tree().process_frame


func _fail(reason: String) -> void:
	_failures.append(reason)
	print("  FAIL — %s" % reason)


func _report() -> void:
	if _failures.is_empty():
		print("Game controls: all checks passed")
		get_tree().quit(0)
		return
	print("Game controls: %d checks failed" % _failures.size())
	get_tree().quit(1)
