extends "res://tests/level_playthrough_test.gd"
## Plays the "Escudo" level end to end. Run via:
##   godot --headless res://tests/test_level_blocker.tscn
##
## The first lemming is made a blocker a few steps after it lands, between
## the entrance and the gap: far enough along that the lemmings dropping in
## behind it land clear of it (one landing inside its zone would not be
## turned, since only walking lemmings are), and well before the gap.
## The blocker never leaves, so the level ends when its time runs out, with
## everyone else saved.

const LEVEL_DATA_PATH := "res://resources/levels/level_10_data.tres"
const TOOL_ID := "blocker"
const BLOCK_AT_X := 480.0

var _blocker_placed := false


func _get_level_data_path() -> String:
	return LEVEL_DATA_PATH


func _play_frame() -> void:
	if _blocker_placed:
		return
	for lemming in get_lemmings():
		if is_walking(lemming) and lemming.direction > 0 and lemming.get_body_rect().get_center().x >= BLOCK_AT_X:
			_blocker_placed = give_tool(TOOL_ID, lemming, "between the entrance and the gap")
			return
