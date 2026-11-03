class_name BiomeStageGenerator
extends RefCounted
## Stages shaped by where they happen. The biomes are scripts of their own
## in BIOME_DIRECTORY (StageBiome), found there by themselves and played in
## their order, each for as many stages as it names: adding a biome is
## adding a file there, without touching the others.
##
## Every stage has:
## - a size that grows with the stage (stage_size: the first fits about one
##   screen, the last is GROWTH_AT_LAST_STAGE times bigger), and a shape:
##   long (WIDE), tall (TALL) or both (BOTH);
## - a way through: across (TRAVERSE), up to an exit high above (ASCEND) or
##   down to one deep below (DESCEND);
## - its biome's ground and pieces, built with the toolkit below (relief,
##   ravines, caves, trees, a pyramid, scaffolding, items for the obstacles).
## Scenery trees stand behind the terrain and carry nothing
## (BackgroundDecor). A border of bedrock nothing breaks walls the stage in
## unless the biome says otherwise.
##
## The result is the core's plain MazeStageData. generate() makes a run's
## stage; generate_custom() makes any biome at any size (the editor).
##
## Every stage is checked to be winnable (CellStageSolver): it is drawn
## again until one lemming can walk from the entrance to an exit far across
## it with the items placed on its way, and that solution is recorded.

const BIOME_DIRECTORY := "res://scripts/procedural/biomes/"

## The first stage: about one screen at 1080p.
const BASE_SIZE := Vector2i(56, 30)
## How much bigger the last stage is than the first, along its long side.
const GROWTH_AT_LAST_STAGE := 3.6
## A tall stage is never narrower than this, nor a long one lower.
const MIN_SIZE := Vector2i(40, 26)

const EMPTY := StageBiome.EMPTY
const EARTH := StageBiome.EARTH
const CONCRETE := StageBiome.CONCRETE
const HEADROOM := StageBiome.HEADROOM
const BORDER := StageBiome.BORDER

## Why each try of the last stage drawn was thrown away (for tools that
## check the generator).
static var last_report := PackedStringArray()
## The biomes found in BIOME_DIRECTORY, in their order (filled on first use).
static var _biomes: Array[StageBiome] = []

var rng := RandomNumberGenerator.new()
var _noise := FastNoiseLite.new()
var stage_columns := 64
var stage_rows := 32
var _cells := PackedByteArray()
var cell_skins := {}
var backdrop_skins := {}
var ladder_cells: Array[Vector2i] = []
var _bricks: Array[Rect2] = []
## Soil steps up the one-block rises (TerrainDestructible.initial_ramps).
var _ramps: Array[Rect2] = []
var _spots: Array[Dictionary] = []
## Tools the obstacles call for, with each obstacle's column (its item goes
## somewhere before it).
var _needs: Array[Dictionary] = []
var _decor: Array[Dictionary] = []
## Furnished rooms (RoomDecor): {"kind", "rect"}.
var furnished_rooms: Array[Dictionary] = []
var _unbreakable := {}
## 0 to 1: how hard, over the whole run (or as the editor asks).
var stage_difficulty := 0.0
var stage_tier := 0
var stage_route := StageBiome.Route.TRAVERSE
var spawn_cell := Vector2i.ZERO
var exit_cell := Vector2i.ZERO


## Every biome, in the order a run goes through them.
static func biomes() -> Array[StageBiome]:
	if _biomes.is_empty():
		_biomes = _find_biomes()
	return _biomes


static func _find_biomes() -> Array[StageBiome]:
	var found: Array[StageBiome] = []
	for file in DirAccess.get_files_at(BIOME_DIRECTORY):
		# Exported games list scripts as .gd.remap or .gdc; load() takes .gd.
		var script_file := file.trim_suffix(".remap")
		if script_file.ends_with(".gdc"):
			script_file = script_file.trim_suffix(".gdc") + ".gd"
		if not script_file.ends_with(".gd"):
			continue
		var script := load(BIOME_DIRECTORY.path_join(script_file)) as GDScript
		var biome := script.new() as StageBiome if script != null else null
		if biome == null or biome.stages.is_empty():
			push_error("%s is not a StageBiome with stages" % file)
			continue
		found.append(biome)
	found.sort_custom(func(a: StageBiome, b: StageBiome) -> bool: return a.order < b.order)
	assert(not found.is_empty(), "No biome in " + BIOME_DIRECTORY)
	return found


## How many stages a run has: every stage of every biome.
static func stage_count() -> int:
	var count := 0
	for biome in biomes():
		count += biome.stages.size()
	return count


static func biome_of(stage_index: int) -> StageBiome:
	var index := maxi(stage_index, 0)
	for biome in biomes():
		if index < biome.stages.size():
			return biome
		index -= biome.stages.size()
	return biomes().back()


## Which of its biome's stages a run's stage is (0 for the first).
static func tier_of(stage_index: int) -> int:
	var index := maxi(stage_index, 0)
	for biome in biomes():
		if index < biome.stages.size():
			return index
		index -= biome.stages.size()
	return biomes().back().stages.size() - 1


