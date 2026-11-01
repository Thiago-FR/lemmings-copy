extends "res://tests/tool_scenario_test.gd"
## Shared check of the explosives (SkillDynamite, SkillTnt). A concrete test
## names the tool and the blast it expects.
##
## Layout: a floor two blocks thick (concrete on top, earth below) between
## two walls. A lemming walking right is given the explosive; a second one
## just behind it is made a blocker (Escudo) so it stands still where the
## blast will reach it.
##
## Checked: the tool is taken and the lemming keeps walking (it puts the
## charge down, it does not blow itself up); the charge goes off after its
## fuse; exactly the blast cells are gone, floor and concrete included, and
## every other cell is still there; the lemming standing in the blast dies
## in the explosion; the one that put the charge down walks on unharmed.

const FLOOR_TOP_ROW := 11
const FLOOR_BOTTOM_ROW := 12
const PLACER_START_X := 240.0
## The blocker stands one block behind the placer, inside the blast.
const BLOCKER_OFFSET_X := -32.0

var _placer: LemmingController = null
var _blocker: LemmingController = null
var _tool_given := false
var _tool_accepted := false
var _blocker_given := false
var _charge_placed_at := -1.0
var _expected_blast: Array[Vector2i] = []
var _exploded := false
var _solid_before := {}


## The explosive under test.
func _make_tool() -> SkillExplosive:
	return null


## Cells the blast should take, as offsets from the charge's own cell.
func _expected_offsets() -> Array[Vector2i]:
	return []


func _get_scenarios() -> Array:
	return [{"name": "charge put down on a concrete floor", "start_x": PLACER_START_X, "run_seconds": 12.0}]


func _build_scenario() -> void:
	_tool_given = false
	_tool_accepted = false
	_blocker_given = false
	_charge_placed_at = -1.0
	_expected_blast = []
	_exploded = false
	_solid_before = {}
	paint(0, 24, FLOOR_BOTTOM_ROW, FLOOR_BOTTOM_ROW)
	for column in range(0, 25):
		terrain.build_cell_at(terrain.to_global(terrain.map_to_local(Vector2i(column, FLOOR_TOP_ROW))), TerrainDestructible.TerrainMaterial.CONCRETE)
	paint(-1, -1, -10, FLOOR_BOTTOM_ROW)
	paint(25, 25, -10, FLOOR_BOTTOM_ROW)
	_placer = spawn_lemming(scenario.start_x, FLOOR_TOP_ROW, 1, "placer")
	_blocker = spawn_lemming(scenario.start_x + BLOCKER_OFFSET_X, FLOOR_TOP_ROW, 1, "blocker")


func _scenario_frame(_delta: float) -> void:
	if not _tool_given and _placer.state_machine.current_state == LemmingStateMachine.State.WALKING \
			and _blocker.state_machine.current_state == LemmingStateMachine.State.WALKING:
		_tool_given = true
		_blocker_given = _blocker.assign_skill(SkillBlocker.new())
		_tool_accepted = _placer.assign_skill(_make_tool())
		var charge := _find_charge()
		if charge != null:
			_charge_placed_at = elapsed
			_expected_blast = charge.get_blast_cells()
			_record_solid_cells()
	if _charge_placed_at >= 0.0 and not _exploded and _find_charge() == null:
		_exploded = true


func _find_charge() -> ExplosiveCharge:
	for child in terrain.get_parent().get_children():
		if child is ExplosiveCharge and not child.is_queued_for_deletion():
			return child
	return null


func _record_solid_cells() -> void:
	for column in range(0, 25):
		for row in range(FLOOR_TOP_ROW, FLOOR_BOTTOM_ROW + 1):
			_solid_before[Vector2i(column, row)] = is_cell_solid(column, row)


func _is_scenario_settled() -> bool:
	return _exploded and elapsed - _charge_placed_at > _make_tool().fuse_seconds + 1.0


func _evaluate_scenario() -> void:
	if not _tool_accepted:
		fail("the explosive was refused")
		return
	if not _blocker_given:
		fail("the blocker was refused")
	if _charge_placed_at < 0.0:
		fail("no charge was put down")
		return
	if not _exploded:
		fail("the charge never went off")
		return

	var centre := _expected_blast[0] - _expected_offsets()[0]
	var expected: Array[Vector2i] = []
	for offset in _expected_offsets():
		expected.append(centre + offset)
	expected.sort()
	var blast := _expected_blast.duplicate()
	blast.sort()
	if blast != expected:
		fail("the blast covers %s, expected %s" % [blast, expected])

	for cell: Vector2i in _solid_before:
		var was_solid: bool = _solid_before[cell]
		var in_blast := expected.has(cell)
		var now_solid := is_cell_solid(cell.x, cell.y)
		if in_blast and now_solid:
			fail("cell %s is in the blast but still there" % cell)
		elif not in_blast and was_solid and not now_solid:
			fail("cell %s is outside the blast but was destroyed" % cell)
	if not expected.any(func(cell: Vector2i) -> bool: return cell.y == FLOOR_TOP_ROW):
		fail("the blast did not reach the concrete floor")

	if deaths.get("blocker", "") != "EXPLOSION":
		fail("the lemming standing in the blast did not die in it (%s)" % deaths.get("blocker", "still alive"))
	if deaths.has("placer"):
		fail("the lemming that put the charge down died (%s)" % deaths["placer"])
	print("  blast cells: %s" % [blast])
