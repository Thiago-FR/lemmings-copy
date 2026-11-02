extends Node
## Clicks the way a person does, in a real window: the system pointer is
## moved onto each button (warp_mouse) before the press and release, then
## the screen the click should open is checked. Menu -> Roguelike -> Play
## (Wizard) -> the stage's Pause button.
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
	get_tree().current_scene = null
	get_tree().change_scene_to_file(MAIN_MENU_PATH)
	await get_tree().create_timer(SCREEN_SECONDS).timeout

	await _click_button_with_text("Roguelike")
	_check(get_tree().current_scene.scene_file_path.contains("roguelike_run"), "the Roguelike button opens a run")

	await _click_button_with_text("Jogar")
	_check(_find(get_tree().root, func(node: Node) -> bool: return node.name == "RoguelikeStage") != null, "Play starts the first stage")

	var pause := _find(get_tree().root, func(node: Node) -> bool: return node is Button and (node as Button).tooltip_text.begins_with("Pausar")) as Button
	if _check(pause != null, "the stage has a Pause button"):
		await _click(pause)
		_check(GameManager.is_paused, "the Pause button pauses the stage")

	var passed := _failures.is_empty()
	print("Real clicks: %s" % ("PASS" if passed else "FAIL (%s)" % "; ".join(_failures)))
	get_tree().quit(0 if passed else 1)


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
