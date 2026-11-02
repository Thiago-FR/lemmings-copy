extends "res://modes/roguelike/tests/stage_playthrough_test.gd"
## Generated stages whose solutions bridge troughs, and a small drawn maze
## where the only way on is to fall into a trough and climb out of it with a
## one-piece ladder (the generator's solutions prefer the bridge, so this
## link is played here on purpose). Run via:
##   godot --headless res://modes/roguelike/tests/test_procedural_play_4.tscn


func _get_scenarios() -> Array[Dictionary]:
	return [
		{"source": "procedural", "stage_index": 3, "seed": 2, "troop": "single"},
		{"source": "procedural", "stage_index": 2, "seed": 13, "troop": "single"},
		_trough_ladder_scenario(),
	]


func _trough_ladder_scenario() -> Dictionary:
	var layout := MazeLayout.new()
	layout.add_open(0, 0)
	var bridge := layout.add_trough(1, 0, 1, 2)
	layout.spawn_room = MazeLayout.room_id(0, 0)
	layout.exit_room = MazeLayout.room_id(2, 0)
	for room in 3:
		layout.reachable_rooms[room] = 0
	var rng := RandomNumberGenerator.new()
	# Painted directly: the solver would refuse it, since the ladder is in the
	# bar from the start rather than lying in the stage.
	var maze := MazeStageGenerator._make_data(layout, rng, 0)
	var definition := RoguelikeStageFactory._from_maze(maze, rng, "Fosso")
	var link := layout.get_link(bridge)
	var plan: Array[Dictionary] = [{
		"tool": "ladder_vertical", "from_column": link.trough_first, "to_column": link.trough_last,
		"row": MazeLayout.floor_row(0) + 1, "direction": 1, "why": "ladder out of the trough", "collect_first": [],
	}]
	return {"source": "custom", "stage_index": 0, "seed": 0, "troop": "single", "definition": definition, "plan": plan, "bar": {"ladder_vertical": 1}}
