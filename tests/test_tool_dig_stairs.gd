extends "res://tests/tool_scenario_test.gd"
## Automated check of the digging stairs (SkillDigStairs). Run via:
##   godot --headless res://tests/test_tool_dig_stairs.tscn
##
## Layout: a floor and, on it, a hill of earth six blocks tall and wide,
## too tall to climb, with a wall at its far end (its far side is a deadly
## drop: whoever is up first turns there instead of jumping off while the
## others are still on the stairs). The first lemming is handed the tool in
## the open and carries it to the hill. Scenario 3: the hill is concrete.
##
## Checked, earth: a staircase is dug up through the hill and every lemming
## walks up it onto the top; no step is taller than a lemming steps up;
## nobody dies. Concrete: the tool is not used (the lemming turns and still
## holds it) and nothing is dug.

const FLOOR_TOP_ROW := 13
const HILL_FIRST_COLUMN := 12
const HILL_LAST_COLUMN := 24
const HILL_TOP_ROW := 7
const FOLLOWER_COUNT := 3
const RUN_SECONDS := 80.0

var _lemmings: Array = []
var _tool_given := false
var _tool_accepted := false
var _on_top := {}


func _get_test_name() -> String:
	return "Digging stairs"


func _get_scenarios() -> Array:
	return [
		{"name": "earth hill, body inside one column", "start_x": 176.0, "concrete": false, "run_seconds": RUN_SECONDS},
		{"name": "earth hill, body straddling two columns", "start_x": 192.0, "concrete": false, "run_seconds": RUN_SECONDS},
		{"name": "concrete hill: not used", "start_x": 176.0, "concrete": true, "run_seconds": 15.0},
	]


func _build_scenario() -> void:
	_tool_given = false
	_tool_accepted = false
	_on_top = {}
	_lemmings = []
	paint(0, 30, FLOOR_TOP_ROW, FLOOR_TOP_ROW + 1)
	paint(-1, -1, -20, FLOOR_TOP_ROW + 1)
	paint(31, 31, -20, FLOOR_TOP_ROW + 1)
	# As in a real stage, the border does not break: a lemming turned back
	# by the concrete still holds the tool and would dig out of the stage.
	for row in range(-20, FLOOR_TOP_ROW + 2):
		terrain.unbreakable_cells[Vector2i(-1, row)] = true
		terrain.unbreakable_cells[Vector2i(31, row)] = true
	paint(HILL_LAST_COLUMN + 1, HILL_LAST_COLUMN + 1, -20, FLOOR_TOP_ROW)
	for row in range(-20, FLOOR_TOP_ROW):
		terrain.unbreakable_cells[Vector2i(HILL_LAST_COLUMN + 1, row)] = true
	for column in range(HILL_FIRST_COLUMN, HILL_LAST_COLUMN + 1):
		for row in range(HILL_TOP_ROW, FLOOR_TOP_ROW):
			var material := TerrainDestructible.TerrainMaterial.CONCRETE if scenario.concrete else TerrainDestructible.TerrainMaterial.EARTH
			terrain.set_cell(Vector2i(column, row), TerrainDestructible.TERRAIN_SOURCE_ID, Vector2i(0, material))
	_lemmings.append(spawn_lemming(scenario.start_x, FLOOR_TOP_ROW, 1, "digger"))
	for index in FOLLOWER_COUNT:
		_lemmings.append(spawn_lemming(scenario.start_x - 32.0 * (index + 1), FLOOR_TOP_ROW, 1, "follower%d" % (index + 1)))


func _scenario_frame(_delta: float) -> void:
	var digger: Variant = _lemmings[0]
	if not _tool_given and is_instance_valid(digger) and digger.state_machine.current_state == LemmingStateMachine.State.WALKING:
		_tool_given = true
		_tool_accepted = digger.assign_skill(SkillDigStairs.new())
	for lemming in _lemmings:
		if is_instance_valid(lemming) and lemming.state_machine.current_state == LemmingStateMachine.State.WALKING \
				and absf(lemming.get_body_rect().end.y - HILL_TOP_ROW * TILE) < 1.5 and terrain.is_solid_at(lemming.get_feet_position()):
			_on_top[lemming.get_meta("label")] = true


func _is_scenario_settled() -> bool:
	return not scenario.concrete and _on_top.size() == _lemmings.size()


func _evaluate_scenario() -> void:
	if not _tool_accepted:
		fail("the tool was refused")
	if not deaths.is_empty():
		fail("deaths: %s" % deaths)
	if scenario.concrete:
		for column in range(HILL_FIRST_COLUMN, HILL_LAST_COLUMN + 1):
			for row in range(HILL_TOP_ROW, FLOOR_TOP_ROW):
				if not is_cell_solid(column, row):
					fail("concrete cell (%d, %d) was dug" % [column, row])
		var digger: Variant = _lemmings[0]
		if is_instance_valid(digger) and not digger.pending_wall_tool is SkillDigStairs:
			fail("the digger no longer holds the tool after turning at concrete")
		return
	for lemming in _lemmings:
		var label: String = lemming.get_meta("label") if is_instance_valid(lemming) else "?"
		if is_instance_valid(lemming) and not _on_top.has(label):
			var body: Rect2 = lemming.get_body_rect()
			fail("%s never got onto the hill (x=%.0f, feet y=%.0f, %s)" % [label, body.position.x, body.end.y,
				LemmingStateMachine.State.keys()[lemming.state_machine.current_state]])