static func biome_by_id(biome_id: StringName) -> StageBiome:
	for biome in biomes():
		if biome.id == biome_id:
			return biome
	return biomes()[0]


## Size of a run's stage: bigger with every stage, along the long side for a
## long or a tall stage, along both (less on each) for one that is both.
static func stage_size(stage_index: int, shape: StageBiome.Shape) -> Vector2i:
	var growth := 1.0 + (GROWTH_AT_LAST_STAGE - 1.0) * clampf(float(stage_index) / float(maxi(stage_count() - 1, 1)), 0.0, 1.0)
	var size := Vector2(BASE_SIZE)
	match shape:
		StageBiome.Shape.WIDE:
			size.x *= growth
		StageBiome.Shape.TALL:
			size = Vector2(BASE_SIZE.x * 0.8, BASE_SIZE.y * growth * 1.2)
		StageBiome.Shape.BOTH:
			size *= pow(growth, 0.65)
	return Vector2i(maxi(roundi(size.x), MIN_SIZE.x), maxi(roundi(size.y), MIN_SIZE.y))


## A run's stage.
static func generate(seed_value: int, stage_index: int) -> MazeStageData:
	var index := clampi(stage_index, 0, stage_count() - 1)
	var biome := biome_of(index)
	var tier := tier_of(index)
	var size := stage_size(index, biome.shapes[tier])
	return _generate_solved(hash("%d:%d" % [seed_value, index]), biome, tier, size, float(index) / float(maxi(stage_count() - 1, 1)))


## Any biome at any size and difficulty (0 to 1), as its tier-th stage is
## shaped (for the editor).
static func generate_custom(seed_value: int, biome_id: StringName, size: Vector2i, difficulty: float, tier: int = 1) -> MazeStageData:
	var generator := BiomeStageGenerator.new()
	var clamped := Vector2i(maxi(size.x, MIN_SIZE.x), maxi(size.y, MIN_SIZE.y))
	var biome := biome_by_id(biome_id)
	return _generate_solved(seed_value, biome, clampi(tier, 0, biome.stages.size() - 1), clamped, clampf(difficulty, 0.0, 1.0))


## Draws stages until one can be won (CellStageSolver) along a way that
## crosses the stage, with the items its solution needs on that way. The
## last one drawn if none could (its solution then stays empty).
static func _generate_solved(seed_value: int, biome: StageBiome, tier: int, size: Vector2i, difficulty: float) -> MazeStageData:
	var data: MazeStageData = null
	last_report.clear()
	var easy_seed := -1
	for attempt in MAX_ATTEMPTS:
		var generator := BiomeStageGenerator.new()
		var attempt_seed := hash("%d:%d" % [seed_value, attempt])
		data = generator._generate(attempt_seed, biome, tier, size, difficulty)
		if generator._solve_and_place_items(data):
			return data
		if generator.was_too_easy and easy_seed < 0:
			easy_seed = attempt_seed
	# Better an easy stage than none.
	if easy_seed >= 0:
		var generator := BiomeStageGenerator.new()
		generator.allow_easy = true
		data = generator._generate(easy_seed, biome, tier, size, difficulty)
		if generator._solve_and_place_items(data):
			return data
	push_warning("No winnable %s stage %d in %d tries" % [biome.id, tier + 1, MAX_ATTEMPTS])
	return data


func _generate(seed_value: int, biome: StageBiome, tier: int, size: Vector2i, difficulty: float) -> MazeStageData:
	_biome = biome
	rng.seed = seed_value
	_noise.seed = rng.randi()
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	stage_tier = tier
	stage_route = biome.routes[tier]
	stage_difficulty = difficulty
	stage_columns = size.x
	stage_rows = size.y
	_cells = PackedByteArray()
	_cells.resize(stage_columns * stage_rows)
	_cells.fill(EMPTY)
	biome.build(self)
	if biome.walled:
		_wall_in()
	if not biome.floating_ground:
		_remove_specks()
	_add_ramps()
	return _to_data(biome)


# --- Winnable -------------------------------------------------------------------

## A stage drawn is thrown away and drawn again at most this many times.
const MAX_ATTEMPTS := 8
## A solution uses at most this many kinds of tool (a tool bar has four
## places).
const MAX_TOOL_KINDS := 4
## The tools a generated stage's solution may use.
const SOLUTION_TOOLS: Array[String] = ["digger", "builder", "bridge", "basher", "ladder_vertical", "floater"]
## How much of the stage the entrance and the exit lie apart, along the
## route's way (across for a crossing, up or down for a climb or a descent),
## so a big stage is not won a few steps from the entrance.
const MIN_SPAN_ACROSS := 0.6
const MIN_SPAN_UP_OR_DOWN := 0.25
## Seconds a lemming takes to walk one block (32px at 50px/s), and the
## stage's clock against the solution's walk.
const SECONDS_PER_BLOCK := 0.64
const TIME_PER_TOOL_SECONDS := 8
const TIME_FACTOR := 1.6
const TIME_MARGIN_SECONDS := 40


