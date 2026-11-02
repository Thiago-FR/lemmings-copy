class_name MazeStageGenerator
extends RefCounted
## Generates a maze stage from a seed and a difficulty (0 to MAX_DIFFICULTY):
## rooms filling one screen, the entrance and the exit anywhere in them
## (even close together, as long as tools are needed between them),
## obstacles that need tools, and item spots spread through it, some on the
## way and some as rewards off it. The same seed and difficulty always give
## the same stage. The result is plain MazeStageData, usable by any mode or
## by the editor.
##
## Steps (MazeLayout explains the room grid and the link kinds):
## 1. A random spanning tree over the rooms, using three kinds of
##    neighbours: side by side (a doorway, a wall or a trough), straight down
##    (a staircase under a patch to dig) and diagonally up (a ladder shaft).
##    A few extra links then add loops and alternative routes.
## 2. The entrance goes in a random room the troop would stay in (no trough
##    to fall into); the exit in any room it takes at least MIN_OBSTACLES
##    tool uses to reach.
## 3. With every tool in endless supply the solver finds a route; a spot
##    with one charge is placed for each tool use on it, somewhere the
##    lemming passes before. Bonus spots go in rooms off the route.
## 4. The real solver (one lemming, nothing in hand, only the spots) must
##    reach the exit; otherwise the layout is thrown away and another tried.
##    Its route is recorded as the stage's solution.
##
## Difficulty raises the obstacles on the way, lowers the share of doorways,
## adds concrete, removes spare charges and shortens the spare time.

const MAX_DIFFICULTY := 4
const MAX_ATTEMPTS := 80

## Per difficulty.
const MIN_OBSTACLES: Array[int] = [2, 3, 4, 5, 5]
const OPEN_CHANCE: Array[float] = [0.5, 0.42, 0.35, 0.3, 0.25]
const TROUGH_CHANCE: Array[float] = [0.35, 0.35, 0.4, 0.4, 0.4]
const CONCRETE_WALL_CHANCE: Array[float] = [0.1, 0.25, 0.4, 0.5, 0.6]
## Floors and the separators no link goes through.
const CONCRETE_CHANCE: Array[float] = [0.15, 0.3, 0.45, 0.6, 0.75]
const EXTRA_LINKS: Array[int] = [1, 2, 2, 3, 3]
## Charges added on top of exactly what the route needs.
const SLACK_CHARGES: Array[int] = [2, 1, 1, 0, 0]
const BONUS_ROOMS: Array[int] = [2, 2, 3, 3, 3]
## The time limit is the route's estimate times this factor, by stage. The
## estimate runs about 2.6 to 4.6 times what the test robot takes; the
## first factors (1.8 to 1.4, never under 3 minutes) left 3.5 to 7 times
## the robot's time and the clock was no challenge at all. Now the limit is
## about 2 to 4 times the robot's (a player reacts slower and releases the
## whole troop), and the playthrough tests check the robot always finishes
## with a quarter of the clock to spare.
const TIME_FACTOR: Array[float] = [1.0, 0.9, 0.85, 0.8, 0.75]
const MIN_TIME_SECONDS := 90
const MAX_TIME_SECONDS := 480
## Rough seconds each move of a route takes, for the time limit.
const SECONDS_PER_MOVE := 22
const SECONDS_PER_TOOL := {"digger": 10, "ladder_vertical": 22, "miner": 6, "basher": 6, "bridge": 10}
const BASE_SECONDS := 40
## Cave from this difficulty on; open sky before it.
const FIRST_CAVE_DIFFICULTY := 2
const MAX_SPOTS_PER_ROOM := 3


static func generate(seed_value: int, difficulty: int) -> MazeStageData:
	var level := clampi(difficulty, 0, MAX_DIFFICULTY)
	for attempt in MAX_ATTEMPTS:
		var rng := RandomNumberGenerator.new()
		rng.seed = mix_seed(seed_value, level, attempt)
		var layout := _try_layout(rng, level)
		if layout != null:
			return _make_data(layout, rng, level)
	push_warning("Maze generation fell back to the plain layout (seed %d, difficulty %d)" % [seed_value, level])
	var fallback_rng := RandomNumberGenerator.new()
	fallback_rng.seed = mix_seed(seed_value, level, MAX_ATTEMPTS)
	return _make_data(_fallback_layout(), fallback_rng, level)


