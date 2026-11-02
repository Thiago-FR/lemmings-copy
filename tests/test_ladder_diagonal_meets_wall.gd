extends "res://tests/tool_scenario_test.gd"
## Automated check that a diagonal ladder always reaches the wall it runs
## into. Run via:
##   godot --headless res://tests/test_ladder_diagonal_meets_wall.tscn
##
## A staircase stops when its next full step does not fit before a wall, so
## it used to end anywhere up to a step's width short of the wall. That gap
## is what the user kept running into (prints/bug5.png, bug7.png): lemmings
## crossing it, or turning at it, and a second ladder never filling it.
##
## Layout: a floor and a platform. Scenario 1: one lemming builds towards
## the platform from a distance that leaves a gap the old way. Scenario 2:
## the gap exists already (a staircase laid by hand ending 24px short of the
## platform, which is 26px above its top step, as in bug7) and a lemming
## walking up it is given a second diagonal ladder.
##
## Checked: the staircase ends touching the platform's wall (no gap), and
## the lemming walks up onto the platform; nobody dies.

const FLOOR_TOP_ROW := 13
const PLATFORM_FIRST_COLUMN := 20
const STEP_WIDTH := 32.0
const STEP_HEIGHT := 8.0

var _lemming: LemmingController = null
var _tool_given := false
var _tool_accepted := false
var _on_platform := false
var _platform_top_row := 0


func _get_test_name() -> String:
	return "Diagonal ladder meets the wall"


func _get_scenarios() -> Array:
	return [
		{"name": "built from a distance that leaves a gap", "kind": "build", "run_seconds": 25.0},
		{"name": "second ladder fills an existing gap (bug7)", "kind": "extend", "run_seconds": 30.0},
	]


func _build_scenario() -> void:
	_tool_given = false
	_tool_accepted = false
	_on_platform = false
	paint(0, 30, FLOOR_TOP_ROW, FLOOR_TOP_ROW + 1)
	paint(-1, -1, -30, FLOOR_TOP_ROW + 1)
	paint(31, 31, -30, FLOOR_TOP_ROW + 1)
	var floor_y := float(FLOOR_TOP_ROW * TILE)
	var wall_x := float(PLATFORM_FIRST_COLUMN * TILE)
	if scenario.kind == "build":
		# Three blocks high: a full staircase (96px) would reach the top, but
		# started 20px off the step grid it meets the wall early.
		_platform_top_row = FLOOR_TOP_ROW - 3
		paint(PLATFORM_FIRST_COLUMN, 30, _platform_top_row, FLOOR_TOP_ROW - 1)
		_lemming = spawn_lemming(wall_x - 9.0 * STEP_WIDTH - 20.0 - 13.0, FLOOR_TOP_ROW, 1, "lemming")
	else:
		# As in bug7: five steps by hand (top step 40px up) ending 24px short
		# of a platform two blocks (64px) high, 24px above the top step.
		_platform_top_row = FLOOR_TOP_ROW - 2
		paint(PLATFORM_FIRST_COLUMN, 30, _platform_top_row, FLOOR_TOP_ROW - 1)
		var steps := 5
		var stairs_end := wall_x - 24.0
		for step in steps:
			terrain.place_brick(Rect2(stairs_end - (steps - step) * STEP_WIDTH, floor_y - STEP_HEIGHT * (step + 1), STEP_WIDTH, STEP_HEIGHT))
		_lemming = spawn_lemming(stairs_end - steps * STEP_WIDTH - 60.0, FLOOR_TOP_ROW, 1, "lemming")


func _scenario_frame(_delta: float) -> void:
	if not is_instance_valid(_lemming):
		return
	if not _tool_given and _lemming.state_machine.current_state == LemmingStateMachine.State.WALKING:
		var ready: bool = scenario.kind == "build" or _lemming.get_body_rect().end.y <= FLOOR_TOP_ROW * TILE - 2.0 * STEP_HEIGHT
		if ready:
			_tool_given = true
			_tool_accepted = _lemming.assign_skill(SkillBuilder.new())
	var body := _lemming.get_body_rect()
	if body.position.x >= PLATFORM_FIRST_COLUMN * TILE and absf(body.end.y - _platform_top_row * TILE) < 2.0 \
			and _lemming.state_machine.current_state == LemmingStateMachine.State.WALKING:
		_on_platform = true


func _is_scenario_settled() -> bool:
	return _on_platform and elapsed > 3.0


func _evaluate_scenario() -> void:
	if not _tool_accepted:
		fail("the diagonal ladder was refused")
	var wall_x := float(PLATFORM_FIRST_COLUMN * TILE)
	var reach := -INF
	# Only the steps before the wall: a staircase carried on along the top of
	# the platform must not hide a gap left at its foot.
	for brick in terrain.get_bricks():
		if brick.position.x < wall_x:
			reach = maxf(reach, brick.end.x)
	print("  last step before the wall ends at x=%.1f, wall at x=%.0f" % [reach, wall_x])
	if wall_x - reach > 0.5:
		fail("the staircase stops %.1fpx short of the wall, leaving a gap" % (wall_x - reach))
	if not _on_platform:
		fail("the lemming never walked onto the platform")
	if not deaths.is_empty():
		fail("deaths: %s" % deaths)
