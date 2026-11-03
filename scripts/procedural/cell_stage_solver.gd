class_name CellStageSolver
extends RefCounted
## Can a stage drawn freely on the grid (MazeStageData) be won, and how? It
## follows ONE lemming walking the stage the way the game moves it, in
## slices of a quarter block (UNIT, 8px: the height of a brick), and tries
## handing it tools on the way. One lemming with only the items it picks
## up is the worst case, so a stage that passes can be won by the troop.
##
## The walking model, from LemmingController:
## - the body is one block tall; it steps up less than a block (up to
##   MAX_RISE_UNITS), a full block is a wall and it turns there (or climbs
##   it with the climber trait);
## - it falls where the floor ends and dies falling more than
##   SAFE_FALL_UNITS (80px) unless it floats; out of the stage is death;
## - it takes any ladder its body reaches, walking or falling, climbs to the
##   top rung and steps off where there is ground (ahead first);
## - bricks (staircases, bridges, ramps) are floor but not wall: a body
##   passes under them.
## The tools, from the skills: the shovel digs straight down through earth,
## the pickaxe and the jackhammer tunnel one block tall at the next wall
## (earth, or earth and concrete), the vertical ladder goes up the next
## wall of at most LADDER_MAX_CELLS, the diagonal ladder lays 12 bricks a
## quarter block higher each, the bridge 12 flat ones from the edge ahead.
## Nothing breaks the stage's border.
##
## Search: by the number of tools used (fewest first), over where the
## lemming is, which way it faces, what it carries and what it has changed.
## Tools are tried at the places that can matter: where the walk turns, falls
## or meets a wall, and near the columns the generator marked (hints).

const UNIT := 8
const UNITS_PER_CELL := 4
const MAX_RISE_UNITS := 3
const SAFE_FALL_UNITS := 10
const BODY_UNITS := 4
const LADDER_MAX_CELLS := 12
const BUILDER_PIECES := 12
const BRIDGE_PIECES := 12
const MAX_WALK_STEPS := 6000
## Walks tried before giving up, and states made.
const MAX_EXPANSIONS := 700
const MAX_NODES := 2000
## How much one more tool weighs against getting a block nearer the exit:
## the search tries the most promising walks first, and prefers fewer tools.
const TOOL_WEIGHT := 8
## A row nearer the exit counts for this many columns.
const ROW_WEIGHT := 4
## Every tool the solver knows how to use.
const TOOLS: Array[String] = ["digger", "builder", "bridge", "basher", "miner", "ladder_vertical", "climber", "floater"]
## Tools carried until a wall (or, the bridge, an edge): giving them anywhere
## on the way there is the same.
const CARRIED: Array[String] = ["basher", "miner", "ladder_vertical", "bridge"]
const TRAITS: Array[String] = ["climber", "floater"]

enum Unit { AIR, EARTH, CONCRETE, BRICK, BEDROCK }

var _columns := 0
var _unit_rows := 0
## column -> PackedByteArray of Unit, one per unit row.
var _base: Array[PackedByteArray] = []
var _ladders := {}
var _spots: Array[Dictionary] = []
var _spawn := Vector2i.ZERO
var _spawn_direction := 1
var _exit := Vector2i.ZERO
var _hints: Array[int] = []
var _unlimited := false
var _allowed: Array[String] = []


## Whether the stage can be won with the items on it, and the moves.
## Returns {"solved", "steps": [{"tool", "column", "row", "direction",
## "collect_first"}], "path": [Vector3i(column, feet unit, direction)],
## "walk_steps"}.
static func solve(data: MazeStageData, hints: Array[int] = []) -> Dictionary:
	var solver := CellStageSolver.new()
	solver._load(data, hints)
	return solver._search()


## The same with endless tools of the given kinds and no items: whether the
## exit can be reached at all, and on which path (items go along it).
static func solve_unlimited(data: MazeStageData, tools: Array[String], hints: Array[int] = []) -> Dictionary:
	var solver := CellStageSolver.new()
	solver._load(data, hints)
	solver._unlimited = true
	solver._allowed = tools
	return solver._search()