## Paints a hand-made layout (spawn_room, exit_room and spots set) the same
## way, after checking it can be won. Returns null if the solver cannot win
## it.
static func from_layout(layout: MazeLayout, seed_value: int, difficulty: int) -> MazeStageData:
	var level := clampi(difficulty, 0, MAX_DIFFICULTY)
	layout.reachable_rooms = MazeSolver.rough_reach(layout)
	var result := MazeSolver.solve(layout)
	if not result.solved:
		return null
	layout.solution_steps.assign(result.steps)
	var rng := RandomNumberGenerator.new()
	rng.seed = mix_seed(seed_value, level, 0)
	return _make_data(layout, rng, level)


static func mix_seed(seed_value: int, difficulty: int, attempt: int) -> int:
	return hash("%d:%d:%d" % [seed_value, difficulty, attempt])


# --- Layout -----------------------------------------------------------------------

static func _try_layout(rng: RandomNumberGenerator, level: int) -> MazeLayout:
	var layout := MazeLayout.new()
	_choose_materials(layout, rng, level)
	var horizontal := _build_links(layout, rng, level)
	_assign_horizontal_kinds(layout, rng, level, horizontal)

	layout.spawn_room = rng.randi_range(0, MazeLayout.ROOM_COUNT - 1)
	if layout.free_floor_columns(layout.spawn_room).size() < 3 or not MazeSolver.is_stable_at_start(layout, layout.spawn_room):
		return null
	var route := _choose_exit(layout, rng, level)
	if route.is_empty():
		return null
	if not _place_route_spots(layout, rng, level, route):
		return null
	_place_bonus_spots(layout, rng, level, route)

	var result := MazeSolver.solve(layout)
	if not result.solved:
		return null
	layout.solution_steps.assign(result.steps)
	return layout


static func _choose_materials(layout: MazeLayout, rng: RandomNumberGenerator, level: int) -> void:
	for room in MazeLayout.ROOM_COUNT:
		layout.floor_materials[room] = _roll_material(rng, CONCRETE_CHANCE[level])
	for band in MazeLayout.ROOM_ROWS:
		for separator in range(1, MazeLayout.SEPARATOR_COLUMNS.size() - 1):
			layout.separator_materials["%d:%d" % [band, separator]] = _roll_material(rng, CONCRETE_CHANCE[level])


static func _roll_material(rng: RandomNumberGenerator, concrete_chance: float) -> int:
	return MazeLayout.CONCRETE if rng.randf() < concrete_chance else MazeLayout.EARTH


## A random spanning tree (Kruskal over shuffled candidates) plus a few extra
## links. Vertical links are added at once; side-by-side ones are returned
## as {"column", "band"} and given a kind afterwards, when it is known what
## stands next to them.
static func _build_links(layout: MazeLayout, rng: RandomNumberGenerator, level: int) -> Array[Dictionary]:
	var candidates: Array[Dictionary] = []
	for band in MazeLayout.ROOM_ROWS:
		for column in MazeLayout.ROOM_COLUMNS - 1:
			candidates.append({"type": "H", "column": column, "band": band, "side": 1, "key": rng.randf()})
	for band in MazeLayout.ROOM_ROWS - 1:
		for column in MazeLayout.ROOM_COLUMNS:
			for side in [-1, 1]:
				# Vertical links a little earlier in the order: they are what
				# makes the maze climb and fall.
				candidates.append({"type": "V", "column": column, "band": band, "side": side, "key": rng.randf() * 0.75})
				if column + side >= 0 and column + side < MazeLayout.ROOM_COLUMNS:
					candidates.append({"type": "D", "column": column, "band": band, "side": side, "key": rng.randf() * 0.75})
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.key < b.key)

	var parent: Array[int] = []
	for room in MazeLayout.ROOM_COUNT:
		parent.append(room)
	var horizontal: Array[Dictionary] = []
	var leftover: Array[Dictionary] = []
	for candidate in candidates:
		var rooms := _candidate_rooms(candidate)
		var root_a := _find(parent, rooms.x)
		var root_b := _find(parent, rooms.y)
		if root_a != root_b and _can_place(layout, candidate):
			_place(layout, candidate, horizontal)
			parent[root_a] = root_b
		else:
			leftover.append(candidate)

	var extra := 0
	for candidate in leftover:
		if extra >= EXTRA_LINKS[level]:
			break
		if _can_place(layout, candidate):
			_place(layout, candidate, horizontal)
			extra += 1
	return horizontal


static func _find(parent: Array[int], node: int) -> int:
	while parent[node] != node:
		node = parent[node]
	return node


