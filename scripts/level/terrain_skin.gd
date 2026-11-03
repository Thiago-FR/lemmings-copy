class_name TerrainSkin
extends Node2D
## Draws a different look over some terrain cells without them being a
## different kind of block: a tree's trunk and leaves, a building's wall with
## windows, a space station's hull. The cells stay plain earth or concrete
## for the lemmings (dug, climbed and bashed the same way); only the picture
## changes, and a cell dug away loses its skin with it, since only cells the
## terrain still has are drawn (redrawn whenever the terrain changes).
##
## skins: cell (Vector2i) -> one of the SKIN_* names. Added as a child of
## the TerrainDestructible it dresses, after the terrain has its cells.

const BARK := &"bark"
const LEAVES := &"leaves"
const WALL := &"wall"
const HULL := &"hull"
const ALIEN_LEAVES := &"alien_leaves"
const ALIEN_STEM := &"alien_stem"
## Behind underground air: the rock wall of a mine or an ice cave, so going
## down reads as going inside.
const CAVE_WALL := &"cave_wall"
const ICE_WALL := &"ice_wall"
## Behind the air inside a station module: the inner wall of a room.
const STATION_INSIDE := &"station_inside"
## The stage's border, which nothing breaks: dark bedrock with iron bolts,
## so it reads as different from the ground.
const BORDER := &"border"
## A wooden crate in a ship's hold: earth for the lemmings (dug and bashed).
const CRATE := &"crate"
## Skins that draw their own edges (no grass or soil edge over them).
const SELF_DRAWN: Array[StringName] = [LEAVES, ALIEN_LEAVES, CRATE]

const OUTLINE := Color(0.08, 0.05, 0.06)
## Per skin: base, dark, light, accent.
const COLOURS := {
	BARK: [Color(0.42, 0.26, 0.14), Color(0.28, 0.17, 0.09), Color(0.55, 0.36, 0.20), Color(0.20, 0.12, 0.07)],
	LEAVES: [Color(0.20, 0.50, 0.26), Color(0.13, 0.37, 0.20), Color(0.28, 0.60, 0.32), Color(0.40, 0.72, 0.38)],
	WALL: [Color(0.44, 0.42, 0.46), Color(0.30, 0.29, 0.33), Color(0.56, 0.54, 0.58), Color(1.0, 0.86, 0.48)],
	HULL: [Color(0.52, 0.56, 0.62), Color(0.34, 0.37, 0.44), Color(0.72, 0.76, 0.82), Color(0.36, 0.86, 1.0)],
	ALIEN_LEAVES: [Color(0.58, 0.26, 0.62), Color(0.44, 0.17, 0.50), Color(0.70, 0.36, 0.74), Color(0.84, 0.52, 0.86)],
	BORDER: [Color(0.18, 0.17, 0.20), Color(0.11, 0.10, 0.13), Color(0.28, 0.27, 0.31), Color(0.55, 0.52, 0.48)],
	CAVE_WALL: [Color(0.17, 0.13, 0.11), Color(0.12, 0.09, 0.08), Color(0.22, 0.17, 0.14), Color(0.30, 0.24, 0.18)],
	STATION_INSIDE: [Color(0.20, 0.23, 0.32), Color(0.15, 0.17, 0.25), Color(0.26, 0.30, 0.40), Color(0.40, 0.85, 1.0)],
	ICE_WALL: [Color(0.28, 0.38, 0.52), Color(0.20, 0.28, 0.40), Color(0.38, 0.50, 0.64), Color(0.62, 0.80, 0.92)],
	CRATE: [Color(0.62, 0.44, 0.24), Color(0.44, 0.30, 0.16), Color(0.76, 0.58, 0.34), Color(0.30, 0.20, 0.10)],
	ALIEN_STEM: [Color(0.24, 0.48, 0.52), Color(0.14, 0.32, 0.36), Color(0.38, 0.66, 0.68), Color(0.10, 0.20, 0.22)],
}

