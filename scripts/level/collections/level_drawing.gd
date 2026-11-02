class_name LevelDrawing
extends Resource
## A drawing from the editor ("Modo livre") as a file: the terrain's cells,
## bricks, entrances, exit, how many lemmings and tools, the setting and the
## size of the drawing. The editor works with the same data as a Dictionary
## (to_dictionary / from_dictionary); collections (LevelCollection) keep it
## in whatever form their levels use.
##
## Also converts the generator's MazeStageData into a drawing, so a
## generated stage can be opened in the editor.

@export var tile_map_data := PackedByteArray()
@export var bricks: Array[Rect2] = []
## {"position": Vector2, "faces_left": bool}
@export var entrances: Array[Dictionary] = []
@export var has_exit := false
@export var exit_position := Vector2.ZERO
@export var total_lemmings := 10
@export var skill_counts: Dictionary = {}
@export var environment_kind: LevelEnvironment.Kind = LevelEnvironment.Kind.SURFACE
## In cells.
@export var size := Vector2i(120, 60)

## Matching RoguelikeStageBuilder and the campaign levels: the entrance
## stands a short drop above the floor, the exit on it.
const ENTRANCE_HEIGHT := 56.0
const EXIT_HEIGHT := 24.0
const DEFAULT_LEMMINGS := 10


func to_dictionary() -> Dictionary:
	return {
		"tile_map_data": tile_map_data,
		"bricks": bricks.duplicate(),
		"entrances": entrances.duplicate(true),
		"exit": exit_position if has_exit else null,
		"total_lemmings": total_lemmings,
		"skill_counts": skill_counts.duplicate(),
		"environment_kind": environment_kind,
		"size": size,
	}


static func from_dictionary(drawing: Dictionary) -> LevelDrawing:
	var file := LevelDrawing.new()
	file.tile_map_data = drawing.tile_map_data
	file.bricks.assign(drawing.get("bricks", []))
	file.entrances.assign(drawing.get("entrances", []))
	file.has_exit = drawing.get("exit") != null
	file.exit_position = drawing.exit if file.has_exit else Vector2.ZERO
	file.total_lemmings = int(drawing.get("total_lemmings", DEFAULT_LEMMINGS))
	file.skill_counts = drawing.get("skill_counts", {}).duplicate()
	file.environment_kind = drawing.get("environment_kind", LevelEnvironment.Kind.SURFACE)
	file.size = drawing.get("size", Vector2i(120, 60))
	return file


## A generated stage as a drawing: its terrain (with ladders and bricks),
## entrance, exit and, as the tool counts, one charge per tool item the
## generator placed. The looks laid over the cells (trees, walls) are not
## part of a drawing.
static func dictionary_from_maze(maze: MazeStageData) -> Dictionary:
	var terrain := TerrainDestructible.new()
	terrain.tile_set = preload("res://resources/tilesets/terrain_tileset.tres")
	maze.paint_onto(terrain)
	var counts := {}
	for spot in maze.item_spots:
		if spot.kind == MazeLayout.SpotKind.TOOL:
			counts[spot.tool_id] = int(counts.get(spot.tool_id, 0)) + int(spot.amount)
	var drawing := {
		"tile_map_data": terrain.tile_map_data,
		"bricks": maze.bricks.duplicate(),
		"entrances": [{"position": MazeStageData.surface_point(maze.spawn_cell) + Vector2.UP * ENTRANCE_HEIGHT, "faces_left": maze.spawn_faces_left}],
		"exit": MazeStageData.surface_point(maze.exit_cell) + Vector2.UP * EXIT_HEIGHT,
		"total_lemmings": DEFAULT_LEMMINGS,
		"skill_counts": counts,
		"environment_kind": maze.environment_kind,
		"size": Vector2i(maze.columns, maze.rows),
	}
	terrain.free()
	return drawing


## The other way: a drawing as plain stage data (cells, ladders, bricks,
## entrance and exit cells), for a game mode that builds levels from it.
static func maze_from_dictionary(drawing: Dictionary) -> MazeStageData:
	var layer := TileMapLayer.new()
	layer.tile_map_data = drawing.tile_map_data
	var size: Vector2i = drawing.get("size", Vector2i(120, 60))
	var maze := MazeStageData.new()
	maze.columns = size.x
	maze.rows = size.y
	maze.cells = PackedByteArray()
	maze.cells.resize(size.x * size.y)
	for cell in layer.get_used_cells():
		if cell.x < 0 or cell.y < 0 or cell.x >= size.x or cell.y >= size.y:
			continue
		if layer.get_cell_source_id(cell) == TerrainDestructible.TERRAIN_SOURCE_ID:
			var material := layer.get_cell_atlas_coords(cell).y
			maze.cells[cell.y * size.x + cell.x] = MazeLayout.CONCRETE if material == TerrainDestructible.TerrainMaterial.CONCRETE else MazeLayout.EARTH
		else:
			maze.ladders.append(cell)
	layer.free()
	maze.bricks.assign(drawing.get("bricks", []))
	var tile := Constants.TERRAIN_TILE_SIZE
	var entrance: Dictionary = drawing.entrances[0]
	maze.spawn_cell = Vector2i(floori(entrance.position.x / tile), roundi((entrance.position.y + ENTRANCE_HEIGHT) / tile))
	maze.spawn_faces_left = entrance.faces_left
	if drawing.get("exit") != null:
		var exit: Vector2 = drawing.exit
		maze.exit_cell = Vector2i(floori(exit.x / tile), roundi((exit.y + EXIT_HEIGHT) / tile))
	maze.environment_kind = drawing.get("environment_kind", LevelEnvironment.Kind.SURFACE)
	return maze
