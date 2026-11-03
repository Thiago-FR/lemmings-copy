class_name TerrainEdgeOverlay
extends Node2D
## Draws the floor, wall and ceiling edges over a TerrainDestructible.
##
## The terrain tiles only show a block's interior. A block that shows open
## air above it gets a floor edge (grass on earth, a slab lip on concrete),
## one open at a side gets a wall edge, and one open below gets a ceiling
## edge; a block with solid neighbours all round keeps the plain interior.
## Floor and wall are the same material with the same collision: this is
## only how the block is drawn, decided from its neighbours, so a level
## (hand-made or generated) never has to say which blocks are floors.
##
## Edges follow what is left of a dug block, not the 32px cell: a block dug
## from the top gets its floor edge on the dug surface, a block dug from a
## side gets its wall edge on the cut, and a neighbour that only covers part
## of a side (because it was dug itself) leaves the rest of that side drawn
## as exposed.
##
## Grass only grows on surfaces that were already open when the terrain was
## first filled in, or on blocks placed later (the editor, the Block tool).
## A surface uncovered by digging or an explosion (a tunnel floor, the
## bottom of a crater) shows bare cut soil instead.
##
## Strip geometry must match tools/build_terrain_art.py, which draws them.

## Rows of a floor strip above the surface (grass blades poke up).
const FLOOR_OVERHANG := 3
## Rows of a ceiling strip below the surface (roots hang down).
const CEILING_OVERHANG := 2
## Material names in TerrainDestructible.TerrainMaterial order, used to find
## each material's strips ("earth_floor.png", "concrete_wall_left.png", ...).
const MATERIAL_NAMES: Array[String] = ["earth", "concrete"]
const PIECE_NAMES: Array[String] = [
	"floor", "floor_dug", "wall_left", "wall_right", "ceiling", "corner_left", "corner_right",
	"details",
]
## Size of one entry in a "<material>_details.png" row.
const DETAIL_SIZE := Vector2(10, 8)
## Share of whole blocks that get a detail, in percent.
const DETAIL_CHANCE_PERCENT := 45
## Details stay this far inside a block, clear of every edge strip.
const DETAIL_MARGIN := Vector2(6, 8)
## Rects here are built from whole multiples of a dig stage, so this only
## absorbs float noise.
const EPSILON := 0.01

var _terrain: TerrainDestructible
## One Dictionary per material: piece name -> Texture2D.
var _pieces: Array[Dictionary] = []
## Cells whose top may grow grass (see the class comment). A set: cell -> true.
var _grassy_cells: Dictionary = {}
var _surface_recorded := false


func _init(terrain: TerrainDestructible) -> void:
	assert(terrain != null, "TerrainEdgeOverlay needs a terrain to decorate")
	_terrain = terrain
	name = "EdgeOverlay"
	_load_pieces()


func _load_pieces() -> void:
	for material_name in MATERIAL_NAMES:
		var pieces := {}
		for piece_name in PIECE_NAMES:
			var path := _terrain.get_art_directory() + "%s_%s.png" % [material_name, piece_name]
			if ResourceLoader.exists(path):
				pieces[piece_name] = load(path)
		assert(pieces.has("floor") and pieces.has("wall_left") and pieces.has("wall_right") and pieces.has("ceiling"),
			"Missing terrain edge art for %s; run tools/build_terrain_art.py" % material_name)
		# Concrete has no separate dug look.
		if not pieces.has("floor_dug"):
			pieces["floor_dug"] = pieces["floor"]
		_pieces.append(pieces)


## Called by the terrain whenever its cells change.
func refresh() -> void:
	if not _surface_recorded:
		_record_grassy_surface()
		_surface_recorded = true
	queue_redraw()


## A block placed after the level started (editor, Block tool) is new ground
## rather than a dug surface, so its top may grow grass.
func mark_grassy(cell: Vector2i) -> void:
	_grassy_cells[cell] = true
	queue_redraw()


func _record_grassy_surface() -> void:
	for cell in _terrain.get_used_cells_by_id(TerrainDestructible.TERRAIN_SOURCE_ID):
		var rect := _solid_rect(cell)
		if _is_dug_from_top(cell, rect):
			continue
		if not _top_exposure(cell, rect).is_empty():
			_grassy_cells[cell] = true


