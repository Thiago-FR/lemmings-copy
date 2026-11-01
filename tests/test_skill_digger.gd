extends Node
## Automated check that a Digger lemming carves a shaft it can actually
## descend, that the shaft is always the same width, and that it survives the
## trip. Run via:
##   godot --headless res://tests/test_skill_digger.tscn
## Exits 0 when every scenario passes, 1 otherwise.
##
## Runs as a scene rather than through --script because LemmingController
## references the SkillManager autoload, and autoloads are only registered
## for a normal scene run (same reason tools/level_smoke_launcher.tscn
## exists instead of a plain script).
##
## Two scenarios, because the bugs this guards against only ever showed up in
## one of them: a lemming already centred in a terrain column, and one
## standing half a tile off. Carving whichever cells the body overlapped
## passed the first and, on the second, dug a hole twice as wide.

const TILE := 32
const FLOOR_TOP_ROW := 5
const FLOOR_BOTTOM_ROW := 6
const CATCH_TOP_ROW := 9
const CATCH_BOTTOM_ROW := 10
const LEVEL_FIRST_COLUMN := 0
const LEVEL_LAST_COLUMN := 24

const SETTLE_SECONDS := 0.2
## Slack for where the body comes to rest: physics leaves it a fraction of a
## pixel short of the surface it is standing on.
const RESTING_TOLERANCE := 1.0
## Time allowed on top of the dig itself for falling out of the shaft and
## landing on the floor below. The dig time is derived from the skill's own
## dig_speed, so retuning the digger does not quietly break this test.
const FALL_AND_LAND_SECONDS := 1.5

const TILE_SET_PATH := "res://resources/tilesets/terrain_tileset.tres"
const LEMMING_SCENE_PATH := "res://scenes/characters/lemming.tscn"

## Where the body stands when the skill is handed over. The first is already
## centred in column 10; the second is half a tile off, so the skill has to
## line it up itself before carving.
const SCENARIOS := [
	{"name": "body already centred in its column", "dig_x": 336.0},
	{"name": "body standing half a tile off centre", "dig_x": 320.0},
]

var _failures: Array[String] = []
var _scenario_index := 0
var _elapsed := 0.0
var _world: Node2D = null
var _terrain: TerrainDestructible = null
var _lemming: LemmingController = null
var _dig_applied := false
var _dig_start_position := Vector2.ZERO
var _dig_start_body_centre := Vector2.ZERO
var _body_size := Vector2.ZERO
var _dig_seconds := 0.0
var _death_report := ""
## Deepest open gap seen under the digger's feet while it was digging.
var _largest_gap_under_feet := 0.0


func _ready() -> void:
	print("Running SkillDigger checks (%d scenarios)" % SCENARIOS.size())
	_start_scenario()


func _physics_process(delta: float) -> void:
	_elapsed += delta

	# Let the lemming settle onto the floor before handing it the skill, so
	# the dig starts from a genuine standing position rather than mid-drop.
	if not _dig_applied:
		if _elapsed >= SETTLE_SECONDS:
			_apply_digger()
		return

	if _elapsed < SETTLE_SECONDS + _dig_seconds:
		_measure_gap_under_feet()
		return

	_evaluate_scenario()
	_teardown_scenario()

	_scenario_index += 1
	if _scenario_index < SCENARIOS.size():
		_start_scenario()
		return

	_report()


