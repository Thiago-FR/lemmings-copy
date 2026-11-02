class_name BiomeStageGenerator
extends RefCounted
## Stages shaped by where they happen: ten biomes in a fixed order (BIOMES),
## STAGES_PER_BIOME stages each, so a player wants to see what comes next.
##
## Every stage has:
## - a size that grows with the stage (stage_size: the first fits about one
##   screen, the last is GROWTH_AT_LAST_STAGE times bigger), and a shape:
##   long (WIDE), tall (TALL) or both (BOTH);
## - a way through: across (TRAVERSE), up to an exit high above (ASCEND) or
##   down to one deep below (DESCEND);
## - relief: hills, cliffs too tall to walk up, ravines, and an underground
##   of caves under the surface in most biomes, with the cave's wall drawn
##   behind its air (TerrainSkin.CAVE_WALL);
## - its biome's own pieces: square tree crowns to climb, a pyramid, a mine,
##   skyscrapers with scaffolding, floating islands, station modules...
## Scenery trees (pines, palms, mushrooms) stand behind the terrain and
## carry nothing (BackgroundDecor). A border of bedrock nothing breaks walls
## the stage in, except in space.
##
## The result is the core's plain MazeStageData. generate() makes a run's
## stage; generate_custom() makes any biome at any size (the editor).
##
## Not yet: checking a stage can be won, and recording its solution.

const STAGES_PER_BIOME := 3
const STAGE_COUNT := 30

enum Shape { WIDE, TALL, BOTH }
enum Route { TRAVERSE, ASCEND, DESCEND }

## Fixed order. Per tier (stage within the biome): the shape and the route.
const BIOMES: Array[Dictionary] = [
	{"id": &"meadow", "name": "Prado", "kind": LevelEnvironment.Kind.SURFACE,
		"stages": ["Campo Aberto", "Colinas Verdes", "Vale dos Ventos"],
		"shapes": [Shape.WIDE, Shape.WIDE, Shape.BOTH], "routes": [Route.TRAVERSE, Route.TRAVERSE, Route.ASCEND]},
	{"id": &"forest", "name": "Floresta", "kind": LevelEnvironment.Kind.FOREST,
		"stages": ["Bosque Alto", "Copas Antigas", "Floresta Funda"],
		"shapes": [Shape.WIDE, Shape.BOTH, Shape.BOTH], "routes": [Route.TRAVERSE, Route.ASCEND, Route.DESCEND]},
	{"id": &"desert", "name": "Deserto", "kind": LevelEnvironment.Kind.DESERT,
		"stages": ["Dunas Quentes", "Ruínas na Areia", "A Pirâmide"],
		"shapes": [Shape.WIDE, Shape.BOTH, Shape.BOTH], "routes": [Route.TRAVERSE, Route.DESCEND, Route.ASCEND]},
	{"id": &"mine", "name": "Mina", "kind": LevelEnvironment.Kind.SURFACE,
		"stages": ["Boca da Mina", "Galerias de Carvão", "Fundo da Mina"],
		"shapes": [Shape.TALL, Shape.BOTH, Shape.TALL], "routes": [Route.DESCEND, Route.DESCEND, Route.DESCEND]},
	{"id": &"crystal", "name": "Caverna de Cristal", "kind": LevelEnvironment.Kind.CRYSTAL_CAVE,
		"stages": ["Gruta Brilhante", "Salões de Cristal", "Coração da Caverna"],
		"shapes": [Shape.BOTH, Shape.WIDE, Shape.BOTH], "routes": [Route.TRAVERSE, Route.TRAVERSE, Route.ASCEND]},
	{"id": &"glacier", "name": "Geleira", "kind": LevelEnvironment.Kind.SNOWFIELD,
		"stages": ["Fenda de Gelo", "Paredão Gelado", "O Cume"],
		"shapes": [Shape.BOTH, Shape.TALL, Shape.TALL], "routes": [Route.ASCEND, Route.ASCEND, Route.ASCEND]},
	{"id": &"volcano", "name": "Vulcão", "kind": LevelEnvironment.Kind.VOLCANO,
		"stages": ["Encosta Negra", "Rios de Brasa", "A Cratera"],
		"shapes": [Shape.WIDE, Shape.BOTH, Shape.TALL], "routes": [Route.TRAVERSE, Route.DESCEND, Route.ASCEND]},
	{"id": &"city", "name": "Cidade", "kind": LevelEnvironment.Kind.CITY,
		"stages": ["Telhados", "Becos e Pontes", "Arranha-céus"],
		"shapes": [Shape.BOTH, Shape.TALL, Shape.TALL], "routes": [Route.ASCEND, Route.ASCEND, Route.ASCEND]},
	{"id": &"planet", "name": "Outro Planeta", "kind": LevelEnvironment.Kind.ALIEN_PLANET,
		"stages": ["Pouso", "Crateras", "Ilhas Flutuantes"],
		"shapes": [Shape.WIDE, Shape.BOTH, Shape.BOTH], "routes": [Route.TRAVERSE, Route.DESCEND, Route.ASCEND]},
	{"id": &"space", "name": "Espaço", "kind": LevelEnvironment.Kind.SPACE,
		"stages": ["Estação", "Cinturão de Asteroides", "Última Doca"],
		"shapes": [Shape.WIDE, Shape.BOTH, Shape.BOTH], "routes": [Route.TRAVERSE, Route.ASCEND, Route.TRAVERSE]},
]

