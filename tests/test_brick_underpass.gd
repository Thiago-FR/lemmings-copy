extends Node
## Automated check that lemmings walk underneath a diagonal ladder. Run via:
##   godot --headless res://tests/test_brick_underpass.tscn
## Exits 0 when every check passes, 1 otherwise.
##
## Layout: a long floor with a finished staircase on it (bricks laid directly,
## rising to the right) and walls far beyond both ends. Two lemmings start
## underneath the staircase, one walking each way.
##
## What is checked: bricks only collide from above, so both lemmings pass
## through the bricks at head height without turning around. Reported as a
## bug: a lemming under the staircase took the bricks for a wall and walked
## back. The one walking left ends by stepping over the lowest brick and down
## onto the floor beyond the staircase, the one walking right comes out past
## its high end.

const TILE := 32
const FLOOR_TOP_ROW := 8
const FLOOR_BOTTOM_ROW := 9
const LEFT_WALL_COLUMN := 0
const RIGHT_WALL_COLUMN := 30
const STEP_COUNT := 12
const STEP_WIDTH := 32.0
const STEP_HEIGHT := 8.0
const STAIRS_START_X := 160.0
## Both start well under the staircase, where the bricks are above the head.
const LEFT_WALKER_START_X := 480.0
const RIGHT_WALKER_START_X := 320.0
## Clear of the staircase's ends by a body width.
const LEFT_GOAL_X := STAIRS_START_X - 30.0
const RIGHT_GOAL_X := STAIRS_START_X + STEP_COUNT * STEP_WIDTH + 30.0
const RUN_SECONDS := 20.0

const TILE_SET_PATH := "res://resources/tilesets/terrain_tileset.tres"
const LEMMING_SCENE_PATH := "res://scenes/characters/lemming.tscn"

var _terrain: TerrainDestructible = null
var _elapsed := 0.0
## Per lemming: the direction it set out in, whether it reached its goal, and
## whether it turned around before getting there.
var _walkers: Array[Dictionary] = []
var _deaths: Array[String] = []


func _ready() -> void:
	print("Running brick underpass checks")
	_terrain = TerrainDestructible.new()
	_terrain.tile_set = load(TILE_SET_PATH)
	add_child(_terrain)
	_paint(LEFT_WALL_COLUMN, RIGHT_WALL_COLUMN, FLOOR_TOP_ROW, FLOOR_BOTTOM_ROW)
	_paint(LEFT_WALL_COLUMN, LEFT_WALL_COLUMN, -20, FLOOR_TOP_ROW - 1)
	_paint(RIGHT_WALL_COLUMN, RIGHT_WALL_COLUMN, -20, FLOOR_TOP_ROW - 1)
	_lay_staircase()

	_walkers.append(_spawn_walker(LEFT_WALKER_START_X, -1, LEFT_GOAL_X, "left walker"))
	_walkers.append(_spawn_walker(RIGHT_WALKER_START_X, 1, RIGHT_GOAL_X, "right walker"))


func _physics_process(delta: float) -> void:
	_elapsed += delta
	var all_resolved := true
	for walker in _walkers:
		_track(walker)
		all_resolved = all_resolved and _is_resolved(walker)
	# Stops as soon as both are past: left alone, a lemming walks back, up the
	# staircase and off its high end, which is not what this checks.
	if all_resolved or _elapsed >= RUN_SECONDS:
		_report()


func _paint(from_column: int, to_column: int, from_row: int, to_row: int) -> void:
	for column in range(from_column, to_column + 1):
		for row in range(from_row, to_row + 1):
			_terrain.set_cell(Vector2i(column, row), TerrainDestructible.TERRAIN_SOURCE_ID, Vector2i.ZERO)


func _lay_staircase() -> void:
	var floor_y := float(FLOOR_TOP_ROW * TILE)
	for step in STEP_COUNT:
		var brick := Rect2(STAIRS_START_X + STEP_WIDTH * step, floor_y - STEP_HEIGHT * (step + 1), STEP_WIDTH, STEP_HEIGHT)
		var laid := _terrain.place_brick(brick)
		assert(laid, "brick %d could not be laid" % step)


func _spawn_walker(x: float, direction: int, goal_x: float, label: String) -> Dictionary:
	var lemming: LemmingController = load(LEMMING_SCENE_PATH).instantiate()
	var body_height: float = (lemming.get_node("CollisionShape2D").shape as RectangleShape2D).size.y
	lemming.terrain = _terrain
	lemming.position = Vector2(x, FLOOR_TOP_ROW * TILE - body_height / 2.0)
	lemming.died.connect(func(cause: LemmingController.DeathCause) -> void:
		_deaths.append("%s died (%s) at t=%.1fs" % [label, LemmingController.DeathCause.keys()[cause], _elapsed]))
	add_child(lemming)
	if lemming.direction != direction:
		lemming.turn_around()
	return {"lemming": lemming, "label": label, "direction": direction, "goal_x": goal_x, "reached_at": -1.0, "turned_at_x": NAN}


func _is_resolved(walker: Dictionary) -> bool:
	return walker.reached_at >= 0.0 or not is_nan(walker.turned_at_x) or not is_instance_valid(walker.lemming)


func _track(walker: Dictionary) -> void:
	if _is_resolved(walker):
		return
	var lemming: LemmingController = walker.lemming
	var centre_x := lemming.get_body_rect().get_center().x
	if lemming.direction != walker.direction:
		walker.turned_at_x = centre_x
	elif (centre_x - walker.goal_x) * walker.direction >= 0.0:
		walker.reached_at = _elapsed


func _report() -> void:
	set_physics_process(false)
	var failures: Array[String] = []
	for walker in _walkers:
		if not is_nan(walker.turned_at_x):
			failures.append("%s turned around under the staircase at x=%.1f" % [walker.label, walker.turned_at_x])
		elif walker.reached_at < 0.0:
			failures.append("%s never got past the staircase (goal x=%.1f)" % [walker.label, walker.goal_x])
		else:
			print("  %s got past the staircase at t=%.1fs" % [walker.label, walker.reached_at])
	failures.append_array(_deaths)

	if failures.is_empty():
		print("Brick underpass: all checks passed")
		get_tree().quit(0)
		return
	print("Brick underpass: %d checks failed" % failures.size())
	for failure in failures:
		print("  - %s" % failure)
	get_tree().quit(1)
