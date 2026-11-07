class_name RoguelikeRunState
extends RefCounted
## Everything a run carries from stage to stage: the troop (one character
## id per lemming), the lemmings lost along the way, the tool bar, the
## relics, the rescues in hand and which stage comes next. Pure data and
## rules, no nodes, so it can be tested on its own.

## One stage per biome stage of the core's generator: ten settings in a
## fixed order, three stages each.
## Every stage of every biome (BiomeStageGenerator).
static func stage_count() -> int:
	return BiomeStageGenerator.stage_count()


# --- Stages (maze generator) ---
## The run's seed: each stage is generated from it and its index, so a run
## can be replayed.
var seed_value := 0
## Hand-made labyrinths instead of generated stages (developer screen).
var use_handmade_stages := false
## The developer screen's choice, kept for the next runs of the session.
static var prefer_handmade_stages := false
## Stages already made, by index (made once, when first asked for).
var stage_definitions: Dictionary = {}
# --- end Stages ---

## The character chosen for the run: the troop, and every recruit, is made
## of it (the user saw no point in mixing characters in a stage).
var character_id: StringName = RoguelikeCharacters.STARTER
## Character ids in spawn order.
var troop: Array[StringName] = []
## Lost lemmings, most recent last; rescues bring them back from the end.
var fallen: Array[StringName] = []
var unlocked_characters: Array[StringName] = []
## Relics owned, in the order they were first taken, and the level of each
## (RoguelikeRelics: taking one again raises its level).
var relics: Array[StringName] = []
var relic_levels: Dictionary = {}
var revive_tokens := 0
var inventory := ToolInventory.new()
## Index of the stage being played or about to be played.
var stage_index := 0
var lemmings_saved_total := 0

## What the lemmings saved earn (the user wanted the number of lemmings to
## pay off): coins to spend in the shop between stages, and the run's score,
## worth more the deeper the stage.
const COINS_PER_SAVED := 3
## A sacrificed lemming (one stuck for good) still leaves a coin behind: a
## reason to end a hopeless wait instead of sitting out the clock, and far
## below what saving it gives (COINS_PER_SAVED plus the lemming itself), so
## sacrificing never pays better than getting a lemming out.
const COINS_PER_SACRIFICED := 1
const SCORE_PER_SAVED := 10
## Every second left on the clock when a stage ends is worth this many
## points per stage number: finishing fast pays, so the clock matters even
## when there is time to spare.
const SCORE_PER_SECOND_LEFT := 1
## Seconds left on the clock when the stage just played ended (set by the
## stage session); cleared once counted.
var last_time_left := 0.0
var coins := 0
var score := 0
## Whether the stage just finished was cleared without losing anyone: the
## reward is then a choice of four cards instead of three.
var last_stage_perfect := false


static func new_run(character: StringName = RoguelikeCharacters.STARTER) -> RoguelikeRunState:
	assert(RoguelikeCharacters.DEFINITIONS.has(character), "Unknown character '%s'" % character)
	var state := RoguelikeRunState.new()
	state.character_id = character
	state.troop.append(character)
	state.unlocked_characters.append(character)
	state.seed_value = randi()
	state.use_handmade_stages = prefer_handmade_stages
	return state


## The run as plain data, for a saved game (RoguelikeRunController keeps
## it between stages). The stages are not in it: they are made again from
## the seed.
func to_dictionary() -> Dictionary:
	var levels := {}
	for relic_id in relic_levels:
		levels[String(relic_id)] = int(relic_levels[relic_id])
	return {
		"seed_value": seed_value,
		"use_handmade_stages": use_handmade_stages,
		"character_id": String(character_id),
		"troop": _strings(troop),
		"fallen": _strings(fallen),
		"unlocked_characters": _strings(unlocked_characters),
		"relics": _strings(relics),
		"relic_levels": levels,
		"revive_tokens": revive_tokens,
		"inventory": inventory.to_dictionary(),
		"stage_index": stage_index,
		"lemmings_saved_total": lemmings_saved_total,
		"last_time_left": last_time_left,
		"coins": coins,
		"score": score,
		"last_stage_perfect": last_stage_perfect,
	}


## A run as to_dictionary() wrote it.
static func from_dictionary(data: Dictionary) -> RoguelikeRunState:
	var state := RoguelikeRunState.new()
	state.seed_value = int(data.seed_value)
	state.use_handmade_stages = bool(data.get("use_handmade_stages", false))
	state.character_id = StringName(data.character_id)
	state.troop = _names(data.troop)
	state.fallen = _names(data.fallen)
	state.unlocked_characters = _names(data.unlocked_characters)
	state.relics = _names(data.relics)
	for relic_id in data.relic_levels:
		state.relic_levels[StringName(relic_id)] = int(data.relic_levels[relic_id])
	state.revive_tokens = int(data.revive_tokens)
	state.inventory = ToolInventory.from_dictionary(data.inventory)
	state.stage_index = int(data.stage_index)
	state.lemmings_saved_total = int(data.lemmings_saved_total)
	state.last_time_left = float(data.get("last_time_left", 0.0))
	state.coins = int(data.coins)
	state.score = int(data.score)
	state.last_stage_perfect = bool(data.get("last_stage_perfect", false))
	return state