## The first stage: about one screen at 1080p.
const BASE_SIZE := Vector2i(56, 30)
## How much bigger the last stage is than the first, along its long side.
const GROWTH_AT_LAST_STAGE := 3.6
## A tall stage is never narrower than this, nor a long one lower.
const MIN_SIZE := Vector2i(40, 26)

const EMPTY := MazeLayout.EMPTY
const EARTH := MazeLayout.EARTH
const CONCRETE := MazeLayout.CONCRETE
## Rows of air a lemming needs over the floor it walks on.
const HEADROOM := 2
## Two columns of bedrock at each side.
const BORDER := 2

var _rng := RandomNumberGenerator.new()
var _noise := FastNoiseLite.new()
var _columns := 64
var _rows := 32
var _cells := PackedByteArray()
var _skins := {}
var _backdrop := {}
var _ladders: Array[Vector2i] = []
var _bricks: Array[Rect2] = []
var _spots: Array[Dictionary] = []
## Tools the obstacles call for, with each obstacle's column (its item goes
## somewhere before it).
var _needs: Array[Dictionary] = []
var _decor: Array[Dictionary] = []
var _climb_trees: Array[Vector2i] = []
var _unbreakable := {}
## 0 to 1: how hard, over the whole run (or as the editor asks).
var _difficulty := 0.0
var _tier := 0
var _route := Route.TRAVERSE
var _spawn := Vector2i.ZERO
var _exit := Vector2i.ZERO


static func biome_of(stage_index: int) -> Dictionary:
	return BIOMES[clampi(stage_index / STAGES_PER_BIOME, 0, BIOMES.size() - 1)]


static func biome_by_id(biome_id: StringName) -> Dictionary:
	for biome in BIOMES:
		if biome.id == biome_id:
			return biome
	return BIOMES[0]


## Size of a run's stage: bigger with every stage, along the long side for a
## long or a tall stage, along both (less on each) for one that is both.
static func stage_size(stage_index: int, shape: Shape) -> Vector2i:
	var growth := 1.0 + (GROWTH_AT_LAST_STAGE - 1.0) * clampf(float(stage_index) / float(STAGE_COUNT - 1), 0.0, 1.0)
	var size := Vector2(BASE_SIZE)
	match shape:
		Shape.WIDE:
			size.x *= growth
		Shape.TALL:
			size = Vector2(BASE_SIZE.x * 0.8, BASE_SIZE.y * growth * 1.2)
		Shape.BOTH:
			size *= pow(growth, 0.65)
	return Vector2i(maxi(roundi(size.x), MIN_SIZE.x), maxi(roundi(size.y), MIN_SIZE.y))


## A run's stage.
static func generate(seed_value: int, stage_index: int) -> MazeStageData:
	var index := clampi(stage_index, 0, STAGE_COUNT - 1)
	var biome := biome_of(index)
	var tier := index % STAGES_PER_BIOME
	var generator := BiomeStageGenerator.new()
	var size := stage_size(index, biome.shapes[tier])
	return generator._generate(hash("%d:%d" % [seed_value, index]), biome, tier, size, float(index) / float(STAGE_COUNT - 1))


## Any biome at any size and difficulty (0 to 1), as its tier-th stage is
## shaped (for the editor).
static func generate_custom(seed_value: int, biome_id: StringName, size: Vector2i, difficulty: float, tier: int = 1) -> MazeStageData:
	var generator := BiomeStageGenerator.new()
	var clamped := Vector2i(maxi(size.x, MIN_SIZE.x), maxi(size.y, MIN_SIZE.y))
	return generator._generate(seed_value, biome_by_id(biome_id), clampi(tier, 0, STAGES_PER_BIOME - 1), clamped, clampf(difficulty, 0.0, 1.0))


func _generate(seed_value: int, biome: Dictionary, tier: int, size: Vector2i, difficulty: float) -> MazeStageData:
	_rng.seed = seed_value
	_noise.seed = _rng.randi()
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_tier = tier
	_route = biome.routes[tier]
	_difficulty = difficulty
	_columns = size.x
	_rows = size.y
	_cells = PackedByteArray()
	_cells.resize(_columns * _rows)
	_cells.fill(EMPTY)
	match biome.id:
		&"meadow":
			_build_meadow()
		&"forest":
			_build_forest()
		&"desert":
			_build_desert()
		&"mine":
			_build_mine()
		&"crystal":
			_build_crystal_cave()
		&"glacier":
			_build_glacier()
		&"volcano":
			_build_volcano()
		&"city":
			_build_city()
		&"planet":
			_build_planet()
		&"space":
			_build_space()
	if biome.id != &"space":
		_wall_in()
	_place_tools()
	return _to_data(biome)


