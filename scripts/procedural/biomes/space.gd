extends StageBiome
## A spaceship in the void: a long hull with the engines at the left and
## the bridge in the nose at the right; inside, decks one above the other,
## bulkheads with doors, shafts between the decks with a ladder up, and
## hatches in the roof (a ladder up each) to walk out on the hull.
## Asteroids drift around it. A fall outside is a fall into space.


func _init() -> void:
	id = &"space"
	name = "Espaço"
	kind = LevelEnvironment.Kind.SPACE
	order = 100
	stages.assign(["Estação", "Cinturão de Asteroides", "Última Doca"])
	shapes.assign([Shape.WIDE, Shape.BOTH, Shape.BOTH])
	routes.assign([Route.TRAVERSE, Route.ASCEND, Route.TRAVERSE])
	floating_ground = true
	# Open space all round: no border, falling off is falling away.
	walled = false
	# The ship paints its own inside; outside is the void.
	inside_wall = &""


func build(g: BiomeStageGenerator) -> void:
	var left := 4
	var right := g.stage_columns - 6
	var centre := g.stage_rows / 2
	var half_height := clampi(g.stage_rows / 2 - 5, 6, 26)
	var tops := PackedInt32Array()
	var bottoms := PackedInt32Array()
	tops.resize(g.stage_columns)
	bottoms.resize(g.stage_columns)
	tops.fill(-1)
	# The hull's outline: full height along the body, tapering to the nose.
	for column in range(left, right + 1):
		var t := float(column - left) / float(right - left)
		var height := half_height
		if t > 0.72:
			height = maxi(4, roundi(half_height * (1.0 - (t - 0.72) / 0.28 * 0.75)))
		tops[column] = centre - height
		bottoms[column] = centre + height
		g.fill_cells(column, tops[column], column, tops[column] + 1, CONCRETE)
		g.fill_cells(column, bottoms[column] - 1, column, bottoms[column], CONCRETE)
	g.fill_cells(left, tops[left], left + 1, bottoms[left], CONCRETE)
	g.fill_cells(right - 1, tops[right], right, bottoms[right], CONCRETE)
	# The nose's slanted plating follows the outline column to column.
	for column in range(left + 1, right + 1):
		for row in range(mini(tops[column], tops[column - 1]), maxi(tops[column], tops[column - 1]) + 1):
			g.set_cell_kind(column, row, CONCRETE)
		for row in range(mini(bottoms[column], bottoms[column - 1]), maxi(bottoms[column], bottoms[column - 1]) + 1):
			g.set_cell_kind(column, row, CONCRETE)
	# Engines sticking out at the back.
	for engine in [centre - half_height / 2, centre + half_height / 2]:
		g.fill_cells(left - 3, engine - 1, left - 1, engine + 1, CONCRETE)
	# Decks every 6 rows, with shafts between them.
	var deck_rows: Array[int] = []
	var deck := bottoms[left] - 1
	while deck - 6 > tops[left] + 3:
		deck -= 6
		deck_rows.append(deck)
		var from := left + 2
		var to := right - 2
		for column in range(from, to + 1):
			if deck > tops[column] + 2 and deck < bottoms[column] - 2:
				g.set_cell_kind(column, deck, CONCRETE)
		for shaft in 1 + g.stage_tier:
			var at := g.rng.randi_range(from + 4, (left + right) / 2 + 6)
			g.set_cell_kind(at, deck, EMPTY)
			g.set_cell_kind(at + 1, deck, EMPTY)
			# Every shaft has its ladder (no tool goes up through a hole in a
			# ceiling), its top rung level with the deck, so the climber
			# steps off onto the deck beside the hole.
			for row in range(deck, deck + 6):
				if g.cell_kind(at, row) == EMPTY:
					g.ladder_cells.append(Vector2i(at, row))
	# Bulkheads with a door on every deck, now and then one shut (to bash).
	var bulkheads: Array[int] = []
	var bulkhead := left + g.rng.randi_range(10, 14)
	while bulkhead < right - 10:
		bulkheads.append(bulkhead)
		for row in range(tops[bulkhead] + 2, bottoms[bulkhead] - 1):
			if g.cell_kind(bulkhead, row) == EMPTY:
				g.set_cell_kind(bulkhead, row, CONCRETE)
		var floors := deck_rows.duplicate()
		floors.append(bottoms[bulkhead] - 1)
		for floor_row in floors:
			if floor_row <= tops[bulkhead] + 3 or floor_row >= bottoms[bulkhead]:
				continue
			var shut := g.rng.randf() < 0.2 + g.stage_tier * 0.1
			for row in range(floor_row - 3, floor_row):
				g.set_cell_kind(bulkhead, row, EARTH if shut else EMPTY)
			if shut:
				g.add_need("basher", bulkhead)
		bulkhead += g.rng.randi_range(10, 15)
	# Hatches in the roof, onto the hull.
	for hatch in 1 + g.stage_tier:
		var at := g.rng.randi_range(left + 8, right - 12)
		g.set_cell_kind(at, tops[at] + 1, EMPTY)
		g.set_cell_kind(at + 1, tops[at] + 1, EMPTY)
		g.set_cell_kind(at, tops[at], EMPTY)
		g.set_cell_kind(at + 1, tops[at], EMPTY)
		# A ladder up through the hatch from the top deck's floor: there is
		# no wall under a hatch for a ladder to go up.
		var row := tops[at]
		while row < bottoms[at] and g.cell_kind(at, row + 1) == EMPTY:
			g.ladder_cells.append(Vector2i(at, row))
			row += 1
		g.ladder_cells.append(Vector2i(at, row))
	# The bridge: a window band in the nose.
	for row in range(centre - 1, centre + 1):
		g.set_cell_kind(right - 1, row, EMPTY)
	for row in range(g.stage_rows):
		for column in range(g.stage_columns):
			if g.cell_kind(column, row) != EMPTY:
				g.cell_skins[Vector2i(column, row)] = TerrainSkin.HULL
	# Everything inside the hull is the ship's inner wall.
	for column in range(left + 1, right):
		for row in range(tops[column] + 2, bottoms[column] - 1):
			if g.cell_kind(column, row) == EMPTY:
				g.backdrop_skins[Vector2i(column, row)] = TerrainSkin.STATION_INSIDE
	# Asteroids around the ship.
	for rock in 4 + g.stage_tier * 2:
		var at := Vector2i(g.rng.randi_range(4, g.stage_columns - 5), g.rng.randi_range(2, g.stage_rows - 3))
		if at.y > tops[clampi(at.x, left, right)] - 3 and at.y < bottoms[clampi(at.x, left, right)] + 3 and at.x >= left - 4 and at.x <= right + 2:
			continue
		g.blob(at, Vector2(2.4, 1.5), EARTH)
	g.spawn_cell = Vector2i(left + 4, bottoms[left] - 1)
	if g.stage_route == Route.ASCEND:
		var top_column := (left + right) / 2
		g.exit_cell = Vector2i(top_column, tops[top_column])
	else:
		g.exit_cell = Vector2i(right - 4, bottoms[right - 4] - 1)
	_furnish_ship(g, left, right, tops, bottoms, deck_rows, bulkheads, centre)
	g.scatter_bonus(3)


