extends StageBiome
## Many pines behind the hills, a ravine, and caves under the forest floor.


func _init() -> void:
	id = &"forest"
	name = "Floresta"
	kind = LevelEnvironment.Kind.FOREST
	order = 20
	stages.assign(["Bosque Alto", "Copas Antigas", "Floresta Funda"])
	shapes.assign([Shape.WIDE, Shape.BOTH, Shape.BOTH])
	routes.assign([Route.TRAVERSE, Route.ASCEND, Route.DESCEND])


func build(g: BiomeStageGenerator) -> void:
	var heights := g.make_relief(0.68, 0.10 if g.stage_route == Route.ASCEND else 0.0, 3 + g.stage_tier, 0.06, 0.08 + g.stage_difficulty * 0.15)
	g.cut_ravines(heights, 1, 4 + g.stage_tier)
	g.fill_ground(heights, EARTH)
	g.carve_caves(heights, 5, 0.12 + g.stage_tier * 0.05, TerrainSkin.CAVE_WALL)
	g.open_into_caves(heights, 1 + g.stage_tier)
	g.rock_pockets(heights, 7, 0.55)
	g.plant_decor(heights, 9 + g.stage_tier * 3, [TreeArt.PINE])
	g.place_spawn_and_exit(heights)