# --- Biomes --------------------------------------------------------------------

## Hills with cliffs, ravines, a few square trees to climb, caves under the
## ground from the second stage on.
func _build_meadow() -> void:
	var heights := _relief(0.78 if _route == Route.ASCEND else 0.62, 0.45 if _route == Route.ASCEND else 0.05, 4 + _tier * 2, 0.05, 0.10 + _difficulty * 0.2)
	_ravines(heights, 1 + _tier, 3)
	_fill_ground(heights, EARTH)
	if _tier >= 1:
		_caves(heights, 4, 0.18, TerrainSkin.CAVE_WALL)
		_open_into_caves(heights, 1)
	_rock_pockets(heights, 6, 0.55)
	_plant_climb_trees(heights, 2 + _tier, true)
	_plant_decor(heights, 2, [TreeArt.PINE])
	_spawn_and_exit(heights)


## Tall trees to climb, pines behind them, a ravine, and caves under the
## forest floor.
func _build_forest() -> void:
	var heights := _relief(0.68, 0.10 if _route == Route.ASCEND else 0.0, 3 + _tier, 0.06, 0.08 + _difficulty * 0.15)
	_ravines(heights, 1, 4 + _tier)
	_fill_ground(heights, EARTH)
	_caves(heights, 5, 0.12 + _tier * 0.05, TerrainSkin.CAVE_WALL)
	_open_into_caves(heights, 1 + _tier)
	_rock_pockets(heights, 7, 0.55)
	_plant_climb_trees(heights, 4 + _tier * 2, _route != Route.ASCEND, true)
	_plant_decor(heights, 6 + _tier * 2, [TreeArt.PINE])
	_spawn_and_exit(heights)
	if _route == Route.ASCEND and not _climb_trees.is_empty():
		_exit = _climb_trees.reduce(func(best: Vector2i, top: Vector2i) -> Vector2i: return top if top.y < best.y else best)


## Dunes, a wide pit, tombs under the sand, and a stepped pyramid that grows
## stage by stage, the exit on its top in the last one.
func _build_desert() -> void:
	var heights := _relief(0.60, 0.0, 4 + _tier * 2, 0.03, 0.05)
	_ravines(heights, 1, 4 + _tier)
	_fill_ground(heights, EARTH)
	_caves(heights, 6, 0.14 + _tier * 0.04, TerrainSkin.CAVE_WALL)
	_open_into_caves(heights, 1)
	_rock_pockets(heights, 5, 0.5)
	_plant_decor(heights, 3 + _tier, [TreeArt.PALM])
	var pyramid_top := _pyramid(heights, 4 + _tier * 2)
	_spawn_and_exit(heights)
	if _route == Route.ASCEND and pyramid_top.x >= 0:
		_exit = pyramid_top


## The way in is on the surface; the exit is at the bottom of the mine, down
## through galleries, around rock that the shovel cannot cut.
func _build_mine() -> void:
	var heights := _relief(0.18, 0.0, 3, 0.07, 0.06)
	_fill_ground(heights, EARTH)
	_caves(heights, 4, 0.22 + _tier * 0.04, TerrainSkin.CAVE_WALL)
	_open_into_caves(heights, 1)
	_rock_pockets(heights, 3, 0.45 - _tier * 0.04)
	_plant_decor(heights, 3, [TreeArt.PINE])
	_spawn_and_exit(heights)
	_need("digger", _spawn.x + 3)
	_need("floater", _columns / 2)
	_scatter_bonus(3)


## A closed cavern of rounded halls and passages, crystal veins in the rock.
func _build_crystal_cave() -> void:
	_fill(0, 0, _columns - 1, _rows - 1, EARTH)
	var heights := PackedInt32Array()
	heights.resize(_columns)
	heights.fill(2)
	_caves(heights, 1, 0.34 + _tier * 0.02, &"")
	_veins(5 + _tier * 3)
	_spawn_and_exit(heights)
	_need("basher", _columns / 3)
	_need("ladder_vertical", _columns * 2 / 3)
	_scatter_bonus(4)


## From an ice cave at the bottom up a mountain of cliffs to the summit;
## more ice caves inside it.
func _build_glacier() -> void:
	var heights := _relief(0.86, 0.72, 3, 0.06, 0.25 + _difficulty * 0.2)
	_fill_ground(heights, EARTH)
	_caves(heights, 4, 0.12 + _tier * 0.04, TerrainSkin.ICE_WALL)
	_start_cave(heights, TerrainSkin.ICE_WALL)
	_plant_decor(heights, 4 + _tier * 2, [TreeArt.SNOW_PINE])
	_exit = _floor_near(_columns - BORDER - 4, heights)