static func _strings(names: Array[StringName]) -> Array:
	var result := []
	for name in names:
		result.append(String(name))
	return result


static func _names(strings: Array) -> Array[StringName]:
	var result: Array[StringName] = []
	for text in strings:
		result.append(StringName(text))
	return result


## The stage at stage_index: generated from the run's seed (harder with every
## stage) or hand-made, made the first time it is asked for.
func get_stage_definition() -> RoguelikeStageDefinition:
	if not stage_definitions.has(stage_index):
		# The hand-made labyrinths are fewer than the run's stages.
		if use_handmade_stages and stage_index < RoguelikeHandmadeStages.STAGE_COUNT:
			stage_definitions[stage_index] = RoguelikeStageFactory.handmade(stage_index)
		else:
			stage_definitions[stage_index] = RoguelikeStageFactory.procedural(seed_value, stage_index)
	return stage_definitions[stage_index]


## Starts making the next stage in the background (drawing a stage and
## checking it can be won takes a while), while this one is played.
func prefetch_next_stage() -> void:
	if stage_index + 1 < stage_count() and not (use_handmade_stages and stage_index + 1 < RoguelikeHandmadeStages.STAGE_COUNT):
		RoguelikeStageFactory.prefetch(seed_value, stage_index + 1)


## Switches between generated and hand-made stages; stages already made are
## dropped so the next one comes from the new source.
func set_handmade_stages(enabled: bool) -> void:
	use_handmade_stages = enabled
	prefer_handmade_stages = enabled
	stage_definitions.clear()


## Plays the run's stages from another seed (the developer screen, to make
## again a stage someone reported); stages already made are dropped.
func set_seed(new_seed: int) -> void:
	seed_value = new_seed
	stage_definitions.clear()


func is_over() -> bool:
	return troop.is_empty()


func is_won() -> bool:
	return stage_index >= stage_count()


## What happened in a stage: who got out and who did not. Survivors are the
## new troop, the rest join the fallen, rescues in hand bring back the most
## recent losses, empty tool slots are freed, and the stage counter moves on.
## Returns the characters brought back by rescues.
func finish_stage(saved: Array[StringName], lost: Array[StringName]) -> Array[StringName]:
	troop = saved.duplicate()
	fallen.append_array(lost)
	lemmings_saved_total += saved.size()
	coins += saved.size() * coins_per_saved()
	score += saved.size() * SCORE_PER_SAVED * (stage_index + 1)
	if not saved.is_empty():
		score += time_bonus()
	last_time_left = 0.0
	last_stage_perfect = lost.is_empty() and not saved.is_empty()
	var revived := use_revive_tokens()
	inventory.remove_empty_slots()
	if not troop.is_empty():
		stage_index += 1
	return revived


## Spends rescues on the most recently lost lemmings, while there are both.
func use_revive_tokens() -> Array[StringName]:
	var revived: Array[StringName] = []
	while revive_tokens > 0 and not fallen.is_empty():
		revive_tokens -= 1
		var character: StringName = fallen.pop_back()
		troop.append(character)
		revived.append(character)
	return revived


## The lemming who joins for clearing the stage just finished: one more of
## the run's character, after each of the first stages (as many as there
## are characters to buy, so the troop grows the same as before), or &""
## past those.
func recruit_for_cleared_stage() -> StringName:
	var join_index := stage_index - 1
	if join_index < 0 or join_index >= RoguelikeCharacters.UNLOCK_ORDER.size():
		return &""
	recruit(character_id)
	return character_id


## Pays for something in the shop. False (and nothing spent) if there are
## not enough coins.
func spend_coins(amount: int) -> bool:
	if amount > coins:
		return false
	coins -= amount
	return true


func recruit(character: StringName) -> void:
	troop.append(character)
	if not unlocked_characters.has(character):
		unlocked_characters.append(character)


## Takes a relic, or raises its level if owned (up to MAX_LEVEL).
func add_relic(relic_id: StringName) -> void:
	var level := get_relic_level(relic_id)
	if level >= RoguelikeRelics.MAX_LEVEL:
		return
	if level == 0:
		relics.append(relic_id)
	relic_levels[relic_id] = level + 1
	if relic_id == RoguelikeRelics.EXTRA_POCKET:
		inventory.add_slot()


## Takes a relic away (developer screen).
func remove_relic(relic_id: StringName) -> void:
	relics.erase(relic_id)
	relic_levels.erase(relic_id)


func get_relic_level(relic_id: StringName) -> int:
	return int(relic_levels.get(relic_id, 0))


## Points for the seconds left in the stage just played (only counted when
## someone got out).
func time_bonus() -> int:
	return int(floor(last_time_left)) * SCORE_PER_SECOND_LEFT * (stage_index + 1)


## Coins each saved lemming earns: the base, plus the Greed relic's level.
func coins_per_saved() -> int:
	return COINS_PER_SAVED + get_relic_level(RoguelikeRelics.GREED)
