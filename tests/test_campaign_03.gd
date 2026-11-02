extends "res://tests/campaign_playthrough_test.gd"
## Plays campaign level 3, "Muralha do Moinho", with a scripted solution. Run via:
##   godot --headless res://tests/test_campaign_03.tscn
##
## A ladder up the lower cliff, then one up the upper cliff from its top.


func _get_level_number() -> int:
	return 3


func _play_frame() -> void:
	give_once("lower ladder", "ladder_vertical", walking_in(10, 33, 1, 28))
	if is_done("lower ladder"):
		give_once("upper ladder", "ladder_vertical", walking_in(34, 51, 1, 22))
