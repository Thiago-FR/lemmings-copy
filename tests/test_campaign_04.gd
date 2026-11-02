extends "res://tests/campaign_playthrough_test.gd"
## Plays campaign level 4, "Escadaria das Dunas", with a scripted solution. Run via:
##   godot --headless res://tests/test_campaign_04.tscn
##
## A staircase begun 9 to 12 blocks before each terrace's wall.


func _get_level_number() -> int:
	return 4


func _play_frame() -> void:
	give_once("first staircase", "builder", walking_in(18, 19, 1, 30))
	if is_done("first staircase"):
		give_once("second staircase", "builder", walking_in(42, 43, 1, 27))
