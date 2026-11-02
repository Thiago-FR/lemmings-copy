class_name BiomeStageGenerator
extends RefCounted
## Stages shaped by where they happen instead of a grid of rooms: a meadow
## of hills and ravines, a forest whose canopies hold the items, dunes with
## buried ruins, a mine to dig down into, a crystal cavern, a glacier to
## climb out of, a volcano of chasms, a city of rooftops, another planet,
## and a space station among asteroids. The biomes come in a fixed order
## (BIOMES), STAGES_PER_BIOME stages each, harder within a biome and from
## one biome to the next, so a player wants to see what comes after.
##
## The result is the core's plain MazeStageData (cells, entrance, exit,
## item spots, cell skins), the same a game mode already builds from.
##
## First pass (2 November 2026): shapes for the user to look at. The stages
## are not yet checked to be winnable, and carry no recorded solution.

const STAGES_PER_BIOME := 3

## Fixed order. id, name, LevelEnvironment.Kind, stage names.
const BIOMES: Array[Dictionary] = [
	{"id": &"meadow", "name": "Prado", "kind": LevelEnvironment.Kind.SURFACE, "stages": ["Campo Aberto", "Colinas Verdes", "Vale dos Ventos"]},
	{"id": &"forest", "name": "Floresta", "kind": LevelEnvironment.Kind.FOREST, "stages": ["Bosque Alto", "Copas Antigas", "Floresta Funda"]},
	{"id": &"desert", "name": "Deserto", "kind": LevelEnvironment.Kind.DESERT, "stages": ["Dunas Quentes", "Ruínas na Areia", "A Pirâmide"]},
	{"id": &"mine", "name": "Mina", "kind": LevelEnvironment.Kind.SURFACE, "stages": ["Boca da Mina", "Galerias de Carvão", "Fundo da Mina"]},
	{"id": &"crystal", "name": "Caverna de Cristal", "kind": LevelEnvironment.Kind.CRYSTAL_CAVE, "stages": ["Gruta Brilhante", "Salões de Cristal", "Coração da Caverna"]},
	{"id": &"glacier", "name": "Geleira", "kind": LevelEnvironment.Kind.SNOWFIELD, "stages": ["Fenda de Gelo", "Paredão Gelado", "O Cume"]},
	{"id": &"volcano", "name": "Vulcão", "kind": LevelEnvironment.Kind.VOLCANO, "stages": ["Encosta Negra", "Rios de Brasa", "A Cratera"]},
	{"id": &"city", "name": "Cidade", "kind": LevelEnvironment.Kind.CITY, "stages": ["Telhados", "Becos e Pontes", "Arranha-céus"]},
	{"id": &"planet", "name": "Outro Planeta", "kind": LevelEnvironment.Kind.ALIEN_PLANET, "stages": ["Pouso", "Crateras", "Ilhas Flutuantes"]},
	{"id": &"space", "name": "Espaço", "kind": LevelEnvironment.Kind.SPACE, "stages": ["Estação", "Cinturão de Asteroides", "Última Doca"]},
]
const STAGE_COUNT := 30

const EMPTY := MazeLayout.EMPTY
const EARTH := MazeLayout.EARTH
const CONCRETE := MazeLayout.CONCRETE
## Rows of air a lemming needs over the floor it walks on.
const HEADROOM := 2
## Pits this deep or more kill (falls of 3 blocks are deadly).
const DEADLY_DROP := 3

var _rng := RandomNumberGenerator.new()
var _noise := FastNoiseLite.new()
var _columns := 64
var _rows := 32
var _cells := PackedByteArray()
var _skins := {}
var _backdrop := {}
var _spots: Array[Dictionary] = []
## Tools the obstacles on the way call for, with the column of each
## obstacle (the item is put somewhere before it).
var _needs: Array[Dictionary] = []
## 0 to 2 within the biome.
var _tier := 0
## 0 to 1 over the whole run.
var _progress := 0.0
var _spawn := Vector2i.ZERO
var _exit := Vector2i.ZERO
## TreeArt trees, plus their column and half width for spacing.
var _trees: Array[Dictionary] = []
var _unbreakable := {}


static func biome_of(stage_index: int) -> Dictionary:
	return BIOMES[clampi(stage_index / STAGES_PER_BIOME, 0, BIOMES.size() - 1)]


