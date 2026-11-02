extends "res://tests/tool_scenario_test.gd"
## Automated check that a lemming does not step up across a gap. Run via:
##   godot --headless res://tests/test_step_over_gap.tscn
##
## Layout: a floor, a diagonal staircase of bricks rising to the right, and
## a platform a little higher than its top step, with a gap between the
## last step and the platform. Reported as a bug (prints/bug4.png): standing
## at the end of the last step, the lemming's back was still on it while
## its front, over the gap, already met the platform's wall; that wall was
## lower than a step's limit, so it was taken as a step and the lemming
## crossed the gap onto the platform.
##
## Checked, without anyone dying:
##   - a gap of a whole block (the body fits in it) is a hole: the lemming
##     never ends up on the platform, it drops into the gap;
##   - a crack a few pixels wide (prints/bug5.png) is stepped over: the
##     lemming climbs onto the platform;
##   - a gap wider than a crack but too narrow to fall into (prints/bug7.png)
##     is a wall: the lemming does not cross it.

const FLOOR_TOP_ROW := 11
const PLATFORM_FIRST_COLUMN := 16
const PLATFORM_TOP_ROW := 9
const STEP_COUNT := 6
const STEP_WIDTH := 32.0
const STEP_HEIGHT := 8.0
const START_X := 120.0

var _lemming: LemmingController = null
var _reached_platform := false


func _get_test_name() -> String:
	return "Step over gap"


func _get_scenarios() -> Array:
	return [
		{"name": "gap of one block: falls in", "gap": 32.0, "crosses": false, "run_seconds": 16.0},
		{"name": "crack of a few pixels: steps over", "gap": 6.0, "crosses": true, "run_seconds": 16.0},
		{"name": "gap a little narrower than the body: turns back", "gap": 22.0, "crosses": false, "run_seconds": 16.0},
	]


func _build_scenario() -> void:
	_reached_platform = false
	paint(0, 24, FLOOR_TOP_ROW, FLOOR_TOP_ROW + 1)
	paint(PLATFORM_FIRST_COLUMN, 24, PLATFORM_TOP_ROW, FLOOR_TOP_ROW - 1)
	paint(-1, -1, -10, FLOOR_TOP_ROW + 1)
	paint(25, 25, -10, FLOOR_TOP_ROW + 1)
	# The staircase ends `gap` pixels before the platform; its top step is
	# 16px below the platform's top, well under a step's limit.
	var floor_y := float(FLOOR_TOP_ROW * TILE)
	var stairs_end := PLATFORM_FIRST_COLUMN * TILE - float(scenario.gap)
	var stairs_start := stairs_end - STEP_COUNT * STEP_WIDTH
	for step in STEP_COUNT:
		terrain.place_brick(Rect2(stairs_start + STEP_WIDTH * step, floor_y - STEP_HEIGHT * (step + 1), STEP_WIDTH, STEP_HEIGHT))
	_lemming = spawn_lemming(START_X, FLOOR_TOP_ROW, 1, "lemming")


func _scenario_frame(_delta: float) -> void:
	if not is_instance_valid(_lemming):
		return
	var body := _lemming.get_body_rect()
	if body.position.x >= PLATFORM_FIRST_COLUMN * TILE - 1.0 and absf(body.end.y - PLATFORM_TOP_ROW * TILE) < 2.0:
		_reached_platform = true


func _evaluate_scenario() -> void:
	if _reached_platform and not scenario.crosses:
		fail("the lemming crossed the gap onto the platform")
	if not _reached_platform and scenario.crosses:
		fail("the lemming did not step over the crack onto the platform")
	if not deaths.is_empty():
		fail("deaths: %s" % deaths)
