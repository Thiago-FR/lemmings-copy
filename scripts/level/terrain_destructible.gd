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
## Terrain comes in two materials, one atlas row each: earth (row 0), which
## every digging tool goes through, and concrete (row 1), which only the
## jackhammer and explosives break. The shovel and the pickaxe stop at it.
##
## The same stage tiles also serve horizontal digging (the pickaxe): drawn
## transposed, a tile has its left side dug away instead of its top, and
## transposed and flipped, its right side. Godot transforms the collision
## with the tile, so no extra tiles are needed. Which way a cell has been
## dug is read back from its transform flags.
##
## A cell can also hold a ladder (a second atlas source with no collision).
## Ladders are not solid: lemmings pass through them, and climbing is decided
## by is_ladder_at(). Digging and carving leave them alone.
##
## On top of the tile grid, the terrain holds bricks: small solid rectangles
## the diagonal ladder lays (see SkillBuilder). They are not tied to the 32px
## grid, so a staircase can be built from wherever the lemming stands, with
## steps a fraction of a tile tall. Bricks count as solid in every query
## here and are removed by the same carving calls, but they only collide from
## above, like a platform: a lemming stands and walks on them, while one
## walking underneath a staircase passes through the bricks at head height
## instead of taking them for a wall.
##
## How the terrain looks: the tiles show each block's interior, and a child
## TerrainEdgeOverlay draws floor, wall and ceiling edges over them from the
## neighbours, refreshed through _update_cells() whenever any cell changes.
## That is drawing only; nothing here reads it.

## Some cells were dug, built or painted (the same batches the edges are
## redrawn for). Drawings laid over the terrain (TerrainSkin) follow it.
signal cells_changed(coords: Array[Vector2i])
## A tool tried to break a cell that never breaks (the stage's border): the
## level shows the tool blowing up there.
signal unbreakable_hit(world_position: Vector2)

const TERRAIN_SOURCE_ID := 0
## Terrain materials, by atlas row.
enum TerrainMaterial { EARTH, CONCRETE }
const LADDER_SOURCE_ID := 1
const BRICK_TEXTURE := preload("res://assets/sprites/terrain/brick.png")
## Pixels at each end of the plank texture kept as they are when a brick
## is narrower or wider than the texture.
const BRICK_END_CAP := 3
## Tile transforms for a cell dug from the side; plain tiles are dug from
## the top.
const DUG_FROM_LEFT := TileSetAtlasSource.TRANSFORM_TRANSPOSE
const DUG_FROM_RIGHT := TileSetAtlasSource.TRANSFORM_TRANSPOSE | TileSetAtlasSource.TRANSFORM_FLIP_H

## Bricks in world space, with the nodes that give each one collision and a
## visual, at the same index.
var _bricks: Array[Rect2] = []
var _brick_nodes: Array[Array] = []
var _brick_body: StaticBody2D = null
var _edge_overlay: TerrainEdgeOverlay = null

## Where the default block art is, and the folder of each art theme.
const ART_DIRECTORY := "res://assets/sprites/terrain/"
const THEMES_DIRECTORY := ART_DIRECTORY + "themes/"
const ATLAS_FILE := "terrain_atlas.png"

## The look of the blocks: a folder under THEMES_DIRECTORY drawn by
## tools/build_terrain_themes.py (sand, snow, ...), or empty for the default
## earth and concrete. Same tiles, same collision: only the textures change.
## Read once, when the terrain enters the scene (LevelManager sets it from
## the level's LevelEnvironment unless the scene already did).
@export var art_theme: StringName = &""
## Bricks (bridges, steps) a saved level starts with: they are not part of
## the tile data, so a level drawn in the editor keeps them here and they
## are laid when the terrain enters the scene.
@export var initial_bricks: Array[Rect2] = []
## Cells that stay solid but are not drawn: something else paints them (a
## tree's crown, see TerrainSkin). cell -> true.
var hidden_cells: Dictionary = {}
## Cells nothing breaks: no tool, no explosive (a stage's border, so no one
## digs out of the map). cell -> true.
var unbreakable_cells: Dictionary = {}