static func generate(seed_value: int, stage_index: int) -> MazeStageData:
	var generator := BiomeStageGenerator.new()
	return generator._generate(seed_value, clampi(stage_index, 0, STAGE_COUNT - 1))


func _generate(seed_value: int, stage_index: int) -> MazeStageData:
	_rng.seed = hash("%d:%d" % [seed_value, stage_index])
	_noise.seed = _rng.randi()
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_tier = stage_index % STAGES_PER_BIOME
	_progress = float(stage_index) / float(STAGE_COUNT - 1)
	var biome := biome_of(stage_index)
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
	return _to_data(biome, stage_index)


# --- Biomes --------------------------------------------------------------------

## Rolling hills, ravines to bridge, a cliff to climb, trees with something
## in their crowns.
func _build_meadow() -> void:
	_start_grid(60 + _tier * 10, 30, EMPTY)
	var heights := _rolling_heights(20, 2 + _tier, 0.05)
	_raise_edges(heights)
	var gaps := 1 + _tier
	for index in gaps:
		var at := _columns * (index + 1) / (gaps + 2) + _rng.randi_range(-2, 2)
		_cut_ravine(heights, at, 3 + _rng.randi_range(0, _tier))
		_need("bridge", at)
	if _tier >= 1:
		var cliff := _columns * 3 / 4
		_raise_from(heights, cliff, 3 + _tier)
		_need("ladder_vertical", cliff)
	_fill_ground(heights, EARTH)
	_concrete_bedrock(heights, 6)
	_plant(2 + _tier, [TreeArt.OAK, TreeArt.CHERRY])
	_spawn_and_exit_on(heights)


## Tall trees close together; the exit up in one of the crowns.
func _build_forest() -> void:
	_start_grid(64 + _tier * 8, 34, EMPTY)
	var heights := _rolling_heights(26, 2, 0.06)
	_raise_edges(heights)
	_cut_ravine(heights, _columns / 2, 4 + _tier)
	_need("bridge", _columns / 2)
	_fill_ground(heights, EARTH)
	_concrete_bedrock(heights, 5)
	var x := 7
	var tallest := Vector2i(-1, _rows)
	while x < _columns - 8:
		var crown := _tree(x, TreeArt.PINE if _rng.randf() < 0.6 else TreeArt.OAK, true)
		if crown.y < tallest.y and x > _columns / 2:
			tallest = crown
		x += _rng.randi_range(9, 12)
	_spawn = _flat_spot(heights, 3, _columns / 4)
	if tallest.x >= 0:
		_exit = tallest
		_need("ladder_vertical", tallest.x - 2)
	else:
		_exit = _flat_spot(heights, _columns * 3 / 4, _columns - 4)


## Dunes, a wide pit, a ruin of carved stone buried in the sand (dig down
## into it) and, last, a stepped pyramid with the exit on top.
func _build_desert() -> void:
	_start_grid(68 + _tier * 8, 32, EMPTY)
	var heights := _rolling_heights(19, 3 + _tier, 0.035)
	_raise_edges(heights)
	_cut_ravine(heights, _columns / 3, 4 + _tier)
	_need("bridge", _columns / 3)
	_fill_ground(heights, EARTH)
	_concrete_bedrock(heights, 4)
	# The buried ruin: a stone room under the sand with something inside.
	var ruin_x := _columns / 2 + _rng.randi_range(0, 6)
	var ruin_top := heights[ruin_x] + 3
	_fill(ruin_x - 3, ruin_top, ruin_x + 3, ruin_top + 5, CONCRETE)
	_fill(ruin_x - 2, ruin_top + 1, ruin_x + 2, ruin_top + 4, EMPTY)
	_fill(ruin_x - 1, ruin_top, ruin_x + 1, ruin_top, EARTH)
	_spot(ruin_x, ruin_top + 5, MazeLayout.SpotKind.BONUS)
	_plant(2, [TreeArt.PALM], 0.3)
	if _tier == 2:
		# The pyramid: steps two blocks high, the exit on the top.
		var base_x := _columns - 26
		var ground := heights[base_x]
		for step in 5:
			_fill(base_x + step * 2, ground - (step + 1) * 2, _columns - 6 - step * 2, ground - 1, CONCRETE)
		_spawn = _flat_spot(heights, 3, _columns / 4)
		_exit = Vector2i((base_x + _columns - 6) / 2, ground - 10)
		_need("builder", base_x)
	else:
		_spawn_and_exit_on(heights)


