extends StageBiome
## Dunes, a wide pit, tombs under the sand, and a stepped pyramid that grows
## stage by stage, the exit on its top in the last one.


func _init() -> void:
	id = &"desert"
	name = "Deserto"
	kind = LevelEnvironment.Kind.DESERT
	order = 30
	stages.assign(["Dunas Quentes", "Ruínas na Areia", "A Pirâmide"])
	shapes.assign([Shape.WIDE, Shape.BOTH, Shape.BOTH])
	routes.assign([Route.TRAVERSE, Route.DESCEND, Route.ASCEND])


func build(g: BiomeStageGenerator) -> void:
	var heights := g.make_relief(0.60, 0.0, 4 + g.stage_tier * 2, 0.03, 0.05)
	g.cut_ravines(heights, 1, 4 + g.stage_tier)
	g.fill_ground(heights, EARTH)
	g.carve_caves(heights, 6, 0.14 + g.stage_tier * 0.04, TerrainSkin.CAVE_WALL)
	g.open_into_caves(heights, 1)
	g.rock_pockets(heights, 5, 0.5)
	g.plant_decor(heights, 3 + g.stage_tier, [TreeArt.PALM])
	var pyramid_top := g.build_pyramid(heights, 4 + g.stage_tier * 2)
	g.place_spawn_and_exit(heights)
	if g.stage_route == Route.ASCEND and pyramid_top.x >= 0:
		g.exit_cell = pyramid_top
