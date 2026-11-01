extends "res://tests/level_playthrough_test.gd"
## Plays the "Picareta" level end to end. Run via:
##   godot --headless res://tests/test_level_miner.tscn
##
## The first lemming walking right gets the pickaxe, carries it to the hill
## and digs straight through; the rest follow through the tunnel.

const LEVEL_DATA_PATH := "res://resources/levels/level_13_data.tres"
const TOOL_ID := "miner"

var _tool_given := false


func _get_level_data_path() -> String:
	return LEVEL_DATA_PATH


func _play_frame() -> void:
	if _tool_given:
		return
	for lemming in get_lemmings():
		if is_walking(lemming) and lemming.direction > 0:
			_tool_given = give_tool(TOOL_ID, lemming, "walking towards the hill")
			return