static func _candidate_rooms(candidate: Dictionary) -> Vector2i:
	var column: int = candidate.column
	var band: int = candidate.band
	match candidate.type:
		"H":
			return Vector2i(MazeLayout.room_id(column, band), MazeLayout.room_id(column + 1, band))
		"V":
			return Vector2i(MazeLayout.room_id(column, band), MazeLayout.room_id(column, band + 1))
	return Vector2i(MazeLayout.room_id(column, band + 1), MazeLayout.room_id(column + candidate.side, band))


static func _can_place(layout: MazeLayout, candidate: Dictionary) -> bool:
	match candidate.type:
		"H":
			return layout.can_link_side_by_side(candidate.column, candidate.band)
		"V":
			return layout.can_stairs(candidate.column, candidate.band, candidate.side)
	return layout.can_ladder(candidate.column, candidate.band, candidate.side)


## Side-by-side links only reserve their separator here and get their real
## kind afterwards.
static func _place(layout: MazeLayout, candidate: Dictionary, horizontal: Array[Dictionary]) -> void:
	match candidate.type:
		"H":
			horizontal.append({"column": candidate.column, "band": candidate.band})
			layout.reserve_separator(candidate.band, candidate.column + 1)
		"V":
			layout.add_stairs(candidate.column, candidate.band, candidate.side)
		"D":
			layout.add_ladder(candidate.column, candidate.band, candidate.side)


static func _assign_horizontal_kinds(layout: MazeLayout, rng: RandomNumberGenerator, level: int, horizontal: Array[Dictionary]) -> void:
	for edge in horizontal:
		var column: int = edge.column
		var band: int = edge.band
		layout.release_separator(band, column + 1)
		if rng.randf() < OPEN_CHANCE[level]:
			layout.add_open(column, band)
		elif layout.can_trough(column, band) and rng.randf() < TROUGH_CHANCE[level]:
			layout.add_trough(column, band, rng.randi_range(1, 2), rng.randi_range(1, 2))
		else:
			var concrete := rng.randf() < CONCRETE_WALL_CHANCE[level]
			layout.add_wall(column, band, MazeLayout.CONCRETE if concrete else MazeLayout.EARTH)


## Picks the exit among the rooms that take enough obstacles to reach (any
## room, any band, next door included) and returns the route the unlimited
## solver finds to it ({} if none works).
static func _choose_exit(layout: MazeLayout, rng: RandomNumberGenerator, level: int) -> Dictionary:
	var reach := MazeSolver.rough_reach(layout)
	layout.reachable_rooms = reach
	var candidates: Array[int] = []
	for room: int in reach:
		if room != layout.spawn_room and reach[room] >= MIN_OBSTACLES[level] and layout.free_floor_columns(room).size() >= 2:
			candidates.append(room)
	_shuffle(candidates, rng)
	for room in candidates.slice(0, 4):
		layout.exit_room = room
		var route := MazeSolver.solve_unlimited(layout)
		if route.solved:
			return route
	layout.exit_room = -1
	return {}


# --- Spots --------------------------------------------------------------------------

## One charge for every tool use on the route, in a stable pen the lemming
## passes through before that use (usually the last one, sometimes an
## earlier one), plus the spare charges. A stage uses at most four
## different tools (digger, ladder, bridge, and the pickaxe or the jackhammer
## -- the jackhammer whenever concrete is on the way, since it breaks both):
## a tool bar of four slots then never has to drop one it picked up here.
static func _place_route_spots(layout: MazeLayout, rng: RandomNumberGenerator, level: int, route: Dictionary) -> bool:
	var steps: Array = route.steps
	var trace: Array = route.trace
	var concrete_on_route := false
	for step in steps:
		var link := layout.get_link(step.link)
		if step.tool != "" and link.kind == MazeLayout.LinkKind.WALL and link.material == MazeLayout.CONCRETE:
			concrete_on_route = true
	var placed: Array[Dictionary] = []
	for index in steps.size():
		var step: Dictionary = steps[index]
		if step.tool == "":
			continue
		var link := layout.get_link(step.link)
		var tool_id: String = step.tool
		if link.kind == MazeLayout.LinkKind.WALL:
			tool_id = "basher" if concrete_on_route or link.material == MazeLayout.CONCRETE else "miner"
		var room := _room_before(layout, rng, trace, index)
		if room < 0:
			return false
		placed.append(layout.add_tool_spot(room, tool_id, 1))
	for extra in SLACK_CHARGES[level]:
		if placed.is_empty():
			break
		placed[rng.randi_range(0, placed.size() - 1)].amount += 1
	return true


