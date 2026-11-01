extends "res://tests/tool_scenario_test.gd"
## Automated check of the blocker (SkillBlocker). Run via:
##   godot --headless res://tests/test_tool_blocker.tscn
##
## Layout: a flat walled floor. One lemming is made a blocker in the middle;
## two others walk towards it, one from each side. Two blocker positions:
## body inside one grid column, and straddling two.
##
## Checked: the blocker stays put and keeps blocking; each walker turns
## around on reaching it and never gets past it, coming back again after
## bouncing off the far wall; nobody dies.

const FLOOR_TOP_ROW := 11
## How far a walker's body may overlap the blocker's before it counts as
## having walked through (the blocker zone is a little wider than the body).
const PASS_THROUGH_TOLERANCE := 4.0
## Long enough for each walker to reach the blocker, bounce off the outer
## wall and reach it a second time.
const RUN_SECONDS := 24.0

var _blocker: LemmingController = null
var _walkers: Array[LemmingController] = []
var _blocker_start_x := 0.0
var _tool_accepted := false
var _tool_given := false
## Per walker label, how many times it turned around right at the blocker.
var _turns_at_blocker := {}
var _passed_through: Array[String] = []


func _get_test_name() -> String:
	return "Blocker"


func _get_scenarios() -> Array:
	return [
		{"name": "blocker inside one column", "blocker_x": 400.0, "run_seconds": RUN_SECONDS},
		{"name": "blocker straddling two columns", "blocker_x": 416.0, "run_seconds": RUN_SECONDS},
	]


func _build_scenario() -> void:
	_tool_accepted = false
	_tool_given = false
	_turns_at_blocker = {"from the left": 0, "from the right": 0}
	_passed_through = []
	paint(0, 24, FLOOR_TOP_ROW, FLOOR_TOP_ROW + 1)
	paint(-1, -1, -10, FLOOR_TOP_ROW + 1)
	paint(25, 25, -10, FLOOR_TOP_ROW + 1)
	_blocker = spawn_lemming(scenario.blocker_x, FLOOR_TOP_ROW, 1, "blocker")
	_walkers = [
		spawn_lemming(144.0, FLOOR_TOP_ROW, 1, "from the left"),
		spawn_lemming(656.0, FLOOR_TOP_ROW, -1, "from the right"),
	]
	for walker in _walkers:
		walker.set_meta("last_direction", walker.direction)


func _scenario_frame(_delta: float) -> void:
	if not _tool_given and _blocker.state_machine.current_state == LemmingStateMachine.State.WALKING:
		_tool_given = true
		_tool_accepted = _blocker.assign_skill(SkillBlocker.new())
		_blocker_start_x = _blocker.get_body_rect().get_center().x
	if not _tool_given:
		return
	var blocker_body := _blocker.get_body_rect()
	for walker in _walkers:
		_track_walker(walker, blocker_body)


func _track_walker(walker: LemmingController, blocker_body: Rect2) -> void:
	var label: String = walker.get_meta("label")
	var body := walker.get_body_rect()
	var from_left := label == "from the left"
	if from_left and body.end.x > blocker_body.position.x + PASS_THROUGH_TOLERANCE:
		_note_passed_through(label)
	if not from_left and body.position.x < blocker_body.end.x - PASS_THROUGH_TOLERANCE:
		_note_passed_through(label)

	var last_direction: int = walker.get_meta("last_direction")
	if walker.direction != last_direction and absf(body.get_center().x - blocker_body.get_center().x) < blocker_body.size.x * 1.5:
		_turns_at_blocker[label] += 1
	walker.set_meta("last_direction", walker.direction)


func _note_passed_through(label: String) -> void:
	if not _passed_through.has(label):
		_passed_through.append(label)


func _evaluate_scenario() -> void:
	if not _tool_accepted:
		fail("the blocker was refused")
	if _blocker.state_machine.current_state != LemmingStateMachine.State.BLOCKING:
		fail("the blocker ended in state %s" % LemmingStateMachine.State.keys()[_blocker.state_machine.current_state])
	var drift := absf(_blocker.get_body_rect().get_center().x - _blocker_start_x)
	if drift > 1.0:
		fail("the blocker moved %.1fpx" % drift)
	for label in _turns_at_blocker:
		if _turns_at_blocker[label] < 2:
			fail("walker %s turned at the blocker %d times, expected at least 2" % [label, _turns_at_blocker[label]])
	if not _passed_through.is_empty():
		fail("walked through the blocker: %s" % ", ".join(_passed_through))
	if not deaths.is_empty():
		fail("deaths: %s" % deaths)
