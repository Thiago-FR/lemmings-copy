extends "res://tests/tool_scenario_test.gd"
## Automated check of the parachute (SkillFloater). Run via:
##   godot --headless res://tests/test_tool_floater.tscn
##
## Layout: a ledge high above a floor, a drop of eight tiles (256px), far
## beyond Constants.MAX_SAFE_FALL_HEIGHT.
##
## Checked: a lemming given the parachute while walking opens it when it
## walks off the ledge, comes down no faster than Constants.FLOAT_FALL_SPEED
## and lands walking; one given the parachute already falling opens it right
## away and survives too; and without it the same drop kills (so a level
## built on this drop really needs the tool).

const LEDGE_TOP_ROW := 3
const LEDGE_LAST_COLUMN := 7
const FLOOR_TOP_ROW := 11
## Fallen this far before the parachute is handed over in the mid-fall case.
const MID_FALL_HANDOVER_DISTANCE := 40.0
## Small margin over the float speed for the frame it opens in.
const FLOAT_SPEED_TOLERANCE := 1.0

var _lemming: LemmingController = null
var _tool_given := false
var _tool_accepted := false
var _was_floating := false
var _fastest_float_speed := 0.0
var _fall_start_y := 0.0


func _get_test_name() -> String:
	return "Floater"


func _get_scenarios() -> Array:
	return [
		{"name": "given while walking, opens on walking off the ledge", "handover": "walking", "start_x": 112.0, "run_seconds": 20.0},
		{"name": "given mid-fall, opens right away", "handover": "falling", "start_x": 232.0, "run_seconds": 20.0},
		{"name": "without it, the same drop kills", "handover": "none", "start_x": 232.0, "run_seconds": 6.0},
	]


func _build_scenario() -> void:
	_tool_given = false
	_tool_accepted = false
	_was_floating = false
	_fastest_float_speed = 0.0
	paint(0, LEDGE_LAST_COLUMN, LEDGE_TOP_ROW, LEDGE_TOP_ROW + 1)
	paint(0, 24, FLOOR_TOP_ROW, FLOOR_TOP_ROW + 1)
	paint(-1, -1, -10, FLOOR_TOP_ROW + 1)
	paint(25, 25, -10, FLOOR_TOP_ROW + 1)
	_lemming = spawn_lemming(scenario.start_x, LEDGE_TOP_ROW, 1, "floater")


func _scenario_frame(_delta: float) -> void:
	if not is_instance_valid(_lemming) or not _lemming.state_machine.is_alive():
		return
	var state := _lemming.state_machine.current_state
	if state == LemmingStateMachine.State.WALKING and _lemming.get_body_rect().end.y <= LEDGE_TOP_ROW * TILE + 1:
		_fall_start_y = _lemming.global_position.y
	if not _tool_given:
		_try_hand_over(state)
	if state == LemmingStateMachine.State.FLOATING:
		_was_floating = true
		_fastest_float_speed = maxf(_fastest_float_speed, _lemming.velocity.y)


func _try_hand_over(state: LemmingStateMachine.State) -> void:
	match scenario.handover:
		"walking":
			if state != LemmingStateMachine.State.WALKING:
				return
		"falling":
			if state != LemmingStateMachine.State.FALLING or _lemming.global_position.y - _fall_start_y < MID_FALL_HANDOVER_DISTANCE:
				return
		_:
			return
	_tool_given = true
	_tool_accepted = _lemming.assign_skill(SkillFloater.new())


func _is_scenario_settled() -> bool:
	if deaths.has("floater"):
		return true
	return _was_floating and _lemming.state_machine.current_state == LemmingStateMachine.State.WALKING and elapsed > 1.0


func _evaluate_scenario() -> void:
	if scenario.handover == "none":
		if deaths.get("floater", "") != "FALL":
			fail("without the parachute the lemming should die from the fall, got %s" % deaths.get("floater", "no death"))
		return

	if not _tool_accepted:
		fail("the parachute was refused")
	if not _was_floating:
		fail("the lemming never opened the parachute")
	if _fastest_float_speed > Constants.FLOAT_FALL_SPEED + FLOAT_SPEED_TOLERANCE:
		fail("came down at %.0f px/s, faster than the float speed %.0f" % [_fastest_float_speed, Constants.FLOAT_FALL_SPEED])
	expect_walking_on_row(_lemming, FLOOR_TOP_ROW, "floater")
