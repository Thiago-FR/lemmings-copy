extends StageBiome
## Hills with cliffs, ravines, a few square trees to climb, caves under the
## ground from the second stage on.


func _init() -> void:
	id = &"meadow"
	name = "Prado"
	kind = LevelEnvironment.Kind.SURFACE
	order = 10
	stages.assign(["Campo Aberto", "Colinas Verdes", "Vale dos Ventos"])
	shapes.assign([Shape.WIDE, Shape.WIDE, Shape.BOTH])
	routes.assign([Route.TRAVERSE, Route.TRAVERSE, Route.ASCEND])


func build(g: BiomeStageGenerator) -> void:
	var heights := g.make_relief(0.78 if g.stage_route == Route.ASCEND else 0.62, 0.45 if g.stage_route == Route.ASCEND else 0.05, 4 + g.stage_tier * 2, 0.05, 0.10 + g.stage_difficulty * 0.2)
	g.cut_ravines(heights, 1 + g.stage_tier, 3)
	g.fill_ground(heights, EARTH)
	if g.stage_tier >= 1:
		g.carve_caves(heights, 4, 0.18, TerrainSkin.CAVE_WALL)
		g.open_into_caves(heights, 1)
	g.rock_pockets(heights, 6, 0.55)
	g.plant_climb_trees(heights, 2 + g.stage_tier, true)
	g.plant_decor(heights, 2, [TreeArt.PINE])
	g.place_spawn_and_exit(heights)
