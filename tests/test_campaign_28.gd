extends "res://tests/campaign_playthrough_test.gd"
## Plays campaign level 28, the first of its biome, with the solution the
## generator recorded for it. Run via:
##   godot --headless res://tests/test_campaign_28.tscn


func _get_level_number() -> int:
	return 28


func _play_frame() -> void:
	play_recorded_solution()