func _start_scenario() -> void:
	_elapsed = 0.0
	_dig_applied = false

	_world = Node2D.new()
	add_child(_world)

	_terrain = TerrainDestructible.new()
	_terrain.tile_set = load(TILE_SET_PATH)
	_world.add_child(_terrain)
	_paint_rect(FLOOR_TOP_ROW, FLOOR_BOTTOM_ROW)
	_paint_rect(CATCH_TOP_ROW, CATCH_BOTTOM_ROW)

	var scenario: Dictionary = SCENARIOS[_scenario_index]
	_lemming = load(LEMMING_SCENE_PATH).instantiate()

	# Read the body straight off the unparented instance rather than
	# hard-coding it, so resizing the collision shape cannot quietly
	# invalidate this test's geometry. LemmingController.get_half_extents()
	# is not usable yet because its @onready reference only resolves once
	# the node is in the tree.
	var collision_shape: CollisionShape2D = _lemming.get_node("CollisionShape2D")
	_body_size = collision_shape.shape.size

	# Feet exactly on the floor surface: the body is centred on the node
	# origin, so the origin sits half a body above the floor's top edge.
	# Positioned before entering the tree because LemmingController starts
	# tracking fall distance from wherever it first lands in the scene —
	# adding it at the origin and moving it afterwards reads as a long
	# plunge and kills it on landing.
	_lemming.position = Vector2(scenario.dig_x, FLOOR_TOP_ROW * TILE - _body_size.y / 2.0)
	# Handed over explicitly: the previous scenario's terrain is still in the
	# "terrain" group until its queue_free() runs, so a group lookup can pick
	# up the wrong one.
	_lemming.terrain = _terrain
	_world.add_child(_lemming)
	_death_report = ""
	_largest_gap_under_feet = 0.0
	_lemming.died.connect(_on_lemming_died)

	print("\n[%d/%d] %s (body %s, standing at x=%s)" % [
		_scenario_index + 1, SCENARIOS.size(), scenario.name, _body_size, scenario.dig_x
	])


## Recorded when it happens, because by evaluation time the body is gone and
## "it died" alone does not say whether it was the fall or something else.
func _on_lemming_died(cause: LemmingController.DeathCause) -> void:
	_death_report = "%s at t=%.2fs, body bottom y=%.1f" % [
		LemmingController.DeathCause.keys()[cause], _elapsed, _lemming.get_body_rect().end.y
	]


## How far below the feet the shaft is already open, sampled every frame of
## the dig. Erasing a whole tile before sinking into it left a hole a full
## tile deep in front of the digger, and lemmings walking past fell into it
## ahead of him. Digging in stages must keep this to one stage at most.
func _measure_gap_under_feet() -> void:
	if not is_instance_valid(_lemming):
		return
	if _lemming.state_machine.current_state != LemmingStateMachine.State.DIGGING:
		return
	const MAX_SCAN := 64.0
	var body := _lemming.get_body_rect()
	var probe := Vector2(body.get_center().x, body.end.y + 0.5)
	var gap := 0.0
	while gap < MAX_SCAN and not _terrain.is_solid_at(probe + Vector2(0, gap)):
		gap += 1.0
	# Once the floor is dug through the gap is the drop to the catch floor,
	# which is the skill finishing, not digging ahead of itself.
	if gap < MAX_SCAN:
		_largest_gap_under_feet = maxf(_largest_gap_under_feet, gap)


func _paint_rect(from_row: int, to_row: int) -> void:
	for column in range(LEVEL_FIRST_COLUMN, LEVEL_LAST_COLUMN + 1):
		for row in range(from_row, to_row + 1):
			_terrain.set_cell(Vector2i(column, row), 0, Vector2i.ZERO)


func _apply_digger() -> void:
	_dig_applied = true

	# Put the body exactly where the scenario wants it, including the walk it
	# does while settling onto the floor. Where it stands relative to the
	# terrain grid is the entire point of these two scenarios.
	var scenario: Dictionary = SCENARIOS[_scenario_index]
	_lemming.global_position.x = scenario.dig_x

	var digger := SkillDigger.new()
	if not _lemming.assign_skill(digger):
		_fail(SCENARIOS[_scenario_index].name, "the lemming refused the Digger in state %s" % _lemming.state_machine.current_state)

	var floor_thickness := float((FLOOR_BOTTOM_ROW - FLOOR_TOP_ROW + 1) * TILE)
	_dig_seconds = floor_thickness / digger.dig_speed + FALL_AND_LAND_SECONDS

	# Recorded after apply_to, which lines the body up with its column.
	# The collision shape sits at an offset from the node origin, so grid
	# questions are asked of the body rectangle and never of the node.
	_dig_start_position = _lemming.global_position
	_dig_start_body_centre = _lemming.get_body_rect().get_center()
	print("  digging starts with body centred at %s" % _dig_start_body_centre)


