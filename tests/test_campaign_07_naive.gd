extends "res://tests/campaign_playthrough_test.gd"
## A naive solution of campaign level 7, "Câmaras de Cristal", that must NOT win (the
## puzzle would be trivial if it did). Run via:
##   godot --headless res://tests/test_campaign_07_naive.tscn
##
## The pickaxe into the wall they walk into, a shovel in the second room and
## the dynamite against the last wall: it is two blocks thick.


func _get_level_number() -> int:
	return 7


func _expects_win() -> bool:
	return false


func _play_frame() -> void:
	give_once("pickaxe into the first wall", "miner", walking_in(12, 21, 1, 18))
	give_once("shaft in the second room", "digger", walking_in(32, 44, 0, 18))
	give_once("dynamite against the last wall", "dynamite", walking_in(46, 46, 1, 20))