static func _room_before(layout: MazeLayout, rng: RandomNumberGenerator, trace: Array, index: int) -> int:
	var pens: Array[int] = []
	for state_index in range(index, -1, -1):
		if trace[state_index].stable:
			pens.append(state_index)
	if pens.is_empty():
		return -1
	var order: Array[int] = [pens[0]]
	if pens.size() > 1 and rng.randf() < 0.4:
		order.push_front(pens[rng.randi_range(1, pens.size() - 1)])
	order.append_array(pens)
	for state_index in order:
		var rooms: Array[int] = []
		rooms.assign(trace[state_index].rooms)
		_shuffle(rooms, rng)
		for room in rooms:
			if _has_spot_space(layout, room):
				return room
	return -1


static func _has_spot_space(layout: MazeLayout, room: int) -> bool:
	var count := layout.spots_in(room)
	var reserved := 1 if room == layout.spawn_room or room == layout.exit_room else 0
	return count < MAX_SPOTS_PER_ROOM and count + reserved < layout.free_floor_columns(room).size()


## Bonus spots in rooms off the route, for the player who explores (at the
## cost of the charges spent getting there), and one on the way now and then.
static func _place_bonus_spots(layout: MazeLayout, rng: RandomNumberGenerator, level: int, route: Dictionary) -> void:
	var on_route := {}
	for state in route.trace:
		for room in state.rooms:
			on_route[room] = true
	var rooms: Array[int] = []
	for room: int in layout.reachable_rooms:
		if not on_route.has(room) and _has_spot_space(layout, room):
			rooms.append(room)
	_shuffle(rooms, rng)
	for room in rooms.slice(0, BONUS_ROOMS[level]):
		layout.add_bonus_spot(room)
	if rng.randf() < 0.5:
		var trace: Array = route.trace
		for room: int in trace[rng.randi_range(0, trace.size() - 1)].rooms:
			if _has_spot_space(layout, room):
				layout.add_bonus_spot(room)
				break


static func _shuffle(values: Array, rng: RandomNumberGenerator) -> void:
	for index in range(values.size() - 1, 0, -1):
		var other := rng.randi_range(0, index)
		var held: Variant = values[index]
		values[index] = values[other]
		values[other] = held


## Only if every attempt failed: the top band as one open hall, the entrance
## at the left and the exit at the right.
static func _fallback_layout() -> MazeLayout:
	var layout := MazeLayout.new()
	for column in MazeLayout.ROOM_COLUMNS - 1:
		layout.add_open(column, 0)
	layout.spawn_room = 0
	layout.exit_room = MazeLayout.ROOM_COLUMNS - 1
	for room in MazeLayout.ROOM_COLUMNS:
		layout.reachable_rooms[room] = 0
	var result := MazeSolver.solve(layout)
	layout.solution_steps.assign(result.get("steps", []))
	return layout


# --- Output ---------------------------------------------------------------------------

static func _make_data(layout: MazeLayout, rng: RandomNumberGenerator, level: int) -> MazeStageData:
	var data := MazeStageData.new()
	data.layout = layout
	var cave := level >= FIRST_CAVE_DIFFICULTY
	data.environment_kind = LevelEnvironment.Kind.CAVE if cave else LevelEnvironment.Kind.SURFACE
	data.cells = MazePainter.paint(layout, rng, not cave)
	_place_markers(layout, rng, data)
	data.suggested_time_seconds = _time_limit(layout, level)
	data.solution = _solution_clicks(layout, data)
	return data


## Distinct free floor columns for the entrance, the exit and every item.
## A spot holding several charges becomes that many items of one charge
## each, side by side: the user found an item giving three charges too
## generous (more per item is for the reward cards to give). Every spot gets
## its first item before any spot gets a second, so the extra items never
## take the floor a spot needs; a room out of floor stacks the rest on the
## spot's first item.
static func _place_markers(layout: MazeLayout, rng: RandomNumberGenerator, data: MazeStageData) -> void:
	var taken := {}
	data.spawn_cell = _take_column(layout, rng, layout.spawn_room, taken, true)
	data.exit_cell = _take_column(layout, rng, layout.exit_room, taken, false)
	var first_items: Array[Dictionary] = []
	for spot_index in layout.spots.size():
		var spot: Dictionary = layout.spots[spot_index]
		var item := _make_item(layout, rng, spot, spot_index, taken)
		first_items.append(item)
		data.item_spots.append(item)
	for spot_index in layout.spots.size():
		var spot: Dictionary = layout.spots[spot_index]
		if spot.kind != MazeLayout.SpotKind.TOOL:
			continue
		for _extra in maxi(int(spot.amount), 1) - 1:
			if _has_free_column(layout, spot.room, taken):
				data.item_spots.append(_make_item(layout, rng, spot, spot_index, taken))
			else:
				first_items[spot_index].amount += 1


