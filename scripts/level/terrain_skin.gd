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
## The stage's border, which nothing breaks: dark bedrock with iron bolts,
## so it reads as different from the ground.
const BORDER := &"border"

const OUTLINE := Color(0.08, 0.05, 0.06)
## Per skin: base, dark, light, accent.
const COLOURS := {
	BARK: [Color(0.42, 0.26, 0.14), Color(0.28, 0.17, 0.09), Color(0.55, 0.36, 0.20), Color(0.20, 0.12, 0.07)],
	LEAVES: [Color(0.22, 0.52, 0.22), Color(0.13, 0.36, 0.15), Color(0.42, 0.72, 0.30), Color(0.60, 0.84, 0.36)],
	WALL: [Color(0.44, 0.42, 0.46), Color(0.30, 0.29, 0.33), Color(0.56, 0.54, 0.58), Color(1.0, 0.86, 0.48)],
	HULL: [Color(0.52, 0.56, 0.62), Color(0.34, 0.37, 0.44), Color(0.72, 0.76, 0.82), Color(0.36, 0.86, 1.0)],
	ALIEN_LEAVES: [Color(0.62, 0.26, 0.66), Color(0.42, 0.14, 0.48), Color(0.86, 0.46, 0.86), Color(0.40, 1.0, 0.86)],
	BORDER: [Color(0.18, 0.17, 0.20), Color(0.11, 0.10, 0.13), Color(0.28, 0.27, 0.31), Color(0.55, 0.52, 0.48)],
	CAVE_WALL: [Color(0.17, 0.13, 0.11), Color(0.12, 0.09, 0.08), Color(0.22, 0.17, 0.14), Color(0.30, 0.24, 0.18)],
	ICE_WALL: [Color(0.28, 0.38, 0.52), Color(0.20, 0.28, 0.40), Color(0.38, 0.50, 0.64), Color(0.62, 0.80, 0.92)],
	ALIEN_STEM: [Color(0.24, 0.48, 0.52), Color(0.14, 0.32, 0.36), Color(0.38, 0.66, 0.68), Color(0.10, 0.20, 0.22)],
}

var skins: Dictionary = {}
## Drawn on empty cells, behind the lemmings (they walk past it): a tree's
## trunk under its canopy. cell -> BARK or ALIEN_STEM.
var backdrop: Dictionary = {}

var _terrain: TerrainDestructible


func _ready() -> void:
	_terrain = get_parent() as TerrainDestructible
	assert(_terrain != null, "A TerrainSkin dresses the TerrainDestructible it is a child of")
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_terrain.cells_changed.connect(func(_coords: Array[Vector2i]) -> void: queue_redraw())


func _draw() -> void:
	var size := _terrain.get_cell_size()
	for cell: Vector2i in backdrop:
		if _terrain.get_cell_source_id(cell) != -1:
			continue
		var rect := Rect2(Vector2(cell) * size, size)
		if backdrop[cell] == CAVE_WALL or backdrop[cell] == ICE_WALL:
			_draw_cave_wall(cell, rect, COLOURS[backdrop[cell]])
		else:
			_draw_trunk(cell, rect, COLOURS[backdrop[cell]])
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
			HULL:
				_draw_hull(cell, rect, COLOURS[HULL])
			BORDER:
				_draw_border(cell, rect, COLOURS[BORDER])
		_draw_outline(cell, rect)


## Dark rock with a few cracks and lumps, flat so the walls in front read.
func _draw_cave_wall(cell: Vector2i, rect: Rect2, colours: Array) -> void:
	draw_rect(rect, colours[0])
	if _hash(cell, 31) % 3 == 0:
		draw_rect(Rect2(rect.position + Vector2(float(_hash(cell, 33) % 20), float(_hash(cell, 35) % 24)), Vector2(8, 3)), colours[1])
	if _hash(cell, 37) % 4 == 0:
		draw_circle(rect.position + Vector2(float(_hash(cell, 39) % 24) + 4.0, float(_hash(cell, 41) % 24) + 4.0), 3.0, colours[2])
	if _hash(cell, 43) % 11 == 0:
		draw_circle(rect.get_center(), 1.5, colours[3])


## A trunk narrower than the cell, so it reads as standing in front of the
## sky rather than as a block.
func _draw_trunk(cell: Vector2i, rect: Rect2, colours: Array) -> void:
	var trunk := Rect2(rect.position + Vector2(8, 0), Vector2(16, rect.size.y))
	draw_rect(trunk.grow_individual(2, 0, 2, 0), OUTLINE)
	draw_rect(trunk, colours[0])
	draw_rect(Rect2(trunk.position + Vector2(3, 0), Vector2(3, trunk.size.y)), colours[2])
	draw_rect(Rect2(trunk.position + Vector2(11, 0), Vector2(2, trunk.size.y)), colours[1])
	if _hash(cell, 17) % 4 == 0:
		draw_circle(trunk.get_center(), 2.5, colours[3])


## Vertical grain, a knot now and then.
func _draw_bark(cell: Vector2i, rect: Rect2, colours: Array) -> void:
	draw_rect(rect, colours[0])
	for stripe in 4:
		var x := rect.position.x + 3.0 + stripe * 7.0 + float(_hash(cell, stripe) % 3)
		draw_rect(Rect2(x, rect.position.y, 2.0, rect.size.y), colours[1] if stripe % 2 == 0 else colours[2])
	if _hash(cell, 9) % 5 == 0:
		draw_circle(rect.get_center() + Vector2(0, 4), 3.5, colours[3])


## A square block of foliage, for the crowns a lemming can climb on: a
## dark base, rows of small leaves in two greens, lighter along the top of
## the crown and darker underneath, outlined where it meets the air.
func _draw_leaves(cell: Vector2i, rect: Rect2, colours: Array) -> void:
	draw_rect(rect, colours[1])
	var air_above := _terrain.get_cell_source_id(cell + Vector2i.UP) == -1
	var air_below := _terrain.get_cell_source_id(cell + Vector2i.DOWN) == -1
	for row in 4:
		for column in 4:
			var leaf := Rect2(rect.position + Vector2(column * 8 + (row % 2) * 4, row * 8 + 1), Vector2(6, 5))
			var shade: Color = colours[0]
			if row == 0 and air_above:
				shade = colours[2]
			elif row == 3 and air_below:
				shade = colours[1].darkened(0.15)
			elif _hash(cell, row * 4 + column) % 3 == 0:
				shade = colours[2]
			draw_rect(leaf.intersection(rect), shade)
	if air_above:
		draw_rect(Rect2(rect.position + Vector2(0, 2), Vector2(rect.size.x, 3)), colours[2])
		for tuft in 3:
			draw_rect(Rect2(rect.position + Vector2(4 + tuft * 10 + _hash(cell, 50 + tuft) % 4, 0), Vector2(3, 2)), colours[3])


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
