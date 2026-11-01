extends SceneTree
## One-off build script: generates the placeholder terrain tiles and a
## TileSet with a destructible-terrain physics layer, matching
## Constants.TERRAIN_COLLISION_LAYER. Run via:
##   godot --headless --script res://tools/build_terrain_tileset.gd
## Replace the colours with real terrain art later; the TileSet layout can stay.
##
## The atlas is one row of DIG_STAGES tiles. Tile 0 is a full block; tile N
## is the same block with its top N/DIG_STAGES dug away, collision included.
## Digging skills step a cell through these stages instead of erasing it in
## one go, so a block being dug keeps real ground under anyone else walking
## over it until the digger has actually got that far down.
## TerrainDestructible reads the stage count from the atlas itself.

const TILE_SIZE := 32
const DIG_STAGES := 4
const TERRAIN_COLLISION_LAYER := 2
const TERRAIN_COLOUR := Color(0.45, 0.32, 0.18)


func _initialize() -> void:
	assert(TILE_SIZE % DIG_STAGES == 0, "Each dig stage must be a whole number of pixels")
	var stage_height := TILE_SIZE / DIG_STAGES

	var atlas_source := TileSetAtlasSource.new()
	atlas_source.texture = _build_atlas_texture(stage_height)
	atlas_source.texture_region_size = Vector2i(TILE_SIZE, TILE_SIZE)

	var tile_set := TileSet.new()
	tile_set.tile_size = Vector2i(TILE_SIZE, TILE_SIZE)

	var physics_layer_index := 0
	tile_set.add_physics_layer(physics_layer_index)
	tile_set.set_physics_layer_collision_layer(physics_layer_index, TERRAIN_COLLISION_LAYER)
	tile_set.set_physics_layer_collision_mask(physics_layer_index, 0)

	tile_set.add_source(atlas_source, 0)

	var half := TILE_SIZE / 2.0
	for stage in DIG_STAGES:
		var atlas_coords := Vector2i(stage, 0)
		atlas_source.create_tile(atlas_coords)
		var top := -half + stage * stage_height
		var polygon := PackedVector2Array([
			Vector2(-half, top), Vector2(half, top),
			Vector2(half, half), Vector2(-half, half),
		])
		var tile_data := atlas_source.get_tile_data(atlas_coords, 0)
		tile_data.add_collision_polygon(physics_layer_index)
		tile_data.set_collision_polygon_points(physics_layer_index, 0, polygon)

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://resources/tilesets"))
	var err := ResourceSaver.save(tile_set, "res://resources/tilesets/terrain_tileset.tres")
	print("terrain_tileset save result: ", err)

	quit()


func _build_atlas_texture(stage_height: int) -> ImageTexture:
	var image := Image.create(TILE_SIZE * DIG_STAGES, TILE_SIZE, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	for stage in DIG_STAGES:
		var dug := stage * stage_height
		image.fill_rect(Rect2i(stage * TILE_SIZE, dug, TILE_SIZE, TILE_SIZE - dug), TERRAIN_COLOUR)
	return ImageTexture.create_from_image(image)
