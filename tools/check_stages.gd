extends SceneTree
## Generates every roguelike stage (each one checked winnable by
## CellStageSolver, drawn again until it is) and prints how long it took,
## whether a solution was found and which tools it uses:
##   godot --headless --path . --script res://tools/check_stages.gd -- [seed] [first] [last]

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var seed_value := int(args[0]) if args.size() > 0 else 1
	var first := int(args[1]) if args.size() > 1 else 1
	var last := int(args[2]) if args.size() > 2 else BiomeStageGenerator.stage_count()
	var failed := 0
	for number in range(first, last + 1):
		var started := Time.get_ticks_msec()
		var data := BiomeStageGenerator.generate(seed_value, number - 1)
		var moves := PackedStringArray()
		for step in data.solution:
			moves.append("%s@%d,%d" % [step.tool, step.from_column, step.row])
		if data.solution.is_empty():
			failed += 1
			for reason in BiomeStageGenerator.last_report:
				print("    ", reason)
		print("%02d %s %dx%d %dms %s time %ds: %s" % [number, data.stage_name, data.columns, data.rows,
			Time.get_ticks_msec() - started, "OK" if not data.solution.is_empty() else "NO SOLUTION",
			data.suggested_time_seconds, " ".join(moves)])
	print("%d without a solution" % failed)
	quit(1 if failed > 0 else 0)
