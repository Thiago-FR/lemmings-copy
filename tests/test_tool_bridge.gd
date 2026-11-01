extends Node
## Automated check of the bridge tool (SkillBridge). Run via:
##   godot --headless res://tests/test_tool_bridge.tscn
## Exits 0 when every scenario passes, 1 otherwise.
##
## Layout: a floor broken by a gap with nothing underneath (falling into it
## is a death by void), the floor continuing on the far side, and boundary
## walls at both ends. A lemming walking towards the gap is given the tool.
##
## What is checked:
##   - every piece is a full tile wide and a quarter tile tall, its top flush
##     with the floor surface, each one right after the previous one at the
##     same height, the first one starting exactly at the floor's edge, and
##     none overlapping terrain;
##   - the lemming moves smoothly while bridging: never more than a couple of
##     pixels in a single frame;
##   - over a gap narrower than a full bridge, the bridge stops at the far
##     side (one piece per tile of gap, fewer than max_pieces) with the
##     builder's leading edge right at the far floor, the builder comes out
##     walking on the far floor, and a second lemming walking across
##     afterwards reaches it too. Covered both from a lemming given the tool
##     well before the gap (it walks to the edge first) and from one already
##     leaning past the edge;
##   - over a gap wider than a full bridge, exactly max_pieces are laid, and
##     the builder walks off the unfinished end and falls out of the level
##     (death by void), as a Lemmings builder running out of bricks does.

const TILE := 32
const FLOOR_TOP_ROW := 8
const FLOOR_BOTTOM_ROW := 9
const LEVEL_LAST_COLUMN := 24
const LEFT_WALL_COLUMN := 0

const SETTLE_SECONDS := 0.2
const WALKER_START_X := 50.0
const BUILDER_SPAWN_X := 100.0
const RUN_SECONDS := 25.0
const RESTING_TOLERANCE := 1.5
## How close to the far side the builder's leading edge has to be when the
## bridge ends.
const STOP_TOLERANCE := 1.0
## Walking pace is under a pixel per frame. Anything above this is a jump.
const MAX_FRAME_MOVE := 2.0

const TILE_SET_PATH := "res://resources/tilesets/terrain_tileset.tres"
const LEMMING_SCENE_PATH := "res://scenes/characters/lemming.tscn"

## gap_first_column / gap_columns: where the gap is and how many tiles wide.
## lean_past_edge: if set, the builder's leading edge is put this far past the
## floor's edge (still standing on the floor) when it gets the tool;
## otherwise it gets the tool where it stands, well before the gap.
## expect: "reach" (both lemmings cross) or "runs_out" (max_pieces laid, the
## builder falls off the end).
const SCENARIOS := [
	{"name": "six-tile gap, tool given well before the edge", "gap_first_column": 9, "gap_columns": 6, "lean_past_edge": 0.0, "expect": "reach"},
	{"name": "six-tile gap, tool given leaning past the edge", "gap_first_column": 9, "gap_columns": 6, "lean_past_edge": 10.0, "expect": "reach"},
	{"name": "gap wider than a full bridge: the bridge runs out", "gap_first_column": 6, "gap_columns": 14, "lean_past_edge": 0.0, "expect": "runs_out"},
]

var _failures: Array[String] = []
var _scenario_index := 0
var _elapsed := 0.0
var _world: Node2D = null
var _terrain: TerrainDestructible = null
var _builder: LemmingController = null
var _walker: LemmingController = null
var _tool: SkillBridge = null
var _tool_accepted := false
var _tool_applied := false
var _builder_done_at := -1.0
var _builder_front_when_done := NAN
var _largest_frame_move := 0.0
var _last_builder_position := Vector2.ZERO
var _reached_far_side := {}
var _deaths: Array[String] = []
var _death_causes := {}


func _ready() -> void:
	print("Running bridge checks (%d scenarios)" % SCENARIOS.size())
	_start_scenario()


