extends Node
## Checks the exit of every environment map (tools/campaign/ambientes/):
## the doorway's two cells above the floor are open, the floor under it is
## solid, and the troop can reach it at all (solver with endless tools).
## Run:
##   godot --headless --path . res://tools/check_ambient_exits.tscn -- [map numbers...]

const AmbientCampaign := preload("res://tools/build_ambient_campaign.gd")
const MAP_COUNT := 30
## The doorway is 48px tall: two cells above the floor row must be air.
const DOORWAY_CELLS := 2


func _ready() -> void:
	var numbers: Array[int] = []
	for arg in OS.get_cmdline_user_args():
		numbers.append(int(arg))
	if numbers.is_empty():
		for number in range(1, MAP_COUNT + 1):
			numbers.append(number)
	var bad := 0
	for number in numbers:
		if not _check(number):
			bad += 1
	print("%d of %d maps with an exit problem" % [bad, numbers.size()])
	get_tree().quit(1 if bad > 0 else 0)


func _check(number: int) -> bool:
	var maze := AmbientCampaign.load_map(number)
	var exit := maze.exit_cell
	var problems: Array[String] = []
	if not maze.is_solid(exit.x, exit.y):
		problems.append("no floor under it")
	for height in range(1, DOORWAY_CELLS + 1):
		if maze.is_solid(exit.x, exit.y - height):
			problems.append("cell %d above the floor is %s" % [height, "concrete" if maze.cell_at(exit.x, exit.y - height) == MazeLayout.CONCRETE else "earth"])
	if maze.unbreakable.has(exit) or exit.y >= maze.rows - 1:
		problems.append("stands on the border")
	var reach := CellStageSolver.solve_unlimited(maze, CellStageSolver.TOOLS)
	if not reach.solved:
		problems.append("unreachable even with endless tools")
	var level := AmbientCampaign.FIRST_LEVEL_INDEX + number
	print("level %02d map %02d %-22s exit %s rows %d: %s" % [level, number, maze.stage_name, exit, maze.rows, "ok" if problems.is_empty() else ", ".join(problems)])
	return problems.is_empty()
