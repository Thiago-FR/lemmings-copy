extends "res://tests/tool_scenario_test.gd"
## Automated check of the rope (SkillRope). Run via:
##   godot --headless res://tests/test_tool_rope.tscn
##
## Layout: a high ledge on the left, eight blocks (256px) above the floor;
## lemmings start on it walking right. The first is given the rope while
## walking. Scenario 2: the ledge is only two blocks up, a safe drop.
##
## Checked, deadly drop: the rope is tied at the ledge's edge and reaches
## the floor; the carrier and every lemming behind it get down alive and
## walk on along the floor. Safe drop: the rope is not used there (the
## carrier still holds it) and nobody dies.

const FLOOR_TOP_ROW := 13
const LEDGE_LAST_COLUMN := 10
const FOLLOWER_COUNT := 3
const RUN_SECONDS := 40.0

var _lemmings: Array = []
var _tool_given := false
var _tool_accepted := false
var _on_floor := {}


func _get_test_name() -> String:
	return "Rope"


func _get_scenarios() -> Array:
	return [
		{"name": "deadly drop: everyone slides down", "ledge_row": FLOOR_TOP_ROW - 8, "deadly": true, "run_seconds": RUN_SECONDS},
		{"name": "deadly drop, body straddling two columns", "ledge_row": FLOOR_TOP_ROW - 6, "deadly": true, "start_offset": 16.0, "run_seconds": RUN_SECONDS},
		{"name": "safe drop: rope kept", "ledge_row": FLOOR_TOP_ROW - 2, "deadly": false, "run_seconds": 20.0},
	]


func _build_scenario() -> void:
	_tool_given = false
	_tool_accepted = false
	_on_floor = {}
	_lemmings = []
	var ledge_row: int = scenario.ledge_row
	paint(0, LEDGE_LAST_COLUMN, ledge_row, ledge_row + 1)
	paint(0, 30, FLOOR_TOP_ROW, FLOOR_TOP_ROW + 1)
	paint(-1, -1, -20, FLOOR_TOP_ROW + 1)
	paint(31, 31, -20, FLOOR_TOP_ROW + 1)
	var start_x: float = 120.0 + float(scenario.get("start_offset", 0.0))
	_lemmings.append(spawn_lemming(start_x, ledge_row, 1, "roper"))
	for index in FOLLOWER_COUNT:
		_lemmings.append(spawn_lemming(start_x - 30.0 * (index + 1), ledge_row, 1, "follower%d" % (index + 1)))


func _scenario_frame(_delta: float) -> void:
	var roper: Variant = _lemmings[0]
	if not _tool_given and is_instance_valid(roper) and roper.state_machine.current_state == LemmingStateMachine.State.WALKING:
		_tool_given = true
		_tool_accepted = roper.assign_skill(SkillRope.new())
	for lemming in _lemmings:
		if is_instance_valid(lemming) and lemming.state_machine.current_state == LemmingStateMachine.State.WALKING \
				and absf(lemming.get_body_rect().end.y - FLOOR_TOP_ROW * TILE) < 1.5 \
				and lemming.get_body_rect().position.x > (LEDGE_LAST_COLUMN + 2) * TILE:
			_on_floor[lemming.get_meta("label")] = true


func _is_scenario_settled() -> bool:
	return _on_floor.size() == _lemmings.size()


func _evaluate_scenario() -> void:
	if not _tool_accepted:
		fail("the rope was refused")
	for lemming in _lemmings:
		var label: String = lemming.get_meta("label") if is_instance_valid(lemming) else "?"
		if is_instance_valid(lemming) and not _on_floor.has(label):
			var body: Rect2 = lemming.get_body_rect()
			fail("%s never walked on along the floor (x=%.0f, feet y=%.0f, %s)" % [label, body.position.x, body.end.y,
				LemmingStateMachine.State.keys()[lemming.state_machine.current_state]])
	if not deaths.is_empty():
		fail("deaths: %s" % deaths)
	var roper: Variant = _lemmings[0]
	if scenario.deadly:
		var rope := terrain.rope_reachable_by(Rect2(Vector2((LEDGE_LAST_COLUMN + 1) * TILE - 4.0, scenario.ledge_row * TILE + Rope.GRIP_BELOW_TOP), Vector2(40, 10)))
		if rope == null:
			fail("no rope hangs at the ledge's edge")
		elif absf(rope.get_bottom().y - FLOOR_TOP_ROW * TILE) > 1.5:
			fail("the rope ends at y=%.0f, not on the floor (y=%d)" % [rope.get_bottom().y, FLOOR_TOP_ROW * TILE])
	elif is_instance_valid(roper) and not roper.pending_wall_tool is SkillRope:
		fail("the rope was used on a safe drop")