## The entrance on the surface, the exit at the bottom of the mine: dig down
## through earth and around bands of rock, into galleries.
func _build_mine() -> void:
	_start_grid(56 + _tier * 8, 36 + _tier * 4, EARTH)
	var surface := 7
	_fill(0, 0, _columns - 1, surface - 1, EMPTY)
	_fill(0, 0, 0, _rows - 1, CONCRETE)
	_fill(_columns - 1, 0, _columns - 1, _rows - 1, CONCRETE)
	_galleries(0.45 - _tier * 0.03, surface + 4, _rows - 3, 0.07)
	# Bands of rock the shovel cannot get through: go round them.
	for band in 1 + _tier:
		var row := surface + 6 + band * 8
		var from := _rng.randi_range(2, _columns / 2)
		_fill(from, row, from + _columns / 3, row, CONCRETE)
	_fill(0, _rows - 2, _columns - 1, _rows - 1, CONCRETE)
	_underground_wall(surface + 1, TerrainSkin.CAVE_WALL)
	_spawn = Vector2i(_rng.randi_range(4, 10), surface)
	_exit = _lowest_floor(_columns / 2, _columns - 3)
	_need("digger", _spawn.x + 2)
	_need("miner", _columns / 2)
	_need("floater", _columns / 2)
	_scatter_bonus(3)


## A closed cavern of rounded halls and narrow passages, crystal veins in
## the walls.
func _build_crystal_cave() -> void:
	_start_grid(64 + _tier * 8, 34 + _tier * 2, EARTH)
	_galleries(0.32 - _tier * 0.02, 3, _rows - 3, 0.06)
	_veins(4 + _tier * 2)
	_frame(CONCRETE)
	_spawn = _highest_floor(3, _columns / 4)
	_exit = _lowest_floor(_columns * 3 / 4, _columns - 3)
	_need("basher", _columns / 3)
	_need("miner", _columns / 2)
	_need("ladder_vertical", _columns * 2 / 3)
	_scatter_bonus(3)


## The troop starts at the bottom of a crevasse and the exit is on the
## summit: walls of ice to climb, ledges to reach.
func _build_glacier() -> void:
	_start_grid(60 + _tier * 8, 38 + _tier * 3, EMPTY)
	var heights := PackedInt32Array()
	heights.resize(_columns)
	# A mountain rising to the right in terraces, each wall 2 to 4 high.
	# Thick at the left, so the start cave fits under the first terraces.
	var height := _rows - 13
	var x := 0
	while x < _columns:
		var width := _rng.randi_range(5, 9)
		for column in range(x, mini(x + width, _columns)):
			heights[column] = height
		x += width
		if x < _columns and height > 6:
			var wall := mini(_rng.randi_range(2, 3 + _tier), height - 5)
			height -= wall
			_need(["ladder_vertical", "climber", "builder"][_rng.randi_range(0, 2)], x)
	_raise_edges(heights)
	_fill_ground(heights, EARTH)
	# The ice cave the troop starts in, under the first terraces, and the
	# shaft up out of it: climbing out is the first thing to do.
	var cave_floor := _rows - 3
	var cave_top := cave_floor - 4
	_fill(3, cave_top, 14 + _tier * 2, cave_floor - 1, EMPTY)
	var shaft := 12 + _tier * 2
	_fill(shaft, heights[shaft], shaft + 1, cave_top, EMPTY)
	_underground_wall(heights[shaft] + 1, TerrainSkin.ICE_WALL)
	_need("ladder_vertical", shaft)
	_plant(2 + _tier, [TreeArt.SNOW_PINE], 0.4)
	_spawn = Vector2i(5, cave_floor)
	_exit = Vector2i(_columns - 5, heights[_columns - 5])
	_scatter_bonus(2)


## Jagged black slopes and chasms that kill, basalt columns in the way.
func _build_volcano() -> void:
	_start_grid(66 + _tier * 8, 34, EMPTY)
	var heights := _rolling_heights(22, 4 + _tier, 0.08)
	_raise_edges(heights)
	for index in 2 + _tier:
		var at := _columns * (index + 1) / (_tier + 4)
		_cut_ravine(heights, at, 3 + _rng.randi_range(0, 2))
		_need("bridge", at)
	_fill_ground(heights, EARTH)
	for column_index in 1 + _tier:
		var at := _rng.randi_range(_columns / 4, _columns - 8)
		_fill(at, heights[at] - 4, at + 1, heights[at] - 1, CONCRETE)
		_need("basher", at)
	_concrete_bedrock(heights, 5)
	_spawn_and_exit_on(heights)