func _ready() -> void:
	add_to_group("terrain")
	_apply_art_theme()
	# The terrain art is drawn at one texel per screen pixel; linear filtering
	# would blur it whenever the window is scaled. Children (edges, bricks)
	# inherit this.
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_edge_overlay = TerrainEdgeOverlay.new(self)
	add_child(_edge_overlay)
	_brick_body = StaticBody2D.new()
	_brick_body.name = "Bricks"
	# Same physics layer as the tiles, so lemmings stand on bricks exactly as
	# they stand on terrain.
	_brick_body.collision_layer = tile_set.get_physics_layer_collision_layer(0)
	_brick_body.collision_mask = 0
	add_child(_brick_body)
	for brick in initial_bricks:
		place_brick(brick)


## The folder the block art is read from (atlas and edge strips).
func get_art_directory() -> String:
	return art_directory_for(art_theme)


## The folder of an art theme, falling back to the default art when the
## theme is empty or was never drawn.
static func art_directory_for(theme: StringName) -> String:
	if theme != &"":
		var directory := THEMES_DIRECTORY + String(theme) + "/"
		if ResourceLoader.exists(directory + ATLAS_FILE):
			return directory
	return ART_DIRECTORY


## Swaps the block textures for the theme's. The tile set is shared by every
## level, so this terrain gets its own copy before the atlas changes.
func _apply_art_theme() -> void:
	var directory := get_art_directory()
	if directory == ART_DIRECTORY or tile_set == null:
		return
	var themed := tile_set.duplicate(true) as TileSet
	var source := themed.get_source(TERRAIN_SOURCE_ID) as TileSetAtlasSource
	source.texture = load(directory + ATLAS_FILE)
	tile_set = themed


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
	collision.one_way_collision = true
	collision.position = local_rect.get_center()
	_brick_body.add_child(collision)

	# Drawn as a plank whose two ends keep their shape while only the middle
	# stretches or shrinks: a short step cut against a wall reads as a short
	# plank, not as a squashed or chopped one (prints/bug8.png).
	var visual := NinePatchRect.new()
	visual.texture = BRICK_TEXTURE
	visual.patch_margin_left = BRICK_END_CAP
	visual.patch_margin_right = BRICK_END_CAP
	visual.axis_stretch_horizontal = NinePatchRect.AXIS_STRETCH_MODE_TILE_FIT
	visual.position = local_rect.position
	visual.size = local_rect.size
	visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(visual)

	_bricks.append(world_rect)
	_brick_nodes.append([collision, visual])
	return true


func get_bricks() -> Array[Rect2]:
	return _bricks.duplicate()


## Whether a brick laid at exactly this rect is still there.
func has_brick(world_rect: Rect2) -> bool:
	return _bricks.has(world_rect)


## A brick as it fits: whole if its spot is free, otherwise cut from its far
## side (the side direction points to) down to the room left before
## whatever is in the way. Empty if not even min_width is free. Used by the
## diagonal ladder and the bridge so their last piece always reaches the
## wall or the far side instead of stopping up to a piece short of it.
func fit_brick(brick: Rect2, direction: int, min_width: float) -> Rect2:
	if not _is_brick_spot_taken(brick):
		return brick
	var width := brick.size.x - 1.0
	while width >= min_width:
		var cut := brick
		cut.size.x = width
		if direction < 0:
			cut.position.x = brick.end.x - width
		if not _is_brick_spot_taken(cut):
			return cut
		width -= 1.0
	return Rect2()


func _is_brick_spot_taken(brick: Rect2) -> bool:
	const OVERLAP_TOLERANCE := 0.5
	return is_solid_in_rect(brick.grow(-OVERLAP_TOLERANCE)) or is_ladder_at(brick.get_center())


## The brick containing world_position, or an empty Rect2 if there is none.
func brick_at(world_position: Vector2) -> Rect2:
	for brick in _bricks:
		if brick.has_point(world_position):
			return brick
	return Rect2()


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


