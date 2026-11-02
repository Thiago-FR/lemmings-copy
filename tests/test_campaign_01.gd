extends "res://tests/campaign_playthrough_test.gd"
## Plays campaign level 1, "Terra Fofa", with a scripted solution. Run via:
##   godot --headless res://tests/test_campaign_01.tscn
##
## The first lemming to walk over the middle of the meadow digs down into the hollow.


func _get_level_number() -> int:
	return 1


func _play_frame() -> void:
	give_once("dig through the meadow", "digger", walking_in(18, 24, 0, 20))
