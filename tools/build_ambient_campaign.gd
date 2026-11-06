extends Node
## Writes the environment levels into the campaign: the 30 maps in
## prints/ambientes, frozen as text in tools/campaign/ambientes/ (taken from
## commit e6f9df0 with seed 1, before the generator changed), become
## campaign levels 4 to 33, after the three tutorial levels. Run:
##   godot --headless --path . res://tools/build_ambient_campaign.tscn -- <map numbers 1..30...>
##
## Each level keeps its map, looks, items and recorded solution. Its tools
## come from items (LevelData.tools_from_items): it starts with the first
## tool its solution uses, the one to get going, and the rest is picked up
## on the way. The maps' surprise spots (the roguelike's bonus items) hold
## a tool more often than not, an hourglass or a bag otherwise: "vai da
## sorte de sair o que precisa".

const MAP_FILE := "res://tools/campaign/ambientes/ambiente_%02d.txt"
## The tutorial comes first.
const FIRST_LEVEL_INDEX := 3
## More lemmings on a bigger map, in fives: about one per 100 cells.
const CELLS_PER_LEMMING := 100
const MIN_LEMMINGS := 15
const MAX_LEMMINGS := 60
const SPAWN_SECONDS := 1.5
const GOAL := 0.3
const PERSONAL_TOOLS: Array[String] = ["floater", "climber"]
## The tools that make a way everyone behind can walk.
const TROOP_TOOLS: Array[String] = ["digger", "builder", "bridge", "basher", "miner", "ladder_vertical"]
## A surprise spot: a tool below this roll, then a bag, then an hourglass.
const SURPRISE_TOOL_CHANCE := 0.6
const SURPRISE_BAG_CHANCE := 0.75
const SURPRISE_TOOLS: Array[String] = ["digger", "ladder_vertical", "bridge", "miner", "basher", "builder"]
const HOURGLASS_SECONDS := 60
## Steps of a map's recorded solution corrected for the real game (the
## generator's model of the walk was looser than the game when these maps
## were made): map number -> {step index: replacement step}. The maps
## themselves are never changed.
const SOLUTION_FIXES := {
	# The shovel on the staircase at column 53 drops the digger 2.75 blocks
	# and kills it; at column 52 it drops straight into the exit.
	2: {3: {"tool": "digger", "from_column": 52, "to_column": 52, "row": 12, "direction": -1}},
	# The ladder for the wall under the exit was recorded where the bridge
	# starts; the lemming is bridging there, never walking. Handed out past
	# the bridge it is carried to that wall.
	3: {5: {"tool": "ladder_vertical", "from_column": 47, "to_column": 49, "row": 16, "direction": 1}},
}

## The exit doorway is 48px tall: two cells of air above its floor.
const EXIT_DOORWAY_CELLS := 2
const MAX_EXIT_TRIES := 12
const EXIT_ROW_WEIGHT := 3
## The entrance is raised when the exit is less than a third of the map
## below it; the hatch needs three cells of air.
const RAISED_SHARE := 3
const ENTRANCE_AIR_CELLS := 3
const MAX_ENTRANCE_TRIES := 8
const ENTRANCE_TRY_SPACING := 8.0

const FIELDS := ["columns", "rows", "cells", "ladders", "bricks", "ramps", "spawn_cell", "exit_cell",
	"item_spots", "solution", "environment_kind", "suggested_time_seconds", "skins", "backdrop",
	"inside_wall", "decor_trees", "rooms", "unbreakable", "spawn_faces_left", "stage_name"]


func _ready() -> void:
	var failed := 0
	for arg in OS.get_cmdline_user_args():
		if not _build(int(arg)):
			failed += 1
	get_tree().quit(1 if failed > 0 else 0)


