extends "res://tests/campaign_playthrough_test.gd"
## Plays campaign level 5, "Garras ao Vento", with a scripted solution. Run via:
##   godot --headless res://tests/test_campaign_05.tscn
##
## Claws for everyone walking towards the mesa, then a parachute (a
## climbing lemming cannot take one, so it is given right after the claws).


func _get_level_number() -> int:
	return 5


func _play_frame() -> void:
	give_each("climber", walking_in(1, 29, 1, 30))
	give_each("floater", both(walking_in(1, 40), has_claws))


func has_claws(lemming: LemmingController) -> bool:
	return lemming.has_climber_skill
