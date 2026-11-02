extends "res://tests/campaign_playthrough_test.gd"
## Plays campaign level 15, "Coroa de Fogo", with a scripted solution. Run via:
##   godot --headless res://tests/test_campaign_15.tscn
##
## The pioneer climbs out, floats down, bridges, breaks the wall and lays the staircase; then TNT by the crater's wall.


func _get_level_number() -> int:
	return 15


func _play_frame() -> void:
	give_once("claws for the pioneer", "climber", walking_in(3, 16, 1, 20))
	if is_done("claws for the pioneer"):
		give_once("parachute for the pioneer", "floater", has_claws)
	if is_done("parachute for the pioneer"):
		give_once("bridge the gorge", "bridge", walking_in(18, 28, 1, 22))
	if is_done("bridge the gorge"):
		give_once("jackhammer through the wall", "basher", walking_in(36, 43, 1, 22))
	if is_done("jackhammer through the wall"):
		give_once("staircase to the terrace", "builder", walking_in(48, 49, 1, 22))
	if is_done("staircase to the terrace") and elapsed > _done_steps["staircase to the terrace"] + 10.0:
		give_once("tnt by the crater's wall", "tnt", walking_in(16, 16, 1, 20))


func has_claws(lemming: LemmingController) -> bool:
	return lemming.has_climber_skill

