extends "res://tests/campaign_playthrough_test.gd"
## A naive solution of campaign level 10, "Contra o Relógio", that must NOT win (the
## puzzle would be trivial if it did). Run via:
##   godot --headless res://tests/test_campaign_10_naive.tscn
##
## Two shafts where they walk, in the first and the third tunnel: they land
## walking the long way and save no time.


func _get_level_number() -> int:
	return 10


func _expects_win() -> bool:
	return false


func _play_frame() -> void:
	give_once("shaft in the first tunnel", "digger", walking_in(30, 30, -1, 12))
	give_once("shaft in the third tunnel", "digger", walking_in(30, 30, -1, 16))