func _build(number: int) -> bool:
	var maze := load_map(number)
	if maze == null:
		return false
	var own_spawn := maze.spawn_cell
	var own_exit := maze.exit_cell
	var own_cells := maze.cells.duplicate()
	_free_exit(maze, number)
	_raise_entrance(maze, number)
	# Only a map whose entrance or exit moved needs more tools; the others
	# keep their items and recorded solution (and its hand fixes).
	var moved := maze.spawn_cell != own_spawn or maze.exit_cell != own_exit or maze.cells != own_cells
	# A map with hand fixes was checked in the game with its own solution.
	if moved or (not SOLUTION_FIXES.has(number) and not _wins_as_it_is(maze)):
		_supply_route(maze, number)
	_fix_solution(maze, number)
	_ground_spots(maze, number)
	var items := _items_of(maze, number)
	var start := _starting_tools(maze)
	for tool_id in start:
		_take_nearest(items, tool_id, maze.spawn_cell)
	var index := FIRST_LEVEL_INDEX + number - 1
	var lemmings := _troop_of(maze)
	# With the parachute or the claws on the way, only the one given it gets
	# through: one lemming, however big the troop.
	var personal := maze.solution.any(func(step: Dictionary) -> bool: return PERSONAL_TOOLS.has(str(step.tool)))
	# (A hair under, so the saved share read back from the file still counts.)
	var goal := 0.999 / lemmings if personal else GOAL
	# The last ones out still need the map's time to get through.
	maze.suggested_time_seconds += roundi(lemmings * SPAWN_SECONDS)
	if not CampaignLevelStore.create_level(index, maze, lemmings, SPAWN_SECONDS, start, goal, items):
		return false
	print("%02d (map %02d) %s: %dx%d, %d lemmings, starts with %s, %d items, %d steps, %d%%" % [index + 1, number, maze.stage_name,
		maze.columns, maze.rows, lemmings, start, items.size(), maze.solution.size(), roundi(goal * 100.0)])
	return true


## The recorded solution reaches the exit, or the solver finds a way with the
## map's own items.
static func _wins_as_it_is(maze: MazeStageData) -> bool:
	var followed := CellStageSolver.follow(maze, maze.solution)
	if followed.end == "exit" and followed.steps_used >= maze.solution.size():
		return true
	return CellStageSolver.solve(maze).solved


static func _troop_of(maze: MazeStageData) -> int:
	var by_size := snappedi(maze.columns * maze.rows / CELLS_PER_LEMMING, 5)
	return clampi(by_size, MIN_LEMMINGS, MAX_LEMMINGS)


## A frozen map as stage data.
static func load_map(number: int) -> MazeStageData:
	var path := MAP_FILE % number
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("No map %s" % path)
		return null
	var data: Dictionary = str_to_var(file.get_as_text())
	var maze := MazeStageData.new()
	for field in FIELDS:
		maze.set(field, data[field])
	return maze


## Some maps came with the exit buried in the ground (the doorway's cells
## earth or concrete, sometimes on the border itself): no portal shows and
## nobody gets out. The exit moves to the nearest place it fits (solid floor,
## the doorway's cells open, not the bottom border) that the troop can reach;
## the terrain stays as it is.
static func _free_exit(maze: MazeStageData, number: int) -> void:
	if _exit_fits(maze, maze.exit_cell):
		return
	var candidates: Array[Vector2i] = []
	for row in range(1, maze.rows - 1):
		for column in range(1, maze.columns - 1):
			if _exit_fits(maze, Vector2i(column, row)):
				candidates.append(Vector2i(column, row))
	var buried := maze.exit_cell
	candidates.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return Vector2(a).distance_squared_to(buried) < Vector2(b).distance_squared_to(buried))
	# Each try is a full search; past the nearest few the map needs a look.
	for cell in candidates.slice(0, MAX_EXIT_TRIES):
		maze.exit_cell = cell
		if CellStageSolver.solve_unlimited(maze, CellStageSolver.TOOLS, [], true).solved:
			print("   map %02d: exit buried at %s, moved to %s" % [number, buried, cell])
			return
	# No open place near is reached: the doorway is dug out where it was, so
	# the portal shows; the way there is dug too.
	maze.exit_cell = buried
	for height in range(1, EXIT_DOORWAY_CELLS + 1):
		maze.cells[(buried.y - height) * maze.columns + buried.x] = MazeLayout.EMPTY
	print("   map %02d: exit buried at %s, its doorway dug out there" % [number, buried])


