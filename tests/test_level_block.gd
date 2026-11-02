extends "res://tests/level_playthrough_test.gd"
## Plays the "Bloco" level end to end. Run via:
##   godot --headless res://tests/test_level_block.tscn
##
## The first lemming walking right is given the block between the entrance
## and the gap; it turns at its own block, and every lemming after it turns
## there too and walks to the exit.

const LEVEL_DATA_PATH := "res://resources/levels/level_10_data.tres"
const TOOL_ID := "block"
const BLOCK_AT_X := 480.0

var _tool_given := false


func _get_level_data_path() -> String:
	return LEVEL_DATA_PATH


func _play_frame() -> void:
	if _tool_given:
		return
	for lemming in get_lemmings():
		if is_walking(lemming) and lemming.direction > 0 and lemming.get_body_rect().get_center().x >= BLOCK_AT_X:
			_tool_given = give_tool(TOOL_ID, lemming, "between the entrance and the gap")
			return
