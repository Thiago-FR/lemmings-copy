extends StageBiome
## Towers far taller than a lemming can climb, with scaffolding up their
## sides (some ladders already up, the rest to build), the street below and
## a subway under it. The exit is on the tallest roof.


func _init() -> void:
	id = &"city"
	name = "Cidade"
	kind = LevelEnvironment.Kind.CITY
	order = 80
	stages.assign(["Telhados", "Becos e Pontes", "Arranha-céus"])
	shapes.assign([Shape.BOTH, Shape.TALL, Shape.TALL])
	routes.assign([Route.ASCEND, Route.ASCEND, Route.ASCEND])


func build(g: BiomeStageGenerator) -> void:
	var street := g.stage_rows - maxi(6, g.stage_rows / 5)
	g.fill_cells(0, street, g.stage_columns - 1, g.stage_rows - 1, EARTH)
	g.fill_cells(0, street, g.stage_columns - 1, street, CONCRETE)
	var heights := PackedInt32Array()
	heights.resize(g.stage_columns)
	heights.fill(street)
	# The subway: a tunnel under the street, entered by stairs at one end.
	var tunnel_top := street + 2
	g.fill_cells(BORDER + 2, tunnel_top, g.stage_columns - BORDER - 3, tunnel_top + 2, EMPTY)
	g.fill_cells(BORDER + 2, tunnel_top + 3, g.stage_columns - BORDER - 3, tunnel_top + 3, CONCRETE)
	for column in range(BORDER + 2, g.stage_columns - BORDER - 2):
		for row in range(tunnel_top, tunnel_top + 3):
			g.backdrop_skins[Vector2i(column, row)] = TerrainSkin.CAVE_WALL
	# The stairs are at the far end of the street, clear of the entrance.
	var stairs := g.stage_columns - BORDER - 7
	for step in 3:
		g.set_cell_kind(stairs + step, street, EMPTY)
		g.set_cell_kind(stairs + step, street + 1 + step, EMPTY)
	var x := BORDER + 6
	var tallest := Vector2i(-1, g.stage_rows)
	while x < g.stage_columns - BORDER - 8:
		var width := g.rng.randi_range(6, 10)
		var right := mini(x + width - 1, g.stage_columns - BORDER - 3)
		var top := street - roundi((street - 4) * g.rng.randf_range(0.35, 0.55 + g.stage_difficulty * 0.4))
		g.fill_cells(x, top, right, street - 1, CONCRETE)
		for row in range(top, street):
			for column in range(x, right + 1):
				g.cell_skins[Vector2i(column, row)] = TerrainSkin.WALL
		g.scaffold(x, right, top, street)
		if top < tallest.y:
			tallest = Vector2i((x + right) / 2, top)
		x = right + g.rng.randi_range(4, 7)
	g.spawn_cell = Vector2i(BORDER + 3, street)
	g.exit_cell = tallest if tallest.x >= 0 else Vector2i(g.stage_columns - 6, street)
	g.add_need("ladder_vertical", g.stage_columns / 3)
	g.add_need("builder", g.stage_columns / 2)
	g.scatter_bonus(3)
