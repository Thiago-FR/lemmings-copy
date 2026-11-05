extends SceneTree
## Checks hand-made campaign levels (tools/campaign/level_NN.gd) with the
## solver before they are written into the game:
## - that walking with no tool never reaches the exit;
## - the shortest way the solver finds with the level's kinds of tools (with
##   no limit on charges): far fewer tools than the intended solution means
##   the puzzle has a shortcut;
## - that the recorded solution, followed by the solver, ends at the exit.
## The solver is a model; the robot in the real game
## (tests/test_campaign_level.tscn) has the last word. Run:
##   godot --headless --path . --script res://tools/check_handmade_level.gd -- <level numbers...>

const LEVEL_SCRIPT := "res://tools/campaign/level_%02d.gd"


func _init() -> void:
	var failed := 0
	for arg in OS.get_cmdline_user_args():
		if not _check(int(arg)):
			failed += 1
	quit(1 if failed > 0 else 0)


func _check(number: int) -> bool:
	var path := LEVEL_SCRIPT % number
	if not ResourceLoader.exists(path):
		print("%02d: no %s" % [number, path])
		return false
	var level: HandmadeLevel = load(path).new()
	var maze := level.build()
	var ok := true
	var bare := CellStageSolver.solve_unlimited(maze, [] as Array[String])
	if bare.solved:
		print("%02d %s: PROBLEM, the exit is reached with no tool at all" % [number, level.level_name])
		ok = false
	var kinds: Array[String] = []
	kinds.assign(level.tools.keys())
	var shortest := CellStageSolver.solve_unlimited(maze, kinds)
	var followed := CellStageSolver.follow(maze, level.solution)
	var recorded_ends_out: bool = followed.steps_used == level.solution.size() and followed.end == "exit"
	print("%02d %s: tools %s, recorded %d steps -> %s; shortest found: %s" % [number, level.level_name, level.tools,
		level.solution.size(), "exit" if recorded_ends_out else "'%s' after %d steps" % [followed.end, followed.steps_used],
		_describe(shortest)])
	return ok


func _describe(result: Dictionary) -> String:
	if not result.solved:
		return "none"
	var moves := PackedStringArray()
	for step in result.steps:
		moves.append("%s@%d,%d%s" % [step.tool, step.column, step.row, ">" if int(step.direction) > 0 else "<"])
	return "%d: %s" % [moves.size(), " ".join(moves)]
