extends "res://tests/tool_scenario_test.gd"
## Automated check of the climber (SkillClimber). Run via:
##   godot --headless res://tests/test_tool_climber.tscn
##
## Layout: a floor and a platform five tiles (160px) tall, far too tall to
## step onto. The climber is handed over in the open; the lemming must climb
## the platform's wall when it reaches it and end up walking on top. Two
## starting positions: body inside one grid column, and straddling two.
## A lemming without the tool walking alongside must turn around at the
## wall instead (so the wall really needs the tool).

const FLOOR_TOP_ROW := 11
const PLATFORM_FIRST_COLUMN := 15
const PLATFORM_TOP_ROW := 6
const CLIMBER_LABEL := "climber"
const WALKER_LABEL := "walker"

var _climber: LemmingController = null
var _walker: LemmingController = null
var _tool_given := false
var _tool_accepted := false
var _walker_turned_at_wall := false
var _arrived_seconds := -1.0


func _get_test_name() -> String:
	return "Climber"


func _get_scenarios() -> Array:
	return [
		{"name": "body inside one column", "start_x": 112.0, "run_seconds": 40.0},
		{"name": "body straddling two columns", "start_x": 128.0, "run_seconds": 40.0},
	]


func _build_scenario() -> void:
	_tool_given = false
	_tool_accepted = false
	_walker_turned_at_wall = false
	_arrived_seconds = -1.0
	paint(0, 24, FLOOR_TOP_ROW, FLOOR_TOP_ROW + 1)
	paint(PLATFORM_FIRST_COLUMN, 24, PLATFORM_TOP_ROW, FLOOR_TOP_ROW - 1)
	paint(-1, -1, -10, FLOOR_TOP_ROW + 1)
	paint(25, 25, -10, FLOOR_TOP_ROW + 1)
	_climber = spawn_lemming(scenario.start_x, FLOOR_TOP_ROW, 1, CLIMBER_LABEL)
	_walker = spawn_lemming(scenario.start_x + 64.0, FLOOR_TOP_ROW, 1, WALKER_LABEL)


func _scenario_frame(_delta: float) -> void:
	if not _tool_given and _climber.state_machine.current_state == LemmingStateMachine.State.WALKING:
		_tool_given = true
		_tool_accepted = _climber.assign_skill(SkillClimber.new())
	if _walker.direction < 0 and _walker.get_body_rect().end.x > PLATFORM_FIRST_COLUMN * TILE - 4.0:
		_walker_turned_at_wall = true
	if _arrived_seconds < 0.0 and _is_walking_on_platform(_climber):
		_arrived_seconds = elapsed


func _is_walking_on_platform(lemming: Variant) -> bool:
	return is_instance_valid(lemming) and lemming.state_machine.current_state == LemmingStateMachine.State.WALKING \
		and absf(lemming.get_body_rect().end.y - PLATFORM_TOP_ROW * TILE) <= 1.5


## Stops a second after arrival: a climber walking on would climb the
## boundary wall next.
func _is_scenario_settled() -> bool:
	return _arrived_seconds >= 0.0 and elapsed - _arrived_seconds > 1.0


func _evaluate_scenario() -> void:
	if not _tool_accepted:
		fail("the climber was refused")
	expect_walking_on_row(_climber, PLATFORM_TOP_ROW, CLIMBER_LABEL)
	if _climber.get_body_rect().position.x < PLATFORM_FIRST_COLUMN * TILE:
		fail("the climber is not over the platform (body starts at x=%.0f)" % _climber.get_body_rect().position.x)
	if not _walker_turned_at_wall:
		fail("the lemming without the tool did not turn around at the wall")
	if not deaths.is_empty():
		fail("deaths: %s" % deaths)