var skins: Dictionary = {}
## Drawn on empty cells, behind the lemmings (they walk past it): a tree's
## trunk under its canopy. cell -> BARK or ALIEN_STEM.
var backdrop: Dictionary = {}
## The wall drawn behind enclosed air (CAVE_WALL, ICE_WALL, STATION_INSIDE),
## or none. Enclosed: rock somewhere above it and rock to both sides, close
## by, in its row; worked out from the cells themselves, so the wall always
## follows the rock (a cave opening onto a cliff shows the sky there) and a
## tunnel dug through a hill gets its wall too.
var inside_wall: StringName = &""
## The cells to look at (the stage's size).
var area := Rect2i()

## How close open sky may be before air stops counting as inside.
const INSIDE_MARGIN := 2
## Rock further up than this is not a ceiling: the air under a floating
## island or a high ledge is outside.
const MAX_CEILING := 8
## This much rock above makes any air underground.
const DEEP_ROCK := 6
enum Ceiling { NONE, CLOSE, DEEP }
## How far to each side a cave's walls may be.
const SIDE_REACH := 10
## Recomputed this far around a change (a change above can uncover cells
## below it in the same column; the margin reaches sideways).
const INSIDE_REACH := SIDE_REACH + 1

var _terrain: TerrainDestructible
## cell -> true for air that gets the inside wall.
var _inside: Dictionary = {}
var _back: Node2D
## Behind the portals (-1).
const BACKDROP_Z := -2


func _ready() -> void:
	_terrain = get_parent() as TerrainDestructible
	assert(_terrain != null, "A TerrainSkin dresses the TerrainDestructible it is a child of")
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_back = Node2D.new()
	_back.name = "Backdrop"
	_back.z_index = BACKDROP_Z
	_back.draw.connect(_draw_backdrop)
	add_child(_back)
	if inside_wall != &"":
		_find_inside(area.position.x, area.end.x - 1)
	_terrain.cells_changed.connect(func(coords: Array[Vector2i]) -> void:
		if inside_wall != &"" and not coords.is_empty():
			var from := coords[0].x
			var to := coords[0].x
			for cell in coords:
				from = mini(from, cell.x)
				to = maxi(to, cell.x)
			_find_inside(from - INSIDE_REACH, to + INSIDE_REACH)
		queue_redraw()
		_back.queue_redraw())


## The backdrop (cave walls, trunks) on a layer of its own behind the
## portals and the lemmings, which sit just behind the terrain (z -1).
func _draw_backdrop() -> void:
	var size := _terrain.get_cell_size()
	if inside_wall != &"":
		for cell: Vector2i in _inside:
			if not backdrop.has(cell):
				_draw_cave_wall(cell, Rect2(Vector2(cell) * size, size), COLOURS[inside_wall])
	for cell: Vector2i in backdrop:
		if _terrain.get_cell_source_id(cell) != -1:
			continue
		var rect := Rect2(Vector2(cell) * size, size)
		if backdrop[cell] == CAVE_WALL or backdrop[cell] == ICE_WALL or backdrop[cell] == STATION_INSIDE:
			_draw_cave_wall(cell, rect, COLOURS[backdrop[cell]])
		else:
			_draw_trunk(cell, rect, COLOURS[backdrop[cell]])


func _draw() -> void:
	var size := _terrain.get_cell_size()
	for cell: Vector2i in skins:
		if _terrain.get_cell_source_id(cell) == -1:
			continue
		var rect := Rect2(Vector2(cell) * size, size)
		match skins[cell]:
			BARK, ALIEN_STEM:
				_draw_bark(cell, rect, COLOURS[skins[cell]])
			LEAVES, ALIEN_LEAVES:
				_draw_leaves(cell, rect, COLOURS[skins[cell]])
			WALL:
				_draw_wall(cell, rect, COLOURS[WALL])
				_draw_outline(cell, rect)
			HULL:
				_draw_hull(cell, rect, COLOURS[HULL])
				_draw_outline(cell, rect)
			BORDER:
				_draw_border(cell, rect, COLOURS[BORDER])
			CRATE:
				_draw_crate(rect, COLOURS[CRATE])