## Black slopes, chasms, lava tubes below; in the last stage a volcano to
## climb with the exit on the crater's rim.
func _build_volcano() -> void:
	var heights: PackedInt32Array
	if _route == Route.ASCEND:
		heights = _volcano_cone()
	else:
		heights = _relief(0.55, 0.0, 6 + _tier * 2, 0.08, 0.2)
		_ravines(heights, 2 + _tier, 3)
	_fill_ground(heights, EARTH)
	_caves(heights, 4, 0.16 + _tier * 0.04, TerrainSkin.CAVE_WALL)
	_open_into_caves(heights, 1)
	for column_index in 1 + _tier:
		var at := _rng.randi_range(BORDER + 6, _columns - BORDER - 7)
		if heights[at] < _rows:
			_fill(at, heights[at] - 4, at, heights[at] - 1, CONCRETE)
			_need("basher", at)
	_spawn_and_exit(heights)


## Towers far taller than a lemming can climb, with scaffolding up their
## sides (some ladders already up, the rest to build), the street below and
## a subway under it. The exit is on the tallest roof.
func _build_city() -> void:
	var street := _rows - maxi(6, _rows / 5)
	_fill(0, street, _columns - 1, _rows - 1, EARTH)
	_fill(0, street, _columns - 1, street, CONCRETE)
	var heights := PackedInt32Array()
	heights.resize(_columns)
	heights.fill(street)
	# The subway: a tunnel under the street, entered by stairs at one end.
	var tunnel_top := street + 2
	_fill(BORDER + 2, tunnel_top, _columns - BORDER - 3, tunnel_top + 2, EMPTY)
	_fill(BORDER + 2, tunnel_top + 3, _columns - BORDER - 3, tunnel_top + 3, CONCRETE)
	for column in range(BORDER + 2, _columns - BORDER - 2):
		for row in range(tunnel_top, tunnel_top + 3):
			_backdrop[Vector2i(column, row)] = TerrainSkin.CAVE_WALL
	for step in 3:
		_set_cell(BORDER + 3 + step, street, EMPTY)
		_set_cell(BORDER + 3 + step, street + 1 + step, EMPTY)
	var x := BORDER + 6
	var tallest := Vector2i(-1, _rows)
	while x < _columns - BORDER - 8:
		var width := _rng.randi_range(6, 10)
		var right := mini(x + width - 1, _columns - BORDER - 3)
		var top := street - roundi((street - 4) * _rng.randf_range(0.35, 0.55 + _difficulty * 0.4))
		_fill(x, top, right, street - 1, CONCRETE)
		for row in range(top, street):
			for column in range(x, right + 1):
				_skins[Vector2i(column, row)] = TerrainSkin.WALL
		_scaffold(x, right, top, street)
		if top < tallest.y:
			tallest = Vector2i((x + right) / 2, top)
		x = right + _rng.randi_range(4, 7)
	_spawn = Vector2i(BORDER + 3, street)
	_exit = tallest if tallest.x >= 0 else Vector2i(_columns - 6, street)
	_need("ladder_vertical", _columns / 3)
	_need("builder", _columns / 2)
	_scatter_bonus(3)


## Purple hills with craters, caves, giant mushrooms behind and rocks
## floating above; the exit up on the highest rock in the last stage.
func _build_planet() -> void:
	var heights := _relief(0.66, 0.0, 4 + _tier, 0.05, 0.1)
	_fill_ground(heights, EARTH)
	for crater in 2 + _tier:
		var at := _rng.randi_range(BORDER + 10, _columns - BORDER - 11)
		_carve_disc(Vector2(at, heights[at]), 3.5 + _rng.randf() * 2.5)
		_need("builder", at - 3)
	heights = _surface_heights()
	_caves(heights, 5, 0.16 + _tier * 0.04, TerrainSkin.CAVE_WALL)
	_open_into_caves(heights, 1)
	_plant_decor(heights, 4, [TreeArt.MUSHROOM])
	var islands: Array[Vector2i] = []
	for island in 2 + _tier:
		var centre := Vector2i(_rng.randi_range(BORDER + 8, _columns - BORDER - 9), _rng.randi_range(4, maxi(5, _rows / 3)))
		_blob(centre, Vector2(4.5, 2.0), EARTH)
		islands.append(centre)
	_spawn_and_exit(_surface_heights())
	if _route == Route.ASCEND:
		islands.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y)
		_exit = islands[0]
		_need("ladder_vertical", _exit.x - 4)
	for island in islands:
		if island != _exit:
			_spot(island.x, island.y, MazeLayout.SpotKind.BONUS)


## Station modules and asteroids spread through the void, at every height.
## A fall is a fall into space.
func _build_space() -> void:
	var modules: Array[Vector2i] = []
	var bands := maxi(1, _rows / 14)
	for band in bands:
		var x := 2 + _rng.randi_range(0, 4)
		while x < _columns - 9:
			var width := _rng.randi_range(7, 11)
			var floor_row := clampi(band * 14 + _rng.randi_range(8, 12), 8, _rows - 4)
			var right := mini(x + width - 1, _columns - 3)
			_module(x, right, floor_row)
			modules.append(Vector2i((x + right) / 2, floor_row))
			var gap := _rng.randi_range(5, 9)
			if _rng.randf() < 0.6:
				_blob(Vector2i(right + gap / 2 + 1, floor_row + _rng.randi_range(-3, 3)), Vector2(2.2, 1.4), EARTH)
			else:
				_need("bridge", right + 1)
			x = right + 1 + gap
	modules.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.x < b.x)
	_spawn = modules[0]
	_exit = modules[modules.size() - 1]
	if _route == Route.ASCEND:
		var highest := modules[0]
		for module in modules:
			if module.y < highest.y:
				highest = module
		_exit = highest
		_need("ladder_vertical", _exit.x)
	_scatter_bonus(3)


