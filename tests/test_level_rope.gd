extends "res://tests/level_playthrough_test.gd"
## Plays the "Corda" level end to end. Run via:
##   godot --headless res://tests/test_level_rope.tscn
##
## The first lemming walking right gets the rope, ties it at the ledge's end
## and lets it down; the rest slide down after it.

const LEVEL_DATA_PATH := "res://resources/levels/level_15_data.tres"
const TOOL_ID := "rope"

var _tool_given := false


func _get_level_data_path() -> String:
	return LEVEL_DATA_PATH


func _play_frame() -> void:
	if _tool_given:
		return
	for lemming in get_lemmings():
		if is_walking(lemming) and lemming.direction > 0:
			_tool_given = give_tool(TOOL_ID, lemming, "walking right")
			return
