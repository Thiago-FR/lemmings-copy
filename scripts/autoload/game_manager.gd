extends Node
## Global game flow: pause state, the currently active level's data, and the
## ways out of a level (restart it, go back to the menu).
## Per-level lemming spawning/win-loss logic lives in LevelManager, not here.

signal game_paused
signal game_resumed
signal fast_forward_changed(enabled: bool)

const MAIN_MENU_SCENE_PATH := "res://scenes/main/main_menu.tscn"
const SETTINGS_PATH := "user://settings.cfg"
## Fast forward: everything (lemmings, tools, the clock) runs this many times
## faster. The physics ticks go up by the same factor, so each step still
## simulates 1/60 s and the game plays out exactly as at normal speed, only
## sooner (bigger steps would let falling lemmings skip through floors).
const FAST_FORWARD_FACTOR := 3
const NORMAL_PHYSICS_TICKS := 60
const CURSOR_ARROW_PATH := "res://assets/sprites/ui/icons/cursor_arrow.png"
const CURSOR_HAND_PATH := "res://assets/sprites/ui/icons/cursor_hand.png"
const CURSOR_GRAB_PATH := "res://assets/sprites/ui/icons/cursor_grab.png"
## Where each pointer image points (its tip; the grab's knuckles).
const CURSOR_ARROW_HOTSPOT := Vector2(1, 1)
const CURSOR_HAND_HOTSPOT := Vector2(13, 3)
const CURSOR_GRAB_HOTSPOT := Vector2(16, 12)

var current_level_data: LevelData
var is_paused: bool = false
## Developer mode (set in the settings screen, saved): shows testing tools
## such as the roguelike's stage and card picker. Modes read it; the core
## only stores it.
var developer_mode: bool = false
var is_fast_forward: bool = false


func _ready() -> void:
	# Lemmings receive clicks through CollisionObject2D.input_event, which
	# requires physics picking to be enabled on the main viewport.
	get_window().physics_object_picking = true
	_set_up_cursors()
	var config := ConfigFile.new()
	config.load(SETTINGS_PATH)
	developer_mode = config.get_value("developer", "enabled", false)


## The game's own mouse pointer (tools/build_ui_art.py), and the pointing
## hand over whatever can be clicked: every button of every screen, and the
## lemmings. Set here, once, so no screen has to remember it.
func _set_up_cursors() -> void:
	Input.set_custom_mouse_cursor(load(CURSOR_ARROW_PATH), Input.CURSOR_ARROW, CURSOR_ARROW_HOTSPOT)
	Input.set_custom_mouse_cursor(load(CURSOR_HAND_PATH), Input.CURSOR_POINTING_HAND, CURSOR_HAND_HOTSPOT)
	Input.set_custom_mouse_cursor(load(CURSOR_GRAB_PATH), Input.CURSOR_DRAG, CURSOR_GRAB_HOTSPOT)
	get_tree().node_added.connect(_on_node_added)


## The hand closes while the button is held and opens again on release.
## Only the hand's picture is swapped: changing a cursor shape while the
## button is down makes Godot send a mouse motion without the button held,
## which cancels the click (no menu button worked with a real mouse).
var _hand_closed := false


func _input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if button == null or button.button_index != MOUSE_BUTTON_LEFT:
		return
	if button.pressed == _hand_closed:
		return
	_hand_closed = button.pressed
	if _hand_closed:
		Input.set_custom_mouse_cursor(load(CURSOR_GRAB_PATH), Input.CURSOR_POINTING_HAND, CURSOR_GRAB_HOTSPOT)
	else:
		Input.set_custom_mouse_cursor(load(CURSOR_HAND_PATH), Input.CURSOR_POINTING_HAND, CURSOR_HAND_HOTSPOT)


func _on_node_added(node: Node) -> void:
	if node is BaseButton:
		(node as BaseButton).mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	elif node is LemmingController:
		var lemming := node as LemmingController
		lemming.mouse_entered.connect(Input.set_default_cursor_shape.bind(Input.CURSOR_POINTING_HAND))
		lemming.mouse_exited.connect(Input.set_default_cursor_shape.bind(Input.CURSOR_ARROW))
		# A lemming that dies or gets out under the pointer sends no
		# mouse_exited: the hand would stay.
		lemming.tree_exiting.connect(Input.set_default_cursor_shape.bind(Input.CURSOR_ARROW))
		lemming.died.connect(func(_cause: LemmingController.DeathCause) -> void: Input.set_default_cursor_shape(Input.CURSOR_ARROW))


func set_developer_mode(enabled: bool) -> void:
	developer_mode = enabled
	var config := ConfigFile.new()
	config.load(SETTINGS_PATH)
	config.set_value("developer", "enabled", enabled)
	config.save(SETTINGS_PATH)


func pause_game() -> void:
	if is_paused:
		return
	is_paused = true
	get_tree().paused = true
	game_paused.emit()


func resume_game() -> void:
	if not is_paused:
		return
	is_paused = false
	get_tree().paused = false
	game_resumed.emit()


func set_fast_forward(enabled: bool) -> void:
	if enabled == is_fast_forward:
		return
	is_fast_forward = enabled
	var factor := FAST_FORWARD_FACTOR if enabled else 1
	Engine.time_scale = factor
	Engine.physics_ticks_per_second = NORMAL_PHYSICS_TICKS * factor
	fast_forward_changed.emit(enabled)


func toggle_fast_forward() -> void:
	set_fast_forward(not is_fast_forward)


func toggle_pause() -> void:
	if is_paused:
		resume_game()
	else:
		pause_game()


## Leaving a level always unpauses first: a paused tree carries over into
## the next scene, which would start frozen.
func restart_level() -> void:
	_unpause_for_scene_change()
	LevelLoader.reload_current_level()


func go_to_main_menu() -> void:
	go_to_scene(MAIN_MENU_SCENE_PATH)


## Leaves the level for another screen (the campaign's level select).
func go_to_scene(scene_path: String) -> void:
	_unpause_for_scene_change()
	get_tree().change_scene_to_file(scene_path)


## Leaves the level for another level (the campaign's next one).
func load_level(level_data: LevelData) -> void:
	_unpause_for_scene_change()
	LevelLoader.load_level(level_data)


## Clears both the tree's pause and is_paused: the result screen pauses the
## tree directly, so the two can disagree.
func _unpause_for_scene_change() -> void:
	set_fast_forward(false)
	var was_paused := is_paused
	is_paused = false
	get_tree().paused = false
	if was_paused:
		game_resumed.emit()
