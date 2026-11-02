extends SceneTree
## Builds the 15 levels of the campaign ("Fases"): each level's scene
## (terrain, entrance, exit, HUD, tool bar, result screen) under
## scenes/levels/campaign/ and its LevelData under resources/levels/campaign/.
## Run via:
##   godot --headless --path . --script res://tools/build_campaign_levels.gd [-- <ascii dir>]
## With a directory after "--", also writes each level's map as text there
## (# earth, = concrete, S entrance, E exit), to check a layout by eye.
##
## Every level is drawn on a grid of LEVEL_COLUMNS x LEVEL_ROWS blocks (the
## standard level size, larger than a Full HD screen): it starts as solid
## earth and the rooms, sky, pits and concrete are painted over it. The
## outer columns always stay solid, so nobody walks or climbs out.
##
## Geometry rules every layout here follows (game_design.md, section 9, and
## the tools' own limits), worth knowing before changing one:
##   - a fall of 2 blocks (64px) is safe, 3 blocks (96px) kills;
##   - a step of a whole block (32px) is a wall; a lemming walks in a tunnel
##     one block tall;
##   - a fall into a pit open to the bottom of the map is a fall into the void;
##   - a dug or blasted shaft drops everyone who walks over it later the full
##     depth, so a floor meant to be dug or blown open is one block thick over
##     a gap one block tall (64px in all);
##   - bridge and diagonal ladder: 12 pieces; vertical ladder: 12 blocks;
##     the diagonal ladder rises a block every 4 steps, so it reaches a ledge
##     3 blocks high when begun 9 to 12 blocks from its wall.
## Each level has a robot playthrough in tests/test_campaign_<nn>.gd; change
## a layout and its test says whether it can still be won.

const LEVEL_COLUMNS := 80
const LEVEL_ROWS := 45
const TILE := 32
const SCENE_DIR := "res://scenes/levels/campaign/"
const DATA_DIR := "res://resources/levels/campaign/"
const TILE_SET_PATH := "res://resources/tilesets/terrain_tileset.tres"
## The entrance is drawn above where lemmings appear; they drop this far to
## the floor below it (a safe fall).
const SPAWN_ABOVE_FLOOR := 56
## The exit's origin is the middle of its 48px box, which sits on the floor.
const EXIT_ABOVE_FLOOR := 24

const AIR := 0
const EARTH := 1
const CONCRETE := 2

var _res: Dictionary = {}
## The level being drawn: LEVEL_ROWS rows of LEVEL_COLUMNS cells.
var _map: Array[PackedByteArray] = []


func _initialize() -> void:
	_res = {
		"tile_set": load(TILE_SET_PATH),
		"level_manager_script": load("res://scripts/level/level_manager.gd"),
		"terrain_script": load("res://scripts/level/terrain_destructible.gd"),
		"spawn_point_scene": load("res://scenes/level/spawn_point.tscn"),
		"exit_point_scene": load("res://scenes/level/exit_point.tscn"),
		"hud_scene": load("res://scenes/ui/hud.tscn"),
		"skill_panel_scene": load("res://scenes/ui/skill_panel.tscn"),
		"level_result_screen_scene": load("res://scenes/ui/level_result_screen.tscn"),
	}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SCENE_DIR))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DATA_DIR))
	var args := OS.get_cmdline_user_args()
	var ascii_dir: String = args[0] if not args.is_empty() else ""

	var levels: Array[Callable] = [
		_level_01, _level_02, _level_03, _level_04, _level_05,
		_level_06, _level_07, _level_08, _level_09, _level_10,
		_level_11, _level_12, _level_13, _level_14, _level_15,
	]
	for index in levels.size():
		_new_map()
		var spec: Dictionary = levels[index].call()
		_decorate(index + 1, _is_underground(spec.environment))
		_save_level(index + 1, spec)
		if ascii_dir != "":
			_write_ascii(ascii_dir.path_join("campaign_%02d.txt" % (index + 1)), spec)
	quit()