## Set when a try was thrown away only for being too easy; allow_easy
## keeps it (the last resort).
var was_too_easy := false
var _biome: StageBiome = null
var allow_easy := false


## Finds a way to the exit with tools to spare, puts one item for every
## tool on that way before the place it is used, checks the stage can then
## be won with those items alone and records how. False if any step fails.
func _solve_and_place_items(data: MazeStageData) -> bool:
	if not _spans_stage():
		last_report.append("entrance %s and exit %s too close" % [spawn_cell, exit_cell])
		return false
	var hints: Array[int] = []
	for need in _needs:
		hints.append(int(need.column))
	var route := CellStageSolver.solve_unlimited(data, SOLUTION_TOOLS if _biome.solution_tools.is_empty() else _biome.solution_tools, hints)
	if not route.solved and not _exit_where_the_way_ends(data, route):
		last_report.append("no way: %s %s" % [route.reason, route.get("best", "")])
		return false
	if not route.solved:
		route = route.nearest
	# A stage further into its biome asks for more: one tool in the first,
	# two in the second, three in the third.
	if route.steps.size() < stage_tier + 1 and not allow_easy:
		last_report.append("too easy: %d tools" % route.steps.size())
		was_too_easy = true
		return false
	var kinds := {}
	for step: Dictionary in route.steps:
		kinds[step.tool] = true
	if kinds.size() > MAX_TOOL_KINDS:
		last_report.append("too many kinds of tool: %s" % ", ".join(kinds.keys()))
		return false
	_place_items_along(route)
	data.item_spots = _spots
	var check := CellStageSolver.solve(data, hints)
	if not check.solved:
		last_report.append("not with the items: %s %s" % [check.reason, check.get("best", "")])
		return false
	data.solution.clear()
	for step: Dictionary in check.steps:
		data.solution.append({"tool": step.tool, "from_column": step.column, "to_column": step.column,
			"row": roundi(float(step.feet) / CellStageSolver.UNITS_PER_CELL), "direction": step.direction,
			"why": "", "collect_first": step.collect_first})
	var walk_seconds := int(check.walk_steps) * SECONDS_PER_BLOCK
	data.suggested_time_seconds = clampi(ceili(walk_seconds * TIME_FACTOR) + TIME_PER_TOOL_SECONDS * check.steps.size() + TIME_MARGIN_SECONDS, 90, 900)
	return true


## When the exit drawn cannot be reached, it goes where the nearest way to
## it ends, if that place is still far enough from the entrance and a
## floor to stand the exit on. The bottom chamber of a descent stays as a
## cave without it.
func _exit_where_the_way_ends(data: MazeStageData, route: Dictionary) -> bool:
	var nearest: Dictionary = route.get("nearest", {})
	if not nearest.has("point") or not nearest.on_whole_block:
		return false
	var previous_exit := exit_cell
	exit_cell = nearest.point
	if not _spans_stage() or cell_kind(exit_cell.x, exit_cell.y) == EMPTY:
		exit_cell = previous_exit
		return false
	data.exit_cell = exit_cell
	return true


## Far enough: across most of the stage, or a good part of its height up
## (a climb) or down (a descent).
func _spans_stage() -> bool:
	if absi(exit_cell.x - spawn_cell.x) >= stage_columns * MIN_SPAN_ACROSS:
		return true
	match stage_route:
		StageBiome.Route.ASCEND:
			return spawn_cell.y - exit_cell.y >= stage_rows * MIN_SPAN_UP_OR_DOWN
		StageBiome.Route.DESCEND:
			return exit_cell.y - spawn_cell.y >= stage_rows * MIN_SPAN_UP_OR_DOWN
	return false


## One item for each tool the way uses, on a floor the lemming walks over
## between the previous tool and this one.
func _place_items_along(route: Dictionary) -> void:
	var path: Array = route.path
	var previous := 0
	for step: Dictionary in route.steps:
		var at: int = step.path_index
		var choices := _item_floors(path, previous, at - 2, false)
		if choices.is_empty():
			choices = _item_floors(path, 0, at, false)
		if choices.is_empty():
			choices = _item_floors(path, 0, at, true)
		if choices.is_empty():
			last_report.append("no floor for the %s item before column %d" % [step.tool, step.column])
			continue
		var spot: Vector2i = choices[rng.randi_range(0, choices.size() - 1)]
		_spots = _spots.filter(func(other: Dictionary) -> bool: return Vector2i(other.column, other.row) != spot)
		_spots.append({"column": spot.x, "row": spot.y, "kind": MazeLayout.SpotKind.TOOL, "tool_id": step.tool,
			"amount": 1, "required": true, "spot_index": _spots.size()})
		previous = at