## Rooftops of different heights with alleys between them; the street far
## below. Start on one roof, get out from another.
func _build_city() -> void:
	_start_grid(70 + _tier * 10, 34, EMPTY)
	var street := _rows - 4
	_fill(0, street, _columns - 1, _rows - 1, EARTH)
	_fill(0, street, _columns - 1, street, CONCRETE)
	var x := 2
	var roofs: Array[Vector2i] = []
	while x < _columns - 6:
		var width := _rng.randi_range(6, 11)
		var top := street - _rng.randi_range(6, 12 + _tier * 2)
		var right := mini(x + width - 1, _columns - 3)
		_fill(x, top, right, street - 1, CONCRETE)
		for row in range(top, street):
			for column in range(x, right + 1):
				_skins[Vector2i(column, row)] = TerrainSkin.WALL
		roofs.append(Vector2i((x + right) / 2, top))
		var alley := _rng.randi_range(2, 4)
		_need("bridge", right + 1)
		x = right + 1 + alley
	_spawn = roofs[0]
	_exit = roofs[roofs.size() - 1]
	_scatter_bonus(3)


## Craters in purple soil, strange trees, spires and rocks floating above.
func _build_planet() -> void:
	_start_grid(66 + _tier * 8, 34, EMPTY)
	var heights := _rolling_heights(23, 2, 0.05)
	_raise_edges(heights)
	_fill_ground(heights, EARTH)
	for crater in 2 + _tier:
		var at := _rng.randi_range(12, _columns - 12)
		_carve_disc(Vector2(at, heights[at]), 3.5 + _rng.randf() * 2.0)
		_need("builder", at - 3)
	for spire in 2:
		var at := _rng.randi_range(8, _columns - 8)
		_fill(at, heights[at] - _rng.randi_range(4, 7), at, heights[at] - 1, CONCRETE)
	_plant(3, [TreeArt.MUSHROOM])
	var islands: Array[Vector2i] = []
	for island in 1 + _tier:
		var centre := Vector2i(_columns * (island + 2) / (_tier + 4), _rng.randi_range(9, 13))
		_blob(centre, Vector2(4.5, 1.8), EARTH)
		islands.append(Vector2i(centre.x, _surface_row(centre.x)))
	_spawn = _flat_spot(heights, 3, _columns / 4)
	if _tier == 2:
		_exit = islands[islands.size() - 1]
		_need("ladder_vertical", _exit.x - 4)
	else:
		_exit = _flat_spot(heights, _columns * 3 / 4, _columns - 4)
		for island in islands:
			_spot(island.x, island.y, MazeLayout.SpotKind.BONUS)


## Station modules floating in the void, asteroids between them. A fall is
## a fall into space.
func _build_space() -> void:
	_start_grid(72 + _tier * 10, 34, EMPTY)
	var modules: Array[Vector2i] = []
	var x := 2
	while x < _columns - 8:
		var width := _rng.randi_range(7, 12)
		var floor_row := _rng.randi_range(14, 24)
		var right := mini(x + width - 1, _columns - 3)
		_fill(x, floor_row, right, floor_row + 2, CONCRETE)
		_fill(x, floor_row - 5, x, floor_row - 1, CONCRETE)
		_fill(right, floor_row - 5, right, floor_row - 1, CONCRETE)
		_fill(x, floor_row - 6, right, floor_row - 6, CONCRETE)
		for row in range(floor_row - 6, floor_row + 3):
			for column in range(x, right + 1):
				if _cell(column, row) != EMPTY:
					_skins[Vector2i(column, row)] = TerrainSkin.HULL
		# A hatch to walk out of each side.
		_fill(x, floor_row - 3, x, floor_row - 1, EMPTY)
		_fill(right, floor_row - 3, right, floor_row - 1, EMPTY)
		modules.append(Vector2i((x + right) / 2, floor_row))
		var gap := _rng.randi_range(5, 9)
		# An asteroid to step on in the gap now and then.
		if gap >= 7 and _rng.randf() < 0.6:
			_blob(Vector2i(right + gap / 2 + 1, floor_row + _rng.randi_range(-2, 3)), Vector2(2.2, 1.4), EARTH)
		else:
			_need("bridge", right + 1)
		x = right + 1 + gap
	_spawn = modules[0]
	_exit = modules[modules.size() - 1]
	_scatter_bonus(3)


