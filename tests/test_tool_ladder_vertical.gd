extends Node
## Automated check of the vertical ladder tool. Run via:
##   godot --headless res://tests/test_tool_ladder_vertical.tscn
## Exits 0 when every scenario passes, 1 otherwise.
##
## Layout: a floor with a platform four tiles tall on the right, a wall far
## too tall to climb on the left, and a boundary wall at the far right so
## lemmings on the platform turn back instead of walking off into the void. The tool is handed over while the
## lemming is walking in the open; it must be carried to the platform's wall
## and used there.
##
## What is checked, per scenario:
##   - the ladder fills exactly the empty column against the platform wall,
##     from the floor up to the platform's top, and no terrain is destroyed;
##   - it is built one segment at a time with the lemming climbing each one
##     before placing the next (never more than one cell ahead of it);
##   - the lemming that built it ends up walking on top of the platform;
##   - a second lemming that walks up afterwards climbs it too;
##   - nobody moves more than a couple of pixels in a frame on the way up,
##     stepping off the top included (it used to jump a whole tile there);
##   - nobody dies.
## The second scenario sends the lemming into the too-tall wall first: it must
## turn around, keep the ladder, and use it on the platform.
## A lemming already carrying a ladder must refuse a second one.

const TILE := 32
## Largest believable movement in one frame. Walking and climbing are both
## under a pixel per frame; grabbing a ladder snaps the body onto its column,
## up to Constants.LADDER_GRAB_DISTANCE. Stepping off the top used to move a
## whole tile (32px) in one frame.
const MAX_FRAME_MOVE := Constants.LADDER_GRAB_DISTANCE + 1.0
const FLOOR_TOP_ROW := 8
const FLOOR_BOTTOM_ROW := 9
const PLATFORM_FIRST_COLUMN := 12
const PLATFORM_TOP_ROW := 4
const LEVEL_LAST_COLUMN := 24
const TALL_WALL_COLUMN := 0
const RIGHT_WALL_COLUMN := LEVEL_LAST_COLUMN + 1
const LADDER_COLUMN := PLATFORM_FIRST_COLUMN - 1

const SETTLE_SECONDS := 0.2
const PLACER_START_X := 200.0
const WALKER_SPAWN_SECONDS := 1.5
const WALKER_START_X := 100.0
## Long enough for the second scenario, where the walker reaches the platform
## before the ladder exists, turns back to the far wall and returns.
const RUN_SECONDS := 30.0
const RESTING_TOLERANCE := 1.5

const TILE_SET_PATH := "res://resources/tilesets/terrain_tileset.tres"
const LEMMING_SCENE_PATH := "res://scenes/characters/lemming.tscn"

const SCENARIOS := [
	{"name": "carried to the wall ahead and used there", "facing": 1},
	{"name": "too-tall wall first, ladder kept for the platform", "facing": -1},
]

var _failures: Array[String] = []
var _scenario_index := 0
var _elapsed := 0.0
var _world: Node2D = null
var _terrain: TerrainDestructible = null
var _placer: LemmingController = null
var _walker: LemmingController = null
var _tool_applied := false
var _tool_accepted := false
var _second_tool_refused := false
var _terrain_cell_count := 0
var _reached_top := {}
var _deaths: Array[String] = []
## Furthest the ladder ever reached above the placer while it was building,
## in cells. One means it only ever put up the segment it was about to climb.
var _largest_lead_cells := 0
## Per lemming label: its position last frame, and the largest distance it
## moved in a single frame before reaching the top.
var _last_positions := {}
var _largest_frame_moves := {}


func _ready() -> void:
	print("Running vertical ladder checks (%d scenarios)" % SCENARIOS.size())
	_start_scenario()


func _physics_process(delta: float) -> void:
	_elapsed += delta

	if not _tool_applied and _elapsed >= SETTLE_SECONDS:
		_apply_tool()
	if _walker == null and _elapsed >= WALKER_SPAWN_SECONDS:
		_walker = _spawn_lemming(WALKER_START_X, 1, "walker")

	# Moves first: the frame a lemming lands on the platform counts too.
	_measure_frame_moves()
	_record_arrivals()
	_measure_ladder_lead()

	if _elapsed >= RUN_SECONDS:
		_evaluate()
		_next_scenario()


