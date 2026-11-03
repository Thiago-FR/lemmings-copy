extends SceneTree
## Prints how the solver sees one raw generated stage (no retries): where
## the first walk goes and why the search gives up.
##   godot --headless --path . --script res://tools/debug_stage.gd -- <stage number> [attempt seed]

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var index := int(args[0]) - 1
	var biome := BiomeStageGenerator.biome_of(index)
	var tier := BiomeStageGenerator.tier_of(index)
	var generator := BiomeStageGenerator.new()
	var data: MazeStageData = generator._generate(int(args[1]) if args.size() > 1 else 7, biome, tier, BiomeStageGenerator.stage_size(index, biome.shapes[tier]), 0.3)
	print("spawn ", data.spawn_cell, " exit ", data.exit_cell, " size ", data.columns, "x", data.rows, " spans ", generator._spans_stage())
	var solver := CellStageSolver.new()
	solver._load(data, [])
	solver._unlimited = true
	solver._allowed.assign(BiomeStageGenerator.SOLUTION_TOOLS)
	var start := solver._start_state()
	var walk := solver._walk(start)
	var trail := PackedStringArray()
	for point in walk.points:
		trail.append("%d,%d" % [point.column, point.feet / 4])
	print("first walk: ", walk.end, " ", walk.points.size(), " points: ", " ".join(trail.slice(0, 60)))
	var result := solver._search()
	print("search: ", result.get("solved"), " ", result.get("reason", ""), " ", result.get("best", ""))
	# The grid around the spawn, '#' earth, '%' concrete, '=' brick/ramp, 'S' spawn, 'E' exit.
	for row in range(0, data.rows):
		var line := ""
		for column in range(0, data.columns):
			var c := Vector2i(column, row)
			if c == data.spawn_cell: line += "S"
			elif c == data.exit_cell: line += "E"
			else:
				var kind := data.cell_at(column, row)
				line += "#" if kind == MazeLayout.EARTH else ("%" if kind == MazeLayout.CONCRETE else ".")
		print(line)
	quit(0)
