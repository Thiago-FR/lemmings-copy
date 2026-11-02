extends "res://tests/campaign_playthrough_test.gd"
## Plays campaign level 12, "Duas Bocas", with a scripted solution. Run via:
##   godot --headless res://tests/test_campaign_12.tscn
##
## The ladder on the left face first; a bridge for the right group over the
## crevasse; then a pickaxe through the tower's foot from the right.


func _get_level_number() -> int:
	return 12


func _play_frame() -> void:
	give_once("ladder on the left face", "ladder_vertical", walking_in(28, 34, 1, 30))
	give_once("bridge the crevasse", "bridge", walking_in(56, 66, -1, 30))
	if is_done("ladder on the left face") and elapsed > _done_steps["ladder on the left face"] + 6.0:
		give_once("tunnel through the foot", "miner", walking_in(45, 49, -1, 30))