## Works out which air is enclosed, for the columns from..to: air with
## rock not far above it (a ceiling), and no open-sky air (air with nothing above it)
## within INSIDE_MARGIN cells, so a cave mouth shows a lip of sky and the
## wall starts just inside, however wide the cave.
func _find_inside(from: int, to: int) -> void:
	var first := maxi(from, area.position.x)
	var last := mini(to, area.end.x - 1)
	for column in range(first, last + 1):
		for row in range(area.position.y, area.end.y):
			var cell := Vector2i(column, row)
			_inside.erase(cell)
			if _is_rock(cell):
				continue
			var ceiling := _ceiling_over(cell)
			if ceiling == Ceiling.NONE or ceiling == Ceiling.CLOSE and not _walled_sideways(cell):
				continue
			if not _open_sky_near(cell):
				_inside[cell] = true


## Rock to the left and to the right, not too far, in the cell's row: a
## cave has walls; the air under an island in the sky does not.
func _walled_sideways(cell: Vector2i) -> bool:
	for step in [-1, 1]:
		var found := false
		for offset in range(1, SIDE_REACH + 1):
			if _is_rock(cell + Vector2i(step * offset, 0)):
				found = true
				break
		if not found:
			return false
	return true


## What is over the cell: nothing (open sky, or a thin island far up), rock
## close above, or a lot of rock (deep underground, however high or wide
## the cavern).
func _ceiling_over(cell: Vector2i) -> Ceiling:
	var rock_above := 0
	var close := false
	for row in range(cell.y - 1, area.position.y - 1, -1):
		if _is_rock(Vector2i(cell.x, row)):
			close = close or cell.y - row <= MAX_CEILING
			rock_above += 1
			if rock_above >= DEEP_ROCK:
				return Ceiling.DEEP
	return Ceiling.CLOSE if close else Ceiling.NONE


func _is_covered(cell: Vector2i) -> bool:
	return _ceiling_over(cell) != Ceiling.NONE


func _open_sky_near(cell: Vector2i) -> bool:
	for dy in range(-INSIDE_MARGIN, INSIDE_MARGIN + 1):
		for dx in range(-INSIDE_MARGIN, INSIDE_MARGIN + 1):
			var near := cell + Vector2i(dx, dy)
			if not area.has_point(near):
				continue
			if not _is_rock(near) and _terrain.get_cell_source_id(near) == -1 and not _is_covered(near):
				return true
	return false


## Terrain that counts as rock around air: not a ladder, not a tree's
## leaves (the air under a crown is outside).
func _is_rock(cell: Vector2i) -> bool:
	return _terrain.get_cell_source_id(cell) == TerrainDestructible.TERRAIN_SOURCE_ID and skins.get(cell) != LEAVES and skins.get(cell) != ALIEN_LEAVES


## Dark rock with a few cracks and lumps, flat so the walls in front read.
func _draw_cave_wall(cell: Vector2i, rect: Rect2, colours: Array) -> void:
	_back.draw_rect(rect, colours[0])
	if _hash(cell, 31) % 3 == 0:
		_back.draw_rect(Rect2(rect.position + Vector2(float(_hash(cell, 33) % 20), float(_hash(cell, 35) % 24)), Vector2(8, 3)), colours[1])
	if _hash(cell, 37) % 4 == 0:
		_back.draw_circle(rect.position + Vector2(float(_hash(cell, 39) % 24) + 4.0, float(_hash(cell, 41) % 24) + 4.0), 3.0, colours[2])
	if _hash(cell, 43) % 11 == 0:
		_back.draw_circle(rect.get_center(), 1.5, colours[3])


## A trunk narrower than the cell, so it reads as standing in front of the
## sky rather than as a block.
func _draw_trunk(cell: Vector2i, rect: Rect2, colours: Array) -> void:
	var trunk := Rect2(rect.position + Vector2(8, 0), Vector2(16, rect.size.y))
	_back.draw_rect(trunk.grow_individual(2, 0, 2, 0), OUTLINE)
	_back.draw_rect(trunk, colours[0])
	_back.draw_rect(Rect2(trunk.position + Vector2(3, 0), Vector2(3, trunk.size.y)), colours[2])
	_back.draw_rect(Rect2(trunk.position + Vector2(11, 0), Vector2(2, trunk.size.y)), colours[1])
	if _hash(cell, 17) % 4 == 0:
		_back.draw_circle(trunk.get_center(), 2.5, colours[3])