# --- Drawing ------------------------------------------------------------------

func _new_map() -> void:
	_map.clear()
	for row in LEVEL_ROWS:
		var cells := PackedByteArray()
		cells.resize(LEVEL_COLUMNS)
		cells.fill(EARTH)
		_map.append(cells)


## Fills columns x0..x1 and rows y0..y1 (inclusive) with kind. The outer
## columns are left solid whatever is painted over them.
func _fill(x0: int, x1: int, y0: int, y1: int, kind: int) -> void:
	for row in range(maxi(y0, 0), mini(y1, LEVEL_ROWS - 1) + 1):
		for column in range(maxi(x0, 1), mini(x1, LEVEL_COLUMNS - 2) + 1):
			_map[row][column] = kind


func _air(x0: int, x1: int, y0: int, y1: int) -> void:
	_fill(x0, x1, y0, y1, AIR)


func _earth(x0: int, x1: int, y0: int, y1: int) -> void:
	_fill(x0, x1, y0, y1, EARTH)


func _concrete(x0: int, x1: int, y0: int, y1: int) -> void:
	_fill(x0, x1, y0, y1, CONCRETE)


## Open sky over the whole level down to row bottom_row.
func _sky(bottom_row: int) -> void:
	_air(1, LEVEL_COLUMNS - 2, 0, bottom_row)


## A pit from row top_row down through the bottom of the map: falling in is
## falling into the void.
func _abyss(x0: int, x1: int, top_row: int) -> void:
	_air(x0, x1, top_row, LEVEL_ROWS - 1)


# --- Decoration -----------------------------------------------------------------
# Only blocks buried well away from any open space change, and never one in
# a wall between two open spaces (open space on both sides in its row, or
# above and below in its column), where a tunnel or a shaft may go. So no
# route, tool or blast of a level is affected: a mass of earth gets boulders of
# stone (concrete) and a band of bedrock along the bottom, and underground
# it also gets closed hollows with crystals or rock in them, as caverns seen
# through the rock.

## Blocks at least this far from open space may become stone.
const STONE_MIN_DEPTH := 3
## Hollows keep at least this much rock between them and any open space.
const HOLLOW_MIN_DEPTH := 5
const BOULDER_ATTEMPTS := 22
const HOLLOW_ATTEMPTS := 30


func _is_underground(environment: LevelEnvironment.Kind) -> bool:
	return environment == LevelEnvironment.Kind.CAVE or environment == LevelEnvironment.Kind.CRYSTAL_CAVE


func _decorate(level_seed: int, underground: bool) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = level_seed * 7919
	var depth := _depth_map(HOLLOW_MIN_DEPTH + 2)
	_mark_dividing_walls(depth)
	_paint_bedrock(depth, level_seed)
	for attempt in BOULDER_ATTEMPTS:
		var centre := Vector2i(rng.randi_range(2, LEVEL_COLUMNS - 3), rng.randi_range(2, LEVEL_ROWS - 3))
		var size := Vector2i(rng.randi_range(1, 3), rng.randi_range(1, 2))
		for row in range(centre.y, centre.y + size.y):
			for column in range(centre.x - size.x / 2, centre.x + size.x - size.x / 2):
				_stone_if_deep(depth, column, row)
	if not underground:
		return
	for attempt in HOLLOW_ATTEMPTS:
		var corner := Vector2i(rng.randi_range(2, LEVEL_COLUMNS - 10), rng.randi_range(2, LEVEL_ROWS - 6))
		var size := Vector2i(rng.randi_range(3, 7), rng.randi_range(2, 3))
		if not _all_deep(depth, corner, size, HOLLOW_MIN_DEPTH):
			continue
		_air(corner.x, corner.x + size.x - 1, corner.y, corner.y + size.y - 1)
		# Crystals (stone) growing from its floor here and there.
		for column in range(corner.x, corner.x + size.x):
			if rng.randf() < 0.35:
				_map[corner.y + size.y - 1][column] = CONCRETE
		var dividing := depth
		depth = _depth_map(HOLLOW_MIN_DEPTH + 2)
		for row in LEVEL_ROWS:
			for column in LEVEL_COLUMNS:
				if dividing[row][column] < 0:
					depth[row][column] = -1


