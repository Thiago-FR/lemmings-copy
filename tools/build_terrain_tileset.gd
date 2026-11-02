extends SceneTree
## One-off build script: builds the terrain TileSet with a destructible-terrain
## physics layer, matching Constants.TERRAIN_COLLISION_LAYER. Run via:
##   python tools/build_terrain_art.py          (draws the PNGs)
##   godot --headless --path . --import         (imports new/changed PNGs)
##   godot --headless --script res://tools/build_terrain_tileset.gd
##
## The art comes from assets/sprites/terrain/ (see tools/build_terrain_art.py);
## this script only lays out the tiles and their collision.
##
## The atlas has one row of DIG_STAGES tiles per terrain material: row 0 is
## earth, row 1 concrete (only the jackhammer breaks it). Tile 0 of a row is
## a full block; tile N is the same block with its top N/DIG_STAGES dug away,
## collision included.
## Digging skills step a cell through these stages instead of erasing it in
## one go, so a block being dug keeps real ground under anyone else walking
## over it until the digger has actually got that far down.
## TerrainDestructible reads the stage count from the atlas itself.
##
## The tiles only show a block's interior. Whether a block looks like a floor
## or a wall depends on its neighbours, so those edges are drawn over the
## tiles at run time by TerrainEdgeOverlay.
##
## A second atlas source holds the ladder tile: same size, no collision.
## Ladder tools replace terrain cells with it, which opens the cell and marks
## it as climbable in one step.

const TILE_SIZE := 32
const DIG_STAGES := 4
const MATERIAL_COUNT := 2
const TERRAIN_COLLISION_LAYER := 2
const TERRAIN_SOURCE_ID := 0
const LADDER_SOURCE_ID := 1
const TERRAIN_ATLAS_PATH := "res://assets/sprites/terrain/terrain_atlas.png"
const LADDER_TEXTURE_PATH := "res://assets/sprites/terrain/ladder.png"


func _initialize() -> void:
	assert(TILE_SIZE % DIG_STAGES == 0, "Each dig stage must be a whole number of pixels")
	var stage_height := TILE_SIZE / DIG_STAGES

	var atlas_texture: Texture2D = load(TERRAIN_ATLAS_PATH)
	assert(atlas_texture != null, "Run tools/build_terrain_art.py and import first")
	assert(atlas_texture.get_size() == Vector2(TILE_SIZE * DIG_STAGES, TILE_SIZE * MATERIAL_COUNT),
		"The terrain atlas must hold DIG_STAGES columns and one row per material")

	var atlas_source := TileSetAtlasSource.new()
	atlas_source.texture = atlas_texture
	atlas_source.texture_region_size = Vector2i(TILE_SIZE, TILE_SIZE)

	var tile_set := TileSet.new()
	tile_set.tile_size = Vector2i(TILE_SIZE, TILE_SIZE)

	var physics_layer_index := 0
	tile_set.add_physics_layer(physics_layer_index)
	tile_set.set_physics_layer_collision_layer(physics_layer_index, TERRAIN_COLLISION_LAYER)
	tile_set.set_physics_layer_collision_mask(physics_layer_index, 0)

	tile_set.add_source(atlas_source, TERRAIN_SOURCE_ID)

	var half := TILE_SIZE / 2.0
	for material in MATERIAL_COUNT:
		for stage in DIG_STAGES:
			var atlas_coords := Vector2i(stage, material)
			atlas_source.create_tile(atlas_coords)
			var top := -half + stage * stage_height
			var polygon := PackedVector2Array([
				Vector2(-half, top), Vector2(half, top),
				Vector2(half, half), Vector2(-half, half),
			])
			var tile_data := atlas_source.get_tile_data(atlas_coords, 0)
			tile_data.add_collision_polygon(physics_layer_index)
			tile_data.set_collision_polygon_points(physics_layer_index, 0, polygon)

	tile_set.add_source(_build_ladder_source(), LADDER_SOURCE_ID)

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://resources/tilesets"))
	var err := ResourceSaver.save(tile_set, "res://resources/tilesets/terrain_tileset.tres")
	print("terrain_tileset save result: ", err)

	quit()


## No collision polygon on purpose: lemmings pass through ladder cells, and
## climbing is decided by asking the terrain whether a cell is a ladder.
func _build_ladder_source() -> TileSetAtlasSource:
	var texture: Texture2D = load(LADDER_TEXTURE_PATH)
	assert(texture != null, "Run tools/build_terrain_art.py and import first")
	var source := TileSetAtlasSource.new()
	source.texture = texture
	source.texture_region_size = Vector2i(TILE_SIZE, TILE_SIZE)
	source.create_tile(Vector2i.ZERO)
	return source