# --- The grid -------------------------------------------------------------------

func _load(data: MazeStageData, hints: Array[int]) -> void:
	_columns = data.columns
	_unit_rows = data.rows * UNITS_PER_CELL
	_hints = hints
	_base.clear()
	for column in _columns:
		var units := PackedByteArray()
		units.resize(_unit_rows)
		for row in data.rows:
			var kind := data.cell_at(column, row)
			var value := Unit.AIR
			if data.unbreakable.has(Vector2i(column, row)):
				value = Unit.BEDROCK
			elif kind == MazeLayout.EARTH:
				value = Unit.EARTH
			elif kind == MazeLayout.CONCRETE:
				value = Unit.CONCRETE
			for unit in UNITS_PER_CELL:
				units[row * UNITS_PER_CELL + unit] = value
		# Two halves per column: the soil ramps are half a column wide.
		_base.append(units)
		_base.append(units.duplicate())
	var bricks: Array[Rect2] = []
	bricks.append_array(data.bricks)
	bricks.append_array(data.ramps)
	for brick in bricks:
		_add_brick(brick)
	for ladder in data.ladders:
		_ladders[ladder] = true
	for spot in data.item_spots:
		if spot.kind == MazeLayout.SpotKind.TOOL:
			_spots.append(spot)
	_spawn = data.spawn_cell
	_spawn_direction = -1 if data.spawn_faces_left else 1
	_exit = data.exit_cell


## A brick fills the units it covers in each half column it covers.
func _add_brick(brick: Rect2) -> void:
	var half_width := float(UNIT * UNITS_PER_CELL) / 2.0
	var first_half := floori(brick.position.x / half_width)
	var last_half := floori((brick.end.x - 0.01) / half_width)
	for half in range(first_half, last_half + 1):
		if half < 0 or half >= _base.size():
			continue
		var top := floori(brick.position.y / UNIT)
		var bottom := ceili(brick.end.y / UNIT)
		for unit in range(maxi(top, 0), mini(bottom, _unit_rows)):
			if _base[half][unit] == Unit.AIR:
				_base[half][unit] = Unit.BRICK


## What is in one half column at a unit.
func _half_unit(state: Dictionary, half: int, unit: int) -> int:
	if half < 0 or half >= _base.size():
		return Unit.BEDROCK
	if unit < 0 or unit >= _unit_rows:
		return Unit.AIR
	var key := half * 65536 + unit
	var changes: Dictionary = state.changes
	if changes.has(key):
		return changes[key]
	return _base[half][unit]


## What is in a column at a unit, both halves together: terrain if either
## half has it, else a brick if either has one.
func _unit(state: Dictionary, column: int, unit: int) -> int:
	var left := _half_unit(state, column * 2, unit)
	var right := _half_unit(state, column * 2 + 1, unit)
	if left != Unit.AIR and left != Unit.BRICK:
		return left
	if right != Unit.AIR and right != Unit.BRICK:
		return right
	return Unit.BRICK if left == Unit.BRICK or right == Unit.BRICK else Unit.AIR


func _set_unit(state: Dictionary, column: int, unit: int, value: int) -> void:
	state.changes[column * 2 * 65536 + unit] = value
	state.changes[(column * 2 + 1) * 65536 + unit] = value


func _is_ladder(state: Dictionary, column: int, row: int) -> bool:
	var cell := Vector2i(column, row)
	return _ladders.has(cell) or state.ladders.has(cell)


## Terrain in the body's way (bricks are not: the body passes under them).
func _body_blocked(state: Dictionary, column: int, feet: int) -> bool:
	for unit in range(feet - BODY_UNITS, feet):
		var value := _unit(state, column, unit)
		if value != Unit.AIR and value != Unit.BRICK:
			return true
	return false


# --- Walking --------------------------------------------------------------------

