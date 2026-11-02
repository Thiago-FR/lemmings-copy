extends Node
## Automated check of the campaign ("Fases") around its levels. Run via:
##   godot --headless res://tests/test_campaign.tscn
## Exits 0 when every check passes, 1 otherwise.
##
## Checked (each level being winnable is tests/test_campaign_<nn>):
##   - all 15 levels load, with a scene, tools, a goal, a time limit, the
##     standard size, and one setting per group of three;
##   - progress: only the first level is open at first; a win clears a level,
##     opens the next and keeps the best percentage;
##   - the level select shows the 15 buttons: won ones with a star, the
##     next one open, the rest locked;
##   - winning a campaign level records the win and offers the next level;
##     losing does not;
##   - a level with more than one entrance splits its lemmings between them;
##   - winning the last level offers the congratulations screen, which shows
##     the credits and leads back to the level select; the level select
##     offers it only once every level is won;
##   - the main menu has the "Fases" button.
## Progress is written to a file of its own, never the player's.

const TEST_SAVE_PATH := "user://test_campaign.cfg"
const MAIN_MENU_SCENE_PATH := "res://scenes/main/main_menu.tscn"
const MIN_COLUMNS := 80
const MIN_ROWS := 45

var _failures: Array[String] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Campaign.save_path = TEST_SAVE_PATH
	Campaign.reset_progress()
	_run.call_deferred()


func _run() -> void:
	get_tree().current_scene = null
	_check_levels()
	_check_progress()
	await _check_select_screen()
	await _check_result_screen()
	await _check_last_level_result()
	await _check_complete_screen()
	await _check_main_menu()
	_finish()


func _check_levels() -> void:
	var names := {}
	for index in Campaign.LEVEL_COUNT:
		var data := Campaign.load_level_data(index)
		if data == null:
			_fail("level %d does not load" % (index + 1))
			continue
		if Campaign.index_of(data) != index:
			_fail("level %d is not found at its own index" % (index + 1))
		if names.has(data.level_name) or data.level_name.is_empty():
			_fail("level %d has an empty or repeated name" % (index + 1))
		names[data.level_name] = true
		if data.available_skills.is_empty() or data.total_lemmings <= 0 or data.time_limit_seconds <= 0:
			_fail("level %d has no tools, lemmings or time" % (index + 1))
		if data.required_percentage <= 0.0 or data.required_percentage > 1.0:
			_fail("level %d has a goal of %.2f" % [index + 1, data.required_percentage])
		for tool_id in data.available_skills:
			if int(data.skill_counts.get(tool_id, 0)) <= 0 or not SkillManager.has_skill(tool_id):
				_fail("level %d offers '%s' without charges or unknown" % [index + 1, tool_id])
		var first_of_world := Campaign.load_level_data(index - index % Campaign.LEVELS_PER_WORLD)
		if first_of_world.environment_kind != data.environment_kind:
			_fail("level %d is not in the setting of its group" % (index + 1))
		var scene := load(data.scene_path) as PackedScene
		if scene == null:
			_fail("level %d has no scene" % (index + 1))
			continue
		var root := scene.instantiate()
		_check_entrances(index, data, root)
		var terrain := root.get_node("Terrain") as TileMapLayer
		var used := terrain.get_used_rect()
		if used.size.x < MIN_COLUMNS or used.size.y < MIN_ROWS:
			_fail("level %d is %dx%d blocks, smaller than the standard" % [index + 1, used.size.x, used.size.y])
		root.free()


## Every entrance releases its own share (lemming_count) when there are
## several, and the shares add up to the level's total.
func _check_entrances(index: int, data: LevelData, root: Node) -> void:
	var entrances: Array[SpawnPoint] = []
	for child in root.get_children():
		if child is SpawnPoint:
			entrances.append(child)
	if entrances.is_empty():
		_fail("level %d has no entrance" % (index + 1))
	if entrances.size() < 2:
		return
	var total := 0
	for entrance in entrances:
		total += entrance.lemming_count
		if entrance.lemming_count <= 0:
			_fail("level %d has an entrance without its own count" % (index + 1))
	if total != data.total_lemmings:
		_fail("level %d's entrances release %d lemmings, not %d" % [index + 1, total, data.total_lemmings])


func _check_progress() -> void:
	if not Campaign.is_unlocked(0) or Campaign.is_unlocked(1):
		_fail("at first only the first level should be open")
	Campaign.record_win(0, 0.8)
	Campaign.record_win(0, 0.7)
	if not Campaign.is_cleared(0) or not Campaign.is_unlocked(1) or Campaign.is_unlocked(2):
		_fail("winning level 1 should clear it and open level 2 only")
	if absf(Campaign.best_percentage(0) - 0.8) > 0.001:
		_fail("the best percentage was not kept (%.2f)" % Campaign.best_percentage(0))
	if Campaign.current_index() != 1:
		_fail("the current level should be 2, is %d" % (Campaign.current_index() + 1))


