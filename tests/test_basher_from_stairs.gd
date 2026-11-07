extends "res://tests/tool_scenario_test.gd"
## Automated check of the jackhammer used from a diagonal ladder's step
## (prints/bug21.png). Run via:
##   godot --headless res://tests/test_basher_from_stairs.tscn
##
## A staircase ends against a tall wall with its top step part way up a
## block, so the lemmings on it stand off the terrain grid. One of them is
## given the jackhammer on the way up.
##
## Checked: the tunnel goes all the way through the wall; the basher and the
## lemmings behind it come out the other side walking; nobody dies.

const FLOOR_TOP_ROW := 13
const WALL_FIRST_COLUMN := 20
const WALL_LAST_COLUMN := 23
const WALL_TOP_ROW := 4
const STEP_WIDTH := 32.0
const STEP_HEIGHT := 8.0
const FOLLOWER_COUNT := 3
## Followers that reach the tunnel before it is through turn back, walk to
## the far boundary and return.
const RUN_SECONDS := 120.0

var _lemmings: Array = []
var _tool_given := false
var _tool_accepted := false
var _through := {}


func _get_test_name() -> String:
	return "Basher from a staircase"


func _get_scenarios() -> Array:
	var scenarios := []
	for steps in [2, 3, 4, 5, 6]:
		scenarios.append({"name": "top step %d px up" % int(steps * STEP_HEIGHT), "steps": steps, "run_seconds": RUN_SECONDS})
	return scenarios


func _build_scenario() -> void:
	_tool_given = false
	_tool_accepted = false
	_through = {}
	_lemmings = []
	paint(0, 34, FLOOR_TOP_ROW, FLOOR_TOP_ROW + 1)
	paint(-1, -1, -10, FLOOR_TOP_ROW + 1)
	paint(35, 35, -10, FLOOR_TOP_ROW + 1)
	paint(WALL_FIRST_COLUMN, WALL_LAST_COLUMN, WALL_TOP_ROW, FLOOR_TOP_ROW - 1)
	var floor_y := float(FLOOR_TOP_ROW * TILE)
	var wall_x := float(WALL_FIRST_COLUMN * TILE)
	var steps: int = scenario.steps
	for step in steps:
		terrain.place_brick(Rect2(wall_x - (steps - step) * STEP_WIDTH, floor_y - STEP_HEIGHT * (step + 1), STEP_WIDTH, STEP_HEIGHT))
	var first_x := wall_x - steps * STEP_WIDTH - 60.0
	_lemmings.append(spawn_lemming(first_x, FLOOR_TOP_ROW, 1, "basher"))
	for index in FOLLOWER_COUNT:
		_lemmings.append(spawn_lemming(first_x - 40.0 * (index + 1), FLOOR_TOP_ROW, 1, "follower%d" % (index + 1)))


func _scenario_frame(_delta: float) -> void:
	var basher: Variant = _lemmings[0]
	if not _tool_given and is_instance_valid(basher) and basher.state_machine.current_state == LemmingStateMachine.State.WALKING \
			and basher.get_body_rect().end.y <= FLOOR_TOP_ROW * TILE - STEP_HEIGHT:
		_tool_given = true
		_tool_accepted = basher.assign_skill(SkillBasher.new())
	for lemming in _lemmings:
		if is_instance_valid(lemming) and lemming.state_machine.current_state == LemmingStateMachine.State.WALKING \
				and lemming.get_body_rect().position.x > (WALL_LAST_COLUMN + 1) * TILE:
			_through[lemming.get_meta("label")] = true


func _is_scenario_settled() -> bool:
	return _through.size() == _lemmings.size()


func _evaluate_scenario() -> void:
	if not _tool_accepted:
		fail("the basher was refused")
	for lemming in _lemmings:
		var label: String = lemming.get_meta("label") if is_instance_valid(lemming) else "?"
		if is_instance_valid(lemming) and not _through.has(label):
			var body: Rect2 = lemming.get_body_rect()
			fail("%s never came out the other side (left at x=%.0f, feet y=%.0f, %s)" % [label, body.position.x, body.end.y,
				LemmingStateMachine.State.keys()[lemming.state_machine.current_state]])
	if not deaths.is_empty():
		fail("deaths: %s" % deaths)
