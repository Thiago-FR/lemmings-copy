extends "res://tests/campaign_playthrough_test.gd"
## Plays campaign level 15, "Coroa de Fogo", with a scripted solution. Run via:
##   godot --headless res://tests/test_campaign_15.tscn
##
## A block behind the first of each group, bridges over both end pits, the
## charge set by a pioneer alone in the middle, then a pickaxe through each
## block.


func _get_level_number() -> int:
	return 15


func _play_frame() -> void:
	give_once("hold the left group", "block", both(walking_in(21, 26, 1, 11), someone_ahead_of(27, 1)))
	give_once("hold the right group", "block", both(walking_in(53, 58, -1, 11), someone_ahead_of(52, -1)))
	give_once("bridge the left pit", "bridge", walking_in(10, 13, -1, 11))
	give_once("bridge the right pit", "bridge", walking_in(66, 69, 1, 11))
	if is_done("hold the left group") and is_done("hold the right group"):
		give_once("charge in the middle", "dynamite", both(walking_in(35, 44, 0, 11), alone_within(120.0)))
	if is_done("charge in the middle") and elapsed > _done_steps["charge in the middle"] + 5.0:
		give_once("open the left pen", "miner", walking_in(12, 20, 1, 11))
		give_once("open the right pen", "miner", walking_in(59, 67, -1, 11))
