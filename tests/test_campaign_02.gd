extends "res://tests/campaign_playthrough_test.gd"
## Plays campaign level 2, "Ribeirão Seco", with a scripted solution. Run via:
##   godot --headless res://tests/test_campaign_02.tscn
##
## The first lemming bridges the first stream bed, and again the second.


func _get_level_number() -> int:
	return 2


func _play_frame() -> void:
	give_once("first bridge", "bridge", walking_in(10, 29, 1, 24))
	if is_done("first bridge"):
		give_once("second bridge", "bridge", walking_in(37, 49, 1, 24))