## The maps came with the exit level with the entrance more often than not:
## on a huge tall cave the way was to walk straight on ("pra q um mapa
## gigante e alto e a saida e so ir reto?"). No tool makes a way up through
## rock, so the exit cannot go up; the entrance goes up instead, on the far
## side from the exit, and the troop has to dig, break and bridge its way
## down. Tried on the highest, farthest places first, the first one the
## solver gets down from wins.
static func _raise_entrance(maze: MazeStageData, number: int) -> void:
	var exit := maze.exit_cell
	if exit.y - maze.spawn_cell.y >= maze.rows / RAISED_SHARE:
		return
	var candidates: Array[Vector2i] = []
	for row in range(ENTRANCE_AIR_CELLS + 1, exit.y - maze.rows / RAISED_SHARE + 1):
		for column in range(1, maze.columns - 1):
			var cell := Vector2i(column, row)
			if _has_room(maze, cell, ENTRANCE_AIR_CELLS):
				candidates.append(cell)
	candidates.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return _drop_score(exit, a) > _drop_score(exit, b))
	var own := maze.spawn_cell
	var own_facing := maze.spawn_faces_left
	var tried: Array[Vector2i] = []
	for cell in candidates:
		if tried.size() >= MAX_ENTRANCE_TRIES:
			break
		if tried.any(func(other: Vector2i) -> bool: return Vector2(other).distance_to(cell) < ENTRANCE_TRY_SPACING):
			continue
		tried.append(cell)
		maze.spawn_cell = cell
		maze.spawn_faces_left = exit.x < cell.x
		if CellStageSolver.solve_unlimited(maze, TROOP_TOOLS, [], true).solved:
			print("   map %02d: entrance %s raised to %s" % [number, own, cell])
			return
	maze.spawn_cell = own
	maze.spawn_faces_left = own_facing
	print("   map %02d: no higher entrance gets down (tried %s)" % [number, tried])


## A climb down and a walk across from the entrance to the exit, the drop
## counting more.
static func _drop_score(exit: Vector2i, cell: Vector2i) -> int:
	return absi(cell.x - exit.x) + EXIT_ROW_WEIGHT * (exit.y - cell.y)


## Solid floor under the cell and `air` open cells above it.
static func _has_room(maze: MazeStageData, cell: Vector2i, air: int) -> bool:
	if cell.y >= maze.rows - 1 or not maze.is_solid(cell.x, cell.y):
		return false
	for height in range(1, air + 1):
		if maze.is_solid(cell.x, cell.y - height):
			return false
	return true


## With the exit moved, the map's tools may no longer reach it. The solver
## finds a way with endless tools; each charge of it the map lacks lies
## where it is used. If the troop still cannot finish, every tool of that
## way lies there.
static func _supply_route(maze: MazeStageData, number: int) -> void:
	if CellStageSolver.solve(maze, [], true).solved:
		return
	# A way the whole troop can follow first, one for the personal tools'
	# holders only if there is no other.
	var route := CellStageSolver.solve_unlimited(maze, TROOP_TOOLS, [], true)
	if not route.solved:
		route = CellStageSolver.solve_unlimited(maze, CellStageSolver.TOOLS, [], true)
	if not route.solved:
		route = CellStageSolver.solve_unlimited(maze, CellStageSolver.TOOLS)
	if not route.solved:
		push_error("Map %02d: the exit cannot be reached at all" % number)
		return
	var original := maze.item_spots.duplicate(true)
	var on_map := {}
	for spot in maze.item_spots:
		if spot.kind == MazeLayout.SpotKind.TOOL:
			on_map[spot.tool_id] = int(on_map.get(spot.tool_id, 0)) + int(spot.amount)
	for step: Dictionary in route.steps:
		var tool_id := str(step.tool)
		if int(on_map.get(tool_id, 0)) > 0:
			on_map[tool_id] = int(on_map[tool_id]) - 1
		else:
			_lay_tool_at(maze, step, route.path)
	if CellStageSolver.solve(maze, [], true).solved:
		print("   map %02d: tools added where the new way uses them" % number)
		return
	maze.item_spots = original
	for step: Dictionary in route.steps:
		_lay_tool_at(maze, step, route.path)
	print("   map %02d: every tool of the new way laid where it is used, solved: %s" % [number, CellStageSolver.solve(maze, [], true).solved])


