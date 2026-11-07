extends "res://tests/level_playthrough_test.gd"
## Plays the "Escada que cava" level end to end. Run via:
##   godot --headless res://tests/test_level_dig_stairs.tscn
##
## The first lemming walking right gets the digging stairs, carries them to
## the hill and digs up to its top; the rest walk up the same steps.

const LEVEL_DATA_PATH := "res://resources/levels/level_16_data.tres"
const TOOL_ID := "dig_stairs"

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
