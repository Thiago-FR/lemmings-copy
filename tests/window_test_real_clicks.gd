extends Node
## Clicks the way a person does, in a real window: the system pointer is
## moved onto each button (warp_mouse) before the press and release, then
## the screen the click should open is checked. Menu -> Roguelike -> its
## menu's New game -> slot 1 (in a folder of its own, never the player's
## saves) -> Play (Wizard) -> the stage's Pause button. Then the free mode with a level
## that drops nothing: its items panel -> a chance's "+" switches the items
## on (it once read as locked).
##
## Why a window: once a bug cancelled every real click on a button (a cursor
## shape changed while the button was held) and passed every headless test,
## because Godot only reacts that way when the system pointer is really over
## the button, and there is no pointer without a window. Hence the name
## window_test_*: run_tests.bat runs these without --headless, after the
## rest. It moves the mouse for a few seconds; leave it alone meanwhile.
##
## Exits 0 when every click did its job, 1 otherwise.

const MAIN_MENU_PATH := "res://scenes/main/main_menu.tscn"
const EDITOR_PATH := "res://scenes/editor/level_editor.tscn"
const TEST_SAVES := "user://test_window_saves/"
const SCREEN_SECONDS := 1.0
const TIMEOUT_SECONDS := 60.0

var _failures: Array[String] = []


func _ready() -> void:
	get_tree().create_timer(TIMEOUT_SECONDS).timeout.connect(func() -> void:
		print("FAIL: timed out")
		get_tree().quit(1))
	_run.call_deferred()


func _run() -> void:
	# This node is the scene the test started with; let the menu take that
	# place without freeing it.
	FolderUtils.delete_folder(TEST_SAVES)
	SaveSlots.root = TEST_SAVES
	# An empty saves folder for the mode: the player's old profile is not
	# adopted into slot 1, so New game there starts without a question.
	DirAccess.make_dir_recursive_absolute(TEST_SAVES.path_join("roguelike"))
	get_tree().current_scene = null
	get_tree().change_scene_to_file(MAIN_MENU_PATH)
	await get_tree().create_timer(SCREEN_SECONDS).timeout

	await _click_button_with_text("Roguelike")
	_check(get_tree().current_scene.scene_file_path.contains("roguelike_run"), "the Roguelike button opens a run")

	var new_game := _find(get_tree().root, func(node: Node) -> bool: return node.name == "NewGame" and (node as Control).is_visible_in_tree()) as Button
	if _check(new_game != null, "the Roguelike opens on its menu, with New game"):
		await _click(new_game)
		var first_slot := _find(get_tree().root, func(node: Node) -> bool: return node.name == "Slot1") as Node
		var pick := first_slot.find_child("Pick", true, false) as Button if first_slot != null else null
		if _check(pick != null, "New game lists the saved games"):
			await _click(pick)
			_check(SaveSlots.is_active("roguelike") and SaveSlots.is_used("roguelike", 0), "an empty slot starts a saved game in slot 1")

	await _click_button_with_text("Jogar")
	_check(_find(get_tree().root, func(node: Node) -> bool: return node.name == "RoguelikeStage") != null, "Play starts the first stage")

	var pause := _find(get_tree().root, func(node: Node) -> bool: return node is Button and (node as Button).tooltip_text.begins_with("Pausar")) as Button
	if _check(pause != null, "the stage has a Pause button"):
		await _click(pause)
		_check(GameManager.is_paused, "the Pause button pauses the stage")
		var menu_button := _find(get_tree().root, func(node: Node) -> bool: return node is Button and (node as Button).tooltip_text.begins_with("Menu")) as Button
		if _check(menu_button != null, "the stage has a Menu button"):
			await _click(menu_button)
			var run_menu := _find(get_tree().root, func(node: Node) -> bool: return node is GameMenu) as GameMenu
			if _check(run_menu != null and run_menu.get_button("Save") != null, "the Menu button opens the game's menu, with Save"):
				await _click(run_menu.get_button("Continue"))
				_check(not is_instance_valid(run_menu), "Continue closes the menu")

	# Before the editor: its items panel, left open, sits over everything.
	await _check_delete_inside_slot_button()
	await _check_drops_panel_answers_when_off()

	SaveSlots.close()
	FolderUtils.delete_folder(TEST_SAVES)
	SaveSlots.root = SaveSlots.ROOT
	var passed := _failures.is_empty()
	print("Real clicks: %s" % ("PASS" if passed else "FAIL (%s)" % "; ".join(_failures)))
	get_tree().quit(0 if passed else 1)


## The delete button sits on top of a saved game's button: a click on it
## asks to delete, and does not load the game.
func _check_delete_inside_slot_button() -> void:
	var menu := GameMenu.new("roguelike", "Roguelike", false)
	var loaded := []
	menu.load_chosen.connect(func(slot: int) -> void: loaded.append(slot))
	get_tree().current_scene.add_child(menu)
	await get_tree().process_frame
	await _click(menu.get_button("Load"))
	var delete := menu.get_button("Delete")
	if not _check(delete != null, "a saved game has a delete button"):
		return
	await _click(delete)
	_check(_find(get_tree().root, func(node: Node) -> bool: return node is ConfirmModal) != null and loaded.is_empty(), "clicking it asks to delete, without loading")
	menu.queue_free()


func _check_drops_panel_answers_when_off() -> void:
	GameManager.resume_game()
	get_tree().change_scene_to_file(EDITOR_PATH)
	await get_tree().create_timer(SCREEN_SECONDS).timeout
	var editor := get_tree().current_scene
	editor.set_dig_drops(null)
	var open_panel := _find(editor, func(node: Node) -> bool: return node.name == "DigDropsButton") as Button
	if not _check(open_panel != null, "the free mode has the items button"):
		return
	await _click(open_panel)
	var earth := _find(get_tree().root, func(node: Node) -> bool: return node.name == "EarthChance")
	if not _check(earth != null, "the items button opens the panel"):
		return
	await _click(earth.find_child("Increase", true, false) as Button)
	_check(editor.get_dig_drops() != null, "with nothing dropping, a chance's + switches the items on")


func _click_button_with_text(text: String) -> void:
	var button := _find(get_tree().root, func(node: Node) -> bool:
		return node is Button and (node as Button).text == text and (node as Button).is_visible_in_tree()) as Button
	if _check(button != null, "there is a '%s' button" % text):
		await _click(button)


## Pointer onto the button's centre, a small move as a hand makes, press,
## release, and time for the screen it opens.
func _click(button: Control) -> void:
	var at := button.get_global_rect().get_center()
	get_viewport().warp_mouse(at)
	_send_motion(at + Vector2(-4, 0))
	await get_tree().process_frame
	_send_motion(at)
	await get_tree().process_frame
	await get_tree().process_frame
	_send_button(at, true)
	await get_tree().process_frame
	await get_tree().process_frame
	_send_button(at, false)
	await get_tree().create_timer(SCREEN_SECONDS, true).timeout


func _send_motion(at: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = at
	motion.global_position = at
	Input.parse_input_event(motion)


func _send_button(at: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	event.position = at
	event.global_position = at
	Input.parse_input_event(event)


func _find(node: Node, matches: Callable) -> Node:
	if matches.call(node):
		return node
	for child in node.get_children():
		var found := _find(child, matches)
		if found != null:
			return found
	return null


func _check(condition: bool, description: String) -> bool:
	print("  [%s] %s" % ["ok" if condition else "FAIL", description])
	if not condition:
		_failures.append(description)
	return condition
