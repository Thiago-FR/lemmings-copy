extends "res://tests/campaign_playthrough_test.gd"
## Plays campaign level 11, "Torre de Gelo", with a scripted solution. Run via:
##   godot --headless res://tests/test_campaign_11.tscn
##
## A block before the chasm, a ladder up the tower, the jackhammer through the ice.


func _get_level_number() -> int:
	return 11


func _play_frame() -> void:
	give_once("block before the chasm", "block", walking_in(41, 43, 1, 30))
	if is_done("block before the chasm"):
		give_once("ladder up the tower", "ladder_vertical", walking_in(16, 32, -1, 30))
	if is_done("ladder up the tower"):
		give_once("jackhammer through the ice", "basher", walking_in(8, 14, -1, 21))
