extends "res://tests/campaign_playthrough_test.gd"
## Plays campaign level 13, "Beiço de Lava", with a scripted solution. Run via:
##   godot --headless res://tests/test_campaign_13.tscn
##
## The bridge to the cliff turns them back; the staircase from the near
## edge rises over the channel onto the lip.


func _get_level_number() -> int:
	return 13


func _play_frame() -> void:
	give_once("bridge to the cliff", "bridge", walking_in(37, 46, 1, 26))
	if is_done("bridge to the cliff"):
		give_once("staircase over the channel", "builder", walking_in(30, 31, -1, 26))
