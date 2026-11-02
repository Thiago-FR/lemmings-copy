extends "res://tests/campaign_playthrough_test.gd"
## Plays campaign level 10, "Contra o Relógio", with a scripted solution. Run via:
##   godot --headless res://tests/test_campaign_10.tscn
##
## A shaft at the first corner (where they turn at the end of the first
## tunnel) and one at the corner of the fourth: four tunnels skipped.


func _get_level_number() -> int:
	return 10


func _play_frame() -> void:
	give_once("shaft at the first corner", "digger", walking_in(52, 52, 1, 12))
	give_once("shaft at the fourth corner", "digger", walking_in(8, 8, -1, 18))