## Cells of the path from..to (indexes) where an item can stand: on ground
## that is there from the start, with the air over it open from the start
## too (never a place the way only reaches by digging: the item would sit
## inside the rock), not on the exit, not where an item already is. On a
## whole block; on a ramp's step only with on_ramps (the item then floats
## over the step, at the top of its block).
func _item_floors(path: Array, from: int, to: int, on_ramps: bool) -> Array[Vector2i]:
	var floors: Array[Vector2i] = []
	for index in range(maxi(from, 0), mini(to, path.size() - 1) + 1):
		var point: Vector3i = path[index]
		var whole := point.y % CellStageSolver.UNITS_PER_CELL == 0
		if whole == on_ramps:
			continue
		var cell := Vector2i(point.x, point.y / CellStageSolver.UNITS_PER_CELL)
		if cell.x == exit_cell.x or floors.has(cell) or cell_kind(cell.x, cell.y - 1) != EMPTY:
			continue
		if whole and cell_kind(cell.x, cell.y) == EMPTY:
			continue
		if _spots.any(func(other: Dictionary) -> bool: return other.kind == MazeLayout.SpotKind.TOOL and Vector2i(other.column, other.row) == cell):
			continue
		floors.append(cell)
	return floors


# --- Toolkit for the biomes (scripts/procedural/biomes) ----------------------

# --- Relief ------------------------------------------------------------------------

## Ground heights (the top solid row of each column). base_share: where the
## ground lies (share of the height from the top) at the left; slope: how
## much higher it ends at the right (negative: lower). Hills roll gently
## (one block per column at most, so the troop walks them), but now and
## then a cliff rises or drops two to five blocks: those need a tool.
func make_relief(base_share: float, slope: float, amplitude: int, frequency: float, cliff_chance: float) -> PackedInt32Array:
	_noise.frequency = frequency
	_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	_noise.fractal_octaves = 3
	var heights := PackedInt32Array()
	heights.resize(stage_columns)
	var previous := -1
	var flat_for := MIN_PLATEAU
	for column in stage_columns:
		flat_for += 1
		var share := float(column) / float(stage_columns - 1)
		var base := (base_share - slope * share) * stage_rows
		var target := clampi(roundi(base + _noise.get_noise_1d(column * 1.0) * amplitude * 2.0), 4, stage_rows - 5)
		if previous < 0:
			previous = target
		var difference := target - previous
		if absi(difference) >= 2 and rng.randf() < cliff_chance:
			previous += clampi(difference, -5, 5)
			flat_for = 0
			if difference < 0:
				add_need(["ladder_vertical", "builder", "climber"][rng.randi_range(0, 2)], column)
		elif difference != 0 and flat_for >= MIN_PLATEAU:
			previous += clampi(difference, -1, 1)
			flat_for = 0
		heights[column] = previous
	return heights


## Gaps down to the bottom: falling in is the end.
func cut_ravines(heights: PackedInt32Array, count: int, width: int) -> void:
	for index in count:
		var at := BORDER + 6 + (stage_columns - BORDER * 2 - 14) * (index + 1) / (count + 1) + rng.randi_range(-2, 2)
		for column in range(at, mini(at + width + rng.randi_range(0, 1), stage_columns - BORDER - 4)):
			heights[column] = stage_rows
		add_need("bridge", at)


func fill_ground(heights: PackedInt32Array, material: int) -> void:
	for column in stage_columns:
		if heights[column] < stage_rows:
			fill_cells(column, heights[column], column, stage_rows - 1, material)


## The current top solid row of every column.
func surface_heights() -> PackedInt32Array:
	var heights := PackedInt32Array()
	heights.resize(stage_columns)
	for column in stage_columns:
		heights[column] = _surface_row(column)
	return heights


## Caves under the ground, from depth rows below the surface down to the
## bottom: rounded halls stretched sideways (so there is floor to walk on),
## with the cave's wall drawn behind their air.
func carve_caves(heights: PackedInt32Array, depth: int, density: float, wall: StringName) -> void:
	_noise.frequency = 0.075
	_noise.fractal_type = FastNoiseLite.FRACTAL_NONE
	var threshold := 0.55 - density
	for column in range(BORDER, stage_columns - BORDER):
		if heights[column] >= stage_rows:
			continue
		for row in range(heights[column] + depth, stage_rows - 2):
			if _noise.get_noise_2d(column * 0.8, row * 1.7) > threshold:
				set_cell_kind(column, row, EMPTY)
				if wall != &"":
					backdrop_skins[Vector2i(column, row)] = wall