# --- Relief ------------------------------------------------------------------------

## Ground heights (the top solid row of each column). base_share: where the
## ground lies (share of the height from the top) at the left; slope: how
## much higher it ends at the right (negative: lower). Hills roll gently
## (one block per column at most, so the troop walks them), but now and
## then a cliff rises or drops two to five blocks: those need a tool.
func _relief(base_share: float, slope: float, amplitude: int, frequency: float, cliff_chance: float) -> PackedInt32Array:
	_noise.frequency = frequency
	_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	_noise.fractal_octaves = 3
	var heights := PackedInt32Array()
	heights.resize(_columns)
	var previous := -1
	for column in _columns:
		var share := float(column) / float(_columns - 1)
		var base := (base_share - slope * share) * _rows
		var target := clampi(roundi(base + _noise.get_noise_1d(column * 1.0) * amplitude * 2.0), 4, _rows - 5)
		if previous < 0:
			previous = target
		var difference := target - previous
		if absi(difference) >= 2 and _rng.randf() < cliff_chance:
			previous += clampi(difference, -5, 5)
			if difference < 0:
				_need(["ladder_vertical", "builder", "climber"][_rng.randi_range(0, 2)], column)
		else:
			previous += clampi(difference, -1, 1)
		heights[column] = previous
	return heights


## Gaps down to the bottom: falling in is the end.
func _ravines(heights: PackedInt32Array, count: int, width: int) -> void:
	for index in count:
		var at := BORDER + 6 + (_columns - BORDER * 2 - 14) * (index + 1) / (count + 1) + _rng.randi_range(-2, 2)
		for column in range(at, mini(at + width + _rng.randi_range(0, 1), _columns - BORDER - 4)):
			heights[column] = _rows
		_need("bridge", at)


func _fill_ground(heights: PackedInt32Array, material: int) -> void:
	for column in _columns:
		if heights[column] < _rows:
			_fill(column, heights[column], column, _rows - 1, material)


## The current top solid row of every column.
func _surface_heights() -> PackedInt32Array:
	var heights := PackedInt32Array()
	heights.resize(_columns)
	for column in _columns:
		heights[column] = _surface_row(column)
	return heights


## Caves under the ground, from depth rows below the surface down to the
## bottom: rounded halls stretched sideways (so there is floor to walk on),
## with the cave's wall drawn behind their air.
func _caves(heights: PackedInt32Array, depth: int, density: float, wall: StringName) -> void:
	_noise.frequency = 0.075
	_noise.fractal_type = FastNoiseLite.FRACTAL_NONE
	var threshold := 0.55 - density
	for column in range(BORDER, _columns - BORDER):
		if heights[column] >= _rows:
			continue
		for row in range(heights[column] + depth, _rows - 2):
			if _noise.get_noise_2d(column * 0.8, row * 1.7) > threshold:
				_set_cell(column, row, EMPTY)
				if wall != &"":
					_backdrop[Vector2i(column, row)] = wall


## Holes from the surface down into the caves below, so the underground is
## part of the way.
func _open_into_caves(heights: PackedInt32Array, count: int) -> void:
	for index in count:
		for attempt in 20:
			var column := _rng.randi_range(BORDER + 8, _columns - BORDER - 9)
			var top := heights[column]
			if top >= _rows:
				continue
			var depth := 0
			while top + depth < _rows - 2 and _cell(column, top + depth) != EMPTY and depth < 8:
				depth += 1
			if depth >= 8 or top + depth >= _rows - 2:
				continue
			_fill(column, top, column + 1, top + depth - 1, EMPTY)
			for row in range(top + 1, top + depth):
				_backdrop[Vector2i(column, row)] = TerrainSkin.CAVE_WALL
				_backdrop[Vector2i(column + 1, row)] = TerrainSkin.CAVE_WALL
			_need("floater", column)
			break


## Rounded lumps of rock the shovel cannot cut, inside the ground only.
func _rock_pockets(heights: PackedInt32Array, depth: int, threshold: float) -> void:
	_noise.frequency = 0.11
	for column in range(BORDER, _columns - BORDER):
		if heights[column] >= _rows:
			continue
		for row in range(heights[column] + depth, _rows - 1):
			if _cell(column, row) == EARTH and _noise.get_noise_2d(column + 500.0, row * 1.3) > threshold:
				_set_cell(column, row, CONCRETE)