## Sets the depth of every block in a wall between two open spaces to -1,
## which no decoration accepts.
func _mark_dividing_walls(depth: Array[PackedInt32Array]) -> void:
	for row in LEVEL_ROWS:
		var air_columns: Array[int] = []
		for column in LEVEL_COLUMNS:
			if _map[row][column] == AIR:
				air_columns.append(column)
		if air_columns.size() >= 2:
			for column in range(air_columns.front(), air_columns.back() + 1):
				depth[row][column] = -1
	for column in LEVEL_COLUMNS:
		var first := -1
		var last := -1
		for row in LEVEL_ROWS:
			if _map[row][column] == AIR:
				if first < 0:
					first = row
				last = row
		if first >= 0:
			for row in range(first, last + 1):
				depth[row][column] = -1


## Distance in blocks from each cell to the nearest open cell (counting
## diagonals as one), up to limit. Outside the map counts as rock.
func _depth_map(limit: int) -> Array[PackedInt32Array]:
	var depth: Array[PackedInt32Array] = []
	for row in LEVEL_ROWS:
		var line := PackedInt32Array()
		line.resize(LEVEL_COLUMNS)
		for column in LEVEL_COLUMNS:
			line[column] = _distance_to_air(column, row, limit)
		depth.append(line)
	return depth


func _distance_to_air(column: int, row: int, limit: int) -> int:
	for reach in range(0, limit + 1):
		for y in range(row - reach, row + reach + 1):
			for x in range(column - reach, column + reach + 1):
				if maxi(absi(x - column), absi(y - row)) != reach:
					continue
				if x >= 0 and x < LEVEL_COLUMNS and y >= 0 and y < LEVEL_ROWS and _map[y][x] == AIR:
					return reach
	return limit + 1


func _stone_if_deep(depth: Array[PackedInt32Array], column: int, row: int) -> void:
	if column < 1 or column > LEVEL_COLUMNS - 2 or row < 0 or row >= LEVEL_ROWS:
		return
	if depth[row][column] >= STONE_MIN_DEPTH and _map[row][column] == EARTH:
		_map[row][column] = CONCRETE


func _all_deep(depth: Array[PackedInt32Array], corner: Vector2i, size: Vector2i, minimum: int) -> bool:
	for row in range(corner.y, corner.y + size.y):
		for column in range(corner.x, corner.x + size.x):
			if depth[row][column] < minimum:
				return false
	return true


## The bottom rows of buried rock become bedrock, along a wavy line.
func _paint_bedrock(depth: Array[PackedInt32Array], level_seed: int) -> void:
	for column in LEVEL_COLUMNS:
		var top := LEVEL_ROWS - 3 + roundi(sin(column * 0.37 + level_seed) * 1.2 + sin(column * 0.13 + level_seed * 2.0))
		for row in range(top, LEVEL_ROWS):
			_stone_if_deep(depth, column, row)


# --- Saving -------------------------------------------------------------------

