extends "res://tests/level_playthrough_test.gd"
## Plays the "Paraquedas" level end to end. Run via:
##   godot --headless res://tests/test_level_floater.tscn
##
## Every lemming gets a parachute as soon as it lands on the ledge and starts
## walking, well before the ledge's end: each one needs its own.

const LEVEL_DATA_PATH := "res://resources/levels/level_08_data.tres"
const TOOL_ID := "floater"


func _get_level_data_path() -> String:
	return LEVEL_DATA_PATH


func _play_frame() -> void:
	for lemming in get_lemmings():
		if is_walking(lemming) and not lemming.has_floater_skill:
			give_tool(TOOL_ID, lemming, "walking on the ledge")
