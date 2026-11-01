extends Node
## Loads a level's terrain scene from its LevelData and hands the data off
## to GameManager so gameplay scripts can read spawn/exit/skill config.

signal level_loaded(level_data: LevelData)
signal level_load_failed(level_data: LevelData)

var current_level_data: LevelData


func load_level(level_data: LevelData) -> void:
	assert(level_data != null, "load_level requires a non-null LevelData")

	if not ResourceLoader.exists(level_data.scene_path):
		push_error("LevelLoader: scene not found at '%s'" % level_data.scene_path)
		level_load_failed.emit(level_data)
		return

	current_level_data = level_data
	GameManager.current_level_data = level_data
	# Deferred: change_scene_to_file() fails if called while the tree is
	# mid-setup (e.g. from a node's own _ready()), which callers of
	# load_level() may legitimately do.
	get_tree().change_scene_to_file.call_deferred(level_data.scene_path)
	level_loaded.emit(level_data)


func reload_current_level() -> void:
	if current_level_data == null:
		push_warning("LevelLoader: no current level to reload")
		return
	load_level(current_level_data)
