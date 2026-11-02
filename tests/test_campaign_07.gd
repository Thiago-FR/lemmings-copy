extends "res://tests/campaign_playthrough_test.gd"
## Plays campaign level 7, "Veios de Cristal", with a scripted solution. Run via:
##   godot --headless res://tests/test_campaign_07.tscn
##
## Pickaxe for the slate walls, the jackhammer for the crystal one.


func _get_level_number() -> int:
	return 7


func _play_frame() -> void:
	give_once("pickaxe, first wall", "miner", walking_in(8, 19, 1, 26))
	if is_done("pickaxe, first wall"):
		give_once("jackhammer, crystal wall", "basher", walking_in(23, 35, 1, 26))
	if is_done("jackhammer, crystal wall"):
		give_once("pickaxe, last wall", "miner", walking_in(39, 51, 1, 26))
