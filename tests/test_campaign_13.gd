extends "res://tests/campaign_playthrough_test.gd"
## Plays campaign level 13, "Passagem de Obsidiana", with a scripted solution. Run via:
##   godot --headless res://tests/test_campaign_13.tscn
##
## Bridge the gorge, blow the floor, break the wall; the pickaxe is not used.


func _get_level_number() -> int:
	return 13


func _play_frame() -> void:
	give_once("bridge the gorge", "bridge", walking_in(8, 20, 1, 18))
	if is_done("bridge the gorge"):
		give_once("dynamite on the shelf", "dynamite", walking_in(40, 40, 1, 18))
	if is_done("dynamite on the shelf"):
		give_once("jackhammer through the wall", "basher", walking_in(52, 57, 1, 20))
