extends "res://tests/campaign_playthrough_test.gd"
## Plays campaign level 12, "Fenda Glacial", with a scripted solution. Run via:
##   godot --headless res://tests/test_campaign_12.tscn
##
## Bridge, pickaxe, ladder: one of each, in that order.


func _get_level_number() -> int:
	return 12


func _play_frame() -> void:
	give_once("bridge the crevasse", "bridge", walking_in(10, 18, 1, 26))
	if is_done("bridge the crevasse"):
		give_once("pickaxe through the drift", "miner", walking_in(27, 32, 1, 26))
	if is_done("pickaxe through the drift"):
		give_once("ladder up the cliff", "ladder_vertical", walking_in(40, 48, 1, 26))
