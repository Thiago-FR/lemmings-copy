extends StageBiome
## A closed cavern of rounded halls and passages, crystal veins in the rock.


func _init() -> void:
	id = &"crystal"
	name = "Caverna de Cristal"
	kind = LevelEnvironment.Kind.CRYSTAL_CAVE
	order = 50
	stages.assign(["Gruta Brilhante", "Salões de Cristal", "Coração da Caverna"])
	shapes.assign([Shape.BOTH, Shape.WIDE, Shape.BOTH])
	routes.assign([Route.TRAVERSE, Route.TRAVERSE, Route.ASCEND])
	inside_wall = &""


func build(g: BiomeStageGenerator) -> void:
	g.fill_cells(0, 0, g.stage_columns - 1, g.stage_rows - 1, EARTH)
	var heights := PackedInt32Array()
	heights.resize(g.stage_columns)
	heights.fill(2)
	g.carve_caves(heights, 1, 0.34 + g.stage_tier * 0.02, &"")
	g.crystal_veins(5 + g.stage_tier * 3)
	g.place_spawn_and_exit(heights)
	g.add_need("basher", g.stage_columns / 3)
	g.add_need("ladder_vertical", g.stage_columns * 2 / 3)
	g.scatter_bonus(4)