## The charge lies on the way to where it is used, at the last point before
## it where the lemming stands on the map's own ground. Laid where the tool
## is used, it floated (a bridge is given at an edge, a ladder mid-fall) or
## sat inside a block still to be dug (prints/bug20.png).
## Several charges for the same point share one item (more charges);
## different tools there lie side by side (ItemCollector).
static func _lay_tool_at(maze: MazeStageData, step: Dictionary, path: Array) -> void:
	var tool_id := str(step.tool)
	var spot := _standing_point_before(maze, int(step.get("path_index", -1)), path)
	if spot.x < 0:
		spot = Vector2i(int(step.column), roundi(float(step.feet) / CellStageSolver.UNITS_PER_CELL))
	for existing in maze.item_spots:
		if int(existing.column) == spot.x and int(existing.row) == spot.y and existing.kind == MazeLayout.SpotKind.TOOL and str(existing.tool_id) == tool_id:
			existing.amount = int(existing.amount) + 1
			return
	maze.item_spots.append({"column": spot.x, "row": spot.y,
		"kind": MazeLayout.SpotKind.TOOL, "tool_id": tool_id, "amount": 1, "required": true, "spot_index": -1})


## Column and floor row of the last point of the walk up to `index` where
## the body stands on solid ground with open air around it, (-1, -1) if none.
static func _standing_point_before(maze: MazeStageData, index: int, path: Array) -> Vector2i:
	for at in range(mini(index, path.size() - 1), -1, -1):
		var point: Vector3i = path[at]
		if point.y % CellStageSolver.UNITS_PER_CELL != 0:
			continue
		var row := point.y / CellStageSolver.UNITS_PER_CELL
		if _stands(maze, Vector2i(point.x, row)):
			return Vector2i(point.x, row)
	return Vector2i(-1, -1)


## Solid floor with open air for the body above it.
static func _stands(maze: MazeStageData, cell: Vector2i) -> bool:
	return maze.is_solid(cell.x, cell.y) and not maze.is_solid(cell.x, cell.y - 1)


## Most rows a spot is moved to reach a floor.
const MAX_GROUNDING_ROWS := 12


## Item spots of the frozen maps that float (no floor under them) or sit in
## a block go down (or up) their column to the nearest floor, as long as
## the troop still gets through with the items where they end up; one that
## would break the way stays and is reported.
static func _ground_spots(maze: MazeStageData, number: int) -> void:
	var solved_before: bool = CellStageSolver.solve(maze, [], true).solved
	for spot in maze.item_spots:
		var cell := Vector2i(int(spot.column), int(spot.row))
		if _stands(maze, cell):
			continue
		var grounded := _nearest_floor(maze, cell)
		if grounded.x < 0:
			print("   map %02d: item at %s has no floor in its column" % [number, cell])
			continue
		spot.row = grounded.y
		if solved_before and not CellStageSolver.solve(maze, [], true).solved:
			spot.row = cell.y
			print("   map %02d: item at %s left floating: on the floor at %s the troop no longer gets through" % [number, cell, grounded])
		else:
			print("   map %02d: item at %s put on the floor at %s" % [number, cell, grounded])


static func _nearest_floor(maze: MazeStageData, cell: Vector2i) -> Vector2i:
	# Inside a block: up to the first open cell. In the air: down to the
	# first floor (where a falling lemming lands).
	var step := -1 if maze.is_solid(cell.x, cell.y - 1) else 1
	for distance in range(1, MAX_GROUNDING_ROWS + 1):
		var candidate := Vector2i(cell.x, cell.y + step * distance)
		if candidate.y <= 0 or candidate.y >= maze.rows:
			break
		if _stands(maze, candidate):
			return candidate
	return Vector2i(-1, -1)


