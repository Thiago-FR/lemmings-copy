extends "res://tests/campaign_playthrough_test.gd"
## Plays any generated campaign level with its recorded solution, the level
## number given after "--" (the campaign builder runs it on every level it
## makes):
##   godot --headless --path . res://tests/test_campaign_level.tscn -- <level number>


func _get_level_number() -> int:
	var args := OS.get_cmdline_user_args()
	return int(args[0]) if args.size() > 0 else 1


func _play_frame() -> void:
	play_recorded_solution()