## Streaks of crystal through the rock.
func _veins(count: int) -> void:
	for vein in count:
		var position := Vector2(_rng.randi_range(4, _columns - 5), _rng.randi_range(4, _rows - 5))
		var heading := _rng.randf() * TAU
		for step in _rng.randi_range(5, 10):
			if _cell(roundi(position.x), roundi(position.y)) == EARTH:
				_set_cell(roundi(position.x), roundi(position.y), CONCRETE)
			heading += _rng.randf_range(-0.5, 0.5)
			position += Vector2.from_angle(heading)


## The troop starts in a cave at the bottom of the left side; a shaft leads
## up from it to the open air.
func _start_cave(heights: PackedInt32Array, wall: StringName) -> void:
	var floor_row := _rows - 3
	var left := BORDER + 1
	var right := mini(left + 10, _columns / 3)
	_fill(left, floor_row - 4, right, floor_row - 1, EMPTY)
	var shaft := right - 1
	_fill(shaft, heights[shaft], shaft + 1, floor_row - 4, EMPTY)
	for column in range(left, shaft + 2):
		for row in range(heights[shaft] + 1, floor_row):
			if _cell(column, row) == EMPTY:
				_backdrop[Vector2i(column, row)] = wall
	_need("ladder_vertical", shaft)
	_spawn = Vector2i(left + 2, floor_row)


## A volcano filling the stage: slopes rising from both sides to a crater
## near the top, cliffs on the way.
func _volcano_cone() -> PackedInt32Array:
	var heights := PackedInt32Array()
	heights.resize(_columns)
	var centre := _columns / 2
	var rim := maxi(4, _rows / 6)
	var foot := _rows - 4
	var previous := foot
	for column in _columns:
		var distance := absf(column - centre) / (_columns / 2.0)
		var target := roundi(lerpf(rim, foot, clampf(distance * 1.15, 0.0, 1.0)))
		if absi(column - centre) <= 3:
			target = rim + 3
		var difference := target - previous
		previous += clampi(difference, -4, 4) if _rng.randf() < 0.35 else clampi(difference, -1, 1)
		heights[column] = previous
	return heights


## A stepped pyramid on the ground, steps two blocks high; returns its top.
func _pyramid(heights: PackedInt32Array, steps: int) -> Vector2i:
	var base_width := steps * 4 + 3
	var left := _columns - BORDER - base_width - 4
	if left < _columns / 3:
		return Vector2i(-1, -1)
	var ground := heights[left]
	for column in range(left, left + base_width):
		ground = maxi(ground, mini(heights[column], _rows - 3))
	for step in steps:
		_fill(left + step * 2, ground - (step + 1) * 2, left + base_width - 1 - step * 2, ground - 1, CONCRETE)
	# A tomb inside, its door to dig to.
	_fill(left + steps, ground - 3, left + base_width - 1 - steps, ground - 2, EMPTY)
	_spot(left + base_width / 2, ground - 1, MazeLayout.SpotKind.BONUS)
	_need("builder", left)
	return Vector2i(left + base_width / 2, ground - steps * 2)


## Scaffolding up one face of a tower: wooden platforms every few rows,
## some joined by ladders already standing, the rest left to the player.
func _scaffold(left: int, right: int, top: int, street: int) -> void:
	var on_left := _rng.randf() < 0.5
	var face := left - 1 if on_left else right + 1
	var reach := 3
	var row := street - 4
	var tile := Constants.TERRAIN_TILE_SIZE
	while row > top + 2:
		for offset in reach:
			var column := face - offset if on_left else face + offset
			if _cell(column, row) == EMPTY:
				_bricks.append(Rect2(column * tile, row * tile, tile, tile / 4.0))
		if _rng.randf() < 0.55:
			var ladder_column := face - 1 if on_left else face + 1
			for ladder_row in range(row, row + 4):
				if _cell(ladder_column, ladder_row) == EMPTY:
					_ladders.append(Vector2i(ladder_column, ladder_row))
		row -= 4


## A station module: a hull floor, walls with a hatch on each side, a roof.
func _module(left: int, right: int, floor_row: int) -> void:
	_fill(left, floor_row, right, floor_row + 1, CONCRETE)
	_fill(left, floor_row - 5, right, floor_row - 5, CONCRETE)
	_fill(left, floor_row - 4, left, floor_row - 4, CONCRETE)
	_fill(right, floor_row - 4, right, floor_row - 4, CONCRETE)
	for row in range(floor_row - 5, floor_row + 2):
		for column in range(left, right + 1):
			if _cell(column, row) != EMPTY:
				_skins[Vector2i(column, row)] = TerrainSkin.HULL


func _carve_disc(centre: Vector2, radius: float) -> void:
	for row in range(floori(centre.y - radius), ceili(centre.y + radius) + 1):
		for column in range(floori(centre.x - radius), ceili(centre.x + radius) + 1):
			if Vector2(column, row).distance_to(centre) <= radius:
				_set_cell(column, row, EMPTY)