func _physics_process(delta: float) -> void:
	_elapsed += delta

	if not _tool_applied and _elapsed >= SETTLE_SECONDS:
		_apply_tool()

	_track_builder()
	_record_arrivals()

	# The walker only starts once the bridge is finished: a lemming that
	# walks onto a bridge still being built can step off its unfinished end,
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
	_builder_front_when_done = NAN
	_largest_frame_move = 0.0
	_reached_far_side = {}
	_deaths = []
	_death_causes = {}

	_world = Node2D.new()
	add_child(_world)

	var scenario: Dictionary = SCENARIOS[_scenario_index]
	_terrain = TerrainDestructible.new()
	_terrain.tile_set = load(TILE_SET_PATH)
	_world.add_child(_terrain)
	_paint(LEFT_WALL_COLUMN, scenario.gap_first_column - 1, FLOOR_TOP_ROW, FLOOR_BOTTOM_ROW)
	_paint(_far_floor_column(), LEVEL_LAST_COLUMN + 1, FLOOR_TOP_ROW, FLOOR_BOTTOM_ROW)
	_paint(LEFT_WALL_COLUMN, LEFT_WALL_COLUMN, -20, FLOOR_TOP_ROW - 1)
	_paint(LEVEL_LAST_COLUMN + 1, LEVEL_LAST_COLUMN + 1, -20, FLOOR_TOP_ROW - 1)

	_builder = _spawn_lemming(BUILDER_SPAWN_X, "builder")
	print("\n[%d/%d] %s" % [_scenario_index + 1, SCENARIOS.size(), scenario.name])


func _far_floor_column() -> int:
	var scenario: Dictionary = SCENARIOS[_scenario_index]
	return scenario.gap_first_column + scenario.gap_columns


func _gap_edge_x() -> float:
	return float(SCENARIOS[_scenario_index].gap_first_column * TILE)


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
		_death_causes[label] = cause
		_deaths.append("%s died (%s) at t=%.1fs, feet %s" % [label, LemmingController.DeathCause.keys()[cause], _elapsed, Vector2(lemming.get_body_rect().get_center().x, lemming.get_body_rect().end.y)]))
	lemming.set_meta("label", label)
	_world.add_child(lemming)
	return lemming


func _apply_tool() -> void:
	_tool_applied = true
	var lean: float = SCENARIOS[_scenario_index].lean_past_edge
	if lean > 0.0:
		_builder.global_position.x += (_gap_edge_x() + lean) - _builder.get_body_rect().end.x
	_last_builder_position = _builder.global_position
	_tool = SkillBridge.new()
	_tool_accepted = _builder.assign_skill(_tool)


func _track_builder() -> void:
	if not _tool_applied or not is_instance_valid(_builder):
		return
	if _builder.state_machine.current_state == LemmingStateMachine.State.BRIDGING:
		_largest_frame_move = maxf(_largest_frame_move, _builder.global_position.distance_to(_last_builder_position))
	elif _builder_done_at < 0.0:
		_builder_done_at = _elapsed
		_builder_front_when_done = _builder.get_body_rect().end.x
	_last_builder_position = _builder.global_position


func _record_arrivals() -> void:
	var floor_top := float(FLOOR_TOP_ROW * TILE)
	var far_floor_x := float(_far_floor_column() * TILE)
	for candidate in [_builder, _walker]:
		# Untyped on purpose: a freed lemming cannot go into a typed array.
		if candidate == null or not is_instance_valid(candidate):
			continue
		var lemming := candidate as LemmingController
		var label: String = lemming.get_meta("label")
		if _reached_far_side.has(label) or lemming.state_machine.current_state != LemmingStateMachine.State.WALKING:
			continue
		var body := lemming.get_body_rect()
		if body.position.x >= far_floor_x and absf(body.end.y - floor_top) <= RESTING_TOLERANCE:
			_reached_far_side[label] = _elapsed