# --- Shapes ----------------------------------------------------------------------

## Two columns of bedrock at each side, top to bottom, and whatever rock
## frames the top and bottom: nothing breaks them, so no one digs out of
## the map. (Space has none: off the edge is the void.)
func _wall_in() -> void:
	for column in [0, 1, _columns - 2, _columns - 1]:
		for row in _rows:
			_set_cell(column, row, EARTH)
	for row in [0, _rows - 1]:
		for column in _columns:
			if _cell(column, row) != EMPTY:
				_unbreakable[Vector2i(column, row)] = true
	for column in [0, 1, _columns - 2, _columns - 1]:
		for row in _rows:
			_unbreakable[Vector2i(column, row)] = true
	for cell: Vector2i in _unbreakable:
		_skins[cell] = TerrainSkin.BORDER


## Rock (or ice) behind every pocket of air from that row down that has
## solid ground above it somewhere: under the surface it reads as inside.
func _underground_wall(from_row: int, wall: StringName) -> void:
	for column in _columns:
		var covered := false
		for row in _rows:
			if _cell(column, row) != EMPTY:
				covered = true
			elif covered and row >= from_row:
				_backdrop[Vector2i(column, row)] = wall


func _start_grid(columns: int, rows: int, fill_with: int) -> void:
	_columns = columns
	_rows = rows
	_cells = PackedByteArray()
	_cells.resize(columns * rows)
	_cells.fill(fill_with)


func _cell(column: int, row: int) -> int:
	if column < 0 or row < 0 or column >= _columns or row >= _rows:
		return CONCRETE
	return _cells[row * _columns + column]


func _set_cell(column: int, row: int, value: int) -> void:
	if column < 0 or row < 0 or column >= _columns or row >= _rows:
		return
	_cells[row * _columns + column] = value
	if value == EMPTY:
		_skins.erase(Vector2i(column, row))


func _fill(x0: int, y0: int, x1: int, y1: int, value: int) -> void:
	for row in range(mini(y0, y1), maxi(y0, y1) + 1):
		for column in range(mini(x0, x1), maxi(x0, x1) + 1):
			_set_cell(column, row, value)


## Ground heights (the top solid row of each column) that rise and fall
## smoothly, never more than one block from one column to the next, so
## the troop walks over them.
func _rolling_heights(base: int, amplitude: int, frequency: float) -> PackedInt32Array:
	_noise.frequency = frequency
	var heights := PackedInt32Array()
	heights.resize(_columns)
	var previous := base
	for column in _columns:
		var target := base + roundi(_noise.get_noise_1d(column) * amplitude)
		previous += clampi(target - previous, -1, 1)
		heights[column] = clampi(previous, 6, _rows - 4)
	return heights


## Tall cliffs at both ends keep the troop in.
func _raise_edges(heights: PackedInt32Array) -> void:
	for column in [0, 1, _columns - 2, _columns - 1]:
		heights[column] = 1


## A gap down to the bottom of the map: falling in is the end.
func _cut_ravine(heights: PackedInt32Array, at: int, width: int) -> void:
	for column in range(at, mini(at + width, _columns - 3)):
		heights[column] = _rows


## A cliff: everything from this column on stands higher.
func _raise_from(heights: PackedInt32Array, at: int, by: int) -> void:
	for column in range(at, _columns - 2):
		if heights[column] < _rows:
			heights[column] = maxi(heights[column] - by, 4)


func _fill_ground(heights: PackedInt32Array, material: int) -> void:
	for column in _columns:
		_fill(column, heights[column], column, _rows - 1, material)


## Rock deep under the ground: dig deep enough and the shovel stops.
func _concrete_bedrock(heights: PackedInt32Array, depth: int) -> void:
	for column in range(2, _columns - 2):
		if heights[column] < _rows:
			_fill(column, heights[column] + depth, column, _rows - 1, CONCRETE)


## Open galleries in solid rock, from organic noise, between two rows.
func _galleries(threshold: float, top: int, bottom: int, frequency: float) -> void:
	_noise.frequency = frequency
	for row in range(top, bottom):
		for column in range(2, _columns - 2):
			# Stretched sideways: halls are wider than tall, so there is
			# floor to walk on.
			if _noise.get_noise_2d(column * 0.7, row * 1.6) > threshold - 0.4:
				_set_cell(column, row, EMPTY)


