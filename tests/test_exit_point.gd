extends "res://tests/tool_scenario_test.gd"
## Automated check of walking into the exit. Run via:
##   godot --headless res://tests/test_exit_point.tscn
##
## Layout: a floor with the exit on it at column EXIT_COLUMN.
## Scenarios:
##   - on the floor: the lemming walks in, reaches the middle of the door
##     before vanishing and is reported saved once it is through;
##   - from a block: a block one row high right beside the exit, the
##     lemming walking on it towards the exit. Reported as a bug: it went in
##     from the top of the block, level with the doorway, instead of
##     dropping down in front of the exit first. It must start going in only
##     with its feet on the exit's floor.

const FLOOR_TOP_ROW := 11
const EXIT_COLUMN := 10
const EXIT_SCENE_PATH := "res://scenes/level/exit_point.tscn"
## Lets the exit's own box start just above the floor (see ExitPoint).
const EXIT_ORIGIN_ABOVE_FLOOR := 24.0

var _lemming: LemmingController = null
var _exit: ExitPoint = null
var _saved := false
var _entry_feet_y := INF
var _entry_x := INF


func _get_test_name() -> String:
	return "Exit point"


func _get_scenarios() -> Array:
	return [
		{"name": "walks in on the floor", "block": false, "run_seconds": 8.0},
		{"name": "drops off a block beside the exit before going in", "block": true, "run_seconds": 8.0},
	]


func _build_scenario() -> void:
	_saved = false
	_entry_feet_y = INF
	_entry_x = INF
	paint(0, 24, FLOOR_TOP_ROW, FLOOR_TOP_ROW + 1)
	paint(-1, -1, -10, FLOOR_TOP_ROW + 1)
	paint(25, 25, -10, FLOOR_TOP_ROW + 1)
	_exit = load(EXIT_SCENE_PATH).instantiate()
	_exit.position = Vector2(EXIT_COLUMN * TILE + TILE / 2.0, FLOOR_TOP_ROW * TILE - EXIT_ORIGIN_ABOVE_FLOOR)
	_world.add_child(_exit)
	_exit.lemming_exited.connect(func(_who: LemmingController) -> void: _saved = true)
	if scenario.block:
		paint(EXIT_COLUMN - 3, EXIT_COLUMN - 1, FLOOR_TOP_ROW - 1, FLOOR_TOP_ROW - 1)
		_lemming = spawn_lemming((EXIT_COLUMN - 3) * TILE + TILE / 2.0, FLOOR_TOP_ROW - 1, 1, "lemming")
	else:
		_lemming = spawn_lemming((EXIT_COLUMN - 4) * TILE + TILE / 2.0, FLOOR_TOP_ROW, 1, "lemming")


func _scenario_frame(_delta: float) -> void:
	if is_instance_valid(_lemming) and _lemming.is_entering_exit and _entry_feet_y == INF:
		_entry_feet_y = _lemming.get_feet_position().y
		_entry_x = _lemming.get_body_rect().get_center().x


func _is_scenario_settled() -> bool:
	return _saved


func _evaluate_scenario() -> void:
	if not _saved:
		fail("the lemming was never saved (%s)" % deaths.get("lemming", "alive"))
		return
	var floor_y := float(FLOOR_TOP_ROW * TILE)
	if absf(_entry_feet_y - floor_y) > 2.0:
		fail("it started going in with its feet at y=%.1f, not on the exit's floor (y=%.0f)" % [_entry_feet_y, floor_y])
	if is_instance_valid(_lemming):
		fail("the lemming was reported saved but is still in the level")
