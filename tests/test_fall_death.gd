extends Node
## Automated check of what a fatal fall looks like and what it reports:
## a lemming dropped from above the safe height must die with cause FALL,
## play the "death_fall" animation where it landed, and only then disappear.
## A lemming dropped from below the safe height must survive. Run via:
##   godot --headless res://tests/test_fall_death.tscn
## Exits 0 when every scenario passes, 1 otherwise.
##
## Runs as a scene for the same reason as test_skill_digger: autoloads only
## exist in a normal scene run.

const TILE := 32
const FLOOR_ROW := 10
const LEVEL_LAST_COLUMN := 20
const DROP_X := 336.0
const TILE_SET_PATH := "res://resources/tilesets/terrain_tileset.tres"
const LEMMING_SCENE_PATH := "res://scenes/characters/lemming.tscn"

## Long enough for the fall, the death animation and the fade to finish.
const RUN_SECONDS := 3.5

const SCENARIOS := [
	{"name": "fall from above the safe height kills", "drop_height": 160.0, "should_die": true},
	{"name": "fall from below the safe height is survived", "drop_height": 48.0, "should_die": false},
]

var _failures: Array[String] = []
var _scenario_index := 0
var _elapsed := 0.0
var _world: Node2D = null
var _lemming: LemmingController = null
var _death_cause := -1
var _death_animation_seen := false
var _freed := false


func _ready() -> void:
	print("Running fall-death checks (%d scenarios)" % SCENARIOS.size())
	_start_scenario()


func _process(delta: float) -> void:
	_elapsed += delta

	# Sampled every frame, since by the end of the run a dead lemming has
	# already been freed and its animation can no longer be read.
	if is_instance_valid(_lemming):
		if _lemming.animated_sprite.animation == &"death_fall":
			_death_animation_seen = true
	else:
		_freed = true

	if _elapsed < RUN_SECONDS:
		return

	_evaluate_scenario()
	_world.queue_free()
	_scenario_index += 1
	if _scenario_index < SCENARIOS.size():
		_start_scenario()
		return
	_report()


func _start_scenario() -> void:
	_elapsed = 0.0
	_death_cause = -1
	_death_animation_seen = false
	_freed = false

	_world = Node2D.new()
	add_child(_world)

	var terrain := TerrainDestructible.new()
	terrain.tile_set = load(TILE_SET_PATH)
	for column in range(LEVEL_LAST_COLUMN + 1):
		terrain.set_cell(Vector2i(column, FLOOR_ROW), 0, Vector2i.ZERO)
	_world.add_child(terrain)

	var scenario: Dictionary = SCENARIOS[_scenario_index]
	_lemming = load(LEMMING_SCENE_PATH).instantiate()
	var body_height: float = (_lemming.get_node("CollisionShape2D").shape as RectangleShape2D).size.y
	_lemming.terrain = terrain
	_lemming.position = Vector2(DROP_X, FLOOR_ROW * TILE - body_height / 2.0 - scenario.drop_height)
	_lemming.died.connect(func(cause: LemmingController.DeathCause) -> void: _death_cause = cause)
	_world.add_child(_lemming)

	print("\n[%d/%d] %s (drop %.0fpx, safe limit %.0fpx)" % [
		_scenario_index + 1, SCENARIOS.size(), scenario.name, scenario.drop_height, Constants.MAX_SAFE_FALL_HEIGHT
	])


func _evaluate_scenario() -> void:
	var scenario: Dictionary = SCENARIOS[_scenario_index]

	if not scenario.should_die:
		if _death_cause != -1:
			_fail(scenario.name, "died (%s) from a fall it should survive" % LemmingController.DeathCause.keys()[_death_cause])
			return
		print("  PASS")
		return

	if _death_cause != LemmingController.DeathCause.FALL:
		var reported: String = "nothing" if _death_cause == -1 else LemmingController.DeathCause.keys()[_death_cause]
		_fail(scenario.name, "death reported %s instead of FALL" % reported)
		return
	if not _death_animation_seen:
		_fail(scenario.name, "the 'death_fall' animation never played")
		return
	if not _freed:
		_fail(scenario.name, "the body was still in the scene %.1fs later; it should fade out and be removed" % RUN_SECONDS)
		return
	print("  PASS")


func _fail(scenario_name: String, reason: String) -> void:
	_failures.append("%s: %s" % [scenario_name, reason])
	print("  FAIL — %s" % reason)


func _report() -> void:
	set_process(false)
	print("")
	if _failures.is_empty():
		print("Fall death: all %d scenarios passed" % SCENARIOS.size())
		get_tree().quit(0)
		return
	print("Fall death: %d of %d scenarios failed" % [_failures.size(), SCENARIOS.size()])
	for failure in _failures:
		print("  - %s" % failure)
	get_tree().quit(1)
