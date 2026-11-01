class_name TerrainDestructible
extends TileMapLayer
## Destructible terrain queried/carved by the digging skills (Digger, Basher,
## Miner) and Bomber. Floor/wall collision for lemmings comes from this
## layer's own physics (configured on the TileSet resource), not from these
## query methods, which only add/remove tiles.


func _ready() -> void:
	add_to_group("terrain")


func is_solid_at(world_position: Vector2) -> bool:
	var cell := local_to_map(to_local(world_position))
	return get_cell_source_id(cell) != -1


func destroy_cell_at(world_position: Vector2) -> bool:
	var cell := local_to_map(to_local(world_position))
	if get_cell_source_id(cell) == -1:
		return false
	erase_cell(cell)
	return true


## Places a solid tile at world_position, used by Builder to lay steps.
func build_cell_at(world_position: Vector2) -> void:
	var cell := local_to_map(to_local(world_position))
	set_cell(cell, 0, Vector2i.ZERO)


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
	var destroyed_count := 0
	for cell in _cells_overlapping(world_rect):
		if get_cell_source_id(cell) != -1:
			erase_cell(cell)
			destroyed_count += 1
	return destroyed_count


## Whether any cell overlapping world_rect is solid. Used to check that an
## opening a lemming is about to move into is genuinely clear.
func is_solid_in_rect(world_rect: Rect2) -> bool:
	return not get_solid_cells_in_rect(world_rect).is_empty()


## Every still-solid cell overlapping world_rect. Separate from
## is_solid_in_rect() so a failing check can name the exact cells that are
## blocking rather than only reporting that something is.
func get_solid_cells_in_rect(world_rect: Rect2) -> Array[Vector2i]:
	var solid_cells: Array[Vector2i] = []
	for cell in _cells_overlapping(world_rect):
		if get_cell_source_id(cell) != -1:
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
func _cells_overlapping(world_rect: Rect2) -> Array[Vector2i]:
	const EDGE_BIAS := 0.001
	var first_cell := local_to_map(to_local(world_rect.position))
	var last_cell := local_to_map(to_local(world_rect.end - Vector2(EDGE_BIAS, EDGE_BIAS)))

	var cells: Array[Vector2i] = []
	for y in range(first_cell.y, last_cell.y + 1):
		for x in range(first_cell.x, last_cell.x + 1):
			cells.append(Vector2i(x, y))
	return cells


func destroy_circle(world_position: Vector2, radius: float) -> void:
	var center_cell := local_to_map(to_local(world_position))
	var cell_size := tile_set.tile_size if tile_set != null else Vector2i(16, 16)
	var radius_in_cells := ceili(radius / float(min(cell_size.x, cell_size.y)))

	for y_offset in range(-radius_in_cells, radius_in_cells + 1):
		for x_offset in range(-radius_in_cells, radius_in_cells + 1):
			var cell := center_cell + Vector2i(x_offset, y_offset)
			var cell_world_position := to_global(map_to_local(cell))
			if world_position.distance_to(cell_world_position) <= radius:
				erase_cell(cell)
