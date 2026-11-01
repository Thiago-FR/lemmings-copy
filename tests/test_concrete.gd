extends "res://tests/tool_scenario_test.gd"
## Automated check of the concrete terrain. Run via:
##   godot --headless res://tests/test_concrete.tscn
##
## Concrete is the second terrain material: the shovel and the pickaxe do
## not get through it, the jackhammer does. One scenario per tool:
##   - shovel: digging down through a row of earth stops on the concrete
##     under it; the lemming walks on, the concrete untouched;
##   - pickaxe: at a concrete wall the lemming turns around as at any wall
##     and keeps carrying the pickaxe; the wall untouched;
##   - jackhammer: digs a tunnel through the same concrete wall and comes
##     out the other side.

const FLOOR_TOP_ROW := 11
const WALL_FIRST_COLUMN := 14
const WALL_LAST_COLUMN := 15
const WALL_TOP_ROW := 7
const START_X := 112.0

var _lemming: LemmingController = null
var _tool_given := false
var _tool_accepted := false
var _turned := false
var _through := false


func _get_test_name() -> String:
	return "Concrete"


func _get_scenarios() -> Array:
	return [
		{"name": "shovel stops on concrete", "tool": "digger", "run_seconds": 8.0},
		{"name": "pickaxe turns at a concrete wall", "tool": "miner", "run_seconds": 10.0},
		{"name": "jackhammer digs through a concrete wall", "tool": "basher", "run_seconds": 20.0},
	]


func _build_scenario() -> void:
	_tool_given = false
	_tool_accepted = false
	_turned = false
	_through = false
	paint(-1, -1, -10, FLOOR_TOP_ROW + 2)
	paint(25, 25, -10, FLOOR_TOP_ROW + 2)
	if scenario.tool == "digger":
		# Earth on top, concrete under it.
		paint(0, 24, FLOOR_TOP_ROW, FLOOR_TOP_ROW)
		_paint_concrete(0, 24, FLOOR_TOP_ROW + 1, FLOOR_TOP_ROW + 1)
	else:
		paint(0, 24, FLOOR_TOP_ROW, FLOOR_TOP_ROW + 1)
		_paint_concrete(WALL_FIRST_COLUMN, WALL_LAST_COLUMN, WALL_TOP_ROW, FLOOR_TOP_ROW - 1)
	_lemming = spawn_lemming(START_X, FLOOR_TOP_ROW, 1, "lemming")


func _paint_concrete(from_column: int, to_column: int, from_row: int, to_row: int) -> void:
	for column in range(from_column, to_column + 1):
		for row in range(from_row, to_row + 1):
			terrain.build_cell_at(terrain.to_global(terrain.map_to_local(Vector2i(column, row))), TerrainDestructible.TerrainMaterial.CONCRETE)


func _make_tool() -> SkillBase:
	match scenario.tool:
		"digger":
			return SkillDigger.new()
		"miner":
			return SkillMiner.new()
	return SkillBasher.new()


func _scenario_frame(_delta: float) -> void:
	if not is_instance_valid(_lemming):
		return
	if not _tool_given and _lemming.state_machine.current_state == LemmingStateMachine.State.WALKING:
		_tool_given = true
		_tool_accepted = _lemming.assign_skill(_make_tool())
	if _lemming.direction < 0:
		_turned = true
	if _lemming.get_body_rect().position.x > (WALL_LAST_COLUMN + 1) * TILE:
		_through = true


func _is_scenario_settled() -> bool:
	if scenario.tool == "basher":
		return _through
	if scenario.tool == "miner":
		return _turned and elapsed > 6.0
	return elapsed > 6.0


func _evaluate_scenario() -> void:
	if not _tool_accepted:
		fail("the tool was refused")
	if not deaths.is_empty():
		fail("deaths: %s" % deaths)
		return
	match scenario.tool:
		"digger":
			for column in range(0, 25):
				if not is_cell_solid(column, FLOOR_TOP_ROW + 1):
					fail("concrete cell (%d, %d) was dug by the shovel" % [column, FLOOR_TOP_ROW + 1])
			expect_walking_on_row(_lemming, FLOOR_TOP_ROW + 1, "lemming")
		"miner":
			_expect_wall_whole()
			if not _turned:
				fail("the lemming did not turn around at the concrete wall")
			if _lemming.pending_wall_tool == null:
				fail("the lemming no longer carries the pickaxe after turning")
		"basher":
			if not _through:
				fail("the jackhammer did not get through the concrete wall")
			for column in range(WALL_FIRST_COLUMN, WALL_LAST_COLUMN + 1):
				if is_cell_solid(column, FLOOR_TOP_ROW - 1):
					fail("tunnel cell (%d, %d) is still there" % [column, FLOOR_TOP_ROW - 1])


func _expect_wall_whole() -> void:
	for column in range(WALL_FIRST_COLUMN, WALL_LAST_COLUMN + 1):
		for row in range(WALL_TOP_ROW, FLOOR_TOP_ROW):
			if not is_cell_solid(column, row) or terrain.get_cell_atlas_coords(Vector2i(column, row)).x != 0:
				fail("concrete cell (%d, %d) was dug by the pickaxe" % [column, row])
