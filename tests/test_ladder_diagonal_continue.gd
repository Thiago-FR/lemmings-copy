extends "res://tests/tool_scenario_test.gd"
## Automated check that a diagonal ladder can be extended. Run via:
##   godot --headless res://tests/test_ladder_diagonal_continue.tscn
##
## Layout: a long open floor. The first lemming builds a full staircase
## (max_pieces steps). A second lemming walking up it is given another
## diagonal ladder half-way up. Reported as a bug: nothing happened, the
## charge was spent, and the staircase could never be made longer, because
## the tool started on the spot and found the next step already there.
##
## Checked: the second lemming takes the tool while on the staircase and
## carries it (it does not stop to build mid-stairs); at the top step it
## carries on building, so the staircase ends up twice as long, every new
## step one step higher than the one before; the second lemming survives
## (the first walks off the top of its own staircase before it is extended,
## a fatal drop, which is not what this checks).

const FLOOR_TOP_ROW := 13
const FIRST_START_X := 64.0
const SECOND_START_X := 40.0
const RUN_SECONDS := 40.0

var _first: LemmingController = null
var _second: LemmingController = null
var _first_given := false
var _second_given := false
var _second_accepted := false
var _carried_mid_stairs := false


func _get_test_name() -> String:
	return "Diagonal ladder extended"


func _get_scenarios() -> Array:
	return [{"name": "second ladder given half-way up", "run_seconds": RUN_SECONDS}]


func _build_scenario() -> void:
	_first_given = false
	_second_given = false
	_second_accepted = false
	_carried_mid_stairs = false
	_second = null
	paint(0, 40, FLOOR_TOP_ROW, FLOOR_TOP_ROW + 1)
	paint(-1, -1, -30, FLOOR_TOP_ROW + 1)
	_first = spawn_lemming(FIRST_START_X, FLOOR_TOP_ROW, 1, "first")


func _scenario_frame(_delta: float) -> void:
	if not _first_given and _first.state_machine.current_state == LemmingStateMachine.State.WALKING:
		_first_given = true
		_first.assign_skill(SkillBuilder.new())
	var first_done := _first_given and terrain.get_bricks().size() >= SkillBuilder.new().max_pieces
	if _second == null and first_done:
		_second = spawn_lemming(SECOND_START_X, FLOOR_TOP_ROW, 1, "second")
	if _second == null or not is_instance_valid(_second) or _second_given:
		return
	# Half-way up: feet at least four steps above the floor.
	var feet_y := _second.get_body_rect().end.y
	if _second.state_machine.current_state == LemmingStateMachine.State.WALKING and feet_y <= FLOOR_TOP_ROW * TILE - 32.0:
		_second_given = true
		_second_accepted = _second.assign_skill(SkillBuilder.new())
		_carried_mid_stairs = _second.pending_wall_tool is SkillBuilder \
			and _second.state_machine.current_state == LemmingStateMachine.State.WALKING


func _is_scenario_settled() -> bool:
	return terrain.get_bricks().size() >= SkillBuilder.new().max_pieces * 2 and _second.state_machine.current_state == LemmingStateMachine.State.WALKING


func _evaluate_scenario() -> void:
	var max_pieces := SkillBuilder.new().max_pieces
	if not _second_given:
		fail("the second lemming never got half-way up the staircase")
		return
	if not _second_accepted:
		fail("a lemming on the staircase refused the diagonal ladder")
	if not _carried_mid_stairs:
		fail("the lemming did not carry the ladder on, walking, while on the staircase")
	var bricks := terrain.get_bricks()
	print("  bricks: %d (expected %d)" % [bricks.size(), max_pieces * 2])
	if bricks.size() != max_pieces * 2:
		fail("the staircase has %d steps, expected %d after extending it" % [bricks.size(), max_pieces * 2])
	bricks.sort_custom(func(a: Rect2, b: Rect2) -> bool: return a.position.x < b.position.x)
	for index in range(1, bricks.size()):
		# Side by side, not stacked: the extension used to lay its first brick
		# on top of the last step, half-way along it (prints/bug6.png).
		if bricks[index].position.x < bricks[index - 1].end.x - 0.5:
			fail("step %d overlaps step %d instead of following it (x %.1f < %.1f)" % [index, index - 1, bricks[index].position.x, bricks[index - 1].end.x])
			break
		var rise := bricks[index - 1].position.y - bricks[index].position.y
		if absf(rise - bricks[index].size.y) > 0.5:
			fail("step %d is %.1fpx above the one before, expected one step (%.0fpx)" % [index, rise, bricks[index].size.y])
			break
	if deaths.has("second"):
		fail("the second lemming died (%s)" % deaths["second"])