## Removes every brick overlapping world_rect; returns how many. Public for
## the shovel, which digs through a brick (a quarter of a block, one dig
## stage) in one go.
func remove_bricks_in(world_rect: Rect2) -> int:
	return _remove_bricks_in(world_rect)


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
	return maxi(1, source.get_atlas_grid_size().x)


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
##
## Concrete is left alone unless breaks_concrete is set.
func dig_stage_in_rect(world_rect: Rect2, breaks_concrete: bool = false) -> int:
	var last_stage := get_dig_stage_count() - 1
	var touched_count := 0
	for cell in _cells_overlapping(world_rect):
		if unbreakable_cells.has(cell) and _is_terrain_cell(cell):
			_refuse(cell)
			continue
		if not _is_terrain_cell(cell) or not _can_break(cell, breaks_concrete):
			continue
		var stage := _dig_stage_of(cell)
		# A cell already dug from the side cannot also be dug from the top
		# with these tiles, so it goes in one go.
		if stage >= last_stage or _dug_side_of(cell) != 0:
			erase_cell(cell)
		else:
			set_cell(cell, TERRAIN_SOURCE_ID, Vector2i(stage + 1, _material_of(cell)))
		touched_count += 1
	return touched_count


## Removes one dig stage from the side of the cell containing world_position
## that faces a lemming digging in direction (its left side when digging
## right), erasing the cell on its last stage. Returns false if there is no
## terrain there, or it is concrete and breaks_concrete is not set. A cell
## already dug from another side goes in one go.
func dig_side_stage_at(world_position: Vector2, direction: int, breaks_concrete: bool = false) -> bool:
	var cell := local_to_map(to_local(world_position))
	if unbreakable_cells.has(cell) and _is_terrain_cell(cell):
		_refuse(cell)
		return false
	if not _is_terrain_cell(cell) or not _can_break(cell, breaks_concrete):
		return false
	var side := DUG_FROM_LEFT if direction > 0 else DUG_FROM_RIGHT
	var stage := _dig_stage_of(cell)
	var already_dug_other_way := stage > 0 and _dug_side_of(cell) != side
	if stage >= get_dig_stage_count() - 1 or already_dug_other_way:
		erase_cell(cell)
	else:
		set_cell(cell, TERRAIN_SOURCE_ID, Vector2i(stage + 1, _material_of(cell)), side)
	return true


## World y of the top of the solid part of the cell containing
## world_position: the cell's top edge for a full block, lower for a partly
## dug one, and its bottom edge once it has been dug out completely.
func solid_top_y_at(world_position: Vector2) -> float:
	var cell := local_to_map(to_local(world_position))
	if not _is_terrain_cell(cell):
		return cell_rect_at(world_position).end.y
	return _solid_rect_of(cell).position.y


func _dig_stage_of(cell: Vector2i) -> int:
	return get_cell_atlas_coords(cell).x


func _material_of(cell: Vector2i) -> TerrainMaterial:
	return get_cell_atlas_coords(cell).y as TerrainMaterial


func _can_break(cell: Vector2i, breaks_concrete: bool) -> bool:
	if unbreakable_cells.has(cell):
		return false
	return breaks_concrete or _material_of(cell) != TerrainMaterial.CONCRETE


## Whether the cell containing world_position is one nothing breaks.
func is_unbreakable_at(world_position: Vector2) -> bool:
	return unbreakable_cells.has(local_to_map(to_local(world_position)))


func _refuse(cell: Vector2i) -> void:
	unbreakable_hit.emit(to_global(map_to_local(cell)))


## Whether the cell containing world_position is concrete.
func is_concrete_at(world_position: Vector2) -> bool:
	var cell := local_to_map(to_local(world_position))
	return _is_terrain_cell(cell) and _material_of(cell) == TerrainMaterial.CONCRETE


## Material of the cell containing world_position, for effects that look
## different per material (the debris a dig throws up). Earth for anything
## that is not terrain.
func material_at(world_position: Vector2) -> TerrainMaterial:
	var cell := local_to_map(to_local(world_position))
	return _material_of(cell) if _is_terrain_cell(cell) else TerrainMaterial.EARTH


