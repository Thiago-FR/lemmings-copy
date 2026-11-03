extends StageBiome
## Purple hills with craters, caves, giant mushrooms behind and rocks
## floating above; the exit up on the highest rock in the last stage.


func _init() -> void:
	id = &"planet"
	name = "Outro Planeta"
	kind = LevelEnvironment.Kind.ALIEN_PLANET
	order = 90
	stages.assign(["Pouso", "Crateras", "Ilhas Flutuantes"])
	shapes.assign([Shape.WIDE, Shape.BOTH, Shape.BOTH])
	routes.assign([Route.TRAVERSE, Route.DESCEND, Route.ASCEND])


func build(g: BiomeStageGenerator) -> void:
	var heights := g.make_relief(0.66, 0.0, 4 + g.stage_tier, 0.05, 0.1)
	g.fill_ground(heights, EARTH)
	for crater in 2 + g.stage_tier:
		var at := g.rng.randi_range(BORDER + 10, g.stage_columns - BORDER - 11)
		g.carve_disc(Vector2(at, heights[at]), 3.5 + g.rng.randf() * 2.5)
		g.add_need("builder", at - 3)
	heights = g.surface_heights()
	g.carve_caves(heights, 5, 0.16 + g.stage_tier * 0.04, TerrainSkin.CAVE_WALL)
	g.open_into_caves(heights, 1)
	g.plant_decor(heights, 4, [TreeArt.MUSHROOM])
	var islands: Array[Vector2i] = []
	for island in 2 + g.stage_tier:
		var centre := Vector2i(g.rng.randi_range(BORDER + 8, g.stage_columns - BORDER - 9), g.rng.randi_range(4, maxi(5, g.stage_rows / 3)))
		g.blob(centre, Vector2(4.5, 2.0), EARTH)
		islands.append(centre)
	g.place_spawn_and_exit(g.surface_heights())
	if g.stage_route == Route.ASCEND:
		islands.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y)
		g.exit_cell = islands[0]
		g.add_need("ladder_vertical", g.exit_cell.x - 4)
	for island in islands:
		if island != g.exit_cell:
			g.add_spot(island.x, island.y, MazeLayout.SpotKind.BONUS)
