extends "res://tests/campaign_playthrough_test.gd"
## Plays campaign level 9, "Rede de Segurança", with a scripted solution. Run via:
##   godot --headless res://tests/test_campaign_09.tscn
##
## A pioneer with claws and a parachute climbs the rock, floats down the
## shaft and puts up the ladder; then a pickaxe opens the rock.


func _get_level_number() -> int:
	return 9


func _play_frame() -> void:
	give_once("claws for the pioneer", "climber", walking_in(8, 18, 1, 30))
	if is_done("claws for the pioneer"):
		give_once("parachute for the pioneer", "floater", has_claws)
	if is_done("parachute for the pioneer"):
		give_once("ladder for the shaft", "ladder_vertical", both(walking_in(24, 39, 1, 30), has_claws))
	if is_done("ladder for the shaft") and elapsed > _done_steps["ladder for the shaft"] + 12.0:
		give_once("open the rock", "miner", both(walking_in(10, 19, 1, 30), func(l: LemmingController) -> bool: return not l.has_climber_skill))


func has_claws(lemming: LemmingController) -> bool:
	return lemming.has_climber_skill
