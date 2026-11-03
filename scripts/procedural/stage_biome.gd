class_name StageBiome
extends RefCounted
## One kind of place a generated stage can happen in (a meadow, a mine, a
## spaceship...). Each biome is a script of its own in
## res://scripts/procedural/biomes/ extending this class; BiomeStageGenerator
## finds them there by itself, so adding a biome is adding a file, and
## changing one never touches another.
##
## A biome says what it is in _init (id, name, its stages' names, shapes and
## routes, where it comes in the run with order) and shapes the stage in
## build(), using the generator's toolkit (g.make_relief, g.carve_caves,
## g.fill_cells, g.add_need...) and setting g.spawn_cell and g.exit_cell.

enum Shape { WIDE, TALL, BOTH }
enum Route { TRAVERSE, ASCEND, DESCEND }

const EMPTY := MazeLayout.EMPTY
const EARTH := MazeLayout.EARTH
const CONCRETE := MazeLayout.CONCRETE
## Columns of bedrock at each side of a walled stage.
const BORDER := 2
## Rows of air a lemming needs over the floor it walks on.
const HEADROOM := 2

var id: StringName = &""
## Shown to the player (pt-BR).
var name := ""
var kind: LevelEnvironment.Kind = LevelEnvironment.Kind.SURFACE
## Where the biome comes in a run: lower first. Leave gaps (10, 20...) so a
## new biome can go between two others.
var order := 0
## One name per stage of the biome; as many stages as names.
var stages: Array[String] = []
## Per stage: long, tall or both.
var shapes: Array[Shape] = []
## Per stage: across, up or down.
var routes: Array[Route] = []
## A border of bedrock nothing breaks around the stage.
var walled := true
## The wall drawn behind enclosed air (TerrainSkin.inside_wall), or none.
var inside_wall: StringName = TerrainSkin.CAVE_WALL
## The tools a stage's solution may use; empty for the generator's own
## (BiomeStageGenerator.SOLUTION_TOOLS). The climber climbs any wall, so it
## only goes where walls are meant to be climbed.
var solution_tools: Array[String] = []
## Ground floating in the air is part of the biome (the planet's islands,
## space's asteroids); elsewhere loose bits are taken away.
var floating_ground := false


## Shapes the stage onto the generator's grid.
func build(_generator: BiomeStageGenerator) -> void:
	push_error("Biome %s does not build anything" % id)
