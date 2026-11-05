class_name Campaign
extends RefCounted
## The campaign ("Fases"): its levels in order, and the player's progress
## through them, saved in user://campaign.cfg. The first level is always
## open; winning a level clears it and opens the next one.
##
## Every level is drawn by hand (tools/campaign/level_NN.gd, written into the
## game by tools/build_handmade_campaign.tscn), numbered from 1; everything
## here takes a zero-based index. The first three teach and stay in the
## meadow; then three levels for each landscape, in the biomes' order.

const LEVEL_COUNT := 33
const LEVEL_DATA_PATH := "res://resources/levels/campaign/campaign_%02d_data.tres"
const SAVE_PATH := "user://campaign.cfg"
## The level select screen.
const SELECT_SCENE_PATH := "res://scenes/ui/campaign_select.tscn"
## The congratulations and credits, after the last level.
const COMPLETE_SCENE_PATH := "res://scenes/ui/campaign_complete.tscn"
const SECTION := "cleared"
## Developer mode: every level open without having won the one before
## (the stars stay true to what was really won).
const DEVELOPER_SECTION := "developer"
const ALL_UNLOCKED_KEY := "all_unlocked"
## Levels per setting (each biome has three): the level select screen
## groups them this way.
const LEVELS_PER_WORLD := 3

## Where progress is read and written. Tests point it elsewhere so they never
## touch the player's own progress.
static var save_path := SAVE_PATH
## Where the levels' LevelData files are (a pattern taking the level
## number). Tests point it at copies so they never change the real levels.
static var level_data_pattern := LEVEL_DATA_PATH


static func level_path(index: int) -> String:
	assert(index >= 0 and index < LEVEL_COUNT, "No campaign level %d" % index)
	return level_data_pattern % (index + 1)


static func load_level_data(index: int) -> LevelData:
	return load(level_path(index)) as LevelData


## The index of a level in the campaign, or -1 if it is not one of them.
static func index_of(level_data: LevelData) -> int:
	if level_data == null:
		return -1
	for index in LEVEL_COUNT:
		if level_data.resource_path == level_path(index):
			return index
	return -1


static func is_cleared(index: int) -> bool:
	return _load().has_section_key(SECTION, _key(index))


static func is_unlocked(index: int) -> bool:
	return index == 0 or is_cleared(index - 1) or is_all_unlocked()


static func is_all_unlocked() -> bool:
	return bool(_load().get_value(DEVELOPER_SECTION, ALL_UNLOCKED_KEY, false))


## Developer mode: opens (or closes again) every level, without marking
## any as won.
static func set_all_unlocked(enabled: bool) -> void:
	var config := _load()
	config.set_value(DEVELOPER_SECTION, ALL_UNLOCKED_KEY, enabled)
	config.save(save_path)


## Best share of lemmings saved in a won level (0 to 1), 0 if never won.
static func best_percentage(index: int) -> float:
	return float(_load().get_value(SECTION, _key(index), 0.0))


## Records a win, keeping the best percentage.
static func record_win(index: int, percentage_saved: float) -> void:
	var config := _load()
	var best := maxf(float(config.get_value(SECTION, _key(index), 0.0)), percentage_saved)
	config.set_value(SECTION, _key(index), best)
	config.save(save_path)


static func has_next(index: int) -> bool:
	return index >= 0 and index + 1 < LEVEL_COUNT


## The first level not cleared yet (the last one once all are), where the
## level select screen starts.
static func current_index() -> int:
	for index in LEVEL_COUNT:
		if not is_cleared(index):
			return index
	return LEVEL_COUNT - 1


## Whether every level has been won.
static func is_complete() -> bool:
	for index in LEVEL_COUNT:
		if not is_cleared(index):
			return false
	return true


static func reset_progress() -> void:
	var config := ConfigFile.new()
	config.save(save_path)


static func _key(index: int) -> String:
	return "level_%02d" % (index + 1)


static func _load() -> ConfigFile:
	var config := ConfigFile.new()
	config.load(save_path)
	return config
