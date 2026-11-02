extends "res://tests/campaign_playthrough_test.gd"
## Plays campaign level 7, "Câmaras de Cristal", with a scripted solution. Run via:
##   godot --headless res://tests/test_campaign_07.tscn
##
## Down at once: a shaft in the first room, a bridge over the chasm below,
## a pickaxe through the last wall.


func _get_level_number() -> int:
	return 7


func _play_frame() -> void:
	give_once("shaft in the first room", "digger", walking_in(10, 16, 0, 18))
	give_once("bridge the chasm", "bridge", walking_in(8, 21, 1, 20))
	give_once("pickaxe through the wall", "miner", walking_in(32, 45, 1, 20))
