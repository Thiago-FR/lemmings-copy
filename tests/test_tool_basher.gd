extends "res://tests/tool_scenario_test.gd"
## Automated check of the basher (SkillBasher). Run via:
##   godot --headless res://tests/test_tool_basher.tscn
##
## Layout: a floor and a wall three tiles thick and four tall standing on it,
## open floor beyond. The basher is handed over in the open, well before the
## wall: a lemming turns around the instant it touches a wall, so the tool
## has to be carried there and used on arrival. Two starting positions: body
## inside one grid column, and straddling two.
##
## Checked: a tunnel one tile tall (the body's height) goes all the way
## through the wall and no higher; the floor is left whole; the basher comes out the other side and
## walks on; a second lemming behind it walks through the same tunnel;
## nobody dies.

const FLOOR_TOP_ROW := 11
const WALL_FIRST_COLUMN := 14
const WALL_LAST_COLUMN := 16
const WALL_TOP_ROW := 7
const TUNNEL_ROWS := 1
## Long enough for the follower to walk back: it reaches the tunnel while it
## is still being dug, turns at its unfinished end, walks to the left
## boundary and back before it can come through.
const RUN_SECONDS := 50.0

var _basher: LemmingController = null
var _follower: LemmingController = null
var _tool_given := false
var _tool_accepted := false
var _through := {}


func _get_test_name() -> String:
	return "Basher"


func _get_scenarios() -> Array:
	return [
		{"name": "body inside one column", "start_x": 112.0, "run_seconds": RUN_SECONDS},
		{"name": "body straddling two columns", "start_x": 128.0, "run_seconds": RUN_SECONDS},
	]


func _build_scenario() -> void:
	_tool_given = false
	_tool_accepted = false
	_through = {}
	paint(0, 24, FLOOR_TOP_ROW, FLOOR_TOP_ROW + 1)
	paint(WALL_FIRST_COLUMN, WALL_LAST_COLUMN, WALL_TOP_ROW, FLOOR_TOP_ROW - 1)
	paint(-1, -1, -10, FLOOR_TOP_ROW + 1)
	paint(25, 25, -10, FLOOR_TOP_ROW + 1)
	_basher = spawn_lemming(scenario.start_x, FLOOR_TOP_ROW, 1, "basher")
	_follower = spawn_lemming(scenario.start_x - 64.0, FLOOR_TOP_ROW, 1, "follower")


func _scenario_frame(_delta: float) -> void:
	if not _tool_given and _basher.state_machine.current_state == LemmingStateMachine.State.WALKING:
		_tool_given = true
		_tool_accepted = _basher.assign_skill(SkillBasher.new())
	for lemming in [_basher, _follower]:
		if is_instance_valid(lemming) and lemming.state_machine.current_state == LemmingStateMachine.State.WALKING \
				and lemming.get_body_rect().position.x > (WALL_LAST_COLUMN + 1) * TILE:
			_through[lemming.get_meta("label")] = true


func _is_scenario_settled() -> bool:
	return _through.size() == 2


func _evaluate_scenario() -> void:
	if not _tool_accepted:
		fail("the basher was refused")
	for column in range(WALL_FIRST_COLUMN, WALL_LAST_COLUMN + 1):
		for row in range(WALL_TOP_ROW, FLOOR_TOP_ROW + 2):
			var in_tunnel := row >= FLOOR_TOP_ROW - TUNNEL_ROWS and row < FLOOR_TOP_ROW
			if in_tunnel and is_cell_solid(column, row):
				fail("tunnel cell (%d, %d) was not dug" % [column, row])
			elif not in_tunnel and not is_cell_solid(column, row):
				fail("cell (%d, %d) outside the tunnel was destroyed" % [column, row])
	for label in ["basher", "follower"]:
		if not _through.has(label):
			fail("%s never came out the other side" % label)
	expect_walking_on_row(_basher, FLOOR_TOP_ROW, "basher")
	expect_walking_on_row(_follower, FLOOR_TOP_ROW, "follower")
	if not deaths.is_empty():
		fail("deaths: %s" % deaths)