## DUG_FROM_LEFT, DUG_FROM_RIGHT, or 0 for a cell dug from the top (or not
## dug at all).
func _dug_side_of(cell: Vector2i) -> int:
	var transform_flags := get_cell_alternative_tile(cell) & (DUG_FROM_LEFT | TileSetAtlasSource.TRANSFORM_FLIP_H)
	if transform_flags == DUG_FROM_LEFT or transform_flags == DUG_FROM_RIGHT:
		return transform_flags
	return 0


## World rectangle of what is left of a terrain cell after digging. Public
## for TerrainEdgeOverlay, which draws edges along it.
func get_cell_solid_rect(cell: Vector2i) -> Rect2:
	return _solid_rect_of(cell)


## World rectangle of what is left of a terrain cell after digging.
func _solid_rect_of(cell: Vector2i) -> Rect2:
	var size := get_cell_size()
	var rect := Rect2(to_global(map_to_local(cell)) - size / 2.0, size)
	var dug := _dig_stage_of(cell) * get_dig_stage_height()
	match _dug_side_of(cell):
		DUG_FROM_LEFT:
			rect.position.x += dug
			rect.size.x -= dug
		DUG_FROM_RIGHT:
			rect.size.x -= dug
		_:
			rect.position.y += dug
			rect.size.y -= dug
	return rect


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
	var solid := _solid_rect_of(cell)
	return world_position.y >= solid.position.y 		and world_position.x >= solid.position.x and world_position.x <= solid.end.x


func destroy_cell_at(world_position: Vector2) -> bool:
	var removed_bricks := _remove_bricks_in(cell_rect_at(world_position))
	var cell := local_to_map(to_local(world_position))
	if not _is_terrain_cell(cell) or unbreakable_cells.has(cell):
		return removed_bricks > 0
	erase_cell(cell)
	return true


## Places a full block of the given material at world_position.
func build_cell_at(world_position: Vector2, material: TerrainMaterial = TerrainMaterial.EARTH) -> void:
	var cell := local_to_map(to_local(world_position))
	set_cell(cell, TERRAIN_SOURCE_ID, Vector2i(0, material))
	if _edge_overlay != null:
		_edge_overlay.mark_grassy(cell)


## TileMapLayer hooks: a hidden cell's tile is drawn fully transparent
## (its collision is untouched).
func _use_tile_data_runtime_update(coords: Vector2i) -> bool:
	return hidden_cells.has(coords)


func _tile_data_runtime_update(_coords: Vector2i, tile_data: TileData) -> void:
	tile_data.modulate = Color(1, 1, 1, 0)


## TileMapLayer hook: called with every batch of changed cells, however they
## were changed (these methods, a direct set_cell, or tile_map_data being
## assigned), so the edges never go stale.
func _update_cells(coords: Array[Vector2i], forced_cleanup: bool) -> void:
	if forced_cleanup or _edge_overlay == null:
		return
	_edge_overlay.refresh()
	cells_changed.emit(coords)


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
		if _is_terrain_cell(cell) and not unbreakable_cells.has(cell):
			erase_cell(cell)
			destroyed_count += 1
	return destroyed_count


## Whether any cell overlapping world_rect is solid. Used to check that an
## opening a lemming is about to move into is genuinely clear.
func is_solid_in_rect(world_rect: Rect2) -> bool:
	return _bricks_overlap(world_rect) or is_terrain_solid_in_rect(world_rect)


## Like is_solid_in_rect() but ignoring bricks, for checks that bricks should
## not take part in because they only block from above.
func is_terrain_solid_in_rect(world_rect: Rect2) -> bool:
	return not get_solid_cells_in_rect(world_rect).is_empty()


## Every still-solid cell overlapping world_rect. Separate from
## is_solid_in_rect() so a failing check can name the exact cells that are
## blocking rather than only reporting that something is.
func get_solid_cells_in_rect(world_rect: Rect2) -> Array[Vector2i]:
	var solid_cells: Array[Vector2i] = []
	for cell in _cells_overlapping(world_rect):
		if not _is_terrain_cell(cell):
			continue
		# A partly dug cell only counts if the rectangle reaches into the
		# part that is still there, not just into the dug-out top or side.
		var solid := _solid_rect_of(cell)
		if world_rect.end.y > solid.position.y and world_rect.end.x > solid.position.x and world_rect.position.x < solid.end.x:
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
