extends Node
## Global game flow: pause state, the currently active level's data, and the
## ways out of a level (restart it, go back to the menu).
## Per-level lemming spawning/win-loss logic lives in LevelManager, not here.

signal game_paused
signal game_resumed

const MAIN_MENU_SCENE_PATH := "res://scenes/main/main_menu.tscn"

var current_level_data: LevelData
var is_paused: bool = false


func _ready() -> void:
	# Lemmings receive clicks through CollisionObject2D.input_event, which
	# requires physics picking to be enabled on the main viewport.
	get_window().physics_object_picking = true


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
	_unpause_for_scene_change()
	get_tree().change_scene_to_file(MAIN_MENU_SCENE_PATH)


## Clears both the tree's pause and is_paused: the result screen pauses the
## tree directly, so the two can disagree.
func _unpause_for_scene_change() -> void:
	var was_paused := is_paused
	is_paused = false
	get_tree().paused = false
	if was_paused:
		game_resumed.emit()
