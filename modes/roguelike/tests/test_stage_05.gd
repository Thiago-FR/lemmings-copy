extends "res://modes/roguelike/tests/stage_playthrough_test.gd"
## Plays hand-made roguelike stage 5 end to end with a scripted bot, alone
## with a full bar and with the whole troop. Run via:
##   godot --headless res://modes/roguelike/tests/test_stage_05.tscn


func _get_scenarios() -> Array[Dictionary]:
	return handmade_scenarios(4)