## Walks the lemming on from where the state has it until it gets out, dies,
## or paces the same stretch for good. Changes the state as it goes (items
## picked up, a carried tool used) and returns {"end": "exit", "dead" or
## "loop", "points": walking positions with what was collected by then,
## "events": point indexes where it turned, fell or met a wall}.
func _walk(state: Dictionary) -> Dictionary:
	var points: Array[Dictionary] = []
	var events := {}
	var seen := {}
	for step in MAX_WALK_STEPS:
		var column: int = state.column
		var feet: int = state.feet
		# A ladder at the body's middle is taken, walking or falling.
		if _is_ladder(state, column, (feet - 2) / UNITS_PER_CELL):
			if not _climb_ladder(state):
				return {"end": "loop", "points": points, "events": events}
			events[points.size()] = true
			continue
		if _unit(state, column, feet) == Unit.AIR:
			if not _fall(state):
				return {"end": "dead", "points": points, "events": events}
			events[points.size()] = true
			continue
		var key := Vector4i(column, feet, state.direction, state.carried.hash())
		if seen.has(key):
			return {"end": "loop", "points": points, "events": events}
		seen[key] = true
		# Items are picked up as soon as the lemming is there: one at a point
		# can be used at that point.
		_collect(state)
		points.append({"column": column, "feet": feet, "direction": state.direction, "collected": state.collected})
		if column == _exit.x and absi(feet - _exit.y * UNITS_PER_CELL) <= 1:
			return {"end": "exit", "points": points, "events": events}
		var ahead: int = column + state.direction
		var rise := _rise(state, ahead, feet, state.direction)
		if rise >= 0:
			state.column = ahead
			state.feet = feet - rise
			state.walked += 1
			continue
		events[points.size() - 1] = true
		if _use_carried_tool(state, ahead):
			state.carried_used_at = points.size()
			continue
		if state.traits.has("climber"):
			_climb_wall(state, ahead)
			continue
		state.direction = -state.direction
	return {"end": "loop", "points": points, "events": events}


## How far up the lemming ends in the next column (0 for level or lower),
## or -1 for a wall. It walks over the column's near half, then its far
## half, each a step of at most MAX_RISE_UNITS (a soil ramp rises half a
## column at a time).
func _rise(state: Dictionary, column: int, feet: int, direction: int) -> int:
	var near := column * 2 + (0 if direction > 0 else 1)
	var far := column * 2 + (1 if direction > 0 else 0)
	var top := feet
	for half in [near, far]:
		var rise := 0
		while rise <= MAX_RISE_UNITS and _half_unit(state, half, top - 1 - rise) != Unit.AIR:
			rise += 1
		if rise > MAX_RISE_UNITS:
			return -1
		top -= rise
	if _body_blocked(state, column, top):
		return -1
	return feet - top


func _fall(state: Dictionary) -> bool:
	var start: int = state.feet
	var feet := start
	while feet < _unit_rows and _unit(state, state.column, feet) == Unit.AIR:
		feet += 1
		if _is_ladder(state, state.column, (feet - 2) / UNITS_PER_CELL):
			state.feet = feet
			return true
	if feet >= _unit_rows:
		return false
	if feet - start > SAFE_FALL_UNITS and not state.traits.has("floater"):
		return false
	state.feet = feet
	return true


## Up to the top rung, then off to the side with ground (ahead first).
## False if there is ground on neither side (it holds on there for good).
func _climb_ladder(state: Dictionary) -> bool:
	var top: int = (state.feet - 2) / UNITS_PER_CELL
	while _is_ladder(state, state.column, top - 1):
		top -= 1
	var feet := top * UNITS_PER_CELL
	for side in [state.direction, -state.direction]:
		var beside: int = state.column + side
		if _unit(state, beside, feet) != Unit.AIR and not _body_blocked(state, beside, feet):
			state.column = beside
			state.feet = feet
			state.direction = side
			return true
	return false


## Up the wall's face; at the top onto it, under an overhang back down.
func _climb_wall(state: Dictionary, wall_column: int) -> void:
	var feet: int = state.feet
	while feet > BODY_UNITS:
		feet -= 1
		if _body_blocked(state, state.column, feet):
			state.feet = feet + 1
			state.direction = -state.direction
			return
		if _unit(state, wall_column, feet - 1) == Unit.AIR and not _body_blocked(state, wall_column, feet):
			state.column = wall_column
			state.feet = feet
			return
	state.direction = -state.direction