func _draw() -> void:
	var cells := _terrain.get_used_cells_by_id(TerrainDestructible.TERRAIN_SOURCE_ID).filter(
		func(cell: Vector2i) -> bool: return not _terrain.hidden_cells.has(cell) and not _terrain.self_drawn_cells.has(cell))
	var edges: Array[Dictionary] = []
	for cell in cells:
		edges.append(_edges_of(cell))
	# Details under everything, then walls and ceilings, floors over them,
	# corner caps last, so the floor edge wraps over the top of a wall edge.
	for index in cells.size():
		_draw_detail(cells[index], edges[index])
	for edge in edges:
		_draw_walls_and_ceiling(edge)
	for edge in edges:
		_draw_floor(edge)
	for edge in edges:
		_draw_corners(edge)


func _edges_of(cell: Vector2i) -> Dictionary:
	var rect := _solid_rect(cell)
	return {
		"cell_rect": _cell_rect(cell),
		"rect": rect,
		"pieces": _pieces[_terrain.get_cell_atlas_coords(cell).y],
		"grassy": _grassy_cells.has(cell) and not _is_dug_from_top(cell, rect),
		"top": _top_exposure(cell, rect),
		"bottom": _bottom_exposure(cell, rect),
		"left": _left_exposure(cell, rect),
		"right": _right_exposure(cell, rect),
	}


## A stone or a root on some whole blocks, picked from the cell's
## coordinates so it stays put between redraws and differs between
## neighbours.
func _draw_detail(cell: Vector2i, edge: Dictionary) -> void:
	var pieces: Dictionary = edge.pieces
	var rect: Rect2 = edge.rect
	if not pieces.has("details") or rect != edge.cell_rect:
		return
	var roll := hash(cell)
	if roll % 100 >= DETAIL_CHANCE_PERCENT:
		return
	var sheet: Texture2D = pieces.details
	var detail_count := int(sheet.get_width() / DETAIL_SIZE.x)
	var source := Rect2(Vector2((roll / 100) % detail_count * DETAIL_SIZE.x, 0), DETAIL_SIZE)
	var room := rect.size - DETAIL_MARGIN * 2.0 - DETAIL_SIZE
	var offset := Vector2((roll / 1000) % int(room.x + 1), (roll / 100000) % int(room.y + 1))
	draw_texture_rect_region(sheet, Rect2(rect.position + DETAIL_MARGIN + offset, DETAIL_SIZE), source)


func _draw_walls_and_ceiling(edge: Dictionary) -> void:
	var cell_rect: Rect2 = edge.cell_rect
	var rect: Rect2 = edge.rect
	var pieces: Dictionary = edge.pieces
	for span: Vector2 in edge.left:
		_draw_vertical_strip(pieces.wall_left, rect.position.x, span, cell_rect)
	for span: Vector2 in edge.right:
		var texture: Texture2D = pieces.wall_right
		_draw_vertical_strip(texture, rect.end.x - texture.get_width(), span, cell_rect)
	for span: Vector2 in edge.bottom:
		var texture: Texture2D = pieces.ceiling
		var strip_top := rect.end.y - (texture.get_height() - CEILING_OVERHANG)
		_draw_horizontal_strip(texture, strip_top, span, cell_rect)


func _draw_floor(edge: Dictionary) -> void:
	var pieces: Dictionary = edge.pieces
	var texture: Texture2D = pieces.floor if edge.grassy else pieces.floor_dug
	var rect: Rect2 = edge.rect
	for span: Vector2 in edge.top:
		_draw_horizontal_strip(texture, rect.position.y - FLOOR_OVERHANG, span, edge.cell_rect)


## A corner cap goes where the floor edge and a wall edge meet at the top
## corner of a block. A bare (dug) earth surface needs none: its outline
## already meets the wall's.
func _draw_corners(edge: Dictionary) -> void:
	var pieces: Dictionary = edge.pieces
	var bare_surface: bool = not edge.grassy and pieces.floor_dug != pieces.floor
	if (edge.top as Array).is_empty() or bare_surface:
		return
	var rect: Rect2 = edge.rect
	var first_top: Vector2 = edge.top.front()
	var last_top: Vector2 = edge.top.back()
	var strip_top := rect.position.y - FLOOR_OVERHANG
	if pieces.has("corner_left") and _starts_at(edge.left, rect.position.y) and absf(first_top.x - rect.position.x) < EPSILON:
		draw_texture(pieces.corner_left, Vector2(rect.position.x, strip_top))
	if pieces.has("corner_right") and _starts_at(edge.right, rect.position.y) and absf(last_top.y - rect.end.x) < EPSILON:
		var texture: Texture2D = pieces.corner_right
		draw_texture(texture, Vector2(rect.end.x - texture.get_width(), strip_top))