## Holes from the surface down into the caves below, so the underground is
## part of the way.
func open_into_caves(heights: PackedInt32Array, count: int) -> void:
	for index in count:
		for attempt in 20:
			var column := rng.randi_range(BORDER + 8, stage_columns - BORDER - 9)
			var top := heights[column]
			if top >= stage_rows:
				continue
			var depth := 0
			while top + depth < stage_rows - 2 and cell_kind(column, top + depth) != EMPTY and depth < 8:
				depth += 1
			if depth >= 8 or top + depth >= stage_rows - 2:
				continue
			fill_cells(column, top, column + 1, top + depth - 1, EMPTY)
			for row in range(top + 1, top + depth):
				backdrop_skins[Vector2i(column, row)] = TerrainSkin.CAVE_WALL
				backdrop_skins[Vector2i(column + 1, row)] = TerrainSkin.CAVE_WALL
			add_need("floater", column)
			break


## Rounded lumps of rock the shovel cannot cut, inside the ground only.
func rock_pockets(heights: PackedInt32Array, depth: int, threshold: float) -> void:
	_noise.frequency = 0.11
	for column in range(BORDER, stage_columns - BORDER):
		if heights[column] >= stage_rows:
			continue
		for row in range(heights[column] + depth, stage_rows - 1):
			if cell_kind(column, row) == EARTH and _noise.get_noise_2d(column + 500.0, row * 1.3) > threshold:
				set_cell_kind(column, row, CONCRETE)


## Streaks of crystal through the rock.
func crystal_veins(count: int) -> void:
	for vein in count:
		var position := Vector2(rng.randi_range(4, stage_columns - 5), rng.randi_range(4, stage_rows - 5))
		var heading := rng.randf() * TAU
		for step in rng.randi_range(5, 10):
			if cell_kind(roundi(position.x), roundi(position.y)) == EARTH:
				set_cell_kind(roundi(position.x), roundi(position.y), CONCRETE)
			heading += rng.randf_range(-0.5, 0.5)
			position += Vector2.from_angle(heading)


## The troop starts in a cave at the bottom of the left side; a shaft leads
## up from it to the open air.
func start_cave(heights: PackedInt32Array, wall: StringName) -> void:
	var floor_row := stage_rows - 3
	var left := BORDER + 1
	var right := mini(left + 10, stage_columns / 3)
	fill_cells(left, floor_row - 4, right, floor_row - 1, EMPTY)
	var shaft := right - 1
	fill_cells(shaft, heights[shaft], shaft + 1, floor_row - 4, EMPTY)
	for column in range(left, shaft + 2):
		for row in range(heights[shaft] + 1, floor_row):
			if cell_kind(column, row) == EMPTY:
				backdrop_skins[Vector2i(column, row)] = wall
	add_need("ladder_vertical", shaft)
	spawn_cell = Vector2i(left + 2, floor_row)


## A chamber carved at the bottom right with the exit in it: the deepest
## place of a stage that goes down, easy to spot. Returns the exit.
func _bottom_chamber(wall: StringName) -> Vector2i:
	var floor_row := stage_rows - 3
	var right := stage_columns - BORDER - 2
	var left := right - 9
	fill_cells(left, floor_row - 4, right, floor_row - 1, EMPTY)
	fill_cells(left, floor_row, right, floor_row, EARTH)
	for row in range(floor_row - 4, floor_row):
		for column in range(left, right + 1):
			backdrop_skins[Vector2i(column, row)] = wall
	return Vector2i(left + 6, floor_row)


## A volcano filling the stage: slopes rising from both sides to a crater
## near the top, cliffs on the way.
func volcano_cone() -> PackedInt32Array:
	var heights := PackedInt32Array()
	heights.resize(stage_columns)
	var centre := stage_columns / 2
	var rim := maxi(4, stage_rows / 6)
	var foot := stage_rows - 4
	var previous := foot
	for column in stage_columns:
		var distance := absf(column - centre) / (stage_columns / 2.0)
		var target := roundi(lerpf(rim, foot, clampf(distance * 1.15, 0.0, 1.0)))
		if absi(column - centre) <= 3:
			target = rim + 3
		var difference := target - previous
		previous += clampi(difference, -4, 4) if rng.randf() < 0.35 else clampi(difference, -1, 1)
		heights[column] = previous
	return heights


## A stepped pyramid on the ground, steps two blocks high; returns its top.
func build_pyramid(heights: PackedInt32Array, steps: int) -> Vector2i:
	var base_width := steps * 4 + 3
	var left := stage_columns - BORDER - base_width - 4
	if left < stage_columns / 3:
		return Vector2i(-1, -1)
	var ground := heights[left]
	for column in range(left, left + base_width):
		ground = maxi(ground, mini(heights[column], stage_rows - 3))
	for step in steps:
		fill_cells(left + step * 2, ground - (step + 1) * 2, left + base_width - 1 - step * 2, ground - 1, CONCRETE)
	# A tomb inside, its door to dig to.
	fill_cells(left + steps, ground - 3, left + base_width - 1 - steps, ground - 2, EMPTY)
	add_spot(left + base_width / 2, ground - 1, MazeLayout.SpotKind.BONUS)
	add_need("builder", left)
	return Vector2i(left + base_width / 2, ground - steps * 2)


