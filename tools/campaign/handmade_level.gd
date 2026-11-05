class_name HandmadeLevel
extends RefCounted
## A campaign level drawn by hand, one file per level (tools/campaign/
## level_NN.gd sets the fields in _init). The map is text, one string per
## row, every row as wide as the first:
##   '#' earth, '%' concrete (only the jackhammer and explosives break it),
##   '.' or ' ' air,
##   'S' the entrance: lemmings land on the block under it,
##   'E' the exit: it stands on the block under it,
##   'H' a ladder segment (air with a ladder in it),
##   'r' / 'l' air with a soil step (half a block high, half a column wide)
##       against its right / left side: what makes a one-block rise walkable.
## A pit left open down to the bottom row is a fall into the void. The
## outer two columns become the unbreakable border whatever is drawn there.
## Built with the landscape's looks (biome_id: its background, blocks,
## trees and cave walls) by tools/build_handmade_campaign.tscn.

var level_name := ""
## The landscape (StageBiome id: meadow, forest, desert, mine, crystal,
## glacier, volcano, city, planet, space).
var biome_id: StringName = &"meadow"
var map: PackedStringArray = []
var lemmings := 10
## Seconds between two lemmings leaving the entrance.
var spawn_seconds := 1.5
## Share of the lemmings to save (0 to 1).
var goal := 0.5
var time_seconds := 180
## tool id -> charges.
var tools := {}
var spawn_faces_left := false
## Scenery trees on the surface (the biome's kinds), how many to try.
var trees := 0
## The robot's way to win (tests/test_campaign_level.tscn), one hand-out
## per entry: {"tool", "from_column", "to_column", "row" (the floor row it
## walks on), "direction" (+1 right, -1 left, 0 either)}. Every hand-out goes
## to the same lemming (the first one given a tool), unless it says "who":
## "any", "other" (not that lemming) or "each" (everyone passing there).
var solution: Array[Dictionary] = []


## The level as stage data (cells, entrance, exit, looks).
func build() -> MazeStageData:
	assert(not map.is_empty(), "%s has no map" % level_name)
	var biome := BiomeStageGenerator.biome_by_id(biome_id)
	assert(biome != null, "Unknown landscape '%s'" % biome_id)
	var g := BiomeStageGenerator.new()
	g.rng.seed = hash(level_name)
	g.stage_columns = map[0].length()
	g.stage_rows = map.size()
	g._cells = PackedByteArray()
	g._cells.resize(g.stage_columns * g.stage_rows)
	var tile := float(Constants.TERRAIN_TILE_SIZE)
	var found_spawn := false
	var found_exit := false
	for row in map.size():
		var line := map[row]
		assert(line.length() == g.stage_columns, "%s: row %d is %d wide, expected %d" % [level_name, row, line.length(), g.stage_columns])
		for column in line.length():
			var symbol := line[column]
			var kind := BiomeStageGenerator.EMPTY
			match symbol:
				"#":
					kind = BiomeStageGenerator.EARTH
				"%":
					kind = BiomeStageGenerator.CONCRETE
				"S":
					g.spawn_cell = Vector2i(column, row + 1)
					found_spawn = true
				"E":
					g.exit_cell = Vector2i(column, row + 1)
					found_exit = true
				"H":
					g.ladder_cells.append(Vector2i(column, row))
				"r", "l":
					var left := column * tile + (tile - BiomeStageGenerator.RAMP_STEP_WIDTH if symbol == "r" else 0.0)
					g._ramps.append(Rect2(left, (row + 1) * tile - BiomeStageGenerator.RAMP_STEP_HEIGHT, BiomeStageGenerator.RAMP_STEP_WIDTH, BiomeStageGenerator.RAMP_STEP_HEIGHT))
				".", " ":
					pass
				_:
					assert(false, "%s: unknown symbol '%s' at %d,%d" % [level_name, symbol, column, row])
			g._cells[row * g.stage_columns + column] = kind
	assert(found_spawn and found_exit, "%s needs an S and an E" % level_name)
	g._wall_in()
	if trees > 0:
		g.plant_decor(g.surface_heights(), trees, _tree_kinds())
	var data := g._to_data(biome)
	data.stage_name = level_name
	data.spawn_faces_left = spawn_faces_left
	data.solution = solution.duplicate(true)
	data.suggested_time_seconds = time_seconds
	return data


func _tree_kinds() -> Array[StringName]:
	match biome_id:
		&"desert":
			return [TreeArt.PALM]
		&"glacier":
			return [TreeArt.SNOW_PINE]
		&"planet":
			return [TreeArt.MUSHROOM]
	return [TreeArt.PINE]
