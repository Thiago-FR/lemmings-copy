extends "res://tests/campaign_playthrough_test.gd"
## Plays campaign level 14, "Caldeirão", with a scripted solution. Run via:
##   godot --headless res://tests/test_campaign_14.tscn
##
## A pioneer climbs out and floats down, bridges the gorge; then a shaft lets the rest out.


func _get_level_number() -> int:
	return 14


func _play_frame() -> void:
	give_once("claws for the pioneer", "climber", walking_in(4, 16, 1, 20))
	if is_done("claws for the pioneer"):
		give_once("parachute for the pioneer", "floater", has_claws)
	if is_done("parachute for the pioneer"):
		give_once("bridge the gorge", "bridge", walking_in(19, 30, 1, 22))
	if is_done("bridge the gorge") and elapsed > _done_steps["bridge the gorge"] + 8.0:
		give_once("shaft for the rest", "digger", walking_in(6, 14, 0, 20))


func has_claws(lemming: LemmingController) -> bool:
	return lemming.has_climber_skill
