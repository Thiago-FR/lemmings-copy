extends Node
## Global game flow: pause state and the currently active level's data.
## Per-level lemming spawning/win-loss logic lives in LevelManager, not here.

signal game_paused
signal game_resumed

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