func _check_select_screen() -> void:
	var screen := (load(Campaign.SELECT_SCENE_PATH) as PackedScene).instantiate() as CampaignSelectScreen
	add_child(screen)
	await get_tree().process_frame
	var cleared := screen.get_level_button(0)
	var next := screen.get_level_button(1)
	var locked := screen.get_level_button(2)
	if cleared.disabled or cleared.icon != UiStyle.icon("star"):
		_fail("a won level should be open and show a star")
	if next.disabled or next.theme_type_variation != UiStyle.PRIMARY_BUTTON:
		_fail("the next level should be open and green")
	if not locked.disabled or locked.icon != UiStyle.icon("lock"):
		_fail("a level not reached yet should be locked")
	if screen.get_level_button(Campaign.LEVEL_COUNT - 1).tooltip_text.is_empty():
		_fail("a level button should name its level in the tooltip")
	screen.queue_free()
	await get_tree().process_frame


## Plays no level: plays the level's ending by hand, the way LevelManager
## announces it, and reads the result screen.
func _check_result_screen() -> void:
	for won in [false, true]:
		var data := Campaign.load_level_data(1)
		GameManager.current_level_data = data
		var level := (load(data.scene_path) as PackedScene).instantiate()
		add_child(level)
		await get_tree().process_frame
		var manager := level as LevelManager
		if won:
			manager.level_completed.emit(1.0)
		else:
			manager.level_failed.emit(0.1)
		var next := level.find_child("NextButton", true, false) as Button
		if next == null:
			_fail("the result screen has no next button")
		elif next.visible != won:
			_fail("the next button should show only after a win (won: %s)" % won)
		if Campaign.is_cleared(1) != won:
			_fail("level 2 cleared should follow the result (won: %s)" % won)
		get_tree().paused = false
		level.queue_free()
		await get_tree().process_frame


func _check_last_level_result() -> void:
	var last := Campaign.LEVEL_COUNT - 1
	var data := Campaign.load_level_data(last)
	GameManager.current_level_data = data
	var level := (load(data.scene_path) as PackedScene).instantiate()
	add_child(level)
	await get_tree().process_frame
	(level as LevelManager).level_completed.emit(1.0)
	var next := level.find_child("NextButton", true, false) as Button
	if next == null or not next.visible or next.icon != UiStyle.icon("star"):
		_fail("winning the last level should offer the congratulations")
	get_tree().paused = false
	level.queue_free()
	await get_tree().process_frame


## The level select offers the congratulations only once every level is
## won; the screen itself shows the credits and leads back to the select.
func _check_complete_screen() -> void:
	var screen := (load(Campaign.SELECT_SCENE_PATH) as PackedScene).instantiate()
	add_child(screen)
	await get_tree().process_frame
	if screen.find_child("CompleteButton", true, false) != null:
		_fail("the congratulations should not be offered before every level is won")
	screen.queue_free()
	for index in Campaign.LEVEL_COUNT:
		Campaign.record_win(index, 1.0)
	if not Campaign.is_complete():
		_fail("every level won should complete the campaign")
	screen = (load(Campaign.SELECT_SCENE_PATH) as PackedScene).instantiate()
	add_child(screen)
	await get_tree().process_frame
	if screen.find_child("CompleteButton", true, false) == null:
		_fail("once every level is won, the level select should offer the congratulations")
	screen.queue_free()
	var complete := (load(Campaign.COMPLETE_SCENE_PATH) as PackedScene).instantiate() as CampaignCompleteScreen
	add_child(complete)
	await get_tree().process_frame
	if complete.find_child("Credits", true, false) == null:
		_fail("the congratulations screen has no credits")
	if complete.get_back_button() == null:
		_fail("the congratulations screen has no way back to the levels")
	complete.queue_free()
	await get_tree().process_frame


func _check_main_menu() -> void:
	var menu := (load(MAIN_MENU_SCENE_PATH) as PackedScene).instantiate()
	add_child(menu)
	await get_tree().process_frame
	if menu.find_child("CampaignButton", true, false) == null:
		_fail("the main menu has no Fases button")
	menu.queue_free()
	await get_tree().process_frame


func _fail(message: String) -> void:
	_failures.append(message)
	print("  FAIL: " + message)


func _finish() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE_PATH))
	get_tree().paused = false
	print("Campaign: %s" % ("PASS" if _failures.is_empty() else "FAIL (%d)" % _failures.size()))
	get_tree().quit(0 if _failures.is_empty() else 1)
