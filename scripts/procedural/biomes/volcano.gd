extends StageBiome
## Black slopes, chasms, lava tubes below; in the last stage a volcano to
## climb with the exit on the crater's rim.


func _init() -> void:
	id = &"volcano"
	name = "Vulcão"
	kind = LevelEnvironment.Kind.VOLCANO
	order = 70
	stages.assign(["Encosta Negra", "Rios de Brasa", "A Cratera"])
	shapes.assign([Shape.WIDE, Shape.BOTH, Shape.TALL])
	routes.assign([Route.TRAVERSE, Route.DESCEND, Route.ASCEND])
	solution_tools.assign(["digger", "builder", "bridge", "basher", "ladder_vertical", "floater", "climber"])


func build(g: BiomeStageGenerator) -> void:
	var heights: PackedInt32Array
	if g.stage_route == Route.ASCEND:
		heights = g.volcano_cone()
	else:
		heights = g.make_relief(0.55, 0.0, 6 + g.stage_tier * 2, 0.08, 0.2)
		g.cut_ravines(heights, 2 + g.stage_tier, 3)
	g.fill_ground(heights, EARTH)
	g.carve_caves(heights, 4, 0.16 + g.stage_tier * 0.04, TerrainSkin.CAVE_WALL)
	g.open_into_caves(heights, 1)
	for column_index in 1 + g.stage_tier:
		var at := g.rng.randi_range(BORDER + 6, g.stage_columns - BORDER - 7)
		if heights[at] < g.stage_rows:
			g.fill_cells(at, heights[at] - 4, at, heights[at] - 1, CONCRETE)
			g.add_need("basher", at)
	g.place_spawn_and_exit(heights)
