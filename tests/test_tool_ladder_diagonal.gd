extends Node
## Automated check of the diagonal ladder tool (SkillBuilder). Run via:
##   godot --headless res://tests/test_tool_ladder_diagonal.tscn
## Exits 0 when every scenario passes, 1 otherwise.
##
## Layout: a floor and, to the right, a platform exactly as high as a full
## staircase (max_pieces steps), with a boundary wall beyond it. A lemming
## facing the platform is given the tool at a set distance from it.
##
## What is checked:
##   - the staircase is max_pieces bricks, each one step up and one step
##     along from the last, and no brick sits inside terrain;
##   - the lemming moves smoothly while building: never more than a couple of
##     pixels in a single frame (the old version jumped a whole tile);
##   - from the right distance the lemming ends up walking on the platform,
##     and a second lemming walking up afterwards climbs the stairs too,
##     without bobbing: its sprite never goes down or jumps more than a
##     couple of pixels in a frame on the way up;
##   - starting too close, the staircase stops at the wall with no brick
##     pushed into it, and the lemming survives.
## Both grid alignments are covered: leading edge on the step grid, and half
## a step off it.

const TILE := 32
const FLOOR_TOP_ROW := 8
const FLOOR_BOTTOM_ROW := 9
const PLATFORM_FIRST_COLUMN := 15
const PLATFORM_HEIGHT_TILES := 3
const LEVEL_LAST_COLUMN := 24
const LEFT_WALL_COLUMN := 0

const SETTLE_SECONDS := 0.2
const WALKER_START_X := 50.0
## Clear of the left wall; _apply_tool() then moves it to the scenario distance.
const BUILDER_SPAWN_X := 100.0
const RUN_SECONDS := 40.0
const RESTING_TOLERANCE := 1.5
## A smooth step-up moves well under a pixel per frame; the old teleport moved
## 32px. Anything above this is a jump.
const MAX_FRAME_MOVE := 2.0

const TILE_SET_PATH := "res://resources/tilesets/terrain_tileset.tres"
const LEMMING_SCENE_PATH := "res://scenes/characters/lemming.tscn"

## distance: gap between the body's leading edge and the platform wall when
## the tool is given. A full staircase is max_pieces steps of one tile each
## (384px). The first scenario starts exactly one staircase away, the second
## a little further (the staircase ends short of the wall by less than a body
## width, which a lemming walks across), and the third starts too close.
const SCENARIOS := [
	{"name": "full staircase, ending exactly at the wall", "distance": 384.0, "expect": "reach"},
	{"name": "full staircase, ending a little short of the wall", "distance": 400.0, "expect": "reach"},
	{"name": "too close: staircase stops at the wall", "distance": 100.0, "expect": "blocked"},
]

var _failures: Array[String] = []
var _scenario_index := 0
var _elapsed := 0.0
var _world: Node2D = null
var _terrain: TerrainDestructible = null
var _builder: LemmingController = null
var _walker: LemmingController = null
var _tool: SkillBuilder = null
var _tool_accepted := false
var _tool_applied := false
var _builder_done_at := -1.0
var _largest_frame_move := 0.0
var _last_builder_position := Vector2.ZERO
var _reached_top := {}
var _walker_sprite_y := INF
var _walker_largest_rise := 0.0
var _walker_largest_drop := 0.0
var _deaths: Array[String] = []


func _ready() -> void:
	print("Running diagonal ladder checks (%d scenarios)" % SCENARIOS.size())
	_start_scenario()


func _physics_process(delta: float) -> void:
	_elapsed += delta

	if not _tool_applied and _elapsed >= SETTLE_SECONDS:
		_apply_tool()

	_track_builder()
	_track_walker_sprite()
	_record_arrivals()

	# The walker only starts once the staircase is finished: a lemming that
	# walks up a staircase still being built can step off its unfinished end,
	# which is the original game's behaviour and not what this checks.
	var scenario: Dictionary = SCENARIOS[_scenario_index]
	if scenario.expect == "reach" and _walker == null and _builder_done_at >= 0.0:
		_walker = _spawn_lemming(WALKER_START_X, "walker")

	if _elapsed >= RUN_SECONDS:
		_evaluate()
		_next_scenario()