func _collect(state: Dictionary) -> void:
	for index in _spots.size():
		var bit := 1 << index
		if state.collected & bit:
			continue
		var spot: Dictionary = _spots[index]
		# Within a block: an item on a ramp sits at the foot of its block.
		if spot.column == state.column and absi(spot.row * UNITS_PER_CELL - int(state.feet)) < UNITS_PER_CELL:
			state.collected |= bit
			state.inventory[spot.tool_id] = int(state.inventory.get(spot.tool_id, 0)) + int(spot.amount)


# --- Tools ----------------------------------------------------------------------

## A carried tool used on the wall ahead, if it is one it works on.
func _use_carried_tool(state: Dictionary, wall_column: int) -> bool:
	var carried: String = state.carried
	if carried == "" or carried == "bridge" or state.feet % UNITS_PER_CELL != 0:
		return false
	var used := false
	match carried:
		"basher", "miner":
			used = _tunnel(state, wall_column, carried == "basher")
		"ladder_vertical":
			used = _ladder_up(state, wall_column)
	if used:
		state.carried = ""
	return used


func _breakable(value: int, concrete_too: bool) -> bool:
	return value == Unit.EARTH or value == Unit.BRICK or concrete_too and value == Unit.CONCRETE


func _tunnel(state: Dictionary, wall_column: int, concrete_too: bool) -> bool:
	var body_row: int = state.feet / UNITS_PER_CELL - 1
	var direction: int = state.direction
	if not _breakable(_unit(state, wall_column, body_row * UNITS_PER_CELL), concrete_too):
		return false
	var column := wall_column
	while column >= 0 and column < _columns:
		var value := _unit(state, column, body_row * UNITS_PER_CELL)
		if value == Unit.AIR or not _breakable(value, concrete_too):
			break
		for unit in UNITS_PER_CELL:
			_set_unit(state, column, body_row * UNITS_PER_CELL + unit, Unit.AIR)
		if _unit(state, column, state.feet) == Unit.AIR:
			break
		column += direction
	return true


func _ladder_up(state: Dictionary, wall_column: int) -> bool:
	var floor_row: int = state.feet / UNITS_PER_CELL
	var top := floor_row - 1
	while top >= 0 and _unit(state, wall_column, top * UNITS_PER_CELL) != Unit.AIR:
		top -= 1
	var height := floor_row - (top + 1)
	if top < 0 or height > LADDER_MAX_CELLS:
		return false
	for row in range(top, floor_row):
		if _body_blocked(state, state.column, (row + 1) * UNITS_PER_CELL):
			return false
	for row in range(top + 1, floor_row):
		state.ladders[Vector2i(state.column, row)] = true
	return true


func _dig_down(state: Dictionary) -> bool:
	var column: int = state.column
	var unit: int = state.feet
	var value := _unit(state, column, unit)
	if value != Unit.EARTH and value != Unit.BRICK:
		return false
	while true:
		value = _unit(state, column, unit)
		if value != Unit.EARTH and value != Unit.BRICK:
			break
		_set_unit(state, column, unit, Unit.AIR)
		unit += 1
	# The shovel takes whole blocks: the rest of the last block goes too.
	while unit % UNITS_PER_CELL != 0 and _unit(state, column, unit) == Unit.EARTH:
		_set_unit(state, column, unit, Unit.AIR)
		unit += 1
	state.feet = unit
	return true


func _build_stairs(state: Dictionary) -> bool:
	var direction: int = state.direction
	var placed := 0
	for piece in range(1, BUILDER_PIECES + 1):
		var column: int = state.column + piece * direction
		var top: int = state.feet - piece
		if _unit(state, column, top) != Unit.AIR or _body_blocked(state, column, top):
			break
		_set_unit(state, column, top, Unit.BRICK)
		placed = piece
	if placed == 0:
		return false
	state.column += placed * direction
	state.feet -= placed
	return true


