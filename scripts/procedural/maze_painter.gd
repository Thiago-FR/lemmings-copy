class_name MazePainter
extends RefCounted
## Turns a MazeLayout into terrain cells (MazeLayout.EMPTY, EARTH, CONCRETE),
## row by row. Every measure that makes a link work for the lemmings lives
## here; the comments say which rule of the game each one keeps (see
## docs/estado_atual.md: steps of 32px are walls, falls over 80px kill, a
## body 30px tall fits under one block).
##
## Rooms also get a look from a small library of ceiling styles (open hall,
## cave ceiling, stalactites, a shelf, a low roof). Decoration only goes above
## the CLEAR_HEIGHT rows over each floor and never where a link needs the
## air, so it never changes how the maze plays.


enum CeilingStyle { HALL, CAVE, STALACTITES, SHELF, LOW_ROOF }

var _cells := PackedByteArray()
var _layout: MazeLayout
var _rng: RandomNumberGenerator
## room -> columns whose whole height must stay as built (staircases,
## ladder shafts).
var _protected: Dictionary = {}


static func paint(layout: MazeLayout, rng: RandomNumberGenerator, open_sky: bool) -> PackedByteArray:
	var painter := MazePainter.new()
	painter._layout = layout
	painter._rng = rng
	painter._paint(open_sky)
	return painter._cells


func _paint(open_sky: bool) -> void:
	_cells.resize(MazeLayout.COLUMNS * MazeLayout.ROWS)
	_cells.fill(MazeLayout.EARTH)
	_paint_separators_and_floors()
	_carve_rooms()
	for link in _layout.links:
		match link.kind:
			MazeLayout.LinkKind.OPEN:
				_carve_doorway(link.separator, link.band)
			MazeLayout.LinkKind.WALL:
				_paint_wall(link)
			MazeLayout.LinkKind.BRIDGE:
				_paint_trough(link)
			MazeLayout.LinkKind.STAIRS:
				_paint_stairs(link)
			MazeLayout.LinkKind.LADDER:
				_paint_ladder(link)
	for room in MazeLayout.ROOM_COUNT:
		if not _layout.reachable_rooms.has(room):
			_fill_room(room)
		elif not (open_sky and MazeLayout.room_band(room) == 0):
			_decorate(room)
	_paint_border()


func _put(column: int, row: int, cell: int) -> void:
	if column < 0 or row < 0 or column >= MazeLayout.COLUMNS or row >= MazeLayout.ROWS:
		return
	_cells[row * MazeLayout.COLUMNS + column] = cell


func _cell(column: int, row: int) -> int:
	return _cells[row * MazeLayout.COLUMNS + column]


func _paint_border() -> void:
	for column in MazeLayout.COLUMNS:
		_put(column, 0, MazeLayout.CONCRETE)
		_put(column, MazeLayout.ROWS - 1, MazeLayout.CONCRETE)
	for row in MazeLayout.ROWS:
		_put(0, row, MazeLayout.CONCRETE)
		_put(MazeLayout.COLUMNS - 1, row, MazeLayout.CONCRETE)


func _paint_separators_and_floors() -> void:
	for room in MazeLayout.ROOM_COUNT:
		var floor_row := MazeLayout.floor_row(MazeLayout.room_band(room))
		for column in range(MazeLayout.first_column(room), MazeLayout.last_column(room) + 1):
			_put(column, floor_row, _layout.floor_materials[room])
	for band in MazeLayout.ROOM_ROWS:
		for separator in range(1, MazeLayout.SEPARATOR_COLUMNS.size() - 1):
			var material: int = _layout.separator_materials.get("%d:%d" % [band, separator], MazeLayout.EARTH)
			for row in range(MazeLayout.top_row(band), MazeLayout.floor_row(band) + 1):
				_put(MazeLayout.SEPARATOR_COLUMNS[separator], row, material)


func _carve_rooms() -> void:
	for room in MazeLayout.ROOM_COUNT:
		var band := MazeLayout.room_band(room)
		for row in range(MazeLayout.top_row(band), MazeLayout.floor_row(band)):
			for column in range(MazeLayout.first_column(room), MazeLayout.last_column(room) + 1):
				_put(column, row, MazeLayout.EMPTY)


func _carve_doorway(separator: int, band: int) -> void:
	var floor_row := MazeLayout.floor_row(band)
	for row in range(floor_row - MazeLayout.DOORWAY_HEIGHT, floor_row):
		_put(separator, row, MazeLayout.EMPTY)


## The whole separator in this band, so the tunnel dug at walking height is
## the only way through. A tunnel is one block tall: the 30px body fits.
func _paint_wall(link: Dictionary) -> void:
	var band: int = link.band
	for row in range(MazeLayout.top_row(band), MazeLayout.floor_row(band)):
		_put(link.separator, row, link.material)