func _start_scenario() -> void:
	_elapsed = 0.0
	_tool_applied = false
	_tool_accepted = false
	_walker = null
	_builder_done_at = -1.0
	_largest_frame_move = 0.0
	_reached_top = {}
	_deaths = []
	_walker_sprite_y = INF
	_walker_largest_rise = 0.0
	_walker_largest_drop = 0.0

	_world = Node2D.new()
	add_child(_world)

	_terrain = TerrainDestructible.new()
	_terrain.tile_set = load(TILE_SET_PATH)
	_world.add_child(_terrain)
	_paint(LEFT_WALL_COLUMN, LEVEL_LAST_COLUMN + 1, FLOOR_TOP_ROW, FLOOR_BOTTOM_ROW)
	_paint(PLATFORM_FIRST_COLUMN, LEVEL_LAST_COLUMN, FLOOR_TOP_ROW - PLATFORM_HEIGHT_TILES, FLOOR_TOP_ROW - 1)
	_paint(LEFT_WALL_COLUMN, LEFT_WALL_COLUMN, -20, FLOOR_TOP_ROW - 1)
	_paint(LEVEL_LAST_COLUMN + 1, LEVEL_LAST_COLUMN + 1, -20, FLOOR_TOP_ROW - 1)

	var scenario: Dictionary = SCENARIOS[_scenario_index]
	_builder = _spawn_lemming(BUILDER_SPAWN_X, "builder")
	print("\n[%d/%d] %s" % [_scenario_index + 1, SCENARIOS.size(), scenario.name])


func _paint(from_column: int, to_column: int, from_row: int, to_row: int) -> void:
	for column in range(from_column, to_column + 1):
		for row in range(from_row, to_row + 1):
			_terrain.set_cell(Vector2i(column, row), TerrainDestructible.TERRAIN_SOURCE_ID, Vector2i.ZERO)


func _spawn_lemming(x: float, label: String) -> LemmingController:
	var lemming: LemmingController = load(LEMMING_SCENE_PATH).instantiate()
	var body_height: float = (lemming.get_node("CollisionShape2D").shape as RectangleShape2D).size.y
	lemming.terrain = _terrain
	lemming.position = Vector2(x, FLOOR_TOP_ROW * TILE - body_height / 2.0)
	lemming.died.connect(func(cause: LemmingController.DeathCause) -> void:
		_deaths.append("%s died (%s) at t=%.1fs, feet %s" % [label, LemmingController.DeathCause.keys()[cause], _elapsed, Vector2(lemming.get_body_rect().get_center().x, lemming.get_body_rect().end.y)]))
	lemming.set_meta("label", label)
	_world.add_child(lemming)
	return lemming


## Puts the builder's leading edge exactly the scenario's distance from the
## platform wall, then hands over the tool on that same frame.
func _apply_tool() -> void:
	_tool_applied = true
	var wall_x := float(PLATFORM_FIRST_COLUMN * TILE)
	var front := _builder.get_body_rect().end.x
	_builder.global_position.x += (wall_x - SCENARIOS[_scenario_index].distance) - front
	_last_builder_position = _builder.global_position
	_tool = SkillBuilder.new()
	_tool_accepted = _builder.assign_skill(_tool)


func _track_builder() -> void:
	if not _tool_applied or not is_instance_valid(_builder):
		return
	if _builder.state_machine.current_state == LemmingStateMachine.State.BUILDING:
		_largest_frame_move = maxf(_largest_frame_move, _builder.global_position.distance_to(_last_builder_position))
	elif _builder_done_at < 0.0:
		_builder_done_at = _elapsed
	_last_builder_position = _builder.global_position


## Per-frame vertical movement of the walker's sprite while it climbs the
## finished staircase. Reported as bobbing: the body is lifted onto each step
## in a single frame, and before the sprite was smoothed that showed as the
## lemming hopping up and dropping back on every step.
func _track_walker_sprite() -> void:
	if _walker == null or not is_instance_valid(_walker) or _reached_top.has("walker"):
		return
	var sprite_y := _walker.animated_sprite.global_position.y
	var on_stairs := _walker.state_machine.current_state == LemmingStateMachine.State.WALKING \
		and _walker.get_body_rect().end.y < FLOOR_TOP_ROW * TILE - 1.0
	if on_stairs and _walker_sprite_y != INF:
		var moved := sprite_y - _walker_sprite_y
		_walker_largest_rise = maxf(_walker_largest_rise, -moved)
		_walker_largest_drop = maxf(_walker_largest_drop, moved)
	_walker_sprite_y = sprite_y