func _evaluate_scenario() -> void:
	var scenario_name: String = SCENARIOS[_scenario_index].name

	if not _death_report.is_empty() or not is_instance_valid(_lemming):
		_fail(scenario_name, "the lemming died (%s); it should survive the shaft it dug" % _death_report)
		return

	var final_position := _lemming.global_position
	var descended := final_position.y - _dig_start_position.y
	var floor_thickness := float((FLOOR_BOTTOM_ROW - FLOOR_TOP_ROW + 1) * TILE)

	print("  descended %.1fpx (floor is %.0fpx thick), final y=%.1f" % [
		descended, floor_thickness, final_position.y
	])

	if descended < floor_thickness:
		_fail(scenario_name, "only descended %.1fpx through a %.0fpx floor — the lemming did not get through the shaft it dug" % [descended, floor_thickness])
		return

	# Descending far enough is not the same as arriving: a lemming wedged in
	# a shaft its own width used to stop at the bottom of the floor and hover
	# there. Landing on the catch floor is the only proof it came out the
	# other side under gravity. Measured on the body's feet rather than the
	# node origin, which sits at an offset from the collision shape.
	var feet_y := _lemming.get_body_rect().end.y
	var catch_floor_top := float(CATCH_TOP_ROW * TILE)
	if absf(feet_y - catch_floor_top) > RESTING_TOLERANCE:
		_fail(scenario_name, "feet came to rest at y=%.1f instead of on the floor below at y=%.1f — it never fell out of the shaft" % [feet_y, catch_floor_top])
		return

	if not _check_shaft_is_one_column_wide(scenario_name):
		return

	var stage_height := _terrain.get_dig_stage_height()
	print("  largest open gap under the feet while digging: %.0fpx (one stage is %.0fpx)" % [_largest_gap_under_feet, stage_height])
	if _largest_gap_under_feet > stage_height + RESTING_TOLERANCE:
		_fail(scenario_name, "the shaft opened %.0fpx below the digger's feet; it must stay within one %.0fpx stage so lemmings walking past cannot fall in ahead of it" % [_largest_gap_under_feet, stage_height])
		return

	if _lemming.state_machine.current_state != LemmingStateMachine.State.WALKING:
		_fail(scenario_name, "ended in state %s; it should be back to WALKING after landing" % _lemming.state_machine.current_state)
		return

	print("  PASS")


## The shaft must be exactly one terrain column: cleared through the full
## floor thickness, with the columns on both sides left untouched. Width
## varying with where the lemming happened to stand is what made the same
## skill leave visibly different holes.
func _check_shaft_is_one_column_wide(scenario_name: String) -> bool:
	var shaft_column := _terrain.local_to_map(_terrain.to_local(_dig_start_body_centre)).x

	var blocking_cells := _terrain.get_solid_cells_in_rect(_column_rect(shaft_column))
	if not blocking_cells.is_empty():
		_fail(scenario_name, "terrain is still solid inside the shaft at cells %s" % [blocking_cells])
		return false

	for neighbour_column in [shaft_column - 1, shaft_column + 1]:
		if not _terrain.is_solid_in_rect(_column_rect(neighbour_column)):
			_fail(scenario_name, "column %d next to the shaft was dug out too — the hole is wider than one tile" % neighbour_column)
			return false

	print("  shaft is exactly one tile wide, at column %d" % shaft_column)
	return true


## World-space rectangle covering one terrain column across the floor's full
## thickness, inset so it cannot bleed into the columns on either side.
func _column_rect(column: int) -> Rect2:
	const EDGE_INSET := 1.0
	return Rect2(
		Vector2(column * TILE + EDGE_INSET, float(FLOOR_TOP_ROW * TILE)),
		Vector2(TILE - 2.0 * EDGE_INSET, float((FLOOR_BOTTOM_ROW - FLOOR_TOP_ROW + 1) * TILE))
	)


func _fail(scenario_name: String, reason: String) -> void:
	_failures.append("%s: %s" % [scenario_name, reason])
	print("  FAIL — %s" % reason)


func _teardown_scenario() -> void:
	_world.queue_free()
	_world = null
	_terrain = null
	_lemming = null


func _report() -> void:
	set_physics_process(false)
	print("")
	if _failures.is_empty():
		print("SkillDigger: all %d scenarios passed" % SCENARIOS.size())
		get_tree().quit(0)
		return

	print("SkillDigger: %d of %d scenarios failed" % [_failures.size(), SCENARIOS.size()])
	for failure in _failures:
		print("  - %s" % failure)
	get_tree().quit(1)
