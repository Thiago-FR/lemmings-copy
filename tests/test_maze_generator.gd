extends Node
## Checks the procedural maze generator (scripts/procedural/) without playing:
## for SEEDS_PER_DIFFICULTY seeds at every difficulty, the stage is the size
## of the screen with a solid border, the reachability model wins it with one
## lemming and only its own item spots, the entrance, exit and spots stand on
## floor with room above, a stage uses at most four different tools, the
## measures every link depends on hold (ladder wall of 12, stair drops of
## 64px, trough one block deep), the same seed gives the same stage, and the
## data paints onto a TerrainDestructible. A hand-made layout goes through
## MazeStageGenerator.from_layout too. Run via:
##   godot --headless res://tests/test_maze_generator.tscn
## Exits 0 when every check passes, 1 otherwise.

const SEEDS_PER_DIFFICULTY := 20
const TILE_SET := preload("res://resources/tilesets/terrain_tileset.tres")

var _failures: Array[String] = []
var _checks := 0


func _ready() -> void:
	var started := Time.get_ticks_msec()
	for difficulty in MazeStageGenerator.MAX_DIFFICULTY + 1:
		var obstacles := 0
		for seed_index in SEEDS_PER_DIFFICULTY:
			var seed_value := 1000 + seed_index * 7919
			var data := MazeStageGenerator.generate(seed_value, difficulty)
			obstacles += data.solution.size()
			_check_stage(data, "difficulty %d seed %d" % [difficulty, seed_value], difficulty)
		print("  difficulty %d: %.1f tool uses on average" % [difficulty, float(obstacles) / SEEDS_PER_DIFFICULTY])
	_check_determinism()
	_check_painting()
	_check_hand_made()
	print("  %d checks in %d ms" % [_checks, Time.get_ticks_msec() - started])
	if _failures.is_empty():
		print("Maze generator: PASS")
	else:
		print("Maze generator: FAIL\n  " + "\n  ".join(_failures.slice(0, 40)))
	get_tree().quit(0 if _failures.is_empty() else 1)


