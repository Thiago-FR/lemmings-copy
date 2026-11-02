extends "res://tests/campaign_playthrough_test.gd"
## A naive solution of campaign level 14, "Veios de Obsidiana", that must NOT win (the
## puzzle would be trivial if it did). Run via:
##   godot --headless res://tests/test_campaign_14_naive.tscn
##
## Digging straight down into the first hollow: the drop kills.


func _get_level_number() -> int:
	return 14


func _expects_win() -> bool:
	return false


func _play_frame() -> void:
	give_once("shaft into the first hollow", "digger", walking_in(47, 47, 1, 9))
