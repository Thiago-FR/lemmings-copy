extends Node
## The roguelike's stages without playing them: for SEEDS run seeds, every
## one of the run's stages is generated from the seed (BiomeStageGenerator),
## has the size of its place in the run, can be won by one lemming with
## only its own items (CellStageSolver), has a recorded solution, puts a
## pickup on every spot, never holds more different tools than the bar has
## slots, has its biome's setting, and comes out the same for the same seed. The five hand-made labyrinths pass the same checks, and the
## developer switch between the two sources works. Run via:
##   godot --headless res://modes/roguelike/tests/test_procedural_stages.tscn
## Exits 0 when every check passes, 1 otherwise.

## Every stage is drawn and solved: a few seeds are plenty.
const SEEDS := 2

var _failures: Array[String] = []
var _checks := 0


func _ready() -> void:
	for seed_index in SEEDS:
		var run_seed := 31337 + seed_index * 104729
		for stage_index in RoguelikeRunState.stage_count():
			var state := RoguelikeRunState.new()
			state.seed_value = run_seed
			state.stage_index = stage_index
			var definition := state.get_stage_definition()
			_check_definition(definition, "seed %d stage %d" % [run_seed, stage_index + 1], stage_index)
			_check(definition.is_procedural, "seed %d stage %d is procedural" % [run_seed, stage_index + 1])
	_check_same_seed()
	_check_handmade()
	_check_source_switch()
	print("  %d checks" % _checks)
	if _failures.is_empty():
		print("Procedural stages: PASS")
	else:
		print("Procedural stages: FAIL\n  " + "\n  ".join(_failures.slice(0, 40)))
	get_tree().quit(0 if _failures.is_empty() else 1)


func _check(condition: bool, description: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(description)


func _check_definition(definition: RoguelikeStageDefinition, name: String, stage_index: int) -> void:
	var maze := definition.maze
	_check(definition.stage_name != "", "%s: has a name" % name)
	if maze.layout != null:
		_check(maze.columns == 60 and maze.rows == 34, "%s: a 60x34 maze" % name)
		_check(MazeSolver.solve(maze.layout).solved, "%s: one lemming with only the stage's items can win it" % name)
	else:
		var biome := BiomeStageGenerator.biome_of(stage_index)
		var size := BiomeStageGenerator.stage_size(stage_index, biome.shapes[BiomeStageGenerator.tier_of(stage_index)])
		_check(Vector2i(maze.columns, maze.rows) == size, "%s: the size of its place in the run" % name)
		# The generator only keeps a stage the solver won with its items, and
		# records that win: re-solving here, without the generator's hints,
		# can run out of search before finding it.
		_check(not maze.solution.is_empty(), "%s: the generator found it winnable with its items" % name)
		_check(definition.get_environment_kind() == biome.kind, "%s: its biome's setting" % name)
	_check(not definition.get_solution().is_empty(), "%s: has a recorded solution" % name)
	_check(definition.pickups.size() == maze.item_spots.size(), "%s: a pickup on every spot" % name)
	var kinds := {}
	for index in definition.pickups.size():
		var spec := definition.pickups[index]
		var spot: Dictionary = maze.item_spots[index]
		_check(spec.column == spot.column and spec.row == spot.row, "%s: pickup %d on its spot" % [name, index])
		if spot.kind == MazeLayout.SpotKind.TOOL:
			_check(spec.kind == RoguelikePickupSpec.Kind.TOOL and spec.tool_id == spot.tool_id and spec.amount == spot.amount, "%s: tool spot %d becomes that tool" % [name, index])
		if spec.kind == RoguelikePickupSpec.Kind.TOOL:
			kinds[spec.tool_id] = true
	_check(kinds.size() <= RoguelikeToolInventory.DEFAULT_MAX_SLOTS, "%s: at most %d different tools (%s)" % [name, RoguelikeToolInventory.DEFAULT_MAX_SLOTS, kinds.keys()])
	if maze.layout != null:
		var cave := stage_index >= MazeStageGenerator.FIRST_CAVE_DIFFICULTY
		_check(definition.get_environment_kind() == (LevelEnvironment.Kind.CAVE if cave else LevelEnvironment.Kind.SURFACE), "%s: environment follows depth" % name)
	_check(definition.time_limit_seconds >= MazeStageGenerator.MIN_TIME_SECONDS, "%s: time limit" % name)


func _check_same_seed() -> void:
	var first := RoguelikeStageFactory.procedural(99, 3)
	var second := RoguelikeStageFactory.procedural(99, 3)
	_check(first.maze.cells == second.maze.cells and first.stage_name == second.stage_name, "the same run seed gives the same stage")
	_check(RoguelikeStageFactory.procedural(99, 2).maze.cells != first.maze.cells, "another stage of the run is another maze")


func _check_handmade() -> void:
	for stage_index in RoguelikeHandmadeStages.STAGE_COUNT:
		var definition := RoguelikeStageFactory.handmade(stage_index)
		_check_definition(definition, "hand-made stage %d" % (stage_index + 1), stage_index)
		_check(not definition.is_procedural and definition.stage_name == RoguelikeHandmadeStages.NAMES[stage_index], "hand-made stage %d keeps its name" % (stage_index + 1))


func _check_source_switch() -> void:
	var state := RoguelikeRunState.new_run()
	_check(state.get_stage_definition().is_procedural, "a run starts with procedural stages")
	state.set_handmade_stages(true)
	_check(not state.get_stage_definition().is_procedural, "switching to hand-made stages takes effect at once")
	_check(not RoguelikeRunState.new_run().get_stage_definition().is_procedural, "the choice holds for the next run")
	state.set_handmade_stages(false)
	_check(state.get_stage_definition().is_procedural, "and switches back")
