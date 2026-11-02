extends "res://tests/tool_scenario_test.gd"
## Automated check that a bridge always reaches the far side of a gap. Run
## via:
##   godot --headless res://tests/test_bridge_meets_far_side.tscn
##
## A bridge used to stop when its next whole piece did not fit, so across a
## gap that is not a whole number of pieces wide it ended up to a piece
## short of the far side. Its last piece is now cut to the room left.
##
## Layout: a floor broken by a bottomless gap six and a half blocks wide
## (the far side is not on the piece grid). A lemming walking towards it is
## given the bridge.
##
## Checked: the bridge ends touching the far side (no gap), the lemming
## walks across onto it, and nobody dies.

const FLOOR_TOP_ROW := 11
const GAP_START_X := 320.0
const GAP_WIDTH := 208.0
const START_X := 120.0

var _lemming: LemmingController = null
var _tool_given := false
var _tool_accepted := false
var _crossed := false


func _get_test_name() -> String:
	return "Bridge meets the far side"


func _get_scenarios() -> Array:
	return [{"name": "gap six and a half blocks wide", "run_seconds": 25.0}]


func _build_scenario() -> void:
	_tool_given = false
	_tool_accepted = false
	_crossed = false
	paint(0, int(GAP_START_X / TILE) - 1, FLOOR_TOP_ROW, FLOOR_TOP_ROW + 1)
	paint(int((GAP_START_X + GAP_WIDTH) / TILE) + 1, 24, FLOOR_TOP_ROW, FLOOR_TOP_ROW + 1)
	paint(-1, -1, -10, FLOOR_TOP_ROW + 1)
	paint(25, 25, -10, FLOOR_TOP_ROW + 1)
	# The far side starts half a block into a cell: dig that cell's left half
	# away from the side, so the gap really is 6.5 blocks.
	var far_cell_x := int((GAP_START_X + GAP_WIDTH) / TILE)
	for row in [FLOOR_TOP_ROW, FLOOR_TOP_ROW + 1]:
		var centre := terrain.to_global(terrain.map_to_local(Vector2i(far_cell_x, row)))
		terrain.build_cell_at(centre)
		for _stage in 2:
			terrain.dig_side_stage_at(centre, 1)
	_lemming = spawn_lemming(START_X, FLOOR_TOP_ROW, 1, "lemming")


func _scenario_frame(_delta: float) -> void:
	if not is_instance_valid(_lemming):
		return
	if not _tool_given and _lemming.state_machine.current_state == LemmingStateMachine.State.WALKING:
		_tool_given = true
		_tool_accepted = _lemming.assign_skill(SkillBridge.new())
	if _lemming.get_body_rect().position.x > GAP_START_X + GAP_WIDTH + 8.0 \
			and _lemming.state_machine.current_state == LemmingStateMachine.State.WALKING:
		_crossed = true


func _is_scenario_settled() -> bool:
	return _crossed


func _evaluate_scenario() -> void:
	if not _tool_accepted:
		fail("the bridge was refused")
	var reach := -INF
	for piece in terrain.get_bricks():
		reach = maxf(reach, piece.end.x)
	var far_side := GAP_START_X + GAP_WIDTH
	print("  bridge ends at x=%.1f, far side at x=%.0f" % [reach, far_side])
	if far_side - reach > 0.5:
		fail("the bridge stops %.1fpx short of the far side" % (far_side - reach))
	if not _crossed:
		fail("the lemming never crossed (%s)" % deaths.get("lemming", "alive"))
	if not deaths.is_empty():
		fail("deaths: %s" % deaths)