func _save_level(number: int, spec: Dictionary) -> void:
	var root := Node2D.new()
	root.name = "Campaign%02d" % number
	root.set_script(_res.level_manager_script)

	var terrain := TileMapLayer.new()
	terrain.name = "Terrain"
	terrain.tile_set = _res.tile_set
	terrain.set_script(_res.terrain_script)
	for row in LEVEL_ROWS:
		for column in LEVEL_COLUMNS:
			var kind: int = _map[row][column]
			if kind != AIR:
				var material := TerrainDestructible.TerrainMaterial.CONCRETE if kind == CONCRETE else TerrainDestructible.TerrainMaterial.EARTH
				terrain.set_cell(Vector2i(column, row), 0, Vector2i(0, material))
	_add_owned(root, terrain)

	var spawn: Node2D = _res.spawn_point_scene.instantiate()
	var spawn_cell: Vector2i = spec.spawn
	spawn.position = Vector2(spawn_cell.x * TILE + TILE / 2, spawn_cell.y * TILE - SPAWN_ABOVE_FLOOR)
	_add_owned(root, spawn)
	var exit_point: Node2D = _res.exit_point_scene.instantiate()
	var exit_cell: Vector2i = spec.exit
	exit_point.position = Vector2(exit_cell.x * TILE + TILE / 2, exit_cell.y * TILE - EXIT_ABOVE_FLOOR)
	_add_owned(root, exit_point)

	_add_owned(root, _res.hud_scene.instantiate())
	_add_owned(root, _res.skill_panel_scene.instantiate())
	_add_owned(root, _res.level_result_screen_scene.instantiate())

	var scene_path := SCENE_DIR + "campaign_%02d.tscn" % number
	var packed := PackedScene.new()
	var err := packed.pack(root)
	assert(err == OK, "Failed to pack %s" % scene_path)
	err = ResourceSaver.save(packed, scene_path)
	root.free()

	var data := LevelData.new()
	data.level_name = spec.name
	data.instructions = spec.get("hint", "")
	data.total_lemmings = spec.lemmings
	data.spawn_rate = spec.rate
	data.required_percentage = spec.required
	data.time_limit_seconds = spec.time
	var tools: Dictionary = spec.tools
	var tool_ids: Array[String] = []
	for tool_id in tools:
		tool_ids.append(tool_id)
	data.available_skills = tool_ids
	data.skill_counts = tools.duplicate()
	data.scene_path = scene_path
	data.environment_kind = spec.environment
	var data_path := DATA_DIR + "campaign_%02d_data.tres" % number
	var data_err := ResourceSaver.save(data, data_path)
	print("%02d %s: scene %d, data %d" % [number, spec.name, err, data_err])


func _add_owned(root: Node, child: Node) -> void:
	root.add_child(child)
	child.owner = root


