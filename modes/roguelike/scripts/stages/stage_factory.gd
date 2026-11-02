class_name RoguelikeStageFactory
extends RefCounted
## Makes the run's stages: a procedural one from the run's seed (the core's
## MazeStageGenerator, harder with every stage), or one of the hand-made
## labyrinths (RoguelikeHandmadeStages). Either way the maze comes as the
## core's MazeStageData and the roguelike puts its own items on the spots:
## the tool spots become tool pickups, the bonus spots a rescue, an
## hourglass, a bag or spare charges.

const PLACES_SURFACE: Array[String] = ["Colinas", "Trilhas", "Ravinas", "Encostas", "Barrancos", "Veredas"]
const PLACES_CAVE: Array[String] = ["Galerias", "Túneis", "Grutas", "Câmaras", "Poços", "Veios", "Covas"]
const QUALIFIERS: Array[String] = ["da Raiz", "do Eco", "de Pedra", "do Musgo", "Esquecidas", "do Carvão", "da Névoa", "do Vento", "Tortas", "do Fundo"]
const TIME_PICKUP_SECONDS := 60
## Coins lying in a stage (the user's idea: coins dropped around the map).
const COIN_PICKUP_AMOUNT := 2
## Charges a bonus spot gives when it turns out to be a tool.
const BONUS_TOOL_CHARGES := 1
const BONUS_TOOLS: Array[String] = ["digger", "ladder_vertical", "bridge", "miner", "basher"]
## A stage never holds more different tools than the bar has slots, so the
## items picked up in it never push each other out of the bar.
const MAX_TOOL_KINDS := RoguelikeToolInventory.DEFAULT_MAX_SLOTS


static func procedural(run_seed: int, stage_index: int) -> RoguelikeStageDefinition:
	var maze := MazeStageGenerator.generate(run_seed + stage_index * 1000003, stage_index)
	var rng := RandomNumberGenerator.new()
	rng.seed = MazeStageGenerator.mix_seed(run_seed, stage_index, -1)
	var places := PLACES_CAVE if maze.environment_kind == LevelEnvironment.Kind.CAVE else PLACES_SURFACE
	var name := "%s %s" % [places[rng.randi_range(0, places.size() - 1)], QUALIFIERS[rng.randi_range(0, QUALIFIERS.size() - 1)]]
	var definition := _from_maze(maze, rng, name)
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
		var spec: RoguelikePickupSpec
		if spot.kind == MazeLayout.SpotKind.TOOL:
			spec = _tool(spot.tool_id, spot.amount)
		else:
			spec = _bonus(rng, kinds)
		spec.column = spot.column
		spec.row = spot.row
		definition.pickups.append(spec)
	return definition


static func _tool(tool_id: String, amount: int) -> RoguelikePickupSpec:
	var spec := RoguelikePickupSpec.new()
	spec.kind = RoguelikePickupSpec.Kind.TOOL
	spec.tool_id = tool_id
	spec.amount = amount
	return spec


## What a bonus spot holds. A tool only joins the stage's tools while they
## are fewer than the bar's slots.
static func _bonus(rng: RandomNumberGenerator, kinds: Array[String]) -> RoguelikePickupSpec:
	var roll := rng.randf()
	var spec := RoguelikePickupSpec.new()
	if roll < 0.15:
		spec.kind = RoguelikePickupSpec.Kind.REVIVE
		spec.amount = 1
	elif roll < 0.27:
		spec.kind = RoguelikePickupSpec.Kind.CHARGE_BAG
		spec.amount = 1
	elif roll < 0.4:
		spec.kind = RoguelikePickupSpec.Kind.TIME
		spec.amount = TIME_PICKUP_SECONDS
	elif roll < 0.65:
		spec.kind = RoguelikePickupSpec.Kind.COINS
		spec.amount = COIN_PICKUP_AMOUNT
	else:
		var choices: Array[String] = []
		choices.assign(BONUS_TOOLS if kinds.size() < MAX_TOOL_KINDS else kinds)
		var tool_id := choices[rng.randi_range(0, choices.size() - 1)]
		if not kinds.has(tool_id):
			kinds.append(tool_id)
		spec = _tool(tool_id, BONUS_TOOL_CHARGES)
	return spec