## Scaffolding up one face of a tower: wooden platforms every few rows,
## some joined by ladders already standing, the rest left to the player.
func scaffold(left: int, right: int, top: int, street: int) -> void:
	var on_left := rng.randf() < 0.5
	var face := left - 1 if on_left else right + 1
	var reach := 3
	var row := street - 4
	var tile := Constants.TERRAIN_TILE_SIZE
	while row > top + 2:
		for offset in reach:
			var column := face - offset if on_left else face + offset
			if cell_kind(column, row) == EMPTY:
				_bricks.append(Rect2(column * tile, row * tile, tile, tile / 4.0))
		if rng.randf() < 0.55:
			var ladder_column := face - 1 if on_left else face + 1
			for ladder_row in range(row, row + 4):
				if cell_kind(ladder_column, ladder_row) == EMPTY:
					ladder_cells.append(Vector2i(ladder_column, ladder_row))
		row -= 4


func carve_disc(centre: Vector2, radius: float) -> void:
	for row in range(floori(centre.y - radius), ceili(centre.y + radius) + 1):
		for column in range(floori(centre.x - radius), ceili(centre.x + radius) + 1):
			if Vector2(column, row).distance_to(centre) <= radius:
				set_cell_kind(column, row, EMPTY)


## A rounded lump, flat on top so it can be stood on.
func blob(centre: Vector2i, radii: Vector2, material: int) -> void:
	for row in range(centre.y, centre.y + ceili(radii.y) + 1):
		for column in range(centre.x - ceili(radii.x), centre.x + ceili(radii.x) + 1):
			var offset := Vector2(column - centre.x, row - centre.y)
			if (offset.x / radii.x) ** 2 + (offset.y / radii.y) ** 2 <= 1.0:
				set_cell_kind(column, row, material)


## Two columns of bedrock at each side, top to bottom, and the rock of the
## top and bottom rows: nothing breaks them.
func _wall_in() -> void:
	for column in [0, 1, stage_columns - 2, stage_columns - 1]:
		for row in stage_rows:
			set_cell_kind(column, row, EARTH)
			_unbreakable[Vector2i(column, row)] = true
	for row in [0, stage_rows - 1]:
		for column in stage_columns:
			if cell_kind(column, row) != EMPTY:
				_unbreakable[Vector2i(column, row)] = true
	for cell: Vector2i in _unbreakable:
		cell_skins[cell] = TerrainSkin.BORDER
		backdrop_skins.erase(cell)


# --- Trees ---------------------------------------------------------------------------

## Scenery trees behind the terrain, on flat ground, apart from each other.
func plant_decor(heights: PackedInt32Array, count: int, kinds: Array[StringName]) -> void:
	var used: Array[int] = []
	for attempt in count * 6:
		if used.size() >= count:
			return
		var column := rng.randi_range(BORDER + 3, stage_columns - BORDER - 4)
		var ground := heights[column]
		if ground >= stage_rows or _surface_row(column) != ground or cell_kind(column, ground - 1) != EMPTY:
			continue
		if used.any(func(other: int) -> bool: return absi(other - column) < 5):
			continue
		var kind := kinds[rng.randi_range(0, kinds.size() - 1)]
		var half := rng.randi_range(2, 3)
		var height := rng.randi_range(6, 9)
		var top := ground - height
		if top < 2:
			continue
		var crown_rows := 1 if kind == TreeArt.PALM else (2 if kind == TreeArt.MUSHROOM else half + 1)
		var crown: Array[Vector2i] = []
		for index in crown_rows:
			var row := top + index
			var reach := half if kind != TreeArt.PINE and kind != TreeArt.SNOW_PINE else index
			for x in range(column - reach, column + reach + 1):
				crown.append(Vector2i(x, row))
		var trunk: Array[Vector2i] = []
		for row in range(top, ground):
			trunk.append(Vector2i(column, row))
		_decor.append({"kind": kind, "box": Rect2i(column - half - 1, top - 1, half * 2 + 3, ground - top + 1), "crown": crown, "trunk": trunk, "seed": rng.randi()})
		used.append(column)


# --- Places ------------------------------------------------------------------------

func cell_kind(column: int, row: int) -> int:
	if column < 0 or row < 0 or column >= stage_columns or row >= stage_rows:
		return CONCRETE
	return _cells[row * stage_columns + column]


func set_cell_kind(column: int, row: int, value: int) -> void:
	if column < 0 or row < 0 or column >= stage_columns or row >= stage_rows:
		return
	_cells[row * stage_columns + column] = value
	var cell := Vector2i(column, row)
	if value == EMPTY:
		cell_skins.erase(cell)
	else:
		backdrop_skins.erase(cell)


func fill_cells(x0: int, y0: int, x1: int, y1: int, value: int) -> void:
	for row in range(mini(y0, y1), maxi(y0, y1) + 1):
		for column in range(mini(x0, x1), maxi(x0, x1) + 1):
			set_cell_kind(column, row, value)


func _surface_row(column: int) -> int:
	for row in stage_rows:
		if cell_kind(column, row) != EMPTY:
			return row
	return stage_rows


