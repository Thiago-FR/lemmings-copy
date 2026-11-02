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

	for entrance in _spawns_of(spec):
		var spawn: Node2D = _res.spawn_point_scene.instantiate()
		var spawn_cell: Vector2i = entrance.cell
		spawn.position = Vector2(spawn_cell.x * TILE + TILE / 2, spawn_cell.y * TILE - SPAWN_ABOVE_FLOOR)
		spawn.set("lemming_count", entrance.get("count", 0))
		spawn.set("faces_left", entrance.get("left", false))
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


## The level's entrances: spec.spawns (cell, count, left) when it has more
## than one, otherwise the single spec.spawn releasing every lemming.
func _spawns_of(spec: Dictionary) -> Array:
	if spec.has("spawns"):
		return spec.spawns
	return [{"cell": spec.spawn}]


func _add_owned(root: Node, child: Node) -> void:
	root.add_child(child)
	child.owner = root


func _write_ascii(path: String, spec: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Cannot write %s" % path)
		return
	var spawn_cells: Array[Vector2i] = []
	for entrance in _spawns_of(spec):
		spawn_cells.append(entrance.cell)
	var exit_cell: Vector2i = spec.exit
	file.store_line("%s  (%s)" % [spec.name, spec.tools])
	file.store_line("    " + "".join(range(LEVEL_COLUMNS).map(func(c: int) -> String: return str(c % 10))))
	for row in LEVEL_ROWS:
		var line := ""
		for column in LEVEL_COLUMNS:
			var mark := ".#="[_map[row][column]]
			if spawn_cells.has(Vector2i(column, row + 1)):
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


## 6. Only blocks: a maze of sand tunnels, one block tall, joined by holes
## (a drop of two blocks, safe) and ending in deep pits. Left alone the
## lemmings drop into the first tunnel and run to a pit; turning them back
## there only sends them to the next pit, and that branch needs three
## turns. With two blocks the way is behind the entrance: turn them back at
## once, towards the hole they never walk past, and once more near the end.
func _level_06() -> Dictionary:
	_sky(8)
	_earth(14, 30, 8, 8)          # dunes
	_earth(46, 66, 7, 8)
	_air(3, 50, 13, 15)           # A, the entrance hall
	_air(5, 5, 16, 16)            # ...its hole behind the entrance
	_air(27, 27, 16, 16)          # ...and the one ahead
	_air(2, 11, 17, 17)           # D, under the entrance
	_air(9, 9, 18, 18)
	_air(14, 64, 17, 17)          # B
	_air(17, 17, 18, 18)
	_air(65, 66, 17, 24)          # B's pit
	_air(8, 40, 19, 19)           # C
	_air(36, 36, 20, 20)
	_air(7, 7, 19, 25)            # C's pit
	_air(30, 60, 21, 21)          # E
	_air(33, 33, 22, 22)
	_air(61, 62, 21, 28)          # E's pit
	_air(20, 45, 23, 23)          # F, with the exit
	_air(23, 28, 22, 22)
	return {
		"name": "Labirinto das Dunas", "environment": LevelEnvironment.Kind.DESERT,
		"spawn": Vector2i(10, 16), "exit": Vector2i(25, 24),
		"lemmings": 10, "rate": 3.0, "required": 0.8, "time": 200,
		"tools": {"block": 2},
	}


## 7. Rooms of crystal. Three ways from the room with the entrance to the
## exit below the far one: along the top (an earth wall, a crystal wall, a
## crystal floor), along the top then down (earth wall, floor, earth wall)
## or down at once (floor, a chasm, an earth wall). One pickaxe, one
## shovel, one bridge, one dynamite: the wall the lemmings walk into first
## is the wrong start, and the dynamite fits no wall here (each is two
## blocks thick).
func _level_07() -> Dictionary:
	_air(2, 22, 12, 17)           # room with the entrance
	_air(25, 46, 12, 17)          # second room (earth wall between)
	_air(49, 76, 12, 17)          # third room
	_concrete(47, 48, 11, 18)     # crystal wall
	_concrete(49, 76, 18, 18)     # third room's crystal floor
	_air(2, 22, 19, 19)           # tunnel under the first room
	_abyss(23, 28, 19)            # the chasm
	_air(29, 46, 19, 19)          # tunnel under the second room
	_air(49, 76, 19, 19)          # tunnel under the third room (earth wall between)
	_air(64, 74, 20, 20)          # the exit's chamber
	return {
		"name": "Câmaras de Cristal", "environment": LevelEnvironment.Kind.CRYSTAL_CAVE,
		"spawn": Vector2i(6, 18), "exit": Vector2i(70, 21),
		"lemmings": 12, "rate": 2.5, "required": 0.75, "time": 210,
		"tools": {"miner": 1, "digger": 1, "bridge": 1, "dynamite": 1},
	}


## 8. Waiting. The way down is through the crystal floor at the far end of
## the hall, and only a blast opens it, which kills whoever is near. Every
## lemming has to be saved: the first goes ahead, a block behind him holds
## the rest, he sets the charge, and a pickaxe through the block lets them
## follow. The floor near the entrance is two blocks thick: a charge there
## only digs a trap.
func _level_08() -> Dictionary:
	_air(2, 38, 18, 21)           # the hall
	_concrete(2, 25, 22, 23)      # its floor, two blocks of crystal...
	_concrete(26, 38, 22, 22)     # ...and one over the gallery
	_air(26, 72, 23, 23)          # the gallery
	_air(62, 70, 21, 22)          # the exit's chamber
	return {
		"name": "A Espera", "environment": LevelEnvironment.Kind.CRYSTAL_CAVE,
		"spawn": Vector2i(5, 22), "exit": Vector2i(66, 24),
		"lemmings": 15, "rate": 2.5, "required": 1.0, "time": 210,
		"tools": {"block": 2, "dynamite": 2, "miner": 1, "digger": 1},
	}


## 9. The safety net. The lemmings land in a hall shut by a rock; past it a
## ledge ends at a narrow shaft, and the way on is a tunnel low in the
## shaft's far wall. A ladder grabs whoever falls past it: a pioneer climbs
## out, floats down the shaft and puts the ladder up to the tunnel, and only
## then a pickaxe opens the rock for the rest, who jump down the shaft onto
## it. A bridge over the shaft leads only to a wall too tall to climb.
func _level_09() -> Dictionary:
	_air(2, 41, 14, 29)           # the hall
	_earth(21, 22, 26, 29)        # the rock shutting the lemmings in
	_air(41, 41, 30, 37)          # the shaft
	_air(42, 62, 35, 35)          # the tunnel in its far wall
	_air(58, 66, 33, 35)          # the exit's chamber
	return {
		"name": "Rede de Segurança", "environment": LevelEnvironment.Kind.CRYSTAL_CAVE,
		"spawn": Vector2i(6, 30), "exit": Vector2i(62, 36),
		"lemmings": 15, "rate": 2.5, "required": 0.8, "time": 210,
		"tools": {"climber": 1, "floater": 1, "ladder_vertical": 1, "miner": 1, "bridge": 1, "block": 1},
	}


## 10. Against the clock. The lemmings zigzag down six tunnels inside the
## mountain to the exit: safe, and far too slow. Every tunnel floor is one
## block over the next, so a shovel anywhere is a safe drop, but dug where
## they walk it saves nothing: they land walking the long way. Dug where they
## turn (a corner), it skips two tunnels.
func _level_10() -> Dictionary:
	_sky(6)
	for tunnel in 6:
		var floor_row := 12 + tunnel * 2
		_air(8, 52, floor_row - 1, floor_row - 1)
		if tunnel < 5:
			var hole_column := 9 if tunnel % 2 == 0 else 51
			_air(hole_column, hole_column, floor_row, floor_row)
	_air(44, 50, 8, 10)           # under the entrance
	_air(53, 62, 21, 21)          # the last tunnel runs on to the exit
	_air(55, 61, 19, 20)
	return {
		"name": "Contra o Relógio", "environment": LevelEnvironment.Kind.SNOWFIELD,
		"spawn": Vector2i(46, 12), "exit": Vector2i(58, 22),
		"lemmings": 20, "rate": 2.0, "required": 0.7, "time": 125,
		"tools": {"digger": 2, "block": 2, "bridge": 1},
	}


## 11. Only bridges. The lemmings come out walking to a pit under a cliff,
## and the exit is the other way, past a gap wider than one bridge. A bridge
## to the cliff turns them back; two in a row cross the gap (the second
## given to one walking on the first), and whoever builds the first walks
## off its end.
func _level_11() -> Dictionary:
	_sky(25)
	_abyss(14, 31, 26)            # the wide gap
	_abyss(47, 52, 26)            # the pit under the cliff
	_earth(53, 78, 14, 25)        # the cliff
	return {
		"name": "Só Pontes", "environment": LevelEnvironment.Kind.SNOWFIELD,
		"spawn": Vector2i(40, 26), "exit": Vector2i(6, 26),
		"lemmings": 15, "rate": 4.0, "required": 0.8, "time": 200,
		"tools": {"bridge": 3},
	}


## 12. Two mouths. Lemmings come out on both sides of an ice tower with the
## exit on top, and there is one ladder. Put up on one face it is the way
## for both, once a tunnel through the tower's foot brings the other side
## to it; dug first, the tunnel leaves no face for the ladder.
func _level_12() -> Dictionary:
	_sky(29)
	_earth(36, 43, 24, 29)        # the tower
	_abyss(50, 54, 30)            # a crevasse on the right
	return {
		"name": "Duas Bocas", "environment": LevelEnvironment.Kind.SNOWFIELD,
		"spawns": [
			{"cell": Vector2i(8, 30), "count": 10},
			{"cell": Vector2i(71, 30), "count": 10, "left": true},
		],
		"exit": Vector2i(40, 24),
		"lemmings": 20, "rate": 3.0, "required": 0.8, "time": 200,
		"tools": {"ladder_vertical": 1, "miner": 1, "bridge": 1, "climber": 2, "block": 1},
	}


## 13. The lava lip. Out of the entrance the lemmings walk to a lava pit
## under a cliff; the exit is the other way, across a channel, on a shelf
## two blocks higher whose edge juts out over the channel. A bridge there
## leads under the lip to a wall, and the lip stops a ladder; a staircase
## from the near edge rises over the channel onto the lip. So the bridge
## is for the pit: either turns them back from the cliff, but only one of
## them then climbs the shelf.
func _level_13() -> Dictionary:
	_sky(25)
	_abyss(47, 52, 26)            # the lava pit
	_earth(53, 78, 10, 25)        # the cliff
	_abyss(22, 29, 26)            # the channel
	_earth(2, 21, 24, 25)         # the shelf
	_earth(22, 22, 24, 24)        # its lip
	return {
		"name": "Beiço de Lava", "environment": LevelEnvironment.Kind.VOLCANO,
		"spawn": Vector2i(36, 26), "exit": Vector2i(8, 24),
		"lemmings": 12, "rate": 3.0, "required": 0.75, "time": 180,
		"tools": {"bridge": 1, "builder": 1, "ladder_vertical": 2},
	}


## 14. Veins of obsidian: plenty of shovels and pickaxes, and the puzzle is
## the rock. A shovel digs until it breaks into a hollow or meets obsidian,
## a pickaxe until it breaks into a hollow; a shaft deeper than two blocks
## kills whoever walks into it after the digger. So the way down to the
## exit is read in the veins: dig onto a vein two blocks down, tunnel
## sideways to the next hollow, and again. Digging straight into the hollow
## below the crater drops them too far; the wrong side of a pit leads into
## lava.
func _level_14() -> Dictionary:
	_sky(8)
	_earth(63, 78, 3, 8)          # the crater's rim
	_concrete(22, 38, 11, 11)     # first vein, two blocks under the crater
	_air(10, 14, 10, 20)          # a lava pocket on the left
	_air(44, 52, 10, 12)          # first hollow
	_concrete(44, 52, 15, 15)     # second vein, under it
	_air(58, 60, 11, 30)          # a lava pocket on the right
	_air(30, 38, 14, 15)          # second hollow
	_concrete(30, 34, 18, 18)     # third vein, under part of it
	_air(35, 45, 17, 17)          # third hollow, one block tall
	_air(50, 56, 17, 19)          # the exit's chamber
	return {
		"name": "Veios de Obsidiana", "environment": LevelEnvironment.Kind.VOLCANO,
		"spawn": Vector2i(6, 9), "exit": Vector2i(53, 20),
		"lemmings": 20, "rate": 2.5, "required": 0.7, "time": 300,
		"tools": {"digger": 8, "miner": 8, "block": 4},
	}


## 15. Crown of fire. Two entrances, both groups dropping into one long
## tunnel that ends in a lava pit at each end, and the exit is under the
## obsidian floor in its middle, where everyone keeps crossing: only a
## charge opens it, and the goal leaves no one to spare. Each group is held
## on its own side (a block behind its first lemming), the two pioneers left
## in the middle set the charge, and pickaxes open the pens. Five walls are
## needed and there are three blocks: bridges over the end pits, to the
## rock beyond, turn the crowd back too.
func _level_15() -> Dictionary:
	_air(3, 20, 6, 8)             # left entrance hall
	_air(19, 19, 9, 9)
	_air(59, 76, 6, 8)            # right entrance hall
	_air(60, 60, 9, 9)
	_air(10, 69, 10, 10)          # the long tunnel
	_air(7, 9, 10, 20)            # lava pit at its left end
	_air(70, 72, 10, 20)          # ...and at its right end
	_concrete(34, 45, 11, 11)     # the obsidian floor in the middle
	_air(30, 50, 12, 12)          # the gallery under it
	_air(47, 50, 13, 13)          # the exit's niche
	return {
		"name": "Coroa de Fogo", "environment": LevelEnvironment.Kind.VOLCANO,
		"spawns": [
			{"cell": Vector2i(6, 9), "count": 10},
			{"cell": Vector2i(73, 9), "count": 10, "left": true},
		],
		"exit": Vector2i(49, 14),
		"lemmings": 20, "rate": 3.0, "required": 0.95, "time": 300,
		"tools": {"block": 3, "bridge": 2, "dynamite": 1, "miner": 2, "digger": 1},
	}
