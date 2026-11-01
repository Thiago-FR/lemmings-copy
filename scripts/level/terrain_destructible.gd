class_name TerrainDestructible
extends TileMapLayer
## Destructible terrain queried/carved by the digging skills (Digger, Basher,
## Miner) and Bomber. Floor/wall collision for lemmings comes from this
## layer's own physics (configured on the TileSet resource), not from these
## query methods, which only add/remove tiles.
##
## A cell can be partly dug. The tile set's atlas holds one tile per dig
## stage (see tools/build_terrain_tileset.gd): stage 0 is a full block and
## each later stage has more of its top removed, with matching collision.
## Every query here only counts the part of a cell that is still there.
##
## A cell can also hold a ladder (a second atlas source with no collision).
## Ladders are not solid: lemmings pass through them, and climbing is decided
## by is_ladder_at(). Digging and carving leave them alone.
##
## On top of the tile grid, the terrain holds bricks: small solid rectangles
## the diagonal ladder lays (see SkillBuilder). They are not tied to the 32px
## grid, so a staircase can be built from wherever the lemming stands, with
## steps a fraction of a tile tall. Bricks collide like terrain, count as
## solid in every query here, and are removed by the same carving calls.

const TERRAIN_SOURCE_ID := 0
const LADDER_SOURCE_ID := 1
const BRICK_COLOUR := Color(0.80, 0.55, 0.30)

## Bricks in world space, with the nodes that give each one collision and a
## visual, at the same index.
var _bricks: Array[Rect2] = []
var _brick_nodes: Array[Array] = []
var _brick_body: StaticBody2D = null


func _ready() -> void:
	add_to_group("terrain")
	_brick_body = StaticBody2D.new()
	_brick_body.name = "Bricks"
	# Same physics layer as the tiles, so lemmings stand on bricks exactly as
	# they stand on terrain.
	_brick_body.collision_layer = tile_set.get_physics_layer_collision_layer(0)
	_brick_body.collision_mask = 0
	add_child(_brick_body)


## Lays a solid brick covering world_rect. Refused (returns false) if the
## space is already taken by terrain or another brick, so a staircase stops
## at a wall instead of being pushed into it.
func place_brick(world_rect: Rect2) -> bool:
	const OVERLAP_TOLERANCE := 0.5
	if is_solid_in_rect(world_rect.grow(-OVERLAP_TOLERANCE)):
		return false

	var local_rect := Rect2(to_local(world_rect.position), world_rect.size)
	var rect_shape := RectangleShape2D.new()
	rect_shape.size = local_rect.size
	var collision := CollisionShape2D.new()
	collision.shape = rect_shape
	collision.position = local_rect.get_center()
	_brick_body.add_child(collision)

	var visual := ColorRect.new()
	visual.color = BRICK_COLOUR
	visual.position = local_rect.position
	visual.size = local_rect.size
	visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(visual)

	_bricks.append(world_rect)
	_brick_nodes.append([collision, visual])
	return true


func get_bricks() -> Array[Rect2]:
	return _bricks.duplicate()


func _is_brick_at(world_position: Vector2) -> bool:
	for brick in _bricks:
		if brick.has_point(world_position):
			return true
	return false


func _bricks_overlap(world_rect: Rect2) -> bool:
	for brick in _bricks:
		if brick.intersects(world_rect):
			return true
	return false


## Removes every brick overlapping world_rect; returns how many.
func _remove_bricks_in(world_rect: Rect2) -> int:
	var removed_count := 0
	for index in range(_bricks.size() - 1, -1, -1):
		if _bricks[index].intersects(world_rect):
			_remove_brick(index)
			removed_count += 1
	return removed_count


func _remove_brick(index: int) -> void:
	for node: Node in _brick_nodes[index]:
		node.queue_free()
	_bricks.remove_at(index)
	_brick_nodes.remove_at(index)


