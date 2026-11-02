extends "res://modes/roguelike/tests/stage_playthrough_test.gd"
## Plays generated roguelike stages (run seed, stage index) end to end with
## a scripted bot following each stage's recorded solution. Run via:
##   godot --headless res://modes/roguelike/tests/test_procedural_play_2.tscn


func _get_scenarios() -> Array[Dictionary]:
	return [
		{"source": "procedural", "stage_index": 3, "seed": 11, "troop": "single"},
		{"source": "procedural", "stage_index": 4, "seed": 11, "troop": "single"},
		{"source": "procedural", "stage_index": 1, "seed": 23, "troop": "full"},
	]
