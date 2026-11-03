extends SceneTree
## Prints a campaign level's cells as text, with its solution:
##   godot --headless --path . --script res://tools/print_campaign_level.gd -- <level number>

func _init() -> void:
	var index := int(OS.get_cmdline_user_args()[0]) - 1
	var maze := LevelDrawing.maze_from_dictionary(CampaignLevelStore.read(index))
	print("spawn ", maze.spawn_cell, " exit ", maze.exit_cell, " solution ", maze.solution)
	print("ramps ", maze.ramps.size())
	var result := CellStageSolver.solve_unlimited(maze, BiomeStageGenerator.SOLUTION_TOOLS)
	var trail := PackedStringArray()
	for point: Vector3i in result.get("path", []):
		trail.append("%d,%.2f" % [point.x, point.y / 4.0])
	print("solved ", result.solved, " steps ", result.get("steps", []))
	print("path ", " ".join(trail))
	for row in maze.rows:
		var line := ""
		for column in maze.columns:
			var cell := Vector2i(column, row)
			if cell == maze.spawn_cell: line += "S"
			elif cell == maze.exit_cell: line += "E"
			else:
				var kind := maze.cell_at(column, row)
				line += "#" if kind == MazeLayout.EARTH else ("%" if kind == MazeLayout.CONCRETE else ".")
		print("%02d " % row + line)
	quit(0)