func _start_scenario() -> void:
	_elapsed = 0.0
	_tool_applied = false
	_tool_accepted = false
	_second_tool_refused = false
	_walker = null
	_reached_top = {}
	_deaths = []
	_largest_lead_cells = 0
	_last_positions = {}
	_largest_frame_moves = {}

	_world = Node2D.new()
	add_child(_world)

	_terrain = TerrainDestructible.new()
	_terrain.tile_set = load(TILE_SET_PATH)
	_world.add_child(_terrain)
	_paint(0, LEVEL_LAST_COLUMN, FLOOR_TOP_ROW, FLOOR_BOTTOM_ROW)
	_paint(PLATFORM_FIRST_COLUMN, LEVEL_LAST_COLUMN, PLATFORM_TOP_ROW, FLOOR_TOP_ROW - 1)
	_paint(TALL_WALL_COLUMN, TALL_WALL_COLUMN, -20, FLOOR_TOP_ROW - 1)
	_paint(RIGHT_WALL_COLUMN, RIGHT_WALL_COLUMN, -20, FLOOR_BOTTOM_ROW)
	_terrain_cell_count = _terrain.get_used_cells_by_id(TerrainDestructible.TERRAIN_SOURCE_ID).size()

	var scenario: Dictionary = SCENARIOS[_scenario_index]
	_placer = _spawn_lemming(PLACER_START_X, scenario.facing, "placer")
	print("\n[%d/%d] %s" % [_scenario_index + 1, SCENARIOS.size(), scenario.name])


func _paint(from_column: int, to_column: int, from_row: int, to_row: int) -> void:
	for column in range(from_column, to_column + 1):
		for row in range(from_row, to_row + 1):
			_terrain.set_cell(Vector2i(column, row), TerrainDestructible.TERRAIN_SOURCE_ID, Vector2i.ZERO)


func _spawn_lemming(x: float, facing: int, label: String) -> LemmingController:
	var lemming: LemmingController = load(LEMMING_SCENE_PATH).instantiate()
	var body_height: float = (lemming.get_node("CollisionShape2D").shape as RectangleShape2D).size.y
	# Handed over explicitly: the previous scenario's terrain stays in the
	# "terrain" group until its queue_free() runs.
	lemming.terrain = _terrain
	# Positioned before entering the tree, or it counts the move as a fall.
	lemming.position = Vector2(x, FLOOR_TOP_ROW * TILE - body_height / 2.0)
	lemming.died.connect(func(cause: LemmingController.DeathCause) -> void:
		_deaths.append("%s died (%s)" % [label, LemmingController.DeathCause.keys()[cause]]))
	lemming.set_meta("label", label)
	_world.add_child(lemming)
	if facing < 0:
		lemming.turn_around()
	return lemming


func _apply_tool() -> void:
	_tool_applied = true
	_tool_accepted = _placer.assign_skill(SkillLadderVertical.new())
	_second_tool_refused = not _placer.assign_skill(SkillLadderVertical.new())


## Arrived means walking on the platform's top surface, off the ladder.
## Recorded the moment it happens.
func _record_arrivals() -> void:
	var platform_top := float(PLATFORM_TOP_ROW * TILE)
	for candidate in [_placer, _walker]:
		# Untyped on purpose: a freed lemming cannot go into a typed array.
		if candidate == null or not is_instance_valid(candidate):
			continue
		var lemming := candidate as LemmingController
		var label: String = lemming.get_meta("label")
		if _reached_top.has(label):
			continue
		if lemming.state_machine.current_state != LemmingStateMachine.State.WALKING:
			continue
		var body: Rect2 = lemming.get_body_rect()
		var on_platform := body.position.x >= PLATFORM_FIRST_COLUMN * TILE
		if on_platform and absf(body.end.y - platform_top) <= RESTING_TOLERANCE:
			_reached_top[label] = _elapsed


func _measure_frame_moves() -> void:
	# Lemmings spawn a hair above the floor and drop onto it at first.
	if _elapsed < SETTLE_SECONDS:
		return
	for candidate in [_placer, _walker]:
		if candidate == null or not is_instance_valid(candidate):
			continue
		var lemming := candidate as LemmingController
		var label: String = lemming.get_meta("label")
		if _reached_top.has(label):
			continue
		if _last_positions.has(label):
			var moved: float = lemming.global_position.distance_to(_last_positions[label])
			_largest_frame_moves[label] = maxf(_largest_frame_moves.get(label, 0.0), moved)
		_last_positions[label] = lemming.global_position