## Whether a lemming can stand on top of that cell.
func _is_floor(column: int, row: int) -> bool:
	if cell_kind(column, row) == EMPTY:
		return false
	for above in range(1, HEADROOM + 1):
		if cell_kind(column, row - above) != EMPTY:
			return false
	return true


## Every floor a lemming could stand on, with ground at both sides (not a
## spike).
func _floors(from: int, to: int) -> Array[Vector2i]:
	var floors: Array[Vector2i] = []
	for column in range(maxi(from, BORDER + 1), mini(to, stage_columns - BORDER - 2) + 1):
		for row in range(2, stage_rows - 1):
			if _is_floor(column, row) and cell_kind(column - 1, row) != EMPTY and cell_kind(column + 1, row) != EMPTY:
				floors.append(Vector2i(column, row))
	return floors


## The floor nearest to a column on the surface.
func floor_near(column: int, heights: PackedInt32Array) -> Vector2i:
	for offset in 12:
		for side in [-1, 1]:
			var x := clampi(column + offset * side, BORDER + 1, stage_columns - BORDER - 2)
			var row := _surface_row(x)
			if row < stage_rows and _is_floor(x, row) and cell_kind(x - 1, row) != EMPTY and cell_kind(x + 1, row) != EMPTY:
				return Vector2i(x, row)
	return Vector2i(column, mini(heights[column], stage_rows - 2))


## Entrance and exit by the stage's route: across (left to right on the
## surface), up (low on the left, the highest floor on the right) or down
## (on the surface, the deepest floor far from it).
func place_spawn_and_exit(heights: PackedInt32Array) -> void:
	var left := BORDER + 3
	var right := stage_columns - BORDER - 4
	var third := stage_columns / 3
	match stage_route:
		StageBiome.Route.TRAVERSE:
			spawn_cell = floor_near(left + 2, heights)
			exit_cell = floor_near(right - 2, heights)
		StageBiome.Route.ASCEND:
			spawn_cell = _lowest(_floors(left, third))
			exit_cell = _highest(_floors(right - third, right))
		StageBiome.Route.DESCEND:
			# As high as the left side goes: the way down is the stage's.
			spawn_cell = _highest(_floors(left, third))
			exit_cell = _bottom_chamber(TerrainSkin.CAVE_WALL)
	if spawn_cell == Vector2i(-1, -1):
		spawn_cell = floor_near(left + 2, heights)
	if exit_cell == Vector2i(-1, -1):
		exit_cell = floor_near(right - 2, heights)


## A floor inside the rock (rock over it, below the stage's top rows)
## between two columns: the highest one, or one of the lowest.
func cave_floor(from: int, to: int, highest: bool) -> Vector2i:
	var floors := _floors(from, to).filter(func(cell: Vector2i) -> bool:
		return cell.y > HEADROOM + 3 and _surface_row(cell.x) < cell.y - HEADROOM)
	var chosen := _highest(floors) if highest else _lowest(floors)
	return chosen if chosen.x >= 0 else Vector2i(from + 2, stage_rows - 3)


func _lowest(floors: Array[Vector2i]) -> Vector2i:
	if floors.is_empty():
		return Vector2i(-1, -1)
	floors.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y > b.y)
	return floors[rng.randi_range(0, mini(2, floors.size() - 1))]


func _highest(floors: Array[Vector2i]) -> Vector2i:
	if floors.is_empty():
		return Vector2i(-1, -1)
	floors.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y)
	return floors[rng.randi_range(0, mini(2, floors.size() - 1))]


# --- Ramps --------------------------------------------------------------------------

## The step up a one-block rise: half a block high, half a column wide.
const RAMP_STEP_HEIGHT := 16.0
const RAMP_STEP_WIDTH := 16.0
## A gentle slope changes height at most once every this many columns, so
## a hill is a few broad steps and not a staircase of single columns.
const MIN_PLATEAU := 3
## Ground left hanging in the air this small is taken away.
const SPECK_CELLS := 80


## A walking lemming steps up less than a block: a full block is a wall. So
## every one-block rise of earth gets low soil steps in front of it, on the
## side it is climbed from (both sides of a hill), and the hills can be
## walked over. Rises of two blocks or more stay walls: those are the
## obstacles that call for a tool.
func _add_ramps() -> void:
	_fill_narrow_dips()
	var claimed := {}
	for row in range(3, stage_rows):
		for column in range(1, stage_columns - 1):
			if not _is_floor_with_room(column, row - 1) or cell_kind(column, row - 1) != EARTH:
				continue
			for side in [-1, 1]:
				_ramp_up_to(column, row, side, claimed)