## Vertical grain, a knot now and then.
func _draw_bark(cell: Vector2i, rect: Rect2, colours: Array) -> void:
	draw_rect(rect, colours[0])
	for stripe in 4:
		var x := rect.position.x + 3.0 + stripe * 7.0 + float(_hash(cell, stripe) % 3)
		draw_rect(Rect2(x, rect.position.y, 2.0, rect.size.y), colours[1] if stripe % 2 == 0 else colours[2])
	if _hash(cell, 9) % 5 == 0:
		draw_circle(rect.get_center() + Vector2(0, 4), 3.5, colours[3])


## A square block of foliage, for the crowns a lemming can climb on, drawn
## flat like the background pines: one green, a few soft clumps a shade
## lighter above and darker below, and where the crown meets the air a dark
## outline with a lit band on top and a shaded band underneath, so the
## crown reads as one shape against the sky.
func _draw_leaves(cell: Vector2i, rect: Rect2, colours: Array) -> void:
	const LINE := 2.0
	draw_rect(rect, colours[0])
	# Soft clumps on an 8 px grid: lighter in the upper half, darker below.
	for clump in 3:
		var at := Vector2(float(_hash(cell, 50 + clump) % 3) * 8.0 + 2.0, float(_hash(cell, 60 + clump) % 3) * 8.0 + 2.0)
		var shade: Color = colours[2] if at.y < 12.0 else colours[1]
		if _hash(cell, 70 + clump) % 3 == 0:
			continue
		draw_rect(Rect2(rect.position + at, Vector2(12, 6)), shade)
		draw_rect(Rect2(rect.position + at + Vector2(2, -2), Vector2(8, 2)), shade)
	var sides := _exposed_sides(cell)
	if Vector2i.UP in sides:
		draw_rect(Rect2(rect.position + Vector2(0, LINE), Vector2(rect.size.x, 5)), colours[2])
		draw_rect(Rect2(rect.position + Vector2(4, LINE + 1), Vector2(rect.size.x - 12, 2)), colours[3])
	if Vector2i.DOWN in sides:
		draw_rect(Rect2(rect.position + Vector2(0, rect.size.y - LINE - 6), Vector2(rect.size.x, 6)), colours[1])
	if Vector2i.LEFT in sides:
		draw_rect(Rect2(rect.position + Vector2(LINE, 0), Vector2(3, rect.size.y)), colours[2])
	if Vector2i.RIGHT in sides:
		draw_rect(Rect2(rect.position + Vector2(rect.size.x - LINE - 4, 0), Vector2(4, rect.size.y)), colours[1])
	for side in sides:
		match side:
			Vector2i.UP:
				draw_rect(Rect2(rect.position, Vector2(rect.size.x, LINE)), OUTLINE)
			Vector2i.DOWN:
				draw_rect(Rect2(rect.position + Vector2(0, rect.size.y - LINE), Vector2(rect.size.x, LINE)), OUTLINE)
			Vector2i.LEFT:
				draw_rect(Rect2(rect.position, Vector2(LINE, rect.size.y)), OUTLINE)
			Vector2i.RIGHT:
				draw_rect(Rect2(rect.position + Vector2(rect.size.x - LINE, 0), Vector2(LINE, rect.size.y)), OUTLINE)


## Planks with a frame and a cross brace.
func _draw_crate(rect: Rect2, colours: Array) -> void:
	var box := rect.grow(-1.0)
	draw_rect(box, OUTLINE)
	draw_rect(box.grow(-2.0), colours[0])
	for plank in range(1, 3):
		draw_rect(Rect2(box.position.x + 2, box.position.y + plank * 10.0, box.size.x - 4, 1.5), colours[1])
	draw_line(box.position + Vector2(5, 5), box.end - Vector2(5, 5), colours[2], 3.0)
	draw_line(Vector2(box.end.x - 5, box.position.y + 5), Vector2(box.position.x + 5, box.end.y - 5), colours[1], 3.0)
	draw_rect(Rect2(box.position + Vector2(2, 2), Vector2(box.size.x - 4, 4)), colours[3])
	draw_rect(Rect2(box.position + Vector2(2, box.size.y - 6), Vector2(box.size.x - 4, 4)), colours[3])
	draw_rect(Rect2(box.position + Vector2(2, 2), Vector2(4, box.size.y - 4)), colours[3])
	draw_rect(Rect2(box.position + Vector2(box.size.x - 6, 2), Vector2(4, box.size.y - 4)), colours[3])