## How many stages a cell goes through before it is gone, read from the
## tile set so this script follows whatever the atlas provides.
func get_dig_stage_count() -> int:
	var source := tile_set.get_source(TERRAIN_SOURCE_ID) as TileSetAtlasSource
	return maxi(1, source.get_tiles_count())


## Pixels removed from the top of a cell by each dig stage.
func get_dig_stage_height() -> float:
	return get_cell_size().y / get_dig_stage_count()


## Removes one dig stage from the top of every solid cell overlapping
## world_rect, erasing cells that were on their last stage. Returns how many
## cells were touched (0 meaning there was nothing left to dig).
##
## This is what the Digger uses instead of destroy_rect(): erasing the whole
## block at once left an open hole the digger then took over a second to
## sink into, and other lemmings walking past fell through it first.
func dig_stage_in_rect(world_rect: Rect2) -> int:
	var last_stage := get_dig_stage_count() - 1
	var touched_count := 0
	for cell in _cells_overlapping(world_rect):
		if not _is_terrain_cell(cell):
			continue
		var stage := _dig_stage_of(cell)
		if stage >= last_stage:
			erase_cell(cell)
		else:
			set_cell(cell, TERRAIN_SOURCE_ID, Vector2i(stage + 1, 0))
		touched_count += 1
	return touched_count


## World y of the top of the solid part of the cell containing
## world_position: the cell's top edge for a full block, lower for a partly
## dug one, and its bottom edge once it has been dug out completely.
func solid_top_y_at(world_position: Vector2) -> float:
	var rect := cell_rect_at(world_position)
	var cell := local_to_map(to_local(world_position))
	if not _is_terrain_cell(cell):
		return rect.end.y
	return rect.position.y + _dig_stage_of(cell) * get_dig_stage_height()


func _dig_stage_of(cell: Vector2i) -> int:
	return get_cell_atlas_coords(cell).x


func _is_terrain_cell(cell: Vector2i) -> bool:
	return get_cell_source_id(cell) == TERRAIN_SOURCE_ID


## Whether the cell containing world_position holds a ladder.
func is_ladder_at(world_position: Vector2) -> bool:
	return get_cell_source_id(local_to_map(to_local(world_position))) == LADDER_SOURCE_ID


## Turns the cell containing world_position into a ladder, replacing
## whatever terrain was there. Returns whether that cell was terrain before,
## which is how a ladder tool knows it has been tunnelling through rock.
func place_ladder_at(world_position: Vector2) -> bool:
	var cell := local_to_map(to_local(world_position))
	var was_terrain := _is_terrain_cell(cell)
	set_cell(cell, LADDER_SOURCE_ID, Vector2i.ZERO)
	return was_terrain


## Size of one terrain cell in pixels. Skills step and carve in multiples of
## this instead of a global constant, so they follow whatever tile set the
## terrain actually uses.
func get_cell_size() -> Vector2:
	return Vector2(tile_set.tile_size)


## World-space rectangle of the cell containing world_position.
func cell_rect_at(world_position: Vector2) -> Rect2:
	var cell := local_to_map(to_local(world_position))
	var size := get_cell_size()
	return Rect2(to_global(map_to_local(cell)) - size / 2.0, size)


func is_solid_at(world_position: Vector2) -> bool:
	if _is_brick_at(world_position):
		return true
	var cell := local_to_map(to_local(world_position))
	if not _is_terrain_cell(cell):
		return false
	return world_position.y >= solid_top_y_at(world_position)


func destroy_cell_at(world_position: Vector2) -> bool:
	var removed_bricks := _remove_bricks_in(cell_rect_at(world_position))
	var cell := local_to_map(to_local(world_position))
	if not _is_terrain_cell(cell):
		return removed_bricks > 0
	erase_cell(cell)
	return true


## Places a solid tile at world_position, used by Builder to lay steps.
func build_cell_at(world_position: Vector2) -> void:
	var cell := local_to_map(to_local(world_position))
	set_cell(cell, TERRAIN_SOURCE_ID, Vector2i.ZERO)


