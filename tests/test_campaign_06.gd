extends "res://tests/campaign_playthrough_test.gd"
## Plays campaign level 6, "Labirinto das Dunas", with a scripted solution. Run via:
##   godot --headless res://tests/test_campaign_06.tscn
##
## Turn them back at once, towards the hole behind the entrance; turn them
## once more in the tunnel before the last pit.


func _get_level_number() -> int:
	return 6


func _play_frame() -> void:
	give_once("turn back at the entrance", "block", walking_in(14, 22, 1, 16))
	if is_done("turn back at the entrance"):
		give_once("turn before the last pit", "block", walking_in(42, 56, 1, 22))
