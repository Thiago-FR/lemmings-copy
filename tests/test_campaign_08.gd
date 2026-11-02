extends "res://tests/campaign_playthrough_test.gd"
## Plays campaign level 8, "A Espera", with a scripted solution. Run via:
##   godot --headless res://tests/test_campaign_08.tscn
##
## The first goes ahead; a block behind him holds the rest; he sets the
## charge far from them; once it has blown, a pickaxe opens the block.


func _get_level_number() -> int:
	return 8


func _play_frame() -> void:
	give_once("hold the rest", "block", both(walking_in(9, 12, 1, 22), someone_ahead_of(15, 1)))
	if is_done("hold the rest"):
		give_once("charge at the far end", "dynamite", walking_in(30, 30, 1, 22))
	if is_done("charge at the far end") and elapsed > _done_steps["charge at the far end"] + 5.0:
		give_once("open the block", "miner", walking_in(3, 9, 1, 22))