func _check(condition: bool, description: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(description)


func _check_stage(data: MazeStageData, name: String, difficulty: int) -> void:
	_check(data.cells.size() == MazeLayout.COLUMNS * MazeLayout.ROWS, "%s: grid is 60x34" % name)
	for column in data.columns:
		_check(data.is_solid(column, 0) and data.is_solid(column, data.rows - 1), "%s: border at column %d" % [name, column])
	for row in data.rows:
		_check(data.is_solid(0, row) and data.is_solid(data.columns - 1, row), "%s: border at row %d" % [name, row])
	var result := MazeSolver.solve(data.layout)
	_check(result.solved, "%s: the model wins it with one lemming and its own items (%s)" % [name, result.get("reason", "")])
	_check(data.solution.size() >= MazeStageGenerator.MIN_OBSTACLES[difficulty], "%s: at least %d tool uses on the way (got %d; fallback?)" % [name, MazeStageGenerator.MIN_OBSTACLES[difficulty], data.solution.size()])
	_check(data.layout.spawn_room != data.layout.exit_room, "%s: entrance and exit in different rooms" % name)
	var expected_environment := LevelEnvironment.Kind.CAVE if difficulty >= MazeStageGenerator.FIRST_CAVE_DIFFICULTY else LevelEnvironment.Kind.SURFACE
	_check(data.environment_kind == expected_environment, "%s: environment follows depth" % name)
	_check_standing(data, data.spawn_cell, "%s: entrance" % name)
	_check_standing(data, data.exit_cell, "%s: exit" % name)
	var kinds := {}
	var used := {}
	for spot in data.item_spots:
		_check_standing(data, Vector2i(spot.column, spot.row), "%s: spot at column %d" % [name, spot.column])
		if spot.kind == MazeLayout.SpotKind.TOOL:
			kinds[spot.tool_id] = true
		var key := Vector2i(spot.column, spot.row)
		_check(not used.has(key) and key != data.spawn_cell and key != data.exit_cell, "%s: spots do not overlap" % name)
		used[key] = true
	_check(kinds.size() <= 4, "%s: at most four different tools (%s)" % [name, kinds.keys()])
	_check_links(data, name)


## Solid floor under the cell and the CLEAR_HEIGHT rows above it open.
func _check_standing(data: MazeStageData, cell: Vector2i, name: String) -> void:
	_check(data.is_solid(cell.x, cell.y), "%s stands on floor" % name)
	for rise in range(1, MazeLayout.CLEAR_HEIGHT + 1):
		_check(not data.is_solid(cell.x, cell.y - rise), "%s has room above (row %d)" % [name, cell.y - rise])


func _check_links(data: MazeStageData, name: String) -> void:
	for link in data.layout.links:
		# Rooms nobody can get into are painted as rock, links and all.
		if not data.layout.reachable_rooms.has(link.a) and MazeLayout.is_room(link.a):
			continue
		var band: int = link.band
		var floor_row := MazeLayout.floor_row(band)
		match link.kind:
			MazeLayout.LinkKind.LADDER:
				var face: int = link.separator
				var shaft: int = link.column
				var lower_floor := MazeLayout.floor_row(band + 1)
				var height := 0
				for row in range(lower_floor - 1, 0, -1):
					if not data.is_solid(face, row):
						break
					height += 1
				_check(height == 12, "%s: ladder wall at column %d is 12 blocks (got %d)" % [name, face, height])
				for row in range(floor_row - 2, lower_floor):
					_check(not data.is_solid(shaft, row), "%s: ladder shaft at column %d open at row %d" % [name, shaft, row])
				_check(data.is_solid(shaft - link.side, floor_row - 2), "%s: curb beside the ladder top" % name)
			MazeLayout.LinkKind.STAIRS:
				var side: int = link.side
				var surface := floor_row
				var column: int = link.column
				_check(data.cell_at(column, floor_row) == MazeLayout.EARTH, "%s: dig patch is earth" % name)
				for step in MazeLayout.STAIR_STEPS:
					var top := _top_of_solid(data, column - side * step, floor_row + 1)
					_check(top - surface == 2, "%s: stair drop of 2 blocks at column %d (got %d)" % [name, column - side * step, top - surface])
					surface = top
				_check(_top_of_solid(data, column - side * MazeLayout.STAIR_STEPS, floor_row + 2 * MazeLayout.STAIR_STEPS) == MazeLayout.floor_row(band + 1), "%s: last step one block over the floor" % name)
			MazeLayout.LinkKind.BRIDGE:
				for column in range(link.trough_first, link.trough_last + 1):
					_check(not data.is_solid(column, floor_row) and data.is_solid(column, floor_row + 1), "%s: trough one block deep at column %d" % [name, column])
				_check(data.is_solid(link.trough_first - 1, floor_row) and data.is_solid(link.trough_last + 1, floor_row), "%s: trough has floor on both sides" % name)


## First solid row at or below from_row.
func _top_of_solid(data: MazeStageData, column: int, from_row: int) -> int:
	for row in range(from_row, data.rows):
		if data.is_solid(column, row):
			return row
	return data.rows


func _check_determinism() -> void:
	var first := MazeStageGenerator.generate(424242, 3)
	var second := MazeStageGenerator.generate(424242, 3)
	_check(first.cells == second.cells and first.spawn_cell == second.spawn_cell and first.exit_cell == second.exit_cell, "the same seed gives the same stage")
	var other := MazeStageGenerator.generate(424243, 3)
	_check(first.cells != other.cells, "another seed gives another stage")


func _check_painting() -> void:
	var data := MazeStageGenerator.generate(77, 2)
	var terrain := TerrainDestructible.new()
	terrain.tile_set = TILE_SET
	data.paint_onto(terrain)
	var mismatches := 0
	for row in data.rows:
		for column in data.columns:
			if (terrain.get_cell_source_id(Vector2i(column, row)) != -1) != data.is_solid(column, row):
				mismatches += 1
	_check(mismatches == 0, "paint_onto puts every solid cell on the terrain (%d mismatches)" % mismatches)
	terrain.free()


func _check_hand_made() -> void:
	var layout := MazeLayout.new()
	layout.add_open(0, 0)
	layout.add_wall(1, 0, MazeLayout.EARTH)
	layout.spawn_room = MazeLayout.room_id(0, 0)
	layout.exit_room = MazeLayout.room_id(2, 0)
	var data := MazeStageGenerator.from_layout(layout, 5, 0)
	_check(data == null, "a hand-made layout without the tool it needs is refused")
	layout.add_tool_spot(MazeLayout.room_id(1, 0), "miner", 1)
	data = MazeStageGenerator.from_layout(layout, 5, 0)
	_check(data != null and data.solution.size() == 1 and data.solution[0].tool == "miner", "with a pickaxe spot it is won with one pickaxe")
