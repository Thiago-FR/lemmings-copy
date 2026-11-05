class_name RoguelikeStageFactory
extends RefCounted
## Makes the run's stages: a procedural one from the run's seed (the core's
## BiomeStageGenerator: ten settings in a fixed order), or one of the hand-made
## labyrinths (RoguelikeHandmadeStages). Either way the maze comes as the
## core's MazeStageData and the roguelike puts its own items on the spots:
## the tool spots become tool pickups, the bonus spots a rescue, an
## hourglass, a bag, coins, an ability recharge or spare charges.

const STAGE_COLLECTION := preload("res://modes/roguelike/level_collection.gd")
const TIME_PICKUP_SECONDS := 60
## Coins lying in a stage (the user's idea: coins dropped around the map).
const COIN_PICKUP_AMOUNT := 2
## A recharge of the character's ability (approved plan: few charges per
## stage, more lying on the map).
const ABILITY_CHARGE_PICKUP_AMOUNT := 1
## Charges a bonus spot gives when it turns out to be a tool.
const BONUS_TOOL_CHARGES := 1
const BONUS_TOOLS: Array[String] = ["digger", "ladder_vertical", "bridge", "miner", "basher"]
## A stage never holds more different tools than the bar has slots, so the
## items picked up in it never push each other out of the bar.
const MAX_TOOL_KINDS := ToolInventory.DEFAULT_MAX_SLOTS


## Stages being made in the background: "seed:index" -> {"task", "maze"}.
static var _prefetched: Dictionary = {}


## Starts making a stage on another thread, so procedural() finds it ready.
static func prefetch(run_seed: int, stage_index: int) -> void:
	var key := "%d:%d" % [run_seed, stage_index]
	if _prefetched.has(key) or FileAccess.file_exists(STAGE_COLLECTION.stage_path(stage_index)):
		return
	BiomeStageGenerator.biomes()
	var entry := {"maze": null}
	entry["task"] = WorkerThreadPool.add_task(func() -> void:
		entry["maze"] = BiomeStageGenerator.generate(run_seed, stage_index))
	_prefetched[key] = entry


## Waits for every stage still being made (before the game closes).
static func finish_prefetches() -> void:
	for key: String in _prefetched:
		var entry: Dictionary = _prefetched[key]
		if not entry.get("waited", false):
			WorkerThreadPool.wait_for_task_completion(entry.task)
			entry["waited"] = true


static func procedural(run_seed: int, stage_index: int) -> RoguelikeStageDefinition:
	# A stage drawn in the editor for this place takes the generated one's.
	var maze: MazeStageData = STAGE_COLLECTION.override_maze(stage_index)
	var key := "%d:%d" % [run_seed, stage_index]
	if maze == null and _prefetched.has(key):
		var entry: Dictionary = _prefetched[key]
		if not entry.get("waited", false):
			WorkerThreadPool.wait_for_task_completion(entry.task)
		_prefetched.erase(key)
		maze = entry.maze
	if maze == null:
		maze = BiomeStageGenerator.generate(run_seed, stage_index)
	var rng := RandomNumberGenerator.new()
	rng.seed = MazeStageGenerator.mix_seed(run_seed, stage_index, -1)
	var definition := _from_maze(maze, rng, maze.stage_name)
	definition.is_procedural = true
	return definition


static func handmade(stage_index: int) -> RoguelikeStageDefinition:
	return from_layout(RoguelikeHandmadeStages.build(stage_index), RoguelikeHandmadeStages.NAMES[stage_index], stage_index)


## A stage from a layout drawn by hand (difficulty sets the look and the
## time to spare). Asserts the layout can be won.
static func from_layout(layout: MazeLayout, name: String, difficulty: int) -> RoguelikeStageDefinition:
	var maze := MazeStageGenerator.from_layout(layout, difficulty, difficulty)
	assert(maze != null, "Hand-made stage '%s' cannot be won" % name)
	var rng := RandomNumberGenerator.new()
	rng.seed = difficulty
	var definition := _from_maze(maze, rng, name)
	definition.is_procedural = false
	return definition


static func _from_maze(maze: MazeStageData, rng: RandomNumberGenerator, name: String) -> RoguelikeStageDefinition:
	var definition := RoguelikeStageDefinition.new()
	definition.maze = maze
	definition.stage_name = name
	definition.time_limit_seconds = maze.suggested_time_seconds
	var kinds: Array[String] = []
	for spot in maze.item_spots:
		if spot.kind == MazeLayout.SpotKind.TOOL and not kinds.has(spot.tool_id):
			kinds.append(spot.tool_id)
	for spot in maze.item_spots:
		var spec: ItemSpec
		if spot.kind == MazeLayout.SpotKind.TOOL:
			spec = _tool(spot.tool_id, spot.amount)
		else:
			spec = _bonus(rng, kinds)
		spec.column = spot.column
		spec.row = spot.row
		definition.pickups.append(spec)
	return definition


static func _tool(tool_id: String, amount: int) -> ItemSpec:
	var spec := ItemSpec.new()
	spec.kind = ItemSpec.Kind.TOOL
	spec.tool_id = tool_id
	spec.amount = amount
	return spec


## What a bonus spot holds. A tool only joins the stage's tools while they
## are fewer than the bar's slots.
static func _bonus(rng: RandomNumberGenerator, kinds: Array[String]) -> ItemSpec:
	var roll := rng.randf()
	var spec := ItemSpec.new()
	if roll < 0.15:
		spec.kind = ItemSpec.Kind.REVIVE
		spec.amount = 1
	elif roll < 0.27:
		spec.kind = ItemSpec.Kind.CHARGE_BAG
		spec.amount = 1
	elif roll < 0.4:
		spec.kind = ItemSpec.Kind.TIME
		spec.amount = TIME_PICKUP_SECONDS
	elif roll < 0.55:
		spec.kind = ItemSpec.Kind.COINS
		spec.amount = COIN_PICKUP_AMOUNT
	elif roll < 0.67:
		spec.kind = ItemSpec.Kind.ABILITY_CHARGE
		spec.amount = ABILITY_CHARGE_PICKUP_AMOUNT
		spec.icon_id = RoguelikeAbilities.CHARGE_ICON
	else:
		var choices: Array[String] = []
		choices.assign(BONUS_TOOLS if kinds.size() < MAX_TOOL_KINDS else kinds)
		var tool_id := choices[rng.randi_range(0, choices.size() - 1)]
		if not kinds.has(tool_id):
			kinds.append(tool_id)
		spec = _tool(tool_id, BONUS_TOOL_CHARGES)
	return spec
