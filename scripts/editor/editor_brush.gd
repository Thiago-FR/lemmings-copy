class_name EditorBrush
extends RefCounted
## Applies the editor's terrain tools (block, ladder, brick, eraser) to a
## TerrainDestructible at a world position, using only the terrain's public
## API so a painted scenario is made of exactly the same pieces the tools
## build during play.
##
## Blocks, ladders and the eraser work on whole 32px cells. Bricks are the
## same 32x8 pieces the bridge and the diagonal ladder lay: one cell wide,
## snapped to the cell columns, and snapped vertically to a quarter of a
## cell, so a painted bridge lines up with the floor beside it.

## Brick height as a fraction of a cell, matching SkillBridge's pieces.
const BRICK_HEIGHT_FRACTION := 0.25

var _terrain: TerrainDestructible


func _init(terrain: TerrainDestructible) -> void:
	assert(terrain != null, "EditorBrush needs a terrain to paint on")
	_terrain = terrain


## Applies a terrain tool at world_position. Entrance and exit are not
## terrain and are ignored here.
func apply(kind: EditorTool.Kind, world_position: Vector2) -> void:
	match kind:
		EditorTool.Kind.BLOCK:
			paint_block(world_position)
		EditorTool.Kind.LADDER:
			paint_ladder(world_position)
		EditorTool.Kind.BRICK:
			paint_brick(world_position)
		EditorTool.Kind.ERASER:
			erase(world_position)


func paint_block(world_position: Vector2) -> void:
	# destroy_rect first so a brick sitting in the cell does not end up
	# buried inside the new block.
	_terrain.destroy_rect(_terrain.cell_rect_at(world_position))
	_terrain.build_cell_at(world_position)


func paint_ladder(world_position: Vector2) -> void:
	_terrain.destroy_rect(_terrain.cell_rect_at(world_position))
	_terrain.place_ladder_at(world_position)


## Returns false when the spot is already taken by terrain or another brick
## (place_brick refuses overlaps), which is what lets a drag lay a clean row.
func paint_brick(world_position: Vector2) -> bool:
	return _terrain.place_brick(brick_rect_at(world_position))


## Clears the cell under world_position: terrain, ladder and any brick
## inside it.
func erase(world_position: Vector2) -> void:
	_terrain.destroy_rect(_terrain.cell_rect_at(world_position))
	var cell := _terrain.local_to_map(_terrain.to_local(world_position))
	_terrain.erase_cell(cell)


## The rectangle a brick painted at world_position would occupy.
func brick_rect_at(world_position: Vector2) -> Rect2:
	var cell_rect := _terrain.cell_rect_at(world_position)
	var brick_height := cell_rect.size.y * BRICK_HEIGHT_FRACTION
	var rows_into_cell := floorf((world_position.y - cell_rect.position.y) / brick_height)
	var top := cell_rect.position.y + rows_into_cell * brick_height
	return Rect2(cell_rect.position.x, top, cell_rect.size.x, brick_height)


## The area a tool would change at world_position, for the cursor preview.
func target_rect(kind: EditorTool.Kind, world_position: Vector2) -> Rect2:
	if kind == EditorTool.Kind.BRICK:
		return brick_rect_at(world_position)
	return _terrain.cell_rect_at(world_position)
