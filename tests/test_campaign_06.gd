extends "res://tests/campaign_playthrough_test.gd"
## Plays campaign level 6, "Oásis Escondido", with a scripted solution. Run via:
##   godot --headless res://tests/test_campaign_06.tscn
##
## A block before the chasm turns everyone back; a pickaxe takes them through the hill.


func _get_level_number() -> int:
	return 6


func _play_frame() -> void:
	give_once("block before the chasm", "block", walking_in(40, 42, 1, 26))
	if is_done("block before the chasm"):
		give_once("pickaxe for the hill", "miner", walking_in(22, 33, -1, 26))