static func _make_item(layout: MazeLayout, rng: RandomNumberGenerator, spot: Dictionary, spot_index: int, taken: Dictionary) -> Dictionary:
	var cell := _take_column(layout, rng, spot.room, taken, false)
	return {
		"column": cell.x, "row": cell.y, "kind": spot.kind, "tool_id": spot.tool_id,
		"amount": 1 if spot.kind == MazeLayout.SpotKind.TOOL else spot.amount, "required": spot.required,
		"spot_index": spot_index,
	}


static func _has_free_column(layout: MazeLayout, room: int, taken: Dictionary) -> bool:
	for column in layout.free_floor_columns(room):
		if not taken.has(column):
			return true
	return false


## The entrance is kept off its room's edges, so the troop lands inside it.
static func _take_column(layout: MazeLayout, rng: RandomNumberGenerator, room: int, taken: Dictionary, centred: bool) -> Vector2i:
	var choices: Array[int] = []
	for column in layout.free_floor_columns(room):
		if not taken.has(column):
			choices.append(column)
	if centred and choices.size() > 4:
		choices = choices.slice(1, choices.size() - 1)
	assert(not choices.is_empty(), "Room %d has no floor left for a marker" % room)
	var column := choices[rng.randi_range(0, choices.size() - 1)]
	taken[column] = true
	return Vector2i(column, MazeLayout.floor_row(MazeLayout.room_band(room)))


static func _time_limit(layout: MazeLayout, level: int) -> int:
	var seconds := BASE_SECONDS
	for step in layout.solution_steps:
		seconds += SECONDS_PER_MOVE + int(SECONDS_PER_TOOL.get(step.tool, 0))
	var limit := int(round(seconds * TIME_FACTOR[level] / 10.0)) * 10
	return clampi(limit, MIN_TIME_SECONDS, MAX_TIME_SECONDS)


## The solution as clicks: for each tool use, where to hand the tool out.
static func _solution_clicks(layout: MazeLayout, data: MazeStageData) -> Array[Dictionary]:
	var clicks: Array[Dictionary] = []
	for step in layout.solution_steps:
		if step.tool == "":
			continue
		var link := layout.get_link(step.link)
		var band: int = link.band
		var walk_row := MazeLayout.floor_row(band)
		var click := {"tool": step.tool, "collect_first": _collected_cells(data, step.collected)}
		match link.kind:
			MazeLayout.LinkKind.WALL:
				var other: int = link.b if step.from == link.a else link.a
				var direction := 1 if MazeLayout.room_column(step.from) < MazeLayout.room_column(other) else -1
				var separator: int = link.separator
				click.merge(_range(separator - 3 * direction, separator - direction, walk_row, direction, "tunnel through the wall at column %d" % separator))
			MazeLayout.LinkKind.BRIDGE:
				var direction := 1 if step.from == link.a else -1
				var edge: int = link.trough_first - 1 if direction > 0 else link.trough_last + 1
				click.merge(_range(edge - 3 * direction, edge, walk_row, direction, "bridge the trough at columns %d-%d" % [link.trough_first, link.trough_last]))
			MazeLayout.LinkKind.TROUGH_LADDER:
				click.merge(_range(link.trough_first, link.trough_last, walk_row + 1, link.side, "ladder out of the trough"))
			MazeLayout.LinkKind.STAIRS:
				click.merge(_range(link.column, link.column, walk_row, 0, "dig the patch at column %d" % link.column))
			MazeLayout.LinkKind.LADDER:
				var side: int = link.side
				var shaft: int = link.column
				click.merge(_range(shaft - 2 * side, shaft, MazeLayout.floor_row(band + 1), side, "ladder up the shaft at column %d" % shaft))
		clicks.append(click)
	return clicks


## Cells of the tool spots in a solver's collected bitmask (spots and
## data.item_spots are in the same order).
static func _collected_cells(data: MazeStageData, collected: int) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	# collected counts the layout's spots; each may have become several items.
	for item in data.item_spots:
		if collected & (1 << int(item.spot_index)):
			cells.append(Vector2i(item.column, item.row))
	return cells


static func _range(from: int, to: int, row: int, direction: int, why: String) -> Dictionary:
	return {"from_column": mini(from, to), "to_column": maxi(from, to), "row": row, "direction": direction, "why": why}