## The doorway needs a solid floor and its two cells above open, and stands
## off the bottom border.
static func _exit_fits(maze: MazeStageData, cell: Vector2i) -> bool:
	return _has_room(maze, cell, EXIT_DOORWAY_CELLS)


## A recorded solution the solver of today no longer follows to the exit
## (it was made with an older, looser one) is solved again, on the same
## map with the same items; then the hand corrections are applied.
static func _fix_solution(maze: MazeStageData, number: int) -> void:
	var followed := CellStageSolver.follow(maze, maze.solution)
	if followed.end != "exit" or followed.steps_used < maze.solution.size():
		var check := CellStageSolver.solve(maze, [], true)
		if not check.solved:
			check = CellStageSolver.solve(maze)
		if check.solved:
			print("   map %02d: recorded solution ends '%s', solved again with %d steps" % [number, followed.end, check.steps.size()])
			maze.solution.clear()
			for step: Dictionary in check.steps:
				maze.solution.append({"tool": step.tool, "from_column": step.column, "to_column": step.column,
					"row": roundi(float(step.feet) / CellStageSolver.UNITS_PER_CELL), "direction": step.direction,
					"why": "", "collect_first": step.collect_first})
		else:
			print("   map %02d: recorded solution ends '%s' and the solver finds none (%s)" % [number, followed.end, check.get("reason", "")])
	var fixes: Dictionary = SOLUTION_FIXES.get(number, {})
	for index in fixes:
		var step: Dictionary = maze.solution[index].duplicate(true)
		step.merge(fixes[index], true)
		maze.solution[index] = step


## The first tool the solution uses: what the troop needs to get going.
static func _starting_tools(maze: MazeStageData) -> Dictionary:
	if maze.solution.is_empty():
		return {}
	return {str(maze.solution[0].tool): 1}


## The starting tool is the item of that tool nearest the entrance, handed
## out up front instead of lying there: one charge fewer on the map.
static func _take_nearest(items: Array[ItemSpec], tool_id: String, from: Vector2i) -> void:
	var nearest: ItemSpec = null
	for spec in items:
		if spec.kind != ItemSpec.Kind.TOOL or spec.tool_id != tool_id:
			continue
		if nearest == null or Vector2(spec.column, spec.row).distance_to(from) < Vector2(nearest.column, nearest.row).distance_to(from):
			nearest = spec
	if nearest == null:
		return
	nearest.amount -= 1
	if nearest.amount <= 0:
		items.erase(nearest)


static func _items_of(maze: MazeStageData, number: int) -> Array[ItemSpec]:
	var rng := RandomNumberGenerator.new()
	rng.seed = number
	var items: Array[ItemSpec] = []
	for spot in maze.item_spots:
		var spec := ItemSpec.new()
		if spot.kind == MazeLayout.SpotKind.TOOL:
			spec.kind = ItemSpec.Kind.TOOL
			spec.tool_id = spot.tool_id
			spec.amount = spot.amount
		else:
			_roll_surprise(spec, rng)
		spec.column = spot.column
		spec.row = spot.row
		items.append(spec)
	return items


static func _roll_surprise(spec: ItemSpec, rng: RandomNumberGenerator) -> void:
	var roll := rng.randf()
	if roll < SURPRISE_TOOL_CHANCE:
		spec.kind = ItemSpec.Kind.TOOL
		spec.tool_id = SURPRISE_TOOLS[rng.randi_range(0, SURPRISE_TOOLS.size() - 1)]
		spec.amount = 1
	elif roll < SURPRISE_BAG_CHANCE:
		spec.kind = ItemSpec.Kind.CHARGE_BAG
		spec.amount = 1
	else:
		spec.kind = ItemSpec.Kind.TIME
		spec.amount = HOURGLASS_SECONDS