## Erases every cell overlapping world_rect and returns how many were
## actually removed (0 meaning the area was already clear).
##
## Digging skills carve through this rather than through destroy_cell_at()
## so the opening is always derived from the lemming's real body rectangle:
## whichever cells the body overlaps get cleared, whether that is one column
## or two. Clearing a fixed cell count instead was what left a lemming with
## part of itself still embedded in rock whenever its body happened to
## straddle a cell boundary.
func destroy_rect(world_rect: Rect2) -> int:
	var destroyed_count := _remove_bricks_in(world_rect)
	for cell in _cells_overlapping(world_rect):
		if _is_terrain_cell(cell):
			erase_cell(cell)
			destroyed_count += 1
	return destroyed_count


## Whether any cell overlapping world_rect is solid. Used to check that an
## opening a lemming is about to move into is genuinely clear.
func is_solid_in_rect(world_rect: Rect2) -> bool:
	return _bricks_overlap(world_rect) or not get_solid_cells_in_rect(world_rect).is_empty()


## Every still-solid cell overlapping world_rect. Separate from
## is_solid_in_rect() so a failing check can name the exact cells that are
## blocking rather than only reporting that something is.
func get_solid_cells_in_rect(world_rect: Rect2) -> Array[Vector2i]:
	var solid_cells: Array[Vector2i] = []
	for cell in _cells_overlapping(world_rect):
		if not _is_terrain_cell(cell):
			continue
		# A partly dug cell only counts if the rectangle reaches down into
		# the part that is still there, not just into the dug-out top.
		var solid_top := solid_top_y_at(to_global(map_to_local(cell)))
		if world_rect.end.y > solid_top:
			solid_cells.append(cell)
	return solid_cells


## Horizontal centre of the terrain column containing world_position.
##
## Digging skills line the lemming up with this before carving, so the shaft
## is always exactly one tile wide. Carving whichever columns the body
## happened to overlap instead produced a one-tile hole when it was aligned
## and a two-tile hole when it straddled a boundary — the same action
## leaving visibly different holes.
func column_centre_x(world_position: Vector2) -> float:
	var cell := local_to_map(to_local(world_position))
	return to_global(map_to_local(cell)).x


## Cell coordinates overlapping a world-space rectangle. The far edge is
## pulled back by a hair so a rectangle ending exactly on a cell boundary
## does not pick up the next cell along, which would make every carve one
## tile wider than the body that asked for it.
##
## The bias was 0.001 and that was not enough: local_to_map() put y=191.999
## in row 6 on a 32px grid, so a carve of exactly one row (160..192) cleared
## two. A tenth of a pixel is still far below any real geometry here.
func _cells_overlapping(world_rect: Rect2) -> Array[Vector2i]:
	const EDGE_BIAS := 0.1
	var first_cell := local_to_map(to_local(world_rect.position))
	var last_cell := local_to_map(to_local(world_rect.end - Vector2(EDGE_BIAS, EDGE_BIAS)))

	var cells: Array[Vector2i] = []
	for y in range(first_cell.y, last_cell.y + 1):
		for x in range(first_cell.x, last_cell.x + 1):
			cells.append(Vector2i(x, y))
	return cells


func destroy_circle(world_position: Vector2, radius: float) -> void:
	for index in range(_bricks.size() - 1, -1, -1):
		if world_position.distance_to(_bricks[index].get_center()) <= radius:
			_remove_brick(index)

	var center_cell := local_to_map(to_local(world_position))
	var cell_size := get_cell_size()
	var radius_in_cells := ceili(radius / minf(cell_size.x, cell_size.y))

	for y_offset in range(-radius_in_cells, radius_in_cells + 1):
		for x_offset in range(-radius_in_cells, radius_in_cells + 1):
			var cell := center_cell + Vector2i(x_offset, y_offset)
			var cell_world_position := to_global(map_to_local(cell))
			if world_position.distance_to(cell_world_position) <= radius:
				erase_cell(cell)
