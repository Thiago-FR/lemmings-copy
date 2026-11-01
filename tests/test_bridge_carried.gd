extends "res://tests/tool_scenario_test.gd"
## Automated check that the bridge is carried when there is no gap ahead.
## Run via:
##   godot --headless res://tests/test_bridge_carried.tscn
##
## Layout: a floor with a bottomless gap four blocks wide on the left and a
## wall on the right. The lemming walks right, towards the wall, with no gap
## ahead of it, and is given the bridge there. Reported as a bug: once a gap
## had been bridged, no other lemming could be given a bridge, because a
## lemming with no gap ahead refused it.
##
## Checked: the tool is taken and the lemming keeps walking with it (not
## bridging yet); it turns at the wall, and on the way back bridges the gap
## and walks across to the far side alive.

const FLOOR_TOP_ROW := 11
const GAP_FIRST_COLUMN := 4
const GAP_LAST_COLUMN := 7
const START_X := 400.0

var _lemming: LemmingController = null
var _tool_given := false
var _tool_accepted := false
var _carried_while_walking := false
var _turned := false
var _crossed := false


func _get_test_name() -> String:
	return "Carried bridge"


func _get_scenarios() -> Array:
	return [{"name": "given with only a wall ahead", "run_seconds": 40.0}]


func _build_scenario() -> void:
	_tool_given = false
	_tool_accepted = false
	_carried_while_walking = false
	_turned = false
	_crossed = false
	paint(0, GAP_FIRST_COLUMN - 1, FLOOR_TOP_ROW, FLOOR_TOP_ROW + 1)
	paint(GAP_LAST_COLUMN + 1, 24, FLOOR_TOP_ROW, FLOOR_TOP_ROW + 1)
	paint(-1, -1, -10, FLOOR_TOP_ROW + 1)
	paint(25, 25, -10, FLOOR_TOP_ROW + 1)
	_lemming = spawn_lemming(START_X, FLOOR_TOP_ROW, 1, "lemming")


func _scenario_frame(_delta: float) -> void:
	if not is_instance_valid(_lemming):
		return
	if not _tool_given and _lemming.state_machine.current_state == LemmingStateMachine.State.WALKING:
		_tool_given = true
		_tool_accepted = _lemming.assign_skill(SkillBridge.new())
		_carried_while_walking = _lemming.pending_wall_tool is SkillBridge \
			and _lemming.state_machine.current_state == LemmingStateMachine.State.WALKING
	if _lemming.direction < 0:
		_turned = true
	if _turned and _lemming.state_machine.current_state == LemmingStateMachine.State.WALKING \
			and _lemming.get_body_rect().end.x < GAP_FIRST_COLUMN * TILE:
		_crossed = true


func _is_scenario_settled() -> bool:
	return _crossed


func _evaluate_scenario() -> void:
	if not _tool_accepted:
		fail("the bridge was refused with no gap ahead")
		return
	if not _carried_while_walking:
		fail("the lemming did not carry the bridge on, walking")
	if not _turned:
		fail("the lemming never turned at the wall")
	if not _crossed:
		fail("the lemming never crossed the gap (%s)" % deaths.get("lemming", "alive"))
	if not deaths.is_empty():
		fail("deaths: %s" % deaths)
	var bricks := terrain.get_bricks()
	print("  bricks laid: %d" % bricks.size())
	if bricks.size() != GAP_LAST_COLUMN - GAP_FIRST_COLUMN + 1:
		fail("expected a bridge of %d pieces across the gap, found %d" % [GAP_LAST_COLUMN - GAP_FIRST_COLUMN + 1, bricks.size()])
