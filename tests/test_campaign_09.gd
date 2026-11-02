extends "res://tests/campaign_playthrough_test.gd"
## Plays campaign level 9, "Coração de Cristal", with a scripted solution. Run via:
##   godot --headless res://tests/test_campaign_09.tscn
##
## TNT by the end wall of the upper gallery.


func _get_level_number() -> int:
	return 9


func _play_frame() -> void:
	give_once("tnt by the end wall", "tnt", both(walking_in(37, 38, 1, 20), alone_within(70.0)))