func _evaluate() -> void:
	var scenario: Dictionary = SCENARIOS[_scenario_index]
	var scenario_name: String = scenario.name

	if not _tool_accepted:
		_fail(scenario_name, "a walking lemming refused the tool")
		return

	var bricks := _terrain.get_bricks()
	print("  %d pieces laid; largest single-frame move while bridging: %.2fpx" % [bricks.size(), _largest_frame_move])
	if _largest_frame_move > MAX_FRAME_MOVE:
		_fail(scenario_name, "the lemming jumped %.1fpx in one frame while bridging; it must move smoothly" % _largest_frame_move)
		return
	if not _check_bridge_shape(scenario_name, bricks):
		return

	if scenario.expect == "runs_out":
		_evaluate_runs_out(scenario_name, bricks)
		return

	if not _deaths.is_empty():
		_fail(scenario_name, ", ".join(_deaths))
		return
	var expected_pieces: int = scenario.gap_columns
	if bricks.size() != expected_pieces:
		_fail(scenario_name, "laid %d pieces, expected %d (one per tile of gap) before reaching the far side" % [bricks.size(), expected_pieces])
		return
	if bricks.size() >= _tool.max_pieces:
		_fail(scenario_name, "the gap was meant to need fewer than max_pieces (%d)" % _tool.max_pieces)
		return
	# Handed back right at the far side, not after carrying on along the far
	# floor still under the tool's control.
	var far_floor_x := float(_far_floor_column() * TILE)
	if absf(_builder_front_when_done - far_floor_x) > STOP_TOLERANCE:
		_fail(scenario_name, "the bridge ended with the builder's leading edge at x=%.1f, expected it to stop at the far side (x=%.0f)" % [_builder_front_when_done, far_floor_x])
		return
	for label in ["builder", "walker"]:
		if not _reached_far_side.has(label):
			_fail(scenario_name, "the %s never came out walking on the far side (%s)" % [label, _describe(label)])
			return
		print("  %s reached the far side at t=%.1fs" % [label, _reached_far_side[label]])
	print("  PASS")


## The bridge stops at max_pieces even though the gap goes on; the builder,
## handed back to normal walking at the unfinished end, walks off it and
## falls out of the level.
func _evaluate_runs_out(scenario_name: String, bricks: Array[Rect2]) -> void:
	if bricks.size() != _tool.max_pieces:
		_fail(scenario_name, "laid %d pieces, expected exactly max_pieces (%d)" % [bricks.size(), _tool.max_pieces])
		return
	if _death_causes.get("builder", -1) != LemmingController.DeathCause.VOID:
		_fail(scenario_name, "expected the builder to walk off the unfinished end and die by void; deaths: [%s], builder %s" % [", ".join(_deaths), _describe("builder")])
		return
	print("  builder walked off the end of the bridge: %s" % _deaths[0])
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


## Every piece is piece width by piece height with its top on the floor
## surface, the first one starts at the floor's edge, each one starts where
## the previous one ends, and none overlaps terrain.
func _check_bridge_shape(scenario_name: String, bricks: Array[Rect2]) -> bool:
	if bricks.is_empty():
		_fail(scenario_name, "no pieces were laid")
		return false
	var piece_size := Vector2(TILE * _tool.step_width_fraction_of_tile, TILE * _tool.piece_height_fraction_of_tile)
	var floor_top := float(FLOOR_TOP_ROW * TILE)
	if not is_equal_approx(bricks[0].position.x, _gap_edge_x()):
		_fail(scenario_name, "the first piece starts at x=%.2f, expected the floor's edge at x=%.0f" % [bricks[0].position.x, _gap_edge_x()])
		return false
	for index in bricks.size():
		var brick := bricks[index]
		if not brick.size.is_equal_approx(piece_size):
			_fail(scenario_name, "piece %d is %s, expected %s" % [index, brick.size, piece_size])
			return false
		if not is_equal_approx(brick.position.y, floor_top):
			_fail(scenario_name, "piece %d has its top at y=%.2f, expected flush with the floor at y=%.0f" % [index, brick.position.y, floor_top])
			return false
		if _terrain.get_solid_cells_in_rect(brick.grow(-0.5)).size() > 0:
			_fail(scenario_name, "piece %d at %s overlaps terrain" % [index, brick])
			return false
		if index > 0:
			var moved := brick.position - bricks[index - 1].position
			if not moved.is_equal_approx(Vector2(piece_size.x, 0.0)):
				_fail(scenario_name, "piece %d is offset %s from the previous one, expected (%s, 0)" % [index, moved, piece_size.x])
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
		print("Bridge: all %d scenarios passed" % SCENARIOS.size())
		get_tree().quit(0)
		return
	print("Bridge: %d of %d scenarios failed" % [_failures.size(), SCENARIOS.size()])
	for failure in _failures:
		print("  - %s" % failure)
	get_tree().quit(1)