## A rounded lump, flat on top so it can be stood on.
func _blob(centre: Vector2i, radii: Vector2, material: int) -> void:
	for row in range(centre.y, centre.y + ceili(radii.y) + 1):
		for column in range(centre.x - ceili(radii.x), centre.x + ceili(radii.x) + 1):
			var offset := Vector2(column - centre.x, row - centre.y)
			if (offset.x / radii.x) ** 2 + (offset.y / radii.y) ** 2 <= 1.0:
				_set_cell(column, row, material)


## Two columns of bedrock at each side, top to bottom, and the rock of the
## top and bottom rows: nothing breaks them.
func _wall_in() -> void:
	for column in [0, 1, _columns - 2, _columns - 1]:
		for row in _rows:
			_set_cell(column, row, EARTH)
			_unbreakable[Vector2i(column, row)] = true
	for row in [0, _rows - 1]:
		for column in _columns:
			if _cell(column, row) != EMPTY:
				_unbreakable[Vector2i(column, row)] = true
	for cell: Vector2i in _unbreakable:
		_skins[cell] = TerrainSkin.BORDER
		_backdrop.erase(cell)


# --- Trees ---------------------------------------------------------------------------

## Trees whose square crowns can be climbed onto: a trunk the troop walks
## past, right under a crown of leaf blocks. Some carry an item on top.
func _plant_climb_trees(heights: PackedInt32Array, count: int, with_items: bool, tall: bool = false) -> void:
	var placed := 0
	for attempt in count * 8:
		if placed >= count:
			return
		var column := _rng.randi_range(BORDER + 4, _columns - BORDER - 5)
		var ground := heights[column]
		if ground >= _rows or heights[column - 1] != ground or heights[column + 1] != ground or _cell(column, ground - 1) != EMPTY:
			continue
		var half := _rng.randi_range(2, 3)
		if _climb_trees.any(func(other: Vector2i) -> bool: return absi(other.x - column) <= half * 2 + 3):
			continue
		var trunk := _rng.randi_range(3, 4) + (_rng.randi_range(2, 5) if tall else 0)
		var crown_bottom := ground - trunk - 1
		var crown_top := crown_bottom - _rng.randi_range(1, 2)
		if crown_top < 3:
			continue
		for row in range(crown_top, crown_bottom + 1):
			var shrink := 1 if row == crown_top and half >= 3 else 0
			for x in range(column - half + shrink, column + half - shrink + 1):
				if _cell(x, row) == EMPTY:
					_set_cell(x, row, EARTH)
					_skins[Vector2i(x, row)] = TerrainSkin.LEAVES
		for row in range(crown_bottom + 1, ground):
			_backdrop[Vector2i(column, row)] = TerrainSkin.BARK
		_climb_trees.append(Vector2i(column, crown_top))
		placed += 1
		if with_items and _rng.randf() < 0.5:
			_spot(column, crown_top, MazeLayout.SpotKind.BONUS)


## Scenery trees behind the terrain, on flat ground away from the climbing
## trees.
func _plant_decor(heights: PackedInt32Array, count: int, kinds: Array[StringName]) -> void:
	var used: Array[int] = []
	for attempt in count * 6:
		if used.size() >= count:
			return
		var column := _rng.randi_range(BORDER + 3, _columns - BORDER - 4)
		var ground := heights[column]
		if ground >= _rows or _surface_row(column) != ground or _cell(column, ground - 1) != EMPTY:
			continue
		if used.any(func(other: int) -> bool: return absi(other - column) < 5):
			continue
		var kind := kinds[_rng.randi_range(0, kinds.size() - 1)]
		var half := _rng.randi_range(2, 3)
		var height := _rng.randi_range(6, 9)
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
		for row in range(top + 1, ground):
			trunk.append(Vector2i(column, row))
		_decor.append({"kind": kind, "box": Rect2i(column - half - 1, top - 1, half * 2 + 3, ground - top + 1), "crown": crown, "trunk": trunk, "seed": _rng.randi()})
		used.append(column)


# --- Places ------------------------------------------------------------------------

func _cell(column: int, row: int) -> int:
	if column < 0 or row < 0 or column >= _columns or row >= _rows:
		return CONCRETE
	return _cells[row * _columns + column]


func _set_cell(column: int, row: int, value: int) -> void:
	if column < 0 or row < 0 or column >= _columns or row >= _rows:
		return
	_cells[row * _columns + column] = value
	var cell := Vector2i(column, row)
	if value == EMPTY:
		_skins.erase(cell)
	else:
		_backdrop.erase(cell)


func _fill(x0: int, y0: int, x1: int, y1: int, value: int) -> void:
	for row in range(mini(y0, y1), maxi(y0, y1) + 1):
		for column in range(mini(x0, x1), maxi(x0, x1) + 1):
			_set_cell(column, row, value)


func _surface_row(column: int) -> int:
	for row in _rows:
		if _cell(column, row) != EMPTY:
			return row
	return _rows


## Whether a lemming can stand on top of that cell.
func _is_floor(column: int, row: int) -> bool:
	if _cell(column, row) == EMPTY:
		return false
	for above in range(1, HEADROOM + 1):
		if _cell(column, row - above) != EMPTY:
			return false
	return true