func _write_ascii(path: String, spec: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Cannot write %s" % path)
		return
	var spawn: Vector2i = spec.spawn
	var exit_cell: Vector2i = spec.exit
	file.store_line("%s  (%s)" % [spec.name, spec.tools])
	file.store_line("    " + "".join(range(LEVEL_COLUMNS).map(func(c: int) -> String: return str(c % 10))))
	for row in LEVEL_ROWS:
		var line := ""
		for column in LEVEL_COLUMNS:
			var mark := ".#="[_map[row][column]]
			if Vector2i(column, row + 1) == spawn:
				mark = "S"
			elif Vector2i(column, row + 1) == exit_cell:
				mark = "E"
			line += mark
		file.store_line("%3d %s" % [row, line])


# --- The levels -----------------------------------------------------------------
# spawn and exit are (column, floor row): the column they stand in and the
# row of the block they stand on.

## 1. The shovel. Lemmings land on a meadow walled in by a hill; the exit is
## in a hollow under it. The meadow is one block thick over a gap one block
## tall, so the shaft is a safe drop for everyone who walks into it.
func _level_01() -> Dictionary:
	_sky(19)
	_earth(36, 78, 12, 19)        # the highland the meadow runs into
	_air(1, 60, 21, 21)           # the hollow under the meadow and the hill
	_air(54, 64, 18, 21)          # the room with the exit
	return {
		"name": "Terra Fofa", "environment": LevelEnvironment.Kind.SURFACE,
		"spawn": Vector2i(10, 20), "exit": Vector2i(60, 22),
		"lemmings": 10, "rate": 2.0, "required": 0.7, "time": 180,
		"tools": {"digger": 3},
		"hint": "A Pá cava para baixo.",
	}


## 2. The bridge. Two dry stream beds with no bottom cross the field; the
## lemmings come out walking towards the first one, with time to bridge it.
func _level_02() -> Dictionary:
	_sky(23)
	_abyss(30, 36, 24)
	_abyss(50, 54, 24)
	_earth(72, 78, 14, 23)        # a cliff past the exit
	_earth(1, 3, 18, 23)          # a rock behind the entrance
	return {
		"name": "Ribeirão Seco", "environment": LevelEnvironment.Kind.SURFACE,
		"spawn": Vector2i(8, 24), "exit": Vector2i(64, 24),
		"lemmings": 10, "rate": 3.0, "required": 0.8, "time": 150,
		"tools": {"bridge": 3},
		"hint": "A Ponte cruza um buraco.",
	}


## 3. The vertical ladder. Two cliffs, one above the other, each six blocks
## high; the exit is on the upper one. Whoever walks back off the lower cliff
## falls to its death, so the second ladder is needed soon.
func _level_03() -> Dictionary:
	_sky(27)
	_earth(34, 78, 22, 27)
	_earth(52, 78, 16, 21)
	return {
		"name": "Muralha do Moinho", "environment": LevelEnvironment.Kind.SURFACE,
		"spawn": Vector2i(8, 28), "exit": Vector2i(66, 16),
		"lemmings": 10, "rate": 2.5, "required": 0.7, "time": 180,
		"tools": {"ladder_vertical": 3},
		"hint": "A Escada vertical sobe numa parede.",
	}


## 4. The diagonal ladder. Two sandstone terraces, each three blocks higher
## than the last: a staircase begun 9 to 12 blocks before each wall reaches
## its top.
func _level_04() -> Dictionary:
	_sky(29)
	_earth(30, 78, 27, 29)
	_earth(54, 78, 24, 26)
	return {
		"name": "Escadaria das Dunas", "environment": LevelEnvironment.Kind.DESERT,
		"spawn": Vector2i(6, 30), "exit": Vector2i(68, 24),
		"lemmings": 10, "rate": 3.0, "required": 0.8, "time": 200,
		"tools": {"builder": 4},
		"hint": "A Escada diagonal sobe aos poucos, na direção em que o boneco anda.",
	}


## 5. Claws and parachute. A mesa ten blocks high stands between the
## entrance and the exit, with a deep canyon beyond it: every lemming has to
## climb it and then float down.
func _level_05() -> Dictionary:
	_sky(29)
	_earth(30, 40, 20, 29)        # the mesa
	_air(41, 78, 30, 32)          # the canyon floor is three blocks lower
	return {
		"name": "Garras ao Vento", "environment": LevelEnvironment.Kind.DESERT,
		"spawn": Vector2i(8, 30), "exit": Vector2i(62, 33),
		"lemmings": 8, "rate": 3.0, "required": 0.75, "time": 180,
		"tools": {"climber": 8, "floater": 8},
		"hint": "Garras sobem paredes. Paraquedas salva da queda.",
	}


## 6. Block and pickaxe. The lemmings come out walking towards a chasm; a
## block turns them back towards a sandstone hill, and the oasis with the
## exit is through it.
func _level_06() -> Dictionary:
	_sky(25)
	_abyss(44, 50, 26)
	_earth(14, 20, 18, 25)        # the hill
	_earth(51, 78, 20, 25)        # beyond the chasm, unreachable
	return {
		"name": "Oásis Escondido", "environment": LevelEnvironment.Kind.DESERT,
		"spawn": Vector2i(34, 26), "exit": Vector2i(6, 26),
		"lemmings": 12, "rate": 2.5, "required": 0.75, "time": 150,
		"tools": {"block": 2, "miner": 2},
		"hint": "O Bloco faz os bonecos voltarem. A Picareta cava reto na terra.",
	}


## 7. Pickaxe or jackhammer. A cave corridor crossed by three walls: slate,
## crystal (concrete: only the jackhammer breaks it), slate.
func _level_07() -> Dictionary:
	_air(1, 72, 20, 25)
	_earth(20, 22, 20, 25)
	_concrete(36, 38, 20, 25)
	_earth(52, 55, 20, 25)
	_concrete(1, 78, 26, 26)      # crystal floor
	return {
		"name": "Veios de Cristal", "environment": LevelEnvironment.Kind.CRYSTAL_CAVE,
		"spawn": Vector2i(6, 26), "exit": Vector2i(66, 26),
		"lemmings": 15, "rate": 2.0, "required": 0.8, "time": 210,
		"tools": {"miner": 2, "basher": 1},
		"hint": "A Britadeira quebra cristal. A Picareta, só pedra comum.",
	}


## 8. Dynamite. Three galleries stacked one above the other, each with a
## crystal floor one block thick over the next: two charges, set down in the
## right places, open the way down to the exit.
func _level_08() -> Dictionary:
	_air(1, 44, 12, 15)           # upper gallery
	_concrete(1, 44, 16, 16)
	_air(1, 60, 17, 17)           # middle gallery, one block tall
	_concrete(1, 60, 18, 18)
	_air(1, 74, 19, 19)           # lower gallery
	_air(62, 74, 15, 19)          # the exit's chamber
	return {
		"name": "Eco Profundo", "environment": LevelEnvironment.Kind.CRYSTAL_CAVE,
		"spawn": Vector2i(6, 16), "exit": Vector2i(70, 20),
		"lemmings": 12, "rate": 2.5, "required": 0.7, "time": 210,
		"tools": {"dynamite": 3},
		"hint": "A Dinamite fica no chão e explode depois de 3 segundos.",
	}


## 9. TNT. The upper gallery's floor is two blocks of crystal, which
## dynamite does not get through, and the lower gallery starts right under
## its end: TNT set down by the end wall opens the way.
func _level_09() -> Dictionary:
	_air(1, 38, 15, 19)           # upper gallery
	_concrete(1, 39, 20, 21)      # its floor, two blocks thick
	_air(40, 74, 20, 21)          # lower gallery
	_air(37, 39, 21, 21)          # ...reaching under the end of the floor
	_air(62, 74, 16, 21)          # the exit's chamber
	_concrete(1, 78, 22, 22)
	return {
		"name": "Coração de Cristal", "environment": LevelEnvironment.Kind.CRYSTAL_CAVE,
		"spawn": Vector2i(6, 20), "exit": Vector2i(70, 22),
		"lemmings": 12, "rate": 2.5, "required": 0.6, "time": 150,
		"tools": {"dynamite": 2, "tnt": 2},
		"hint": "O TNT abre um buraco maior que a Dinamite.",
	}


## 10. Shovel, bridge, diagonal ladder. A snowy shelf over a hollow, a
## crevasse in the valley and a terrace with the exit.
func _level_10() -> Dictionary:
	_sky(17)
	_earth(25, 30, 10, 17)        # the cliff closing the shelf
	_air(1, 30, 19, 19)           # the hollow under the shelf
	_air(31, 78, 18, 19)          # the valley
	_abyss(39, 44, 20)
	_earth(57, 78, 17, 19)        # the terrace
	return {
		"name": "Travessia Gelada", "environment": LevelEnvironment.Kind.SNOWFIELD,
		"spawn": Vector2i(8, 18), "exit": Vector2i(70, 17),
		"lemmings": 12, "rate": 3.0, "required": 0.8, "time": 200,
		"tools": {"digger": 1, "bridge": 1, "builder": 2},
	}


## 11. Block, vertical ladder, jackhammer. The lemmings come out walking
## towards a chasm; behind them is an ice tower, and on top of it a wall of
## ice in front of the exit.
func _level_11() -> Dictionary:
	_sky(29)
	_abyss(45, 50, 30)
	_earth(1, 14, 21, 29)         # the tower
	_concrete(6, 7, 13, 20)       # the ice wall on top
	_earth(51, 78, 24, 29)
	return {
		"name": "Torre de Gelo", "environment": LevelEnvironment.Kind.SNOWFIELD,
		"spawn": Vector2i(34, 30), "exit": Vector2i(3, 21),
		"lemmings": 14, "rate": 2.5, "required": 0.85, "time": 150,
		"tools": {"block": 1, "ladder_vertical": 1, "basher": 1},
	}


## 12. Bridge, pickaxe, vertical ladder, one of each. A crevasse, a snow
## drift and a cliff, in that order.
func _level_12() -> Dictionary:
	_sky(25)
	_abyss(19, 26, 26)
	_earth(33, 39, 18, 25)        # the drift
	_earth(49, 78, 19, 25)        # the cliff
	return {
		"name": "Fenda Glacial", "environment": LevelEnvironment.Kind.SNOWFIELD,
		"spawn": Vector2i(8, 26), "exit": Vector2i(64, 19),
		"lemmings": 15, "rate": 3.0, "required": 0.85, "time": 180,
		"tools": {"bridge": 1, "miner": 1, "ladder_vertical": 1},
	}


## 13. Bridge, dynamite, jackhammer, and a pickaxe that does not help. A
## gorge, an obsidian floor over a lower gallery, an obsidian wall.
func _level_13() -> Dictionary:
	_sky(12)
	_air(1, 50, 13, 17)           # upper shelf
	_concrete(28, 50, 18, 18)     # its obsidian floor past the gorge
	_abyss(21, 27, 13)            # the gorge
	_air(29, 60, 19, 19)          # lower gallery, one block tall
	_air(52, 72, 15, 19)          # ...and its high end
	_concrete(58, 61, 15, 19)     # the obsidian wall
	_concrete(29, 78, 20, 20)
	return {
		"name": "Passagem de Obsidiana", "environment": LevelEnvironment.Kind.VOLCANO,
		"spawn": Vector2i(6, 18), "exit": Vector2i(67, 20),
		"lemmings": 15, "rate": 3.0, "required": 0.8, "time": 150,
		"tools": {"bridge": 1, "dynamite": 1, "basher": 1, "miner": 1},
	}


## 14. A pioneer. The lemmings fall into a caldera they cannot leave: one
## climbs out, floats down and bridges the gorge outside; then a shaft dug
## through the caldera's floor lets the rest out underneath.
func _level_14() -> Dictionary:
	_sky(11)
	_air(4, 16, 12, 19)           # the caldera
	_air(19, 78, 12, 21)          # outside
	_air(4, 18, 21, 21)           # the gallery under the caldera
	_abyss(31, 37, 22)
	return {
		"name": "Caldeirão", "environment": LevelEnvironment.Kind.VOLCANO,
		"spawn": Vector2i(8, 20), "exit": Vector2i(50, 22),
		"lemmings": 15, "rate": 2.5, "required": 0.9, "time": 160,
		"tools": {"climber": 1, "floater": 1, "bridge": 1, "digger": 1},
	}


## 15. Everything at once, one of each: a pioneer climbs out of the
## crater, floats down, bridges a gorge, breaks an obsidian wall and lays a
## staircase up to the exit; TNT by the crater's wall lets the others out.
func _level_15() -> Dictionary:
	_sky(9)
	_air(3, 16, 10, 19)           # the crater
	_concrete(3, 17, 20, 21)      # its floor, two blocks of obsidian
	_air(15, 17, 21, 21)          # the gallery reaches under its end
	_air(18, 78, 10, 21)          # outside
	_abyss(29, 35, 22)
	_concrete(44, 46, 14, 21)     # the obsidian wall
	_earth(60, 78, 19, 21)        # the terrace with the exit
	return {
		"name": "Coroa de Fogo", "environment": LevelEnvironment.Kind.VOLCANO,
		"spawn": Vector2i(7, 20), "exit": Vector2i(70, 19),
		"lemmings": 20, "rate": 2.5, "required": 0.75, "time": 210,
		"tools": {"climber": 1, "floater": 1, "bridge": 1, "basher": 1, "builder": 1, "tnt": 1},
	}
