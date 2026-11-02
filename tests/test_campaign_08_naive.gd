extends "res://tests/campaign_playthrough_test.gd"
## A naive solution of campaign level 8, "A Espera", that must NOT win (the
## puzzle would be trivial if it did). Run via:
##   godot --headless res://tests/test_campaign_08_naive.tscn
##
## The charge at the far end without holding the others back: the blast
## takes some of them, and every lemming is needed.


func _get_level_number() -> int:
	return 8


func _expects_win() -> bool:
	return false


func _play_frame() -> void:
	give_once("charge at the far end", "dynamite", walking_in(30, 30, 1, 22))