## Ramp pieces on the side `side` of the high column, whose floor is
## row - 1, down to the low floor at row.
func _ramp_up_to(high: int, row: int, side: int, claimed: Dictionary) -> void:
	# One step half a block high and half a column wide, against the rise:
	# the lemming goes up the block in two half steps, and it reads as a
	# plain step cut in the ground.
	var low := high + side
	if not _is_floor_with_room(low, row) or cell_kind(low, row) != EARTH:
		return
	if low == exit_cell.x or claimed.has(Vector2i(low, row)):
		return
	claimed[Vector2i(low, row)] = true
	var tile := Constants.TERRAIN_TILE_SIZE
	var left := float(low) * tile + (tile - RAMP_STEP_WIDTH if side < 0 else 0.0)
	_ramps.append(Rect2(left, row * tile - RAMP_STEP_HEIGHT, RAMP_STEP_WIDTH, RAMP_STEP_HEIGHT))


## Ground of at most SPECK_CELLS cells hanging in the air, cut loose by the
## carving (a ravine or a cave round it), is taken away: in a meadow it
## looks like a mistake. Not in a biome with floating ground on purpose.
func _remove_specks() -> void:
	var seen := {}
	for row in stage_rows:
		for column in stage_columns:
			var start := Vector2i(column, row)
			if seen.has(start) or cell_kind(column, row) == EMPTY:
				continue
			var piece: Array[Vector2i] = [start]
			seen[start] = true
			var index := 0
			while index < piece.size() and piece.size() <= SPECK_CELLS:
				var cell := piece[index]
				index += 1
				for step in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
					var next: Vector2i = cell + step
					if seen.has(next) or cell_kind(next.x, next.y) == EMPTY:
						continue
					seen[next] = true
					piece.append(next)
			if piece.size() <= SPECK_CELLS:
				for cell in piece:
					set_cell_kind(cell.x, cell.y, EMPTY)
					cell_skins.erase(cell)
	# A scenery tree that stood on what was taken away goes with it.
	_decor = _decor.filter(func(tree: Dictionary) -> bool:
		var trunk: Array = tree.trunk
		var base: Vector2i = trunk.back()
		return cell_kind(base.x, base.y + 1) != EMPTY)


## A dip one column wide and one block deep between two floors: no room
## for a ramp on both sides, and a lemming turns at its far lip. Filled.
func _fill_narrow_dips() -> void:
	for row in range(3, stage_rows - 1):
		for column in range(1, stage_columns - 1):
			if not _is_floor_with_room(column, row + 1) or cell_kind(column, row + 1) != EARTH:
				continue
			if _is_floor_with_room(column - 1, row) and _is_floor_with_room(column + 1, row) and column != spawn_cell.x and column != exit_cell.x:
				set_cell_kind(column, row, EARTH)


## Solid ground with two empty cells over it (a lemming's room).
func _is_floor_with_room(column: int, row: int) -> bool:
	return cell_kind(column, row) != EMPTY and cell_kind(column, row - 1) == EMPTY and cell_kind(column, row - 2) == EMPTY


# --- Items --------------------------------------------------------------------------

func add_need(tool_id: String, column: int) -> void:
	_needs.append({"tool": tool_id, "column": column})


func add_spot(column: int, row: int, kind: MazeLayout.SpotKind, tool_id: String = "") -> void:
	for spot in _spots:
		if absi(spot.column - column) <= 1 and spot.row == row:
			return
	_spots.append({"column": column, "row": row, "kind": kind, "tool_id": tool_id, "amount": 1, "required": kind == MazeLayout.SpotKind.TOOL, "spot_index": _spots.size()})


func scatter_bonus(count: int) -> void:
	var floors := _floors(0, stage_columns)
	for bonus in count:
		if floors.is_empty():
			return
		var at: Vector2i = floors[rng.randi_range(0, floors.size() - 1)]
		add_spot(at.x, at.y, MazeLayout.SpotKind.BONUS)


func _to_data(biome: StageBiome) -> MazeStageData:
	var data := MazeStageData.new()
	data.columns = stage_columns
	data.rows = stage_rows
	data.cells = _cells
	data.skins = cell_skins
	# Only trunks are kept as painted backdrop: the wall behind caves and
	# rooms is worked out from the cells when the stage is shown.
	var trunks := {}
	for cell: Vector2i in backdrop_skins:
		if backdrop_skins[cell] in [TerrainSkin.BARK, TerrainSkin.ALIEN_STEM, TerrainSkin.STATION_INSIDE]:
			trunks[cell] = backdrop_skins[cell]
	data.backdrop = trunks
	data.inside_wall = biome.inside_wall
	data.decor_trees = _decor
	data.rooms = furnished_rooms
	data.unbreakable = _unbreakable
	data.ladders = ladder_cells
	data.bricks = _bricks
	data.ramps = _ramps
	data.spawn_cell = spawn_cell
	data.exit_cell = exit_cell
	data.spawn_faces_left = false
	data.item_spots = _spots
	data.environment_kind = biome.kind
	data.stage_name = biome.stages[stage_tier]
	data.suggested_time_seconds = clampi(90 + (stage_columns * stage_rows) / 30, 120, 600)
	return data
