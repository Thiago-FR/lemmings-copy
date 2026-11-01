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
