extends "res://tests/tool_scenario_test.gd"
## Automated check of the block (SkillBlock). Run via:
##   godot --headless res://tests/test_tool_block.tscn
##
## Layout: a walled floor. A lemming walking right is given the block; a
## second one behind it walks the same way. Two starting positions: body
## inside one grid column, and straddling two (the block must never land on
## the body).
##
## Checked: exactly one block of earth appears, in the body's row, just in
## front of the lemming and not overlapping it; the lemming turns around at
## it, and so does the second lemming; nobody walks through it or dies. A
## lemming with a wall right in front refuses the tool.

const FLOOR_TOP_ROW := 11
const RUN_SECONDS := 12.0

var _builder: LemmingController = null
var _follower: LemmingController = null
var _tool_given := false
var _tool_accepted := false
var _block_cell := Vector2i(-100, -100)
var _turned := {}
var _passed := []
var _refused_at_wall := false


func _get_test_name() -> String:
	return "Block"


func _get_scenarios() -> Array:
	return [
		{"name": "body inside one column", "start_x": 400.0, "run_seconds": RUN_SECONDS},
		{"name": "body straddling two columns", "start_x": 416.0, "run_seconds": RUN_SECONDS},
	]


func _build_scenario() -> void:
	_tool_given = false
	_tool_accepted = false
	_block_cell = Vector2i(-100, -100)
	_turned = {}
	_passed = []
	_refused_at_wall = false
	paint(0, 24, FLOOR_TOP_ROW, FLOOR_TOP_ROW + 1)
	paint(-1, -1, -10, FLOOR_TOP_ROW + 1)
	paint(25, 25, -10, FLOOR_TOP_ROW + 1)
	_builder = spawn_lemming(scenario.start_x, FLOOR_TOP_ROW, 1, "builder")
	_follower = spawn_lemming(scenario.start_x - 96.0, FLOOR_TOP_ROW, 1, "follower")


func _scenario_frame(_delta: float) -> void:
	if not _tool_given and _builder.state_machine.current_state == LemmingStateMachine.State.WALKING:
		_tool_given = true
		var cells_before := terrain.get_used_cells().size()
		_tool_accepted = _builder.assign_skill(SkillBlock.new())
		for cell in terrain.get_used_cells():
			if cell.y == FLOOR_TOP_ROW - 1:
				_block_cell = cell
		if terrain.get_used_cells().size() != cells_before + 1:
			fail("expected exactly one new block, got %d" % (terrain.get_used_cells().size() - cells_before))
		if terrain.cell_rect_at(terrain.to_global(terrain.map_to_local(_block_cell))).intersects(_builder.get_body_rect().grow(-0.5)):
			fail("the block was put down overlapping the lemming")
	for lemming in [_builder, _follower]:
		if not is_instance_valid(lemming):
			continue
		var label: String = lemming.get_meta("label")
		if lemming.direction < 0:
			_turned[label] = true
		if _block_cell.x > -100 and lemming.get_body_rect().end.x > _block_cell.x * TILE + 1.0:
			if not _passed.has(label):
				_passed.append(label)


func _is_scenario_settled() -> bool:
	return _turned.size() == 2 and elapsed > 6.0


func _evaluate_scenario() -> void:
	if not _tool_accepted:
		fail("the block was refused in the open")
		return
	print("  block at %s" % _block_cell)
	if _block_cell.x < 0:
		fail("no block was put down in the body's row")
	for label in ["builder", "follower"]:
		if not _turned.has(label):
			fail("%s never turned around at the block" % label)
	if not _passed.is_empty():
		fail("walked through the block: %s" % ", ".join(_passed))
	if not deaths.is_empty():
		fail("deaths: %s" % deaths)
	# A lemming facing the boundary wall right in front refuses a block.
	_builder.global_position.x = 25 * TILE - _builder.get_half_extents().x - 1.0
	if _builder.direction < 0:
		_builder.turn_around()
	if _builder.state_machine.current_state == LemmingStateMachine.State.WALKING and _builder.assign_skill(SkillBlock.new()):
		fail("a lemming with a wall right in front was given a block")
