extends Node
## Shared scaffolding for tool tests: each scenario gets a fresh terrain
## painted from tile rectangles, lemmings standing on a given row, and a
## fixed run time, after which the test checks the outcome. A tool test
## extends this script, lists its scenarios and fills in the hooks below.
## Exits 0 when every scenario passes, 1 otherwise.

const TILE := 32
const TILE_SET_PATH := "res://resources/tilesets/terrain_tileset.tres"
const LEMMING_SCENE_PATH := "res://scenes/characters/lemming.tscn"

## The scenario being run, as listed by _get_scenarios().
var scenario: Dictionary = {}
## Seconds since the current scenario started.
var elapsed := 0.0
var terrain: TerrainDestructible = null
## Cause of death per lemming label, for every lemming that died this
## scenario.
var deaths: Dictionary = {}

var _scenarios: Array = []
var _scenario_index := 0
var _world: Node2D = null
var _failures: Array[String] = []
var _failed_scenario_count := 0


func _ready() -> void:
	_scenarios = _get_scenarios()
	assert(not _scenarios.is_empty(), "A tool test needs at least one scenario")
	print("Running %s checks (%d scenarios)" % [_get_test_name(), _scenarios.size()])
	_start_scenario()


# --- Hooks for the concrete test -------------------------------------------

func _get_test_name() -> String:
	return "tool"


## Each scenario is a Dictionary with at least "name" and "run_seconds".
func _get_scenarios() -> Array:
	return []


## Paints the terrain and spawns the lemmings for `scenario`.
func _build_scenario() -> void:
	pass


## Called every physics frame while the scenario runs (hand out tools,
## record measurements).
func _scenario_frame(_delta: float) -> void:
	pass


## Lets a scenario end before run_seconds once its outcome is settled.
func _is_scenario_settled() -> bool:
	return false


## Checks the outcome, reporting each problem through fail().
func _evaluate_scenario() -> void:
	pass


# --- Helpers ----------------------------------------------------------------

func paint(from_column: int, to_column: int, from_row: int, to_row: int) -> void:
	for column in range(from_column, to_column + 1):
		for row in range(from_row, to_row + 1):
			terrain.set_cell(Vector2i(column, row), TerrainDestructible.TERRAIN_SOURCE_ID, Vector2i.ZERO)


## A lemming whose body centre is at body_centre_x, standing on top of
## floor_row (or with its feet at that height, in mid-air, if the row is
## empty there).
func spawn_lemming(body_centre_x: float, floor_row: int, facing: int, label: String) -> LemmingController:
	var lemming: LemmingController = load(LEMMING_SCENE_PATH).instantiate()
	var shape_node: CollisionShape2D = lemming.get_node("CollisionShape2D")
	var half := (shape_node.shape as RectangleShape2D).size / 2.0
	# Handed over explicitly: the previous scenario's terrain stays in the
	# "terrain" group until its queue_free() runs.
	lemming.terrain = terrain
	# Positioned before entering the tree, or it counts the move as a fall.
	lemming.position = Vector2(body_centre_x, floor_row * TILE - half.y) - shape_node.position
	lemming.set_meta("label", label)
	lemming.died.connect(func(cause: LemmingController.DeathCause) -> void:
		deaths[label] = LemmingController.DeathCause.keys()[cause])
	_world.add_child(lemming)
	if facing < 0:
		lemming.turn_around()
	return lemming


func fail(message: String) -> void:
	_failures.append(message)


func is_cell_solid(column: int, row: int) -> bool:
	return terrain.get_cell_source_id(Vector2i(column, row)) == TerrainDestructible.TERRAIN_SOURCE_ID


## Fails unless the lemming is alive, walking, and standing on solid ground
## at the top of floor_row. Arrival, not just movement: a lemming that moved
## the right amount but is hovering or stuck in a skill has not arrived.
## lemming is untyped on purpose: a dead lemming is freed, and passing a freed
## object to a typed parameter is a script error that aborts the caller
## without failing the test (a climber that fell to its death passed).
func expect_walking_on_row(lemming: Variant, floor_row: int, label: String) -> void:
	if not is_instance_valid(lemming) or not lemming.state_machine.is_alive():
		fail("%s is not alive (%s)" % [label, deaths.get(label, "gone")])
		return
	var live: LemmingController = lemming
	var state := live.state_machine.current_state
	if state != LemmingStateMachine.State.WALKING:
		fail("%s ended in state %s, expected WALKING" % [label, LemmingStateMachine.State.keys()[state]])
	var body := live.get_body_rect()
	var expected_feet_y := float(floor_row * TILE)
	if absf(body.end.y - expected_feet_y) > 1.5:
		fail("%s has its feet at y=%.1f, expected to stand on row %d (y=%.0f)" % [label, body.end.y, floor_row, expected_feet_y])
	if not terrain.is_solid_at(live.get_feet_position()):
		fail("%s has nothing solid under its feet" % label)


# --- Runner -----------------------------------------------------------------

func _physics_process(delta: float) -> void:
	elapsed += delta
	_scenario_frame(delta)
	if elapsed >= float(scenario.run_seconds) or _is_scenario_settled():
		_finish_scenario()


func _start_scenario() -> void:
	scenario = _scenarios[_scenario_index]
	elapsed = 0.0
	deaths = {}
	_failures = []
	_world = Node2D.new()
	add_child(_world)
	terrain = TerrainDestructible.new()
	terrain.tile_set = load(TILE_SET_PATH)
	_world.add_child(terrain)
	print("\n[%d/%d] %s" % [_scenario_index + 1, _scenarios.size(), scenario.name])
	_build_scenario()


func _finish_scenario() -> void:
	_evaluate_scenario()
	if _failures.is_empty():
		print("  PASS (%.1fs)" % elapsed)
	else:
		_failed_scenario_count += 1
		for failure in _failures:
			print("  FAIL: %s" % failure)

	_world.queue_free()
	_scenario_index += 1
	if _scenario_index < _scenarios.size():
		_start_scenario()
		return

	set_physics_process(false)
	if _failed_scenario_count == 0:
		print("\n%s: all %d scenarios passed" % [_get_test_name(), _scenarios.size()])
		get_tree().quit(0)
	else:
		print("\n%s: %d of %d scenarios FAILED" % [_get_test_name(), _failed_scenario_count, _scenarios.size()])
		get_tree().quit(1)