## Streaks of crystal (concrete) running through the rock.
func _veins(count: int) -> void:
	for vein in count:
		var position := Vector2(_rng.randi_range(4, _columns - 5), _rng.randi_range(4, _rows - 5))
		var heading := _rng.randf() * TAU
		for step in _rng.randi_range(5, 10):
			if _cell(roundi(position.x), roundi(position.y)) == EARTH:
				_set_cell(roundi(position.x), roundi(position.y), CONCRETE)
			heading += _rng.randf_range(-0.5, 0.5)
			position += Vector2.from_angle(heading)


func _frame(material: int) -> void:
	_fill(0, 0, _columns - 1, 0, material)
	_fill(0, _rows - 1, _columns - 1, _rows - 1, material)
	_fill(0, 0, 0, _rows - 1, material)
	_fill(_columns - 1, 0, _columns - 1, _rows - 1, material)


func _carve_disc(centre: Vector2, radius: float) -> void:
	for row in range(floori(centre.y - radius), ceili(centre.y + radius) + 1):
		for column in range(floori(centre.x - radius), ceili(centre.x + radius) + 1):
			if Vector2(column, row).distance_to(centre) <= radius:
				_set_cell(column, row, EMPTY)


## A rounded lump (an island, an asteroid), flat on top so it can be
## stood on.
func _blob(centre: Vector2i, radii: Vector2, material: int) -> void:
	for row in range(centre.y - ceili(radii.y), centre.y + ceili(radii.y) + 1):
		for column in range(centre.x - ceili(radii.x), centre.x + ceili(radii.x) + 1):
			var offset := Vector2(column - centre.x, maxf(0.0, row - centre.y))
			if (offset.x / radii.x) ** 2 + (offset.y / radii.y) ** 2 <= 1.0 and row >= centre.y:
				_set_cell(column, row, material)
	_fill(centre.x - floori(radii.x), centre.y, centre.x + floori(radii.x), centre.y, material)


## A tree standing on the ground at that column: a trunk the troop walks
## past (drawn behind them) and a crown that can be stood on, shaped by its
## kind (TreeArt paints it). Refused (returns x = -1) where the ground is
## not flat under it, where there is no ground, or too close to another
## tree. Returns the spot on top of the crown.
func _tree(column: int, kind: StringName, tall: bool = false) -> Vector2i:
	var ground := _surface_row(column)
	if ground >= _rows - 1 or _surface_row(column - 1) != ground or _surface_row(column + 1) != ground:
		return Vector2i(-1, _rows)
	var half_width := _rng.randi_range(2, 3) + (1 if tall else 0)
	for other in _trees:
		if absi(other.column - column) <= other.half_width + half_width:
			return Vector2i(-1, _rows)
	var trunk_height := _rng.randi_range(4, 5) + (3 if tall else 0)
	var crown_row := ground - trunk_height
	# Half width of each crown row, top first.
	var shape: Array[int] = []
	match kind:
		TreeArt.PINE, TreeArt.SNOW_PINE:
			for tier in range(0, half_width + 1):
				shape.append(tier)
		TreeArt.PALM:
			shape = [half_width]
		TreeArt.MUSHROOM:
			shape = [half_width - 1, half_width]
		_:
			shape = [half_width - 1, half_width, half_width]
	var top_row := crown_row - shape.size() + 1
	if top_row < 2:
		return Vector2i(-1, _rows)
	var crown: Array[Vector2i] = []
	for index in shape.size():
		var row := top_row + index
		for x in range(column - shape[index], column + shape[index] + 1):
			if _cell(x, row) == EMPTY:
				_set_cell(x, row, EARTH)
				crown.append(Vector2i(x, row))
	var trunk: Array[Vector2i] = []
	for row in range(crown_row + 1, ground):
		trunk.append(Vector2i(column, row))
	var widest: int = shape.max()
	_trees.append({
		"kind": kind, "column": column, "half_width": widest,
		"box": Rect2i(column - widest - 1, top_row - 1, widest * 2 + 3, ground - top_row + 1),
		"crown": crown, "trunk": trunk, "seed": _rng.randi(),
	})
	return Vector2i(column, top_row)


