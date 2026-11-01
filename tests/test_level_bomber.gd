extends "res://tests/level_playthrough_test.gd"
## Plays the "Bomba" level end to end. Run via:
##   godot --headless res://tests/test_level_bomber.tscn
##
## The first lemming to land in the pen gets the bomber; when it goes off
## the thin wall opens and the rest walk out to the exit.

const LEVEL_DATA_PATH := "res://resources/levels/level_11_data.tres"
const TOOL_ID := "bomber"

var _bomb_given := false


func _get_level_data_path() -> String:
	return LEVEL_DATA_PATH


func _play_frame() -> void:
	if _bomb_given:
		return
	for lemming in get_lemmings():
		if is_walking(lemming):
			_bomb_given = give_tool(TOOL_ID, lemming, "walking in the pen")
			return
