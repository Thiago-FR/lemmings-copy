extends "res://tests/campaign_playthrough_test.gd"
## Plays campaign level 14, "Veios de Obsidiana", with a scripted solution. Run via:
##   godot --headless res://tests/test_campaign_14.tscn
##
## Onto the first vein, a tunnel right to the first hollow, onto the second
## vein, a tunnel left to the second hollow, down into the third, a tunnel
## right to the exit.


func _get_level_number() -> int:
	return 14


func _play_frame() -> void:
	give_once("onto the first vein", "digger", walking_in(26, 34, 1, 9))
	if is_done("onto the first vein"):
		give_once("tunnel to the first hollow", "miner", walking_in(22, 38, 1, 11))
	if is_done("tunnel to the first hollow"):
		give_once("onto the second vein", "digger", walking_in(46, 50, 0, 13))
	if is_done("onto the second vein"):
		give_once("tunnel to the second hollow", "miner", walking_in(44, 52, -1, 15))
	if is_done("tunnel to the second hollow"):
		give_once("down into the third hollow", "digger", walking_in(35, 36, 0, 16))
	if is_done("down into the third hollow"):
		give_once("tunnel to the exit", "miner", walking_in(36, 45, 1, 18))
