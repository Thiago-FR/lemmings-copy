extends SceneTree
## Prints a campaign level's cells as text, with its solution:
##   godot --headless --path . --script res://tools/print_campaign_level.gd -- <level number> [first column] [last column] [first row] [last row]
## '#' earth, '%' concrete, '/' a cell holding a soil ramp, '=' a brick,
## 'H' a ladder, 'S' entrance, 'E' exit, '1'-'9' where each solution step
## hands its tool over (on the row above its floor).

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var index := int(args[0]) - 1
	var maze := LevelDrawing.maze_from_dictionary(CampaignLevelStore.read(index))
	var first_column := int(args[1]) if args.size() > 1 else 0
	var last_column := int(args[2]) if args.size() > 2 else maze.columns - 1
	var first_row := int(args[3]) if args.size() > 3 else 0
	var last_row := int(args[4]) if args.size() > 4 else maze.rows - 1
	print("spawn ", maze.spawn_cell, " exit ", maze.exit_cell, " size ", maze.columns, "x", maze.rows)
	for step_index in maze.solution.size():
		var step: Dictionary = maze.solution[step_index]
		print("step %d: %s at columns %d-%d, floor row %d, facing %d" % [step_index + 1, step.tool, step.from_column, step.to_column, step.row, step.get("direction", 0)])
	var marks := {}
	var tile := float(Constants.TERRAIN_TILE_SIZE)
	for ramp in maze.ramps:
		marks[Vector2i(floori(ramp.position.x / tile), floori(ramp.position.y / tile))] = "/"
	for brick in maze.bricks:
		marks[Vector2i(floori(brick.position.x / tile), floori(brick.position.y / tile))] = "="
	for ladder in maze.ladders:
		marks[ladder] = "H"
	for step_index in maze.solution.size():
		var step: Dictionary = maze.solution[step_index]
		marks[Vector2i(int(step.from_column), int(step.row) - 1)] = str((step_index + 1) % 10)
	var header := "    "
	for column in range(first_column, last_column + 1):
		header += str(column % 10)
	print(header)
	for row in range(first_row, last_row + 1):
		var line := ""
		for column in range(first_column, last_column + 1):
			var cell := Vector2i(column, row)
			if cell == maze.spawn_cell: line += "S"
			elif cell == maze.exit_cell: line += "E"
			elif marks.has(cell): line += marks[cell]
			else:
				var kind := maze.cell_at(column, row)
				line += "#" if kind == MazeLayout.EARTH else ("%" if kind == MazeLayout.CONCRETE else ".")
		print("%03d " % row + line)
	quit(0)
