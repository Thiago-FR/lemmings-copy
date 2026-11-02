class_name RoguelikeStageBuilder
extends RefCounted
## Turns a RoguelikeStageDefinition into a playable level: a LevelManager
## root with the terrain (the maze painted by the core's MazeStageData), the
## entrance, the exit and the items. The UI is not added here
## (RoguelikeStageSession does that), so tests and the run build exactly the
## same world.

const TILE_SET := preload("res://resources/tilesets/terrain_tileset.tres")
const SPAWN_POINT_SCENE := preload("res://scenes/level/spawn_point.tscn")
const EXIT_POINT_SCENE := preload("res://scenes/level/exit_point.tscn")

## Heights above the walking surface, matching the hand-made levels: the
## entrance releases lemmings a short drop above the ground, the exit stands
## on it, an item floats at body height.
const SPAWN_HEIGHT := 56.0
const EXIT_HEIGHT := 24.0
const PICKUP_HEIGHT := 16.0


## The finished level root, ready to be added to the tree once
## GameManager.current_level_data is set (LevelManager reads it on entering).
func build(definition: RoguelikeStageDefinition) -> LevelManager:
	assert(definition != null and definition.maze != null, "A stage needs a definition with its maze")
	var terrain := TerrainDestructible.new()
	terrain.name = "Terrain"
	terrain.tile_set = TILE_SET
	# Painted before the terrain enters the tree, so its edge overlay draws
	# everything once instead of after every block.
	definition.maze.paint_onto(terrain)

	var level := LevelManager.new()
	level.name = "RoguelikeStage"
	level.add_child(terrain)
	var spawn_point: SpawnPoint = SPAWN_POINT_SCENE.instantiate()
	spawn_point.position = MazeStageData.surface_point(definition.maze.spawn_cell) + Vector2.UP * SPAWN_HEIGHT
	spawn_point.faces_left = definition.maze.spawn_faces_left
	level.add_child(spawn_point)
	var exit_point: ExitPoint = EXIT_POINT_SCENE.instantiate()
	exit_point.position = MazeStageData.surface_point(definition.maze.exit_cell) + Vector2.UP * EXIT_HEIGHT
	level.add_child(exit_point)
	for spec in definition.pickups:
		var pickup := RoguelikePickup.new()
		pickup.spec = spec
		pickup.position = MazeStageData.surface_point(Vector2i(spec.column, spec.row)) + Vector2.UP * PICKUP_HEIGHT
		level.add_child(pickup)
	return level
