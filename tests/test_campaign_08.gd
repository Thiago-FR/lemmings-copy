extends "res://tests/campaign_playthrough_test.gd"
## Plays campaign level 8, "Eco Profundo", with a scripted solution. Run via:
##   godot --headless res://tests/test_campaign_08.tscn
##
## One charge on the upper floor, one on the middle floor away from the first hole.


func _get_level_number() -> int:
	return 8


func _play_frame() -> void:
	give_once("dynamite, upper floor", "dynamite", walking_in(30, 30, 1, 16))
	if is_done("dynamite, upper floor"):
		give_once("dynamite, middle floor", "dynamite", walking_in(52, 52, 1, 18))
