extends "res://tests/tool_scenario_test.gd"
## Automated check of the pickaxe (SkillMiner). Run via:
##   godot --headless res://tests/test_tool_miner.tscn
##
## Layout: a floor and a wall of earth three tiles thick and four tall
## standing on it, open floor beyond. The pickaxe is handed over in the open,
## well before the wall; it is carried there and used on arrival. Two
## starting positions: body inside one grid column, and straddling two.
##
## Checked: a tunnel one tile tall (the body's height) goes all the way
## through the wall, with no partly dug cell left in it and nothing above it
## or below it touched; the digger walks into the tunnel smoothly, never
## more than a couple of pixels in a frame (it used to jump a whole tile per
## swing); it comes out the other side and walks on; a second lemming walks
## through the same tunnel; nobody dies.

const FLOOR_TOP_ROW := 11
const WALL_FIRST_COLUMN := 14
const WALL_LAST_COLUMN := 16
const WALL_TOP_ROW := 7
const RUN_SECONDS := 30.0
const MAX_FRAME_MOVE := 2.0

var _digger: LemmingController = null
var _follower: LemmingController = null
var _tool_given := false
var _tool_accepted := false
var _through := {}
var _last_digger_x := NAN
var _largest_dig_move := 0.0


func _get_test_name() -> String:
	return "Pickaxe"


func _get_scenarios() -> Array:
	return [
		{"name": "body inside one column", "start_x": 112.0, "run_seconds": RUN_SECONDS},
		{"name": "body straddling two columns", "start_x": 128.0, "run_seconds": RUN_SECONDS},
	]


func _build_scenario() -> void:
	_tool_given = false
	_tool_accepted = false
	_through = {}
	_last_digger_x = NAN
	_largest_dig_move = 0.0
	paint(0, 24, FLOOR_TOP_ROW, FLOOR_TOP_ROW + 1)
	paint(WALL_FIRST_COLUMN, WALL_LAST_COLUMN, WALL_TOP_ROW, FLOOR_TOP_ROW - 1)
	paint(-1, -1, -10, FLOOR_TOP_ROW + 1)
	paint(25, 25, -10, FLOOR_TOP_ROW + 1)
	_digger = spawn_lemming(scenario.start_x, FLOOR_TOP_ROW, 1, "digger")
	_follower = spawn_lemming(scenario.start_x - 64.0, FLOOR_TOP_ROW, 1, "follower")


func _scenario_frame(_delta: float) -> void:
	if not _tool_given and _digger.state_machine.current_state == LemmingStateMachine.State.WALKING:
		_tool_given = true
		_tool_accepted = _digger.assign_skill(SkillMiner.new())
	_measure_dig_move()
	for lemming in [_digger, _follower]:
		if is_instance_valid(lemming) and lemming.state_machine.current_state == LemmingStateMachine.State.WALKING \
				and lemming.get_body_rect().position.x > (WALL_LAST_COLUMN + 1) * TILE:
			_through[lemming.get_meta("label")] = true


func _measure_dig_move() -> void:
	if not is_instance_valid(_digger):
		return
	var x := _digger.global_position.x
	if _digger.state_machine.current_state == LemmingStateMachine.State.MINING and not is_nan(_last_digger_x):
		_largest_dig_move = maxf(_largest_dig_move, absf(x - _last_digger_x))
	_last_digger_x = x


func _is_scenario_settled() -> bool:
	return _through.size() == 2


func _evaluate_scenario() -> void:
	if not _tool_accepted:
		fail("the pickaxe was refused")
	for column in range(WALL_FIRST_COLUMN, WALL_LAST_COLUMN + 1):
		for row in range(WALL_TOP_ROW, FLOOR_TOP_ROW + 2):
			var in_tunnel := row == FLOOR_TOP_ROW - 1
			if in_tunnel and terrain.get_cell_source_id(Vector2i(column, row)) != -1:
				fail("tunnel cell (%d, %d) was not dug out completely" % [column, row])
			elif not in_tunnel and not is_cell_solid(column, row):
				fail("cell (%d, %d) outside the tunnel was destroyed" % [column, row])
			elif not in_tunnel and terrain.get_cell_atlas_coords(Vector2i(column, row)) != Vector2i.ZERO:
				fail("cell (%d, %d) outside the tunnel was partly dug" % [column, row])
	print("  digger moved at most %.2fpx in a frame while digging" % _largest_dig_move)
	if _largest_dig_move > MAX_FRAME_MOVE:
		fail("the digger jumped %.1fpx in one frame while digging" % _largest_dig_move)
	for label in ["digger", "follower"]:
		if not _through.has(label):
			fail("%s never came out the other side" % label)
	expect_walking_on_row(_digger, FLOOR_TOP_ROW, "digger")
	expect_walking_on_row(_follower, FLOOR_TOP_ROW, "follower")
	if not deaths.is_empty():
		fail("deaths: %s" % deaths)
