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
## Not yet: checking a stage can be won, and recording its solution.

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
var _spots: Array[Dictionary] = []
## Tools the obstacles call for, with each obstacle's column (its item goes
## somewhere before it).
var _needs: Array[Dictionary] = []
var _decor: Array[Dictionary] = []
## Furnished rooms (RoomDecor): {"kind", "rect"}.
var furnished_rooms: Array[Dictionary] = []
var climb_tree_tops: Array[Vector2i] = []
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
	var generator := BiomeStageGenerator.new()
	var size := stage_size(index, biome.shapes[tier])
	return generator._generate(hash("%d:%d" % [seed_value, index]), biome, tier, size, float(index) / float(maxi(stage_count() - 1, 1)))


## Any biome at any size and difficulty (0 to 1), as its tier-th stage is
## shaped (for the editor).
static func generate_custom(seed_value: int, biome_id: StringName, size: Vector2i, difficulty: float, tier: int = 1) -> MazeStageData:
	var generator := BiomeStageGenerator.new()
	var clamped := Vector2i(maxi(size.x, MIN_SIZE.x), maxi(size.y, MIN_SIZE.y))
	var biome := biome_by_id(biome_id)
	return generator._generate(seed_value, biome, clampi(tier, 0, biome.stages.size() - 1), clamped, clampf(difficulty, 0.0, 1.0))


func _generate(seed_value: int, biome: StageBiome, tier: int, size: Vector2i, difficulty: float) -> MazeStageData:
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
	_place_tools()
	return _to_data(biome)


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
	for column in stage_columns:
		var share := float(column) / float(stage_columns - 1)
		var base := (base_share - slope * share) * stage_rows
		var target := clampi(roundi(base + _noise.get_noise_1d(column * 1.0) * amplitude * 2.0), 4, stage_rows - 5)
		if previous < 0:
			previous = target
		var difference := target - previous
		if absi(difference) >= 2 and rng.randf() < cliff_chance:
			previous += clampi(difference, -5, 5)
			if difference < 0:
				add_need(["ladder_vertical", "builder", "climber"][rng.randi_range(0, 2)], column)
		else:
			previous += clampi(difference, -1, 1)
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

## Trees whose square crowns can be climbed onto: a trunk the troop walks
## past, right under a crown of leaf blocks. Some carry an item on top.
func plant_climb_trees(heights: PackedInt32Array, count: int, with_items: bool, tall: bool = false) -> void:
	var placed := 0
	for attempt in count * 8:
		if placed >= count:
			return
		var column := rng.randi_range(BORDER + 4, stage_columns - BORDER - 5)
		var ground := heights[column]
		if ground >= stage_rows or heights[column - 1] != ground or heights[column + 1] != ground or cell_kind(column, ground - 1) != EMPTY:
			continue
		var half := rng.randi_range(2, 3)
		if climb_tree_tops.any(func(other: Vector2i) -> bool: return absi(other.x - column) <= half * 2 + 3):
			continue
		var trunk := rng.randi_range(3, 4) + (rng.randi_range(2, 5) if tall else 0)
		var crown_bottom := ground - trunk - 1
		# The crown's outline, row by row from the top (half widths): a
		# rounded top widening down to its widest rows at the bottom, even on
		# both sides (the user turned down crowns that tuck in at the base
		# or lose an end at random).
		var shape: Array[int] = []
		if half <= 2:
			shape.assign([1, half, half])
		elif half == 3:
			shape.assign([1, 2, 3, 3])
		else:
			shape.assign([half - 2, half - 1, half, half])
		var crown_top := crown_bottom - shape.size() + 1
		if crown_top < 3:
			continue
		for index in shape.size():
			var row := crown_top + index
			for x in range(column - shape[index], column + shape[index] + 1):
				if cell_kind(x, row) == EMPTY:
					set_cell_kind(x, row, EARTH)
					cell_skins[Vector2i(x, row)] = TerrainSkin.LEAVES
		for row in range(crown_bottom + 1, ground):
			backdrop_skins[Vector2i(column, row)] = TerrainSkin.BARK
		climb_tree_tops.append(Vector2i(column, crown_top))
		placed += 1
		if with_items and rng.randf() < 0.5:
			add_spot(column, crown_top, MazeLayout.SpotKind.BONUS)


## Scenery trees behind the terrain, on flat ground away from the climbing
## trees.
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
		if climb_tree_tops.any(func(tree: Vector2i) -> bool: return absi(tree.x - column) < 7):
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
			spawn_cell = floor_near(left + 2, heights)
			exit_cell = _bottom_chamber(TerrainSkin.CAVE_WALL)
	if spawn_cell == Vector2i(-1, -1):
		spawn_cell = floor_near(left + 2, heights)
	if exit_cell == Vector2i(-1, -1):
		exit_cell = floor_near(right - 2, heights)


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


# --- Items --------------------------------------------------------------------------

func add_need(tool_id: String, column: int) -> void:
	_needs.append({"tool": tool_id, "column": column})


func add_spot(column: int, row: int, kind: MazeLayout.SpotKind, tool_id: String = "") -> void:
	for spot in _spots:
		if absi(spot.column - column) <= 1 and spot.row == row:
			return
	_spots.append({"column": column, "row": row, "kind": kind, "tool_id": tool_id, "amount": 1, "required": kind == MazeLayout.SpotKind.TOOL, "spot_index": _spots.size()})


## One item per tool the way calls for (at most two of a kind, so the bar
## is not all ladders), on a floor somewhere before its obstacle and not
## right in front of it.
func _place_tools() -> void:
	var floors := _floors(0, stage_columns)
	var counts := {}
	for need in _needs:
		if int(counts.get(need.tool, 0)) >= 2:
			continue
		counts[need.tool] = int(counts.get(need.tool, 0)) + 1
		var before := floors.filter(func(floor_cell: Vector2i) -> bool:
			return absi(floor_cell.x - spawn_cell.x) < absi(need.column - spawn_cell.x) - 3 and floor_cell != spawn_cell and floor_cell != exit_cell)
		if before.is_empty():
			before = floors
		if before.is_empty():
			continue
		var at: Vector2i = before[rng.randi_range(0, before.size() - 1)]
		add_spot(at.x, at.y, MazeLayout.SpotKind.TOOL, need.tool)


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
	data.spawn_cell = spawn_cell
	data.exit_cell = exit_cell
	data.spawn_faces_left = false
	data.item_spots = _spots
	data.environment_kind = biome.kind
	data.stage_name = biome.stages[stage_tier]
	data.suggested_time_seconds = clampi(90 + (stage_columns * stage_rows) / 30 + 15 * mini(_needs.size(), 12), 120, 600)
	return data