func _build_bridge(state: Dictionary) -> bool:
	var direction: int = state.direction
	var feet: int = state.feet
	var column: int = state.column
	# It walks on, on the level (SkillBridge._find_floor_edge: anything at
	# body height, even a ramp's low step, comes first and there is no
	# bridge), to where the ground ends. Checked by half column.
	if feet % UNITS_PER_CELL != 0:
		return false
	var found := false
	for walk in 64:
		var ahead := column + direction
		var halves := [ahead * 2, ahead * 2 + 1] if direction > 0 else [ahead * 2 + 1, ahead * 2]
		var edge := false
		for half: int in halves:
			if _half_unit(state, half, feet - 1) != Unit.AIR:
				return false
			if _half_unit(state, half, feet) == Unit.AIR:
				edge = true
				break
		if edge:
			found = true
			break
		column = ahead
	if not found:
		return false
	var placed := 0
	for piece in BRIDGE_PIECES:
		var at := column + direction * (piece + 1)
		if _unit(state, at, feet) != Unit.AIR or _body_blocked(state, at, feet):
			break
		_set_unit(state, at, feet, Unit.BRICK)
		placed += 1
	if placed == 0:
		return false
	state.column = column
	state.feet = feet
	return true


## Hands the tool to the lemming at that point. False if it does nothing
## there (the state is then of no use).
func _apply(state: Dictionary, tool: String) -> bool:
	if tool in TRAITS:
		if state.traits.has(tool):
			return false
		state.traits[tool] = true
		return true
	if tool in CARRIED and tool != "bridge":
		if state.carried != "":
			return false
		state.carried = tool
		return true
	match tool:
		"digger":
			return _dig_down(state)
		"builder":
			return _build_stairs(state)
		"bridge":
			return _build_bridge(state)
	return false


# --- Search ---------------------------------------------------------------------

func _start_state() -> Dictionary:
	return {"column": _spawn.x, "feet": _spawn.y * UNITS_PER_CELL, "direction": _spawn_direction,
		"changes": {}, "ladders": {}, "traits": {}, "carried": "", "collected": 0, "inventory": {},
		"walked": 0, "tools_used": 0, "parent": -1, "move": {}, "carried_used_at": -1}


func _copy(state: Dictionary) -> Dictionary:
	var copy := state.duplicate()
	copy.changes = state.changes.duplicate()
	copy.ladders = state.ladders.duplicate()
	copy.traits = state.traits.duplicate()
	copy.inventory = state.inventory.duplicate()
	return copy


## Best first: every state is walked as soon as it is made, and scored by
## the tools it used and how near the exit its walk got. Two states whose
## walks end the same way (same places reached, same tools left) are one.
func _search() -> Dictionary:
	var nodes: Array[Dictionary] = []
	var open: Array[int] = []
	var seen := {}
	var start := _start_state()
	_walk_node(start)
	nodes.append(start)
	if start.walk.end == "exit":
		return _result(nodes, 0)
	open.append(0)
	var expansions := 0
	while not open.is_empty():
		var best := 0
		for index in open.size():
			if nodes[open[index]].score < nodes[open[best]].score:
				best = index
		var node_index: int = open[best]
		open.remove_at(best)
		var node := nodes[node_index]
		expansions += 1
		if expansions > MAX_EXPANSIONS or nodes.size() > MAX_NODES:
			return _failure(nodes, "search too large")
		for child in _children(node):
			child.parent = node_index
			_walk_node(child)
			var key := _outcome_key(child)
			if seen.has(key):
				continue
			seen[key] = true
			nodes.append(child)
			if child.walk.end == "exit":
				return _result(nodes, nodes.size() - 1)
			if not child.walk.points.is_empty():
				open.append(nodes.size() - 1)
	return _failure(nodes, "exit not reachable")


