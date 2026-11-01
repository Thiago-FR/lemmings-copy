extends "res://tests/tool_scenario_test.gd"
## Automated check of the bomber (SkillBomber). Run via:
##   godot --headless res://tests/test_tool_bomber.tscn
##
## Layout: a pen two tiles wide, closed on the left by a thick block and on
## the right by a wall one tile thick and four tall; open floor beyond it.
## Two lemmings walk back and forth inside. One gets the bomber; the fuse is
## started at two different moments, so it goes off with the body at
## different spots in the pen (pressed against the thin wall, and further
## from it).
##
## Checked: the bomber dies in an explosion when the fuse runs out, not
## before; the thin wall is opened enough for a lemming to walk through; the
## floor under the blast is left whole (on this grid a crater is a pit one
## tile deep that nobody can walk out of); and the other lemming walks out
## of the pen to the far side.

const FLOOR_TOP_ROW := 11
const WALL_TOP_ROW := 7
const BLOCK_LAST_COLUMN := 9
const THIN_WALL_COLUMN := 12
const PEN_CENTRE_X := 352.0
const RUN_SECONDS := 16.0

var _bomber: LemmingController = null
var _walker: LemmingController = null
var _tool_accepted := false
var _tool_given_at := -1.0
var _exploded_at := -1.0
var _walker_reached_far_side := false


func _get_test_name() -> String:
	return "Bomber"


func _get_scenarios() -> Array:
	return [
		{"name": "fuse started early", "handover_seconds": 0.2, "run_seconds": RUN_SECONDS},
		{"name": "fuse started later", "handover_seconds": 0.9, "run_seconds": RUN_SECONDS},
		{"name": "fuse started later still", "handover_seconds": 1.4, "run_seconds": RUN_SECONDS},
	]


func _build_scenario() -> void:
	_tool_accepted = false
	_tool_given_at = -1.0
	_exploded_at = -1.0
	_walker_reached_far_side = false
	paint(0, 24, FLOOR_TOP_ROW, FLOOR_TOP_ROW + 1)
	paint(0, BLOCK_LAST_COLUMN, WALL_TOP_ROW, FLOOR_TOP_ROW - 1)
	paint(THIN_WALL_COLUMN, THIN_WALL_COLUMN, WALL_TOP_ROW, FLOOR_TOP_ROW - 1)
	paint(-1, -1, -10, FLOOR_TOP_ROW + 1)
	paint(25, 25, -10, FLOOR_TOP_ROW + 1)
	_bomber = spawn_lemming(PEN_CENTRE_X, FLOOR_TOP_ROW, 1, "bomber")
	_walker = spawn_lemming(PEN_CENTRE_X, FLOOR_TOP_ROW, -1, "walker")


func _scenario_frame(_delta: float) -> void:
	if _tool_given_at < 0.0 and elapsed >= scenario.handover_seconds:
		_tool_given_at = elapsed
		_tool_accepted = _bomber.assign_skill(SkillBomber.new())
	if _exploded_at < 0.0 and deaths.has("bomber"):
		_exploded_at = elapsed
	if is_instance_valid(_walker) and _walker.get_body_rect().position.x > (THIN_WALL_COLUMN + 1) * TILE:
		_walker_reached_far_side = true


func _is_scenario_settled() -> bool:
	return _walker_reached_far_side and _exploded_at >= 0.0


func _evaluate_scenario() -> void:
	if not _tool_accepted:
		fail("the bomber was refused")
		return
	if deaths.get("bomber", "") != "EXPLOSION":
		fail("the bomber did not die in an explosion (%s)" % deaths.get("bomber", "still alive"))
	else:
		var fuse := _exploded_at - _tool_given_at
		var expected_fuse := SkillBomber.new().fuse_seconds
		if absf(fuse - expected_fuse) > 0.1:
			fail("went off %.2fs after the fuse was lit, expected %.2fs" % [fuse, expected_fuse])
	_expect_wall_opened()
	for column in range(BLOCK_LAST_COLUMN, THIN_WALL_COLUMN + 2):
		for row in [FLOOR_TOP_ROW, FLOOR_TOP_ROW + 1]:
			if not is_cell_solid(column, row):
				fail("the floor cell (%d, %d) under the blast was destroyed" % [column, row])
	if not _walker_reached_far_side:
		fail("the other lemming never got out of the pen")
	if deaths.has("walker"):
		fail("the other lemming died (%s)" % deaths.walker)


## Opened enough to walk through: a body-sized box standing on the floor in
## the wall's column overlaps no terrain.
func _expect_wall_opened() -> void:
	var body_size := Vector2(Constants.MAX_BODY_WIDTH, 30.0)
	var box := Rect2(Vector2((THIN_WALL_COLUMN + 0.5) * TILE - body_size.x / 2.0, FLOOR_TOP_ROW * TILE - body_size.y), body_size)
	var blocking := terrain.get_solid_cells_in_rect(box.grow(-1.0))
	if not blocking.is_empty():
		fail("the thin wall is still closed: cells %s block the way" % [blocking])
