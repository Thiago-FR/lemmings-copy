extends "res://tests/level_playthrough_test.gd"
## Plays the "Garras" level end to end. Run via:
##   godot --headless res://tests/test_level_climber.tscn
##
## Every lemming gets the climber while walking right, towards the platform:
## each one needs its own. One heading left would climb the boundary wall
## instead, so those are left alone until they turn back.

const LEVEL_DATA_PATH := "res://resources/levels/level_09_data.tres"
const TOOL_ID := "climber"


func _get_level_data_path() -> String:
	return LEVEL_DATA_PATH


func _play_frame() -> void:
	for lemming in get_lemmings():
		if is_walking(lemming) and lemming.direction > 0 and not lemming.has_climber_skill:
			give_tool(TOOL_ID, lemming, "walking towards the platform")