## Every floor a lemming could stand on, with ground at both sides (not a
## spike).
func _floors(from: int, to: int) -> Array[Vector2i]:
	var floors: Array[Vector2i] = []
	for column in range(maxi(from, BORDER + 1), mini(to, _columns - BORDER - 2) + 1):
		for row in range(2, _rows - 1):
			if _is_floor(column, row) and _cell(column - 1, row) != EMPTY and _cell(column + 1, row) != EMPTY:
				floors.append(Vector2i(column, row))
	return floors


## The floor nearest to a column on the surface.
func _floor_near(column: int, heights: PackedInt32Array) -> Vector2i:
	for offset in 12:
		for side in [-1, 1]:
			var x := clampi(column + offset * side, BORDER + 1, _columns - BORDER - 2)
			var row := _surface_row(x)
			if row < _rows and _is_floor(x, row) and _cell(x - 1, row) != EMPTY and _cell(x + 1, row) != EMPTY:
				return Vector2i(x, row)
	return Vector2i(column, mini(heights[column], _rows - 2))


## Entrance and exit by the stage's route: across (left to right on the
## surface), up (low on the left, the highest floor on the right) or down
## (on the surface, the deepest floor far from it).
func _spawn_and_exit(heights: PackedInt32Array) -> void:
	var left := BORDER + 3
	var right := _columns - BORDER - 4
	var third := _columns / 3
	match _route:
		Route.TRAVERSE:
			_spawn = _floor_near(left + 2, heights)
			_exit = _floor_near(right - 2, heights)
		Route.ASCEND:
			_spawn = _lowest(_floors(left, third))
			_exit = _highest(_floors(right - third, right))
		Route.DESCEND:
			_spawn = _floor_near(left + 2, heights)
			_exit = _lowest(_floors(right - third, right))
	if _spawn == Vector2i(-1, -1):
		_spawn = _floor_near(left + 2, heights)
	if _exit == Vector2i(-1, -1):
		_exit = _floor_near(right - 2, heights)


func _lowest(floors: Array[Vector2i]) -> Vector2i:
	if floors.is_empty():
		return Vector2i(-1, -1)
	floors.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y > b.y)
	return floors[_rng.randi_range(0, mini(2, floors.size() - 1))]


func _highest(floors: Array[Vector2i]) -> Vector2i:
	if floors.is_empty():
		return Vector2i(-1, -1)
	floors.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y)
	return floors[_rng.randi_range(0, mini(2, floors.size() - 1))]


# --- Items --------------------------------------------------------------------------

func _need(tool_id: String, column: int) -> void:
	_needs.append({"tool": tool_id, "column": column})


func _spot(column: int, row: int, kind: MazeLayout.SpotKind, tool_id: String = "") -> void:
	for spot in _spots:
		if absi(spot.column - column) <= 1 and spot.row == row:
			return
	_spots.append({"column": column, "row": row, "kind": kind, "tool_id": tool_id, "amount": 1, "required": kind == MazeLayout.SpotKind.TOOL, "spot_index": _spots.size()})


## One item per tool the way calls for (at most two of a kind, so the bar
## is not all ladders), on a floor somewhere before its obstacle and not
## right in front of it.
func _place_tools() -> void:
	var floors := _floors(0, _columns)
	var counts := {}
	for need in _needs:
		if int(counts.get(need.tool, 0)) >= 2:
			continue
		counts[need.tool] = int(counts.get(need.tool, 0)) + 1
		var before := floors.filter(func(floor_cell: Vector2i) -> bool:
			return absi(floor_cell.x - _spawn.x) < absi(need.column - _spawn.x) - 3 and floor_cell != _spawn and floor_cell != _exit)
		if before.is_empty():
			before = floors
		if before.is_empty():
			continue
		var at: Vector2i = before[_rng.randi_range(0, before.size() - 1)]
		_spot(at.x, at.y, MazeLayout.SpotKind.TOOL, need.tool)


func _scatter_bonus(count: int) -> void:
	var floors := _floors(0, _columns)
	for bonus in count:
		if floors.is_empty():
			return
		var at: Vector2i = floors[_rng.randi_range(0, floors.size() - 1)]
		_spot(at.x, at.y, MazeLayout.SpotKind.BONUS)


func _to_data(biome: Dictionary) -> MazeStageData:
	var data := MazeStageData.new()
	data.columns = _columns
	data.rows = _rows
	data.cells = _cells
	data.skins = _skins
	data.backdrop = _backdrop
	data.decor_trees = _decor
	data.unbreakable = _unbreakable
	data.ladders = _ladders
	data.bricks = _bricks
	data.spawn_cell = _spawn
	data.exit_cell = _exit
	data.spawn_faces_left = false
	data.item_spots = _spots
	data.environment_kind = biome.kind
	data.stage_name = biome.stages[_tier]
	data.suggested_time_seconds = clampi(90 + (_columns * _rows) / 30 + 15 * mini(_needs.size(), 12), 120, 600)
	return data
