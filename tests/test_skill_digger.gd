extends Node
## Automated check that a Digger lemming carves a shaft it can actually
## descend, and survives the trip. Run via:
##   godot --headless res://tests/test_skill_digger.tscn
## Exits 0 when every scenario passes, 1 otherwise.
##
## Runs as a scene rather than through --script because LemmingController
## references the SkillManager autoload, and autoloads are only registered
## for a normal scene run (same reason tools/level_smoke_launcher.tscn
## exists instead of a plain script).
##
## Two scenarios, because the bug this guards against only ever showed up in
## one of them: a lemming whose body sits exactly inside one terrain column,
## and one whose body straddles two. Carving a fixed cell count instead of
## the body's real footprint passes the first and fails the second, which is
## why the original symptom looked intermittent.

const TILE := 16
const FLOOR_TOP_ROW := 10
const FLOOR_BOTTOM_ROW := 13
const CATCH_TOP_ROW := 15
const CATCH_BOTTOM_ROW := 18
const LEVEL_FIRST_COLUMN := 0
const LEVEL_LAST_COLUMN := 19

const SETTLE_SECONDS := 0.2
## Slack for where the body comes to rest: physics leaves it a fraction of a
## pixel short of the surface it is standing on.
const RESTING_TOLERANCE := 1.0
const DIG_SECONDS := 2.5

const TILE_SET_PATH := "res://resources/tilesets/terrain_tileset.tres"
const LEMMING_SCENE_PATH := "res://scenes/characters/lemming.tscn"

## Where the body sits when digging starts. The first centres the 16px body
## inside column 10; the second offsets it by half a tile so it overlaps
## columns 9 and 10.
const SCENARIOS := [
	{"name": "body aligned to one terrain column", "dig_x": 168.0},
	{"name": "body straddling two terrain columns", "dig_x": 160.0},
]

var _failures: Array[String] = []
var _scenario_index := 0
var _elapsed := 0.0
var _world: Node2D = null
var _terrain: TerrainDestructible = null
var _lemming: LemmingController = null
var _dig_applied := false
var _dig_start_position := Vector2.ZERO
var _body_size := Vector2.ZERO


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

	if _elapsed < SETTLE_SECONDS + DIG_SECONDS:
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
	# adding it at the origin and moving it afterwards reads as a 146px
	# plunge and kills it on landing.
	_lemming.position = Vector2(scenario.dig_x, FLOOR_TOP_ROW * TILE - _body_size.y / 2.0)
	_world.add_child(_lemming)

	print("\n[%d/%d] %s (body %s, digging from x=%s)" % [
		_scenario_index + 1, SCENARIOS.size(), scenario.name, _body_size, scenario.dig_x
	])


func _paint_rect(from_row: int, to_row: int) -> void:
	for column in range(LEVEL_FIRST_COLUMN, LEVEL_LAST_COLUMN + 1):
		for row in range(from_row, to_row + 1):
			_terrain.set_cell(Vector2i(column, row), 0, Vector2i.ZERO)


func _apply_digger() -> void:
	_dig_applied = true

	# Place the body exactly where the scenario wants it before digging
	# starts. It walks while settling onto the floor, so where it spawned is
	# not where it ends up — and how the body sits relative to the terrain
	# grid is the entire point of these two scenarios.
	var scenario: Dictionary = SCENARIOS[_scenario_index]
	_lemming.global_position.x = scenario.dig_x
	_dig_start_position = _lemming.global_position

	var digger := SkillDigger.new()
	digger.skill_id = "digger"
	_lemming.current_skill = digger
	digger.apply_to(_lemming)
	print("  digging starts at %s" % _dig_start_position)


func _evaluate_scenario() -> void:
	var scenario_name: String = SCENARIOS[_scenario_index].name

	if not is_instance_valid(_lemming):
		_fail(scenario_name, "the lemming died while digging; it should survive the shaft it dug")
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
	# other side under gravity.
	var expected_resting_y := float(CATCH_TOP_ROW * TILE) - _body_size.y / 2.0
	if absf(final_position.y - expected_resting_y) > RESTING_TOLERANCE:
		_fail(scenario_name, "came to rest at y=%.1f instead of landing on the floor below at y=%.1f — it never fell out of the shaft" % [final_position.y, expected_resting_y])
		return

	# The shaft itself must be clear across the full floor thickness, not
	# merely wide enough at the single row the lemming happens to be in.
	var shaft := Rect2(
		Vector2(_dig_start_position.x - _body_size.x / 2.0, float(FLOOR_TOP_ROW * TILE)),
		Vector2(_body_size.x, floor_thickness)
	)
	var blocking_cells := _terrain.get_solid_cells_in_rect(shaft)
	if not blocking_cells.is_empty():
		_fail(scenario_name, "terrain is still solid inside the shaft at cells %s" % [blocking_cells])
		return

	if _lemming.state_machine.current_state != LemmingStateMachine.State.WALKING:
		_fail(scenario_name, "ended in state %s; it should be back to WALKING after landing" % _lemming.state_machine.current_state)
		return

	print("  PASS")


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
