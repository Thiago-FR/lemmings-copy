extends "res://tests/campaign_playthrough_test.gd"
## A naive solution of campaign level 15, "Coroa de Fogo", that must NOT win (the
## puzzle would be trivial if it did). Run via:
##   godot --headless res://tests/test_campaign_15_naive.tscn
##
## Both pits bridged, and the charge set in the middle without holding
## anyone back: the blast takes too many.


func _get_level_number() -> int:
	return 15


func _expects_win() -> bool:
	return false


func _play_frame() -> void:
	give_once("bridge the left pit", "bridge", walking_in(10, 13, -1, 11))
	give_once("bridge the right pit", "bridge", walking_in(66, 69, 1, 11))
	if is_done("bridge the left pit") and is_done("bridge the right pit"):
		give_once("charge in the middle", "dynamite", both(walking_in(38, 41, 0, 11), alone_within(60.0)))