func _measure_ladder_lead() -> void:
	if _placer == null or not is_instance_valid(_placer):
		return
	if _placer.state_machine.current_state != LemmingStateMachine.State.LADDER_PLACING:
		return
	var cells := _ladder_cells()
	if cells.is_empty():
		return
	var body_row := _terrain.local_to_map(_placer.get_body_rect().get_center()).y
	_largest_lead_cells = maxi(_largest_lead_cells, body_row - cells[0].y)


func _evaluate() -> void:
	var scenario_name: String = SCENARIOS[_scenario_index].name

	if not _tool_accepted:
		_fail(scenario_name, "a walking lemming refused the ladder")
		return
	if not _second_tool_refused:
		_fail(scenario_name, "a lemming already carrying a ladder accepted a second one")
		return
	if not _deaths.is_empty():
		_fail(scenario_name, ", ".join(_deaths))
		return

	var expected: Array[Vector2i] = []
	for row in range(PLATFORM_TOP_ROW, FLOOR_TOP_ROW):
		expected.append(Vector2i(LADDER_COLUMN, row))
	var placed := _ladder_cells()
	print("  ladder cells: %s" % [placed])
	if placed != expected:
		_fail(scenario_name, "ladder occupies %s, expected %s" % [placed, expected])
		return

	var terrain_now := _terrain.get_used_cells_by_id(TerrainDestructible.TERRAIN_SOURCE_ID).size()
	if terrain_now != _terrain_cell_count:
		_fail(scenario_name, "terrain went from %d cells to %d; the ladder must not destroy anything" % [_terrain_cell_count, terrain_now])
		return

	print("  ladder reached at most %d cell(s) above the placer while building" % _largest_lead_cells)
	if _largest_lead_cells > 1:
		_fail(scenario_name, "the ladder went %d cells above the placer before it climbed; it must place one segment and climb it before the next" % _largest_lead_cells)
		return

	for label in ["placer", "walker"]:
		if not _reached_top.has(label):
			_fail(scenario_name, "the %s never came out walking on top of the platform (%s)" % [label, _describe(label)])
			return
		print("  %s reached the top at t=%.1fs" % [label, _reached_top[label]])
		var largest_move: float = _largest_frame_moves.get(label, 0.0)
		print("  %s moved at most %.2fpx in a frame" % [label, largest_move])
		if largest_move > MAX_FRAME_MOVE:
			_fail(scenario_name, "the %s jumped %.1fpx in one frame on the way up" % [label, largest_move])
			return
	print("  PASS")


func _describe(label: String) -> String:
	var lemming: LemmingController = _placer if label == "placer" else _walker
	if lemming == null or not is_instance_valid(lemming):
		return "gone"
	return "ended in state %s with feet at %s" % [
		LemmingStateMachine.State.keys()[lemming.state_machine.current_state],
		Vector2(lemming.get_body_rect().get_center().x, lemming.get_body_rect().end.y)
	]


## Ladder cells sorted top to bottom, for a stable comparison.
func _ladder_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for cell in _terrain.get_used_cells_by_id(TerrainDestructible.LADDER_SOURCE_ID):
		cells.append(cell)
	cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y if a.x == b.x else a.x < b.x)
	return cells


func _next_scenario() -> void:
	_world.queue_free()
	_world = null
	_scenario_index += 1
	if _scenario_index < SCENARIOS.size():
		_start_scenario()
		return
	_report()


func _fail(scenario_name: String, reason: String) -> void:
	_failures.append("%s: %s" % [scenario_name, reason])
	print("  FAIL — %s" % reason)


func _report() -> void:
	set_physics_process(false)
	print("")
	if _failures.is_empty():
		print("Vertical ladder: all %d scenarios passed" % SCENARIOS.size())
		get_tree().quit(0)
		return
	print("Vertical ladder: %d of %d scenarios failed" % [_failures.size(), SCENARIOS.size()])
	for failure in _failures:
		print("  - %s" % failure)
	get_tree().quit(1)
