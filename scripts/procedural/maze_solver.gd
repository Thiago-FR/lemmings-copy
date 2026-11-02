class_name MazeSolver
extends RefCounted
## Reachability model of a MazeLayout: can ONE lemming, starting
## at the entrance with an empty tool bar, reach the exit using only the
## items it collects on the way? One lemming is the worst case (a troop can
## split up and collect in two places at once, a lone lemming cannot), and
## an empty bar the poorest start, so a stage that passes is solvable
## whatever the run carries into it.
##
## The model works on pens: rooms joined by free two-way links (doorways,
## and walls or troughs already opened). A lemming paces its whole pen, so
## it collects every item in it, and can open any obstacle on its edge,
## provided the pen is stable. A pen with a free one-way exit (a trough to
## fall into, a dug hole, a ladder already up) is a transit pen: the
## lemming leaves it on its own, so the model collects nothing there and
## only lets it take that exit, or bridge the trough it is about to fall
## into (a bridge is handed out early and carried to the hole). That keeps
## the model on the safe side of what the player can actually do.
##
## Search: breadth-first over (pen, links opened, items collected, charges
## left), so the solution found uses the fewest moves.

const MAX_STATES := 40000

var _layout: MazeLayout
var _pen_cache: Dictionary = {}


static func solve(layout: MazeLayout) -> Dictionary:
	var solver := MazeSolver.new()
	solver._layout = layout
	return solver._search(false)


## The same search with every tool in endless supply: whether the exit can
## be reached at all, and by which route. The generator places the items
## along that route.
static func solve_unlimited(layout: MazeLayout) -> Dictionary:
	var solver := MazeSolver.new()
	solver._layout = layout
	return solver._search(true)


## Rooms the entrance can get to if every obstacle could be opened, over the
## links' directions alone (no pens, no transit rule): a quick upper bound
## used to pick the exit. Returns room -> obstacles crossed on the way.
static func rough_reach(layout: MazeLayout) -> Dictionary:
	var distance := {layout.spawn_room: 0}
	var frontier: Array[int] = [layout.spawn_room]
	# Free moves cost nothing, obstacles one: a 0-1 breadth-first search.
	while not frontier.is_empty():
		var node: int = frontier.pop_front()
		for link in layout.links:
			var targets: Array[int] = []
			if link.a == node:
				targets.append(link.b)
			if link.b == node and (link.two_way or link.kind == MazeLayout.LinkKind.OPEN):
				targets.append(link.a)
			var cost := 0 if link.tools.is_empty() else 1
			for target in targets:
				var candidate: int = distance[node] + cost
				if not distance.has(target) or candidate < distance[target]:
					distance[target] = candidate
					if cost == 0:
						frontier.push_front(target)
					else:
						frontier.push_back(target)
	var rooms := {}
	for node in distance:
		if MazeLayout.is_room(node):
			rooms[node] = distance[node]
	return rooms


## Whether the lemmings would stay in this room's pen before anything is
## opened (no trough or other free exit leads out of it). The entrance has
## to be in such a pen, so the troop gathers its first items before moving.
static func is_stable_at_start(layout: MazeLayout, room: int) -> bool:
	var solver := MazeSolver.new()
	solver._layout = layout
	var opened := PackedByteArray()
	opened.resize(layout.links.size())
	var info := solver._pens(opened)
	return not info.exits.has(info.pen_of[room])


func _search(unlimited: bool) -> Dictionary:
	var opened := PackedByteArray()
	opened.resize(_layout.links.size())
	var start := {"pos": _layout.spawn_room, "opened": opened, "collected": 0, "inventory": {}, "parent": -1, "step": {}}
	_collect(start, unlimited)
	var states: Array[Dictionary] = [start]
	var visited := {_key(start, unlimited): true}
	var head := 0
	while head < states.size():
		if states.size() > MAX_STATES:
			return {"solved": false, "reason": "search too large", "states": states.size()}
		var state := states[head]
		var info := _pens(state.opened)
		var pen: int = info.pen_of[state.pos]
		var stable: bool = not info.exits.has(pen)
		if stable and info.pen_of[_layout.exit_room] == pen:
			return _result(states, head)
		for child in _children(state, head, info, pen, stable, unlimited):
			_collect(child, unlimited)
			var key := _key(child, unlimited)
			if visited.has(key):
				continue
			visited[key] = true
			states.append(child)
		head += 1
	return {"solved": false, "reason": "exit not reachable", "states": states.size()}


func _children(state: Dictionary, index: int, info: Dictionary, pen: int, stable: bool, unlimited: bool) -> Array[Dictionary]:
	var children: Array[Dictionary] = []
	if not stable:
		for exit_link in info.exits[pen]:
			var link := _layout.get_link(exit_link)
			children.append(_child(state, index, link.b, state.opened, state.inventory, {"link": link.id, "tool": "", "from": link.a}))
	for link in _layout.links:
		if link.tools.is_empty() or state.opened[link.id] == 1:
			continue
		if not stable and link.kind != MazeLayout.LinkKind.BRIDGE:
			continue
		var ends: Array[int] = [link.a]
		if link.two_way:
			ends.append(link.b)
		for end in ends:
			if info.pen_of[end] != pen:
				continue
			var target: int = link.b if end == link.a else link.a
			for tool: String in link.tools:
				if not unlimited and int(state.inventory.get(tool, 0)) <= 0:
					continue
				var opened: PackedByteArray = state.opened.duplicate()
				opened[link.id] = 1
				var inventory: Dictionary = state.inventory.duplicate()
				if not unlimited:
					inventory[tool] = int(inventory[tool]) - 1
				children.append(_child(state, index, target, opened, inventory, {"link": link.id, "tool": tool, "from": end}))
	return children