func _starts_at(spans: Array, y: float) -> bool:
	return not spans.is_empty() and absf((spans.front() as Vector2).x - y) < EPSILON


## Draws the part of a horizontal strip over x in span. The strip's columns
## line up with the cell, so neighbouring cells continue the pattern.
func _draw_horizontal_strip(texture: Texture2D, strip_top: float, span: Vector2, cell_rect: Rect2) -> void:
	var width := span.y - span.x
	var source := Rect2(span.x - cell_rect.position.x, 0, width, texture.get_height())
	draw_texture_rect_region(texture, Rect2(span.x, strip_top, width, texture.get_height()), source)


func _draw_vertical_strip(texture: Texture2D, strip_left: float, span: Vector2, cell_rect: Rect2) -> void:
	var height := span.y - span.x
	var source := Rect2(0, span.x - cell_rect.position.y, texture.get_width(), height)
	draw_texture_rect_region(texture, Rect2(strip_left, span.x, texture.get_width(), height), source)


# --- Exposure: which parts of each side of a block face open air ----------
# Each returns the exposed stretches of that side as Vector2(from, to), in x
# for top/bottom and in y for left/right, in this node's coordinates.
#
# What is left of a dug block always reaches the cell's bottom edge, and the
# side it was not dug from, so a neighbour covers the shared side over its
# own solid extent unless it was dug away from that very side.

func _top_exposure(cell: Vector2i, rect: Rect2) -> Array[Vector2]:
	var span := Vector2(rect.position.x, rect.end.x)
	var above := cell + Vector2i.UP
	if _is_dug_from_top(cell, rect) or not _is_terrain(above):
		return [span]
	var cover := _solid_rect(above)
	return _subtract(span, Vector2(cover.position.x, cover.end.x))


func _bottom_exposure(cell: Vector2i, rect: Rect2) -> Array[Vector2]:
	var span := Vector2(rect.position.x, rect.end.x)
	var below := cell + Vector2i.DOWN
	if not _is_terrain(below):
		return [span]
	var cover := _solid_rect(below)
	if cover.position.y > rect.end.y + EPSILON:
		return [span]
	return _subtract(span, Vector2(cover.position.x, cover.end.x))


func _left_exposure(cell: Vector2i, rect: Rect2) -> Array[Vector2]:
	var span := Vector2(rect.position.y, rect.end.y)
	var neighbour := cell + Vector2i.LEFT
	if rect.position.x > _cell_rect(cell).position.x + EPSILON or not _is_terrain(neighbour):
		return [span]
	var cover := _solid_rect(neighbour)
	if cover.end.x < rect.position.x - EPSILON:
		return [span]
	return _subtract(span, Vector2(cover.position.y, cover.end.y))


func _right_exposure(cell: Vector2i, rect: Rect2) -> Array[Vector2]:
	var span := Vector2(rect.position.y, rect.end.y)
	var neighbour := cell + Vector2i.RIGHT
	if rect.end.x < _cell_rect(cell).end.x - EPSILON or not _is_terrain(neighbour):
		return [span]
	var cover := _solid_rect(neighbour)
	if cover.position.x > rect.end.x + EPSILON:
		return [span]
	return _subtract(span, Vector2(cover.position.y, cover.end.y))


## span minus cover, as zero, one or two stretches.
func _subtract(span: Vector2, cover: Vector2) -> Array[Vector2]:
	var result: Array[Vector2] = []
	if cover.y <= span.x + EPSILON or cover.x >= span.y - EPSILON:
		result.append(span)
		return result
	if cover.x > span.x + EPSILON:
		result.append(Vector2(span.x, cover.x))
	if cover.y < span.y - EPSILON:
		result.append(Vector2(cover.y, span.y))
	return result


func _is_dug_from_top(cell: Vector2i, rect: Rect2) -> bool:
	return rect.position.y > _cell_rect(cell).position.y + EPSILON


func _is_terrain(cell: Vector2i) -> bool:
	return _terrain.get_cell_source_id(cell) == TerrainDestructible.TERRAIN_SOURCE_ID


## The terrain's own idea of what is left of a cell, moved into this node's
## coordinates (which are the terrain's, since this is its child at the
## origin).
func _solid_rect(cell: Vector2i) -> Rect2:
	var world_rect := _terrain.get_cell_solid_rect(cell)
	return Rect2(_terrain.to_local(world_rect.position), world_rect.size)


func _cell_rect(cell: Vector2i) -> Rect2:
	var size := _terrain.get_cell_size()
	return Rect2(_terrain.map_to_local(cell) - size / 2.0, size)