## Concrete wall with a lit or dark window in most cells.
func _draw_wall(cell: Vector2i, rect: Rect2, colours: Array) -> void:
	draw_rect(rect, colours[0])
	draw_rect(Rect2(rect.position, Vector2(rect.size.x, 2.0)), colours[2])
	draw_rect(Rect2(rect.position + Vector2(0, rect.size.y - 2.0), Vector2(rect.size.x, 2.0)), colours[1])
	if _hash(cell, 1) % 6 == 0:
		return
	var window := Rect2(rect.position + Vector2(8, 7), Vector2(16, 17))
	var lit := _hash(cell, 2) % 3 == 0
	draw_rect(window.grow(1.0), colours[1])
	draw_rect(window, colours[3] if lit else Color(0.16, 0.20, 0.30))
	draw_rect(Rect2(window.position + Vector2(7, 0), Vector2(2, window.size.y)), colours[1])


## Big dark stones with a bolt in the middle.
func _draw_border(cell: Vector2i, rect: Rect2, colours: Array) -> void:
	draw_rect(rect, colours[1])
	draw_rect(rect.grow(-2.0), colours[0])
	draw_rect(Rect2(rect.position + Vector2(2, 2), Vector2(rect.size.x - 4.0, 2.0)), colours[2])
	draw_rect(Rect2(rect.position + Vector2(2, 2), Vector2(2.0, rect.size.y - 4.0)), colours[2])
	draw_circle(rect.get_center(), 3.0, colours[1])
	draw_circle(rect.get_center() - Vector2(0.5, 0.5), 2.0, colours[3])


## Metal plates with rivets, and a small light on some.
func _draw_hull(cell: Vector2i, rect: Rect2, colours: Array) -> void:
	draw_rect(rect, colours[1])
	draw_rect(rect.grow(-2.0), colours[0])
	draw_rect(Rect2(rect.position + Vector2(2, 2), Vector2(rect.size.x - 4.0, 3.0)), colours[2])
	for corner in [Vector2(5, 8), Vector2(27, 8), Vector2(5, 27), Vector2(27, 27)]:
		draw_circle(rect.position + corner, 1.5, colours[1])
	if _hash(cell, 4) % 5 == 0:
		draw_rect(Rect2(rect.get_center() - Vector2(3, 1), Vector2(6, 4)), colours[3])


## A dark line along the sides that face open air, so the shape reads.
func _draw_outline(cell: Vector2i, rect: Rect2) -> void:
	for side in _exposed_sides(cell):
		match side:
			Vector2i.UP:
				draw_rect(Rect2(rect.position, Vector2(rect.size.x, 2.0)), OUTLINE)
			Vector2i.DOWN:
				draw_rect(Rect2(rect.position + Vector2(0, rect.size.y - 2.0), Vector2(rect.size.x, 2.0)), OUTLINE)
			Vector2i.LEFT:
				draw_rect(Rect2(rect.position, Vector2(2.0, rect.size.y)), OUTLINE)
			Vector2i.RIGHT:
				draw_rect(Rect2(rect.position + Vector2(rect.size.x - 2.0, 0), Vector2(2.0, rect.size.y)), OUTLINE)


func _exposed_sides(cell: Vector2i) -> Array[Vector2i]:
	var sides: Array[Vector2i] = []
	for side in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		if _terrain.get_cell_source_id(cell + side) == -1:
			sides.append(side)
	return sides


static func _hash(cell: Vector2i, salt: int) -> int:
	return absi(hash(Vector3i(cell.x, cell.y, salt)))