func _child(state: Dictionary, parent: int, pos: int, opened: PackedByteArray, inventory: Dictionary, step: Dictionary) -> Dictionary:
	return {"pos": pos, "opened": opened, "collected": state.collected, "inventory": inventory, "parent": parent, "step": step}


## Picks up every item in the lemming's pen, if it is a stable one.
func _collect(state: Dictionary, unlimited: bool) -> void:
	if unlimited:
		return
	var info := _pens(state.opened)
	var pen: int = info.pen_of[state.pos]
	if info.exits.has(pen):
		return
	for index in _layout.spots.size():
		var bit := 1 << index
		if state.collected & bit:
			continue
		var spot: Dictionary = _layout.spots[index]
		if spot.kind != MazeLayout.SpotKind.TOOL or info.pen_of[spot.room] != pen:
			continue
		state.collected |= bit
		state.inventory[spot.tool_id] = int(state.inventory.get(spot.tool_id, 0)) + int(spot.amount)


func _key(state: Dictionary, unlimited: bool) -> String:
	var info := _pens(state.opened)
	var pen_part := "%d|%s" % [info.pen_of[state.pos], state.opened.hex_encode()]
	if unlimited:
		return pen_part
	var tools: Array = state.inventory.keys()
	tools.sort()
	var charges := PackedStringArray()
	for tool_id in tools:
		charges.append("%s=%d" % [tool_id, state.inventory[tool_id]])
	return "%s|%d|%s" % [pen_part, state.collected, ",".join(charges)]


## Pens for a set of opened links: pen_of[node] (the pen's lowest node id)
## and exits[pen] -> ids of the active free one-way links leaving it.
func _pens(opened: PackedByteArray) -> Dictionary:
	var cache_key := opened.hex_encode()
	if _pen_cache.has(cache_key):
		return _pen_cache[cache_key]
	var parent: Array[int] = []
	for node in _layout.node_count:
		parent.append(node)
	for link in _layout.links:
		if _joins_both_ways(link, opened):
			var root_a := _find(parent, link.a)
			var root_b := _find(parent, link.b)
			parent[maxi(root_a, root_b)] = mini(root_a, root_b)
	var pen_of: Array[int] = []
	for node in _layout.node_count:
		pen_of.append(_find(parent, node))
	var exits := {}
	for link in _layout.links:
		if _is_active_one_way(link, opened) and pen_of[link.a] != pen_of[link.b]:
			if not exits.has(pen_of[link.a]):
				exits[pen_of[link.a]] = []
			exits[pen_of[link.a]].append(link.id)
	var info := {"pen_of": pen_of, "exits": exits}
	_pen_cache[cache_key] = info
	return info


static func _find(parent: Array[int], node: int) -> int:
	while parent[node] != node:
		node = parent[node]
	return node


static func _joins_both_ways(link: Dictionary, opened: PackedByteArray) -> bool:
	if link.kind == MazeLayout.LinkKind.OPEN:
		return true
	return link.two_way and opened[link.id] == 1


static func _is_active_one_way(link: Dictionary, opened: PackedByteArray) -> bool:
	match link.kind:
		MazeLayout.LinkKind.TROUGH_FALL:
			for blocker: int in link.disabled_by:
				if opened[blocker] == 1:
					return false
			return true
		MazeLayout.LinkKind.STAIRS, MazeLayout.LinkKind.LADDER, MazeLayout.LinkKind.TROUGH_LADDER:
			return opened[link.id] == 1
	return false


## The path from the start to state `last`: the moves made ("steps": link,
## tool ("" for a free move), the node it was made from, and "collected",
## the spots taken by then) and, for every
## state along it, the rooms of the lemming's pen and whether that pen was
## stable ("trace", one entry more than steps).
func _result(states: Array[Dictionary], last: int) -> Dictionary:
	var chain: Array[Dictionary] = []
	var index := last
	while index >= 0:
		chain.push_front(states[index])
		index = states[index].parent
	var steps: Array[Dictionary] = []
	var trace: Array[Dictionary] = []
	var previous: Dictionary = {}
	for state in chain:
		if not state.step.is_empty():
			# Which spots were taken before this move (a bitmask over
			# layout.spots): whoever plays the solution collects them first.
			steps.append(state.step.merged({"collected": previous.collected}))
		previous = state
		var info := _pens(state.opened)
		var pen: int = info.pen_of[state.pos]
		var rooms: Array[int] = []
		for room in MazeLayout.ROOM_COUNT:
			if info.pen_of[room] == pen:
				rooms.append(room)
		trace.append({"rooms": rooms, "stable": not info.exits.has(pen), "pos": state.pos})
	return {"solved": true, "steps": steps, "trace": trace, "states": states.size()}
