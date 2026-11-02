extends "res://tests/campaign_playthrough_test.gd"
## Plays campaign level 10, "Travessia Gelada", with a scripted solution. Run via:
##   godot --headless res://tests/test_campaign_10.tscn
##
## Dig through the shelf, bridge the crevasse, a staircase up the terrace.


func _get_level_number() -> int:
	return 10


func _play_frame() -> void:
	give_once("dig through the shelf", "digger", walking_in(10, 20, 0, 18))
	give_once("bridge the crevasse", "bridge", walking_in(31, 38, 1, 20))
	if is_done("bridge the crevasse"):
		give_once("staircase to the terrace", "builder", walking_in(45, 46, 1, 20))
