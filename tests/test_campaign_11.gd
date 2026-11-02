extends "res://tests/campaign_playthrough_test.gd"
## Plays campaign level 11, "Só Pontes", with a scripted solution. Run via:
##   godot --headless res://tests/test_campaign_11.tscn
##
## A bridge to the cliff turns them back; the first back at the gap bridges
## it and walks off the end; one walking on that bridge carries the third.


func _get_level_number() -> int:
	return 11


func _play_frame() -> void:
	give_once("bridge to the cliff", "bridge", walking_in(41, 46, 1, 26))
	if is_done("bridge to the cliff"):
		give_once("first bridge over the gap", "bridge", walking_in(32, 34, -1, 26))
	# Only once the first bridge is finished and its builder has walked off
	# the end: given earlier, the carrier would start a second bridge at the
	# unfinished end, beside the first builder.
	if is_done("first bridge over the gap") and elapsed > _done_steps["first bridge over the gap"] + 8.0:
		give_once("second bridge, carried", "bridge", both(walking_in(21, 31, -1, 26), func(l: LemmingController) -> bool: return not someone_ahead_of(21, -1).call(l)))
