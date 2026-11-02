extends "res://tests/campaign_playthrough_test.gd"
## A naive solution of campaign level 6, "Labirinto das Dunas", that must NOT win (the
## puzzle would be trivial if it did). Run via:
##   godot --headless res://tests/test_campaign_06_naive.tscn
##
## Turning them back at each pit as they reach it: the branch they fall
## into needs three turns and there are two blocks.


func _get_level_number() -> int:
	return 6


func _expects_win() -> bool:
	return false


func _play_frame() -> void:
	give_once("turn before the first pit", "block", walking_in(55, 63, 1, 18))
	if is_done("turn before the first pit"):
		give_once("turn before the second pit", "block", walking_in(9, 14, -1, 20))