## A few trees of the biome's kinds on the ground, an item on some crowns.
func _plant(count: int, kinds: Array[StringName], bonus_share: float = 0.5) -> void:
	for attempt in count * 6:
		if count <= 0:
			return
		var top := _tree(_rng.randi_range(6, _columns - 7), kinds[_rng.randi_range(0, kinds.size() - 1)])
		if top.x < 0:
			continue
		count -= 1
		if _rng.randf() < bonus_share:
			_spot(top.x, top.y, MazeLayout.SpotKind.BONUS)


# --- Places ------------------------------------------------------------------------

## The top solid row of a column (rows if it has none).
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


## A spot on the ground between two columns, preferring flat stretches.
func _flat_spot(heights: PackedInt32Array, from: int, to: int) -> Vector2i:
	for attempt in 30:
		var column := _rng.randi_range(from, to)
		if heights[column] < _rows and heights[column - 1] == heights[column] and heights[column + 1] == heights[column] and _is_floor(column, heights[column]):
			return Vector2i(column, heights[column])
	var column := clampi((from + to) / 2, 1, _columns - 2)
	return Vector2i(column, _surface_row(column))


func _spawn_and_exit_on(heights: PackedInt32Array) -> void:
	_spawn = _flat_spot(heights, 3, _columns / 5)
	_exit = _flat_spot(heights, _columns * 4 / 5, _columns - 4)


## Floors inside a cave, scanning a band of columns.
func _floors_between(from: int, to: int) -> Array[Vector2i]:
	var floors: Array[Vector2i] = []
	for column in range(from, to + 1):
		for row in range(2, _rows - 1):
			if _is_floor(column, row) and _cell(column - 1, row) != EMPTY and _cell(column + 1, row) != EMPTY:
				floors.append(Vector2i(column, row))
	return floors


func _lowest_floor(from: int, to: int) -> Vector2i:
	var floors := _floors_between(from, to)
	if floors.is_empty():
		return Vector2i((from + to) / 2, _rows - 2)
	floors.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y > b.y)
	return floors[_rng.randi_range(0, mini(3, floors.size() - 1))]


func _highest_floor(from: int, to: int) -> Vector2i:
	var floors := _floors_between(from, to)
	if floors.is_empty():
		return Vector2i((from + to) / 2, 4)
	floors.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y)
	return floors[_rng.randi_range(0, mini(3, floors.size() - 1))]


# --- Items --------------------------------------------------------------------------

func _need(tool_id: String, column: int) -> void:
	_needs.append({"tool": tool_id, "column": column})


func _spot(column: int, row: int, kind: MazeLayout.SpotKind, tool_id: String = "") -> void:
	for spot in _spots:
		if absi(spot.column - column) <= 1 and spot.row == row:
			return
	_spots.append({"column": column, "row": row, "kind": kind, "tool_id": tool_id, "amount": 1, "required": kind == MazeLayout.SpotKind.TOOL, "spot_index": _spots.size()})


## One item per tool the way calls for, on a floor somewhere before its
## obstacle (not right in front of it: the player has to think back to it).
func _place_tools() -> void:
	var floors := _floors_between(2, _columns - 3)
	for need in _needs:
		var before := floors.filter(func(floor_cell: Vector2i) -> bool:
			return absi(floor_cell.x - _spawn.x) < absi(need.column - _spawn.x) - 3 and floor_cell != _spawn and floor_cell != _exit)
		if before.is_empty():
			before = floors
		if before.is_empty():
			continue
		var at: Vector2i = before[_rng.randi_range(0, before.size() - 1)]
		_spot(at.x, at.y, MazeLayout.SpotKind.TOOL, need.tool)


## Bonuses in out-of-the-way floors.
func _scatter_bonus(count: int) -> void:
	var floors := _floors_between(2, _columns - 3)
	for bonus in count:
		if floors.is_empty():
			return
		var at: Vector2i = floors[_rng.randi_range(0, floors.size() - 1)]
		_spot(at.x, at.y, MazeLayout.SpotKind.BONUS)


func _to_data(biome: Dictionary, stage_index: int) -> MazeStageData:
	var data := MazeStageData.new()
	data.columns = _columns
	data.rows = _rows
	data.cells = _cells
	data.skins = _skins
	data.backdrop = _backdrop
	data.trees = _trees
	data.unbreakable = _unbreakable
	data.spawn_cell = _spawn
	data.exit_cell = _exit
	data.spawn_faces_left = false
	data.item_spots = _spots
	data.environment_kind = biome.kind
	data.stage_name = biome.stages[_tier]
	data.suggested_time_seconds = 150 + 20 * _needs.size()
	return data