## A search that did not reach the exit: why, and the way to the place
## nearest it that was reached ("nearest": like a solution, with "point",
## the column and floor row of that place), which the generator can move
## the exit to.
func _failure(nodes: Array[Dictionary], reason: String) -> Dictionary:
	var best := _best_node(nodes)
	# The point of that walk nearest the exit where an exit could stand: on
	# a whole block of terrain (not a ramp or a brick).
	var points: Array = nodes[best].walk.points
	var chosen := -1
	var chosen_distance := 1 << 30
	for index in points.size():
		var point: Dictionary = points[index]
		var feet: int = point.feet
		if feet % UNITS_PER_CELL != 0:
			continue
		var below := _unit(nodes[best].after, point.column, feet)
		if below == Unit.AIR or below == Unit.BRICK:
			continue
		var distance: int = absi(int(point.column) - _exit.x) + ROW_WEIGHT * absi(feet / UNITS_PER_CELL - _exit.y)
		if distance < chosen_distance:
			chosen_distance = distance
			chosen = index
	var failure := {"solved": false, "reason": reason, "best": _describe(nodes, best)}
	if chosen >= 0:
		var nearest := _result(nodes, best, chosen)
		var point: Dictionary = points[chosen]
		nearest["point"] = Vector2i(point.column, int(point.feet) / UNITS_PER_CELL)
		nearest["on_whole_block"] = true
		failure["nearest"] = nearest
	return failure


func _best_node(nodes: Array[Dictionary]) -> int:
	var best := 0
	for index in nodes.size():
		if nodes[index].score - int(nodes[index].tools_used) * TOOL_WEIGHT < nodes[best].score - int(nodes[best].tools_used) * TOOL_WEIGHT:
			best = index
	return best


## For a search that failed: the tools of the walk that got nearest the
## exit, and where that walk ended.
func _describe(nodes: Array[Dictionary], index: int) -> String:
	var moves := PackedStringArray()
	var at := index
	while at >= 0:
		var move: Dictionary = nodes[at].move
		if not move.is_empty():
			moves.insert(0, "%s@%d,%d" % [move.tool, move.column, move.feet / UNITS_PER_CELL])
		at = int(nodes[at].parent)
	var points: Array = nodes[index].walk.points
	var last: Dictionary = points.back() if not points.is_empty() else {"column": -1, "feet": -1}
	return "%s -> %s at %d,%d (%d nodes)" % [" ".join(moves), nodes[index].walk.end, last.column, last.feet / UNITS_PER_CELL, nodes.size()]


## Walks the state and scores it.
func _walk_node(node: Dictionary) -> void:
	var walked := _copy(node)
	node.walk = _walk(walked)
	node.after = walked
	var nearest := 1 << 30
	node.nearest_index = 0
	var points: Array = node.walk.points
	for index in points.size():
		var point: Dictionary = points[index]
		var distance: int = absi(int(point.column) - _exit.x) + ROW_WEIGHT * absi(int(point.feet) / UNITS_PER_CELL - _exit.y)
		if distance < nearest:
			nearest = distance
			node.nearest_index = index
	node.score = int(node.tools_used) * TOOL_WEIGHT + nearest


## What a walk came to: where it went and with what.
func _outcome_key(node: Dictionary) -> String:
	var after: Dictionary = node.after
	var reached := PackedInt32Array()
	for point: Dictionary in node.walk.points:
		reached.append(int(point.column) * 4096 + int(point.feet))
	reached.sort()
	return "%s|%d|%s|%s|%s|%d|%d" % [node.walk.end, hash(reached), after.carried, ",".join(after.traits.keys()),
		str(after.inventory), after.collected, hash(after.changes.keys())]