## Gives every compartment of the ship (between two bulkheads, between two
## decks) a use: the engine room at the back, the bridge in the nose at the
## window's height, the rest of the ship's rooms mixed in between. A cargo
## hold gets crates on its floor, low enough to step over, that can be dug.
func _furnish_ship(g: BiomeStageGenerator, left: int, right: int, tops: PackedInt32Array, bottoms: PackedInt32Array, deck_rows: Array[int], bulkheads: Array[int], centre: int) -> void:
	var walls: Array[int] = [left + 1]
	walls.append_array(bulkheads)
	walls.append(right - 1)
	var floors: Array[int] = deck_rows.duplicate()
	floors.sort()
	floors.append(g.stage_rows)
	# floor index -> the kind of the room last furnished on that floor, so
	# two rooms side by side or one over the other are never the same.
	var left_kinds := {}
	for index in walls.size() - 1:
		var from := walls[index] + 1
		var ceiling := tops[from] + 1
		var above_kind := &""
		for floor_index in floors.size():
			var floor_row := floors[floor_index]
			var bottom := floor_row
			if floor_row == g.stage_rows:
				bottom = ceiling + 1
				while bottom < g.stage_rows and g.cell_kind(from, bottom) == EMPTY:
					bottom += 1
				# Only the hull's floor: past it is space (an asteroid).
				if bottom > bottoms[from]:
					continue
			var rect := _room_rect(g, from, walls[index + 1] - 1, ceiling + 1, bottom)
			ceiling = floor_row
			if rect.size.x < 4 or rect.size.y < 3:
				continue
			var kind: StringName
			if index == 0:
				kind = RoomDecor.ENGINE
			elif index == walls.size() - 2 and rect.position.y <= centre and rect.end.y >= centre:
				kind = RoomDecor.BRIDGE
			else:
				var choices := RoomDecor.SHIP_ROOMS.filter(func(other: StringName) -> bool:
					return other != above_kind and other != left_kinds.get(floor_index, &""))
				kind = choices[g.rng.randi_range(0, choices.size() - 1)]
			left_kinds[floor_index] = kind
			above_kind = kind
			g.furnished_rooms.append({"kind": kind, "rect": rect})
			if kind == RoomDecor.CARGO:
				_stack_crates(g, rect)


## The air of a room from the column from to at most to, rows top to
## bottom - 1, cut short where the hull closes in (the nose).
func _room_rect(g: BiomeStageGenerator, from: int, to: int, top: int, bottom: int) -> Rect2i:
	var last := from - 1
	for column in range(from, to + 1):
		var open := true
		for row in range(top, bottom):
			if g.cell_kind(column, row) != EMPTY:
				open = false
				break
		if not open or g.cell_kind(column, bottom) == EMPTY and g.cell_kind(column - 1, bottom) == EMPTY and g.cell_kind(column + 1, bottom) == EMPTY:
			break
		last = column
	return Rect2i(from, top, last - from + 1, bottom - top)


func _stack_crates(g: BiomeStageGenerator, room: Rect2i) -> void:
	var floor_row := room.end.y
	for column in range(room.position.x + 2, room.end.x - 2):
		var cell := Vector2i(column, floor_row - 1)
		if g.rng.randf() > 0.4 or g.cell_kind(column, floor_row) == EMPTY or cell in g.ladder_cells:
			continue
		if absi(column - g.spawn_cell.x) <= 2 or absi(column - g.exit_cell.x) <= 2:
			continue
		g.set_cell_kind(column, floor_row - 1, EARTH)
		g.cell_skins[cell] = TerrainSkin.CRATE