func _record_arrivals() -> void:
	var platform_top := float((FLOOR_TOP_ROW - PLATFORM_HEIGHT_TILES) * TILE)
	for candidate in [_builder, _walker]:
		# Untyped on purpose: a freed lemming cannot go into a typed array.
		if candidate == null or not is_instance_valid(candidate):
			continue
		var lemming := candidate as LemmingController
		var label: String = lemming.get_meta("label")
		if _reached_top.has(label) or lemming.state_machine.current_state != LemmingStateMachine.State.WALKING:
			continue
		var body := lemming.get_body_rect()
		if body.position.x >= PLATFORM_FIRST_COLUMN * TILE and absf(body.end.y - platform_top) <= RESTING_TOLERANCE:
			_reached_top[label] = _elapsed


func _evaluate() -> void:
	var scenario: Dictionary = SCENARIOS[_scenario_index]
	var scenario_name: String = scenario.name

	if not _tool_accepted:
		_fail(scenario_name, "a walking lemming refused the tool")
		return
	if not _deaths.is_empty():
		_fail(scenario_name, ", ".join(_deaths))
		return

	var bricks := _terrain.get_bricks()
	print("  %d bricks laid; largest single-frame move while building: %.2fpx" % [bricks.size(), _largest_frame_move])
	if _largest_frame_move > MAX_FRAME_MOVE:
		_fail(scenario_name, "the lemming jumped %.1fpx in one frame while building; it must move smoothly" % _largest_frame_move)
		return
	if not _check_staircase_shape(scenario_name, bricks):
		return

	if scenario.expect == "blocked":
		var expected_bricks := int(scenario.distance / (TILE * _tool.step_width_fraction_of_tile))
		if bricks.size() != expected_bricks:
			_fail(scenario_name, "laid %d bricks, expected %d before reaching the wall" % [bricks.size(), expected_bricks])
			return
		print("  PASS")
		return

	if bricks.size() != _tool.max_pieces:
		_fail(scenario_name, "laid %d bricks, expected the full %d" % [bricks.size(), _tool.max_pieces])
		return
	for label in ["builder", "walker"]:
		if not _reached_top.has(label):
			_fail(scenario_name, "the %s never came out walking on the platform (%s)" % [label, _describe(label)])
			return
		print("  %s reached the platform at t=%.1fs" % [label, _reached_top[label]])
	print("  walker sprite on the stairs: largest rise %.2fpx, largest drop %.2fpx per frame" % [_walker_largest_rise, _walker_largest_drop])
	if _walker_largest_rise > MAX_FRAME_MOVE or _walker_largest_drop > MAX_FRAME_MOVE:
		_fail(scenario_name, "the walker's sprite bobbed on the stairs (up %.1fpx, down %.1fpx in one frame)" % [_walker_largest_rise, _walker_largest_drop])
		return
	print("  PASS")


func _describe(label: String) -> String:
	var lemming: LemmingController = _builder if label == "builder" else _walker
	if lemming == null or not is_instance_valid(lemming):
		return "gone"
	var body := lemming.get_body_rect()
	return "ended %s with leading edge x=%.1f, feet y=%.1f" % [
		LemmingStateMachine.State.keys()[lemming.state_machine.current_state],
		body.end.x if lemming.direction > 0 else body.position.x, body.end.y
	]


## Every brick is one step up and one step along from the previous one, all
## step width by step height, and none overlaps terrain.
func _check_staircase_shape(scenario_name: String, bricks: Array[Rect2]) -> bool:
	if bricks.is_empty():
		_fail(scenario_name, "no bricks were laid")
		return false
	var step := Vector2(TILE * _tool.step_width_fraction_of_tile, TILE * _tool.step_height_fraction_of_tile)
	for index in bricks.size():
		var brick := bricks[index]
		if not brick.size.is_equal_approx(step):
			_fail(scenario_name, "brick %d is %s, expected %s" % [index, brick.size, step])
			return false
		if _terrain.get_solid_cells_in_rect(brick.grow(-0.5)).size() > 0:
			_fail(scenario_name, "brick %d at %s overlaps terrain" % [index, brick])
			return false
		if index > 0:
			var moved := brick.position - bricks[index - 1].position
			if not moved.is_equal_approx(Vector2(step.x, -step.y)):
				_fail(scenario_name, "brick %d is offset %s from the previous one, expected (%s, %s)" % [index, moved, step.x, -step.y])
				return false
	return true


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
		print("Diagonal ladder: all %d scenarios passed" % SCENARIOS.size())
		get_tree().quit(0)
		return
	print("Diagonal ladder: %d of %d scenarios failed" % [_failures.size(), SCENARIOS.size()])
	for failure in _failures:
		print("  - %s" % failure)
	get_tree().quit(1)
