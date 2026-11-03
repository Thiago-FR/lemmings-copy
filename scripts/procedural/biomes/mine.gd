extends StageBiome
## The way in is on the surface; the exit is at the bottom of the mine, down
## through galleries, around rock that the shovel cannot cut.


func _init() -> void:
	id = &"mine"
	name = "Mina"
	kind = LevelEnvironment.Kind.SURFACE
	order = 40
	stages.assign(["Boca da Mina", "Galerias de Carvão", "Fundo da Mina"])
	shapes.assign([Shape.TALL, Shape.BOTH, Shape.TALL])
	routes.assign([Route.DESCEND, Route.DESCEND, Route.DESCEND])


func build(g: BiomeStageGenerator) -> void:
	var heights := g.make_relief(0.18, 0.0, 3, 0.07, 0.06)
	g.fill_ground(heights, EARTH)
	g.carve_caves(heights, 4, 0.22 + g.stage_tier * 0.04, TerrainSkin.CAVE_WALL)
	g.open_into_caves(heights, 1)
	g.rock_pockets(heights, 3, 0.45 - g.stage_tier * 0.04)
	g.plant_decor(heights, 3, [TreeArt.PINE])
	g.place_spawn_and_exit(heights)
	g.add_need("digger", g.spawn_cell.x + 3)
	g.add_need("floater", g.stage_columns / 2)
	g.scatter_bonus(3)
