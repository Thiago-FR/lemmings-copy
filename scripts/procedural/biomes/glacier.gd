extends StageBiome
## From an ice cave at the bottom up a mountain of cliffs to the summit;
## more ice caves inside it.


func _init() -> void:
	id = &"glacier"
	name = "Geleira"
	kind = LevelEnvironment.Kind.SNOWFIELD
	order = 60
	stages.assign(["Fenda de Gelo", "Paredão Gelado", "O Cume"])
	shapes.assign([Shape.BOTH, Shape.TALL, Shape.TALL])
	routes.assign([Route.ASCEND, Route.ASCEND, Route.ASCEND])
	solution_tools.assign(["digger", "builder", "bridge", "basher", "ladder_vertical", "floater", "climber"])
	inside_wall = TerrainSkin.ICE_WALL


func build(g: BiomeStageGenerator) -> void:
	var heights := g.make_relief(0.86, 0.72, 3, 0.06, 0.25 + g.stage_difficulty * 0.2)
	g.fill_ground(heights, EARTH)
	g.carve_caves(heights, 4, 0.12 + g.stage_tier * 0.04, TerrainSkin.ICE_WALL)
	g.start_cave(heights, TerrainSkin.ICE_WALL)
	g.plant_decor(heights, 4 + g.stage_tier * 2, [TreeArt.SNOW_PINE])
	g.exit_cell = g.floor_near(g.stage_columns - BORDER - 4, heights)
