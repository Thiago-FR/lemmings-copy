extends "res://tests/level_playthrough_test.gd"
## Plays the "Dinamite" level end to end. Run via:
##   godot --headless res://tests/test_level_dynamite.tscn
##
## The first lemming to walk past the middle of the floor puts the charge
## down there and walks on; the blast opens the floor and the lemmings drop
## into the room with the exit underneath.

const LEVEL_DATA_PATH := "res://resources/levels/level_11_data.tres"
const TOOL_ID := "dynamite"
const PLACE_AT_X := 400.0

var _tool_given := false


func _get_level_data_path() -> String:
	return LEVEL_DATA_PATH


func _play_frame() -> void:
	if _tool_given:
		return
	for lemming in get_lemmings():
		if is_walking(lemming) and lemming.direction > 0 and lemming.get_body_rect().get_center().x >= PLACE_AT_X:
			_tool_given = give_tool(TOOL_ID, lemming, "in the middle of the floor")
			return
