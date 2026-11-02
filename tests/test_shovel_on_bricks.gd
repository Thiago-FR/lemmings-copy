extends "res://tests/tool_scenario_test.gd"
## Automated check that the shovel digs through bricks. Run via:
##   godot --headless res://tests/test_shovel_on_bricks.tscn
##
## Layout: a thick earth floor on concrete, with a row of bricks (bridge
## pieces) lying on it. A lemming walking on the bricks is given the shovel. It used to find
## no earth under its feet, stop at once and waste the charge.
##
## Checked: the shovel is taken; the brick under the lemming goes; the
## lemming keeps digging down into the earth below (ends up below the
## floor's surface); nobody dies.

const FLOOR_TOP_ROW := 9
const FLOOR_BOTTOM_ROW := 13
const BRICK_HEIGHT := 8.0
const START_X := 200.0
const GIVE_AT_X := 300.0

var _lemming: LemmingController = null
var _tool_given := false
var _tool_accepted := false
var _bricks_before := 0


func _get_test_name() -> String:
	return "Shovel on bricks"


func _get_scenarios() -> Array:
	return [{"name": "standing on a bridge piece", "run_seconds": 12.0}]


func _build_scenario() -> void:
	_tool_given = false
	_tool_accepted = false
	paint(0, 24, FLOOR_TOP_ROW, FLOOR_BOTTOM_ROW - 1)
	# Concrete at the bottom, where the shovel stops instead of digging out
	# of the level.
	for column in range(0, 25):
		terrain.build_cell_at(terrain.to_global(terrain.map_to_local(Vector2i(column, FLOOR_BOTTOM_ROW))), TerrainDestructible.TerrainMaterial.CONCRETE)
	paint(-1, -1, -10, FLOOR_BOTTOM_ROW)
	paint(25, 25, -10, FLOOR_BOTTOM_ROW)
	var floor_y := float(FLOOR_TOP_ROW * TILE)
	for column in range(4, 20):
		terrain.place_brick(Rect2(column * TILE, floor_y - BRICK_HEIGHT, TILE, BRICK_HEIGHT))
	_bricks_before = terrain.get_bricks().size()
	_lemming = spawn_lemming(START_X, FLOOR_TOP_ROW, 1, "lemming")
	_lemming.global_position.y -= BRICK_HEIGHT


func _scenario_frame(_delta: float) -> void:
	if not _tool_given and is_instance_valid(_lemming) \
			and _lemming.state_machine.current_state == LemmingStateMachine.State.WALKING \
			and _lemming.get_body_rect().get_center().x >= GIVE_AT_X:
		_tool_given = true
		_tool_accepted = _lemming.assign_skill(SkillDigger.new())


func _evaluate_scenario() -> void:
	if not _tool_given:
		fail("the lemming never got to where the shovel is given")
		return
	if not _tool_accepted:
		fail("the shovel was refused on a brick")
	if terrain.get_bricks().size() >= _bricks_before:
		fail("no brick was dug")
	if not deaths.is_empty():
		fail("deaths: %s" % deaths)
		return
	var feet_y := _lemming.get_body_rect().end.y
	print("  feet ended at y=%.1f (floor surface y=%d)" % [feet_y, FLOOR_TOP_ROW * TILE])
	if feet_y <= FLOOR_TOP_ROW * TILE + 1.0:
		fail("the lemming did not dig down into the earth under the brick")
