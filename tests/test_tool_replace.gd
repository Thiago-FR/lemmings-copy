extends "res://tests/tool_scenario_test.gd"
## Automated check that a newer tool replaces the one a lemming holds. Run via:
##   godot --headless res://tests/test_tool_replace.tscn
##
## Reported as a bug: a lemming carrying a pickaxe towards a concrete wall
## (which the pickaxe cannot dig, so it turns and keeps carrying it for
## good) refused the shovel the player gave it, and was stuck.
##
## Layout: a floor two rows deep of earth with a concrete wall on the right.
## Scenarios:
##   - carried: the lemming is given the pickaxe, turns at the concrete
##     still carrying it, and is then given the shovel: it takes it, drops
##     the pickaxe (carried_tool_dropped, so the charge can be given back)
##     and digs down through the floor;
##   - in use: a lemming digging down with the shovel is given the
##     jackhammer partway: the digging stops, it carries the jackhammer, and
##     the dropped-tool signal is not sent (the shovel was used).
##   - the block, used on the spot, leaves a carried tool alone.

const FLOOR_TOP_ROW := 11
const WALL_FIRST_COLUMN := 14
const WALL_LAST_COLUMN := 15
const WALL_TOP_ROW := 7
const START_X := 112.0
## Pixels the shovel digs before the jackhammer is handed over.
const DIG_BEFORE_SWITCH := 10.0

var _lemming: LemmingController = null
var _step := 0
var _start_feet_y := 0.0
var _dropped: Array[StringName] = []
var _replaced := false
var _dug_below_floor := false
var _block_kept_carried := false


func _get_test_name() -> String:
	return "Tool replace"


func _get_scenarios() -> Array:
	return [
		{"name": "shovel replaces a carried pickaxe", "kind": "carried", "run_seconds": 12.0},
		{"name": "jackhammer interrupts the shovel", "kind": "in_use", "run_seconds": 6.0},
		{"name": "block leaves a carried pickaxe alone", "kind": "block", "run_seconds": 3.0},
	]


func _build_scenario() -> void:
	_step = 0
	_dropped.clear()
	_replaced = false
	_dug_below_floor = false
	_block_kept_carried = false
	paint(-1, -1, -10, FLOOR_TOP_ROW + 3)
	paint(25, 25, -10, FLOOR_TOP_ROW + 3)
	paint(0, 24, FLOOR_TOP_ROW, FLOOR_TOP_ROW + 3)
	for column in range(WALL_FIRST_COLUMN, WALL_LAST_COLUMN + 1):
		for row in range(WALL_TOP_ROW, FLOOR_TOP_ROW):
			terrain.build_cell_at(terrain.to_global(terrain.map_to_local(Vector2i(column, row))), TerrainDestructible.TerrainMaterial.CONCRETE)
	_lemming = spawn_lemming(START_X, FLOOR_TOP_ROW, 1, "lemming")
	_lemming.carried_tool_dropped.connect(func(skill: SkillBase) -> void: _dropped.append(skill.id))


func _scenario_frame(_delta: float) -> void:
	if not is_instance_valid(_lemming):
		return
	var walking := _lemming.state_machine.current_state == LemmingStateMachine.State.WALKING
	match scenario.kind:
		"carried":
			if _step == 0 and walking:
				_step = 1
				_lemming.assign_skill(SkillMiner.new())
			elif _step == 1 and _lemming.direction < 0 and walking:
				_step = 2
				_replaced = _lemming.pending_wall_tool is SkillMiner and _lemming.assign_skill(SkillDigger.new())
		"in_use":
			if _step == 0 and walking:
				_step = 1
				_start_feet_y = _lemming.get_feet_position().y
				_lemming.assign_skill(SkillDigger.new())
			elif _step == 1 and _lemming.get_feet_position().y > _start_feet_y + DIG_BEFORE_SWITCH:
				_step = 2
				_replaced = _lemming.assign_skill(SkillBasher.new())
		"block":
			if _step == 0 and walking:
				_step = 1
				_lemming.assign_skill(SkillMiner.new())
				var block_taken := _lemming.assign_skill(SkillBlock.new())
				_block_kept_carried = block_taken and _lemming.pending_wall_tool is SkillMiner
	if _lemming.get_feet_position().y > (FLOOR_TOP_ROW + 1) * TILE:
		_dug_below_floor = true


func _evaluate_scenario() -> void:
	match scenario.kind:
		"carried":
			if not _replaced:
				fail("the lemming carrying the pickaxe did not take the shovel")
			if _dropped != [&"miner"]:
				fail("dropping the pickaxe was reported as %s, expected [miner]" % [_dropped])
			if not _dug_below_floor:
				fail("the shovel did not dig down through the floor")
		"in_use":
			if not _replaced:
				fail("the digging lemming did not take the jackhammer")
			if not _dropped.is_empty():
				fail("a tool in use was reported as dropped unused (%s)" % [_dropped])
			if is_instance_valid(_lemming) and not (_lemming.pending_wall_tool is SkillBasher or _lemming.current_skill is SkillBasher):
				fail("the lemming does not hold the jackhammer after the switch")
			if is_instance_valid(_lemming) and _lemming.current_skill is SkillDigger:
				fail("the shovel kept digging after the switch")
		"block":
			if not _block_kept_carried:
				fail("placing a block dropped the carried pickaxe")
