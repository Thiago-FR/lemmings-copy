extends SceneTree
## One-off build script: generates a solid-color placeholder tile and a
## TileSet with a destructible-terrain physics layer, matching
## Constants.TERRAIN_COLLISION_LAYER. Run via:
##   godot --headless --script res://tools/build_terrain_tileset.gd
## Replace with real terrain art later; the TileSet itself can stay.

const TILE_SIZE := 32
const TERRAIN_COLLISION_LAYER := 2


func _initialize() -> void:
	var image := Image.create(TILE_SIZE, TILE_SIZE, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.45, 0.32, 0.18))
	var texture := ImageTexture.create_from_image(image)

	var atlas_source := TileSetAtlasSource.new()
	atlas_source.texture = texture
	atlas_source.texture_region_size = Vector2i(TILE_SIZE, TILE_SIZE)
	atlas_source.create_tile(Vector2i(0, 0))

	var tile_set := TileSet.new()
	tile_set.tile_size = Vector2i(TILE_SIZE, TILE_SIZE)

	var physics_layer_index := 0
	tile_set.add_physics_layer(physics_layer_index)
	tile_set.set_physics_layer_collision_layer(physics_layer_index, TERRAIN_COLLISION_LAYER)
	tile_set.set_physics_layer_collision_mask(physics_layer_index, 0)

	tile_set.add_source(atlas_source, 0)

	var tile_data := atlas_source.get_tile_data(Vector2i(0, 0), 0)
	var half := TILE_SIZE / 2.0
	var polygon := PackedVector2Array([
		Vector2(-half, -half), Vector2(half, -half),
		Vector2(half, half), Vector2(-half, half),
	])
	tile_data.add_collision_polygon(physics_layer_index)
	tile_data.set_collision_polygon_points(physics_layer_index, 0, polygon)

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://resources/tilesets"))
	var err := ResourceSaver.save(tile_set, "res://resources/tilesets/terrain_tileset.tres")
	print("terrain_tileset save result: ", err)

	quit()