## One block deep: a lemming falling in drops 32px and the sides, a block
## tall, are walls it cannot walk up (it would need 30px or less). The
## bottom is concrete so a shovel cannot open it onto the room below.
func _paint_trough(link: Dictionary) -> void:
	var band: int = link.band
	var floor_row := MazeLayout.floor_row(band)
	_carve_doorway(link.separator, band)
	for column in range(link.trough_first, link.trough_last + 1):
		_put(column, floor_row, MazeLayout.EMPTY)
		_put(column, floor_row + 1, MazeLayout.CONCRETE)


## The patch is earth whatever the floor is made of. Under it, step k (1 to 5)
## stands 2k rows below the floor, k - 1 columns away from the separator, and
## is solid down to the floor below; the floor below is one row under the
## last step. Each drop is 64px. The separator is the back wall of the first
## step, so whoever lands there facing it turns and walks down.
func _paint_stairs(link: Dictionary) -> void:
	var band: int = link.band
	var side: int = link.side
	var floor_row := MazeLayout.floor_row(band)
	var lower_floor := MazeLayout.floor_row(band + 1)
	var lower := MazeLayout.room_id(MazeLayout.room_column(link.a), band + 1)
	_put(link.column, floor_row, MazeLayout.EARTH)
	for step in range(1, MazeLayout.STAIR_STEPS + 1):
		var column: int = link.column - side * (step - 1)
		for row in range(floor_row + 2 * step, lower_floor):
			_put(column, row, _layout.floor_materials[lower])
		_protect(lower, column)


## The separator in the upper band keeps a one-block sill (the top of the
## wall the ladder leans on) with an opening above it; the floor above the
## shaft is cut through; a curb two blocks tall stands beside the shaft top
## in the room above it. The wall is 12 blocks from the lower floor to the
## sill's top: the ladder's 12 pieces exactly.
func _paint_ladder(link: Dictionary) -> void:
	var band: int = link.band
	var side: int = link.side
	var floor_row := MazeLayout.floor_row(band)
	var shaft: int = link.column
	var above := MazeLayout.room_id(MazeLayout.room_column(link.a), band)
	for row in range(floor_row - 1 - MazeLayout.DOORWAY_HEIGHT, floor_row - 1):
		_put(link.separator, row, MazeLayout.EMPTY)
	_put(shaft, floor_row, MazeLayout.EMPTY)
	for row in range(floor_row - MazeLayout.CURB_HEIGHT, floor_row):
		_put(shaft - side, row, _layout.floor_materials[above])
	_protect(link.a, shaft)
	_protect(above, shaft)
	_protect(above, shaft - side)


func _protect(room: int, column: int) -> void:
	if not _protected.has(room):
		_protected[room] = {}
	_protected[room][column] = true


## A room nobody can get into: solid rock, so the screen does not show
## empty chambers that lead nowhere.
func _fill_room(room: int) -> void:
	var band := MazeLayout.room_band(room)
	var material: int = _layout.floor_materials[room]
	for row in range(MazeLayout.top_row(band), MazeLayout.floor_row(band)):
		for column in range(MazeLayout.first_column(room), MazeLayout.last_column(room) + 1):
			if _cell(column, row) == MazeLayout.EMPTY and not _is_protected(room, column):
				_put(column, row, material)


func _is_protected(room: int, column: int) -> bool:
	return _protected.has(room) and _protected[room].has(column)


func _decorate(room: int) -> void:
	var band := MazeLayout.room_band(room)
	var top := MazeLayout.top_row(band)
	# Lowest row decoration may fill: CLEAR_HEIGHT rows of air stay above the
	# floor, and one more under it so nothing hangs at head height.
	var lowest := MazeLayout.floor_row(band) - MazeLayout.CLEAR_HEIGHT - 1
	if lowest < top:
		return
	var material: int = _layout.floor_materials[room]
	var first := MazeLayout.first_column(room)
	var last := MazeLayout.last_column(room)
	var depths := {}
	match _rng.randi_range(0, CeilingStyle.size() - 1):
		CeilingStyle.CAVE:
			var depth := _rng.randi_range(0, lowest - top)
			for column in range(first, last + 1):
				depth = clampi(depth + _rng.randi_range(-1, 1), 0, lowest - top + 1)
				depths[column] = depth
		CeilingStyle.STALACTITES:
			for count in _rng.randi_range(1, 3):
				depths[_rng.randi_range(first, last)] = lowest - top + 1
		CeilingStyle.SHELF:
			var shelf_row := _rng.randi_range(top + 1, lowest)
			var start := _rng.randi_range(first, last - 2)
			for column in range(start, mini(start + _rng.randi_range(3, 5), last + 1)):
				if not _is_protected(room, column):
					_put(column, shelf_row, material)
		CeilingStyle.LOW_ROOF:
			for column in range(first, last + 1):
				depths[column] = lowest - top + 1 - (1 if _rng.randf() < 0.3 else 0)
	for column: int in depths:
		if _is_protected(room, column):
			continue
		for row in range(top, top + int(depths[column])):
			if _cell(column, row) == MazeLayout.EMPTY:
				_put(column, row, material)
