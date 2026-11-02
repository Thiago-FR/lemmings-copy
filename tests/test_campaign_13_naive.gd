extends "res://tests/campaign_playthrough_test.gd"
## A naive solution of campaign level 13, "Beiço de Lava", that must NOT win (the
## puzzle would be trivial if it did). Run via:
##   godot --headless res://tests/test_campaign_13_naive.tscn
##
## The staircase to the cliff to turn them back, the bridge over the channel
## and a ladder up the shelf: the lip stops the ladder.


func _get_level_number() -> int:
	return 13


func _expects_win() -> bool:
	return false


func _play_frame() -> void:
	give_once("staircase to the cliff", "builder", walking_in(40, 44, 1, 26))
	if is_done("staircase to the cliff"):
		give_once("bridge the channel", "bridge", walking_in(30, 31, -1, 26))
	if is_done("bridge the channel"):
		give_each("ladder_vertical", walking_in(23, 29, -1, 26))