## Every useful tool at every point worth trying it on this node's walk.
func _children(node: Dictionary) -> Array[Dictionary]:
	var children: Array[Dictionary] = []
	var walk: Dictionary = node.walk
	var points: Array = walk.points
	var segment_starts := {0: true}
	for event_index: int in walk.events:
		segment_starts[event_index + 1] = true
	for index in points.size():
		var point: Dictionary = points[index]
		var at_segment_start := segment_starts.has(index)
		var near_event := false
		for ahead in range(index, mini(index + 3, points.size())):
			if walk.events.has(ahead):
				near_event = true
		var column: int = point.column
		var near_hint := _hints.any(func(hint: int) -> bool: return absi(hint - column) <= 1)
		if not (at_segment_start or near_event or near_hint):
			continue
		for tool in _tools_at(node, point):
			if tool == "bridge":
				if not (at_segment_start or near_event):
					continue
			elif tool in CARRIED or tool in TRAITS:
				if not at_segment_start:
					continue
			elif not (near_event or near_hint):
				continue
			var child := _state_at(node, index)
			if not _apply(child, tool):
				continue
			if not _unlimited:
				child.inventory[tool] = int(child.inventory[tool]) - 1
			child.tools_used = int(node.tools_used) + 1
			child.move = {"tool": tool, "column": point.column, "feet": point.feet, "direction": point.direction, "collected": point.collected, "point_index": index}
			children.append(child)
	return children


## The tools the lemming could be handed at that point.
func _tools_at(node: Dictionary, point: Dictionary) -> Array[String]:
	var tools: Array[String] = []
	if _unlimited:
		for tool in _allowed:
			if not (tool in TRAITS and node.traits.has(tool)):
				tools.append(tool)
		return tools
	var inventory := _inventory_at(node, int(point.collected))
	for tool: String in inventory:
		if int(inventory[tool]) > 0 and tool in TOOLS:
			tools.append(tool)
	return tools


## The node's inventory with the items picked up on its walk by a point.
func _inventory_at(node: Dictionary, collected: int) -> Dictionary:
	var inventory: Dictionary = node.inventory.duplicate()
	for index in _spots.size():
		var bit := 1 << index
		if collected & bit and not int(node.collected) & bit:
			var spot: Dictionary = _spots[index]
			inventory[spot.tool_id] = int(inventory.get(spot.tool_id, 0)) + int(spot.amount)
	return inventory


## The state when the lemming stands at that point of the node's walk.
func _state_at(node: Dictionary, index: int) -> Dictionary:
	var point: Dictionary = node.walk.points[index]
	var child := _copy(node)
	child.column = point.column
	child.feet = point.feet
	child.direction = point.direction
	child.collected = point.collected
	child.inventory = _inventory_at(node, int(point.collected))
	child.walked = int(node.walked) + index
	child.carried_used_at = -1
	# A tool carried to a wall earlier on this walk has been used by then.
	var used_at: int = node.after.carried_used_at
	if used_at >= 0 and index >= used_at:
		child.changes = node.after.changes.duplicate()
		child.ladders = node.after.ladders.duplicate()
		child.carried = ""
	child.parent = -1
	child.move = {}
	return child


## The moves and the path to node `last`, its own walk followed to its end
## or, with until_last, to that point of it.
func _result(nodes: Array[Dictionary], last: int, until_last: int = -1) -> Dictionary:
	var chain: Array[Dictionary] = []
	var index := last
	while index >= 0:
		chain.push_front(nodes[index])
		index = int(nodes[index].parent)
	var steps: Array[Dictionary] = []
	var path: Array[Vector3i] = []
	for chain_index in chain.size():
		var node := chain[chain_index]
		if not node.move.is_empty():
			var move: Dictionary = node.move
			var collect_first: Array[Vector2i] = []
			for spot_index in _spots.size():
				if int(move.collected) & (1 << spot_index):
					collect_first.append(Vector2i(_spots[spot_index].column, _spots[spot_index].row))
			steps.append({"tool": move.tool, "column": move.column, "row": ceili(float(move.feet) / UNITS_PER_CELL),
				"feet": move.feet, "direction": move.direction, "collect_first": collect_first, "path_index": path.size() - 1})
		# This node's walk up to where the next tool was handed over.
		var points: Array = node.walk.points
		var until := points.size() - 1
		if chain_index + 1 < chain.size():
			until = int(chain[chain_index + 1].move.point_index)
		elif until_last >= 0:
			until = until_last
		for point_index in until + 1:
			var point: Dictionary = points[point_index]
			path.append(Vector3i(point.column, point.feet, point.direction))
	var last_node: Dictionary = nodes[last]
	return {"solved": true, "steps": steps, "path": path, "walk_steps": path.size()}
