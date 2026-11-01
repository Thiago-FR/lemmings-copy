extends "res://tests/level_playthrough_test.gd"
## Plays the "Britadeira" level end to end. Run via:
##   godot --headless res://tests/test_level_basher.tscn
##
## The first lemming walking right gets the basher, carries it to the thick
## wall and tunnels through; the rest follow through the tunnel.

const LEVEL_DATA_PATH := "res://resources/levels/level_12_data.tres"
const TOOL_ID := "basher"

var _tool_given := false


func _get_level_data_path() -> String:
	return LEVEL_DATA_PATH


func _play_frame() -> void:
	if _tool_given:
		return
	for lemming in get_lemmings():
		if is_walking(lemming) and lemming.direction > 0:
			_tool_given = give_tool(TOOL_ID, lemming, "walking towards the wall")
			return
