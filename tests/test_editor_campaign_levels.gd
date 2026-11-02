extends Node
## The editor's developer tools for the campaign, on copies of level 12 (it
## has two entrances facing opposite ways) so the real levels and the
## player's progress are never touched:
## - opening a level brings its terrain, entrances (and their facing), exit,
##   lemming count and tools into the editor;
## - saving over it backs the old version up first, and the saved files are
##   what the game loads (terrain change, bricks, counts);
## - a backup opens again exactly as the level was, and saving it back
##   makes one more backup;
## - several entrances share the troop in a test run;
## - developer mode can open every campaign level and lock them again.

const LEVEL_INDEX := 11
const WORK_DIRECTORY := "user://test_editor_campaign/"
const EDITOR_SCENE := preload("res://scenes/editor/level_editor.tscn")
var _failures: Array[String] = []
var _editor: LevelEditorController
## Empty cells of level 12, painted to tell the saved level from the old
## one (found once it is open).
var _mark_cell := Vector2i.ZERO
var _brick_cell := Vector2i.ZERO


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run.call_deferred()


func _run() -> void:
	_prepare_copies()
	GameManager.developer_mode = true
	_editor = EDITOR_SCENE.instantiate()
	add_child(_editor)
	await get_tree().process_frame

	_check_open()
	await _check_save()
	_check_backup_round_trip()
	await _check_shared_troop()
	_check_unlock_all()

	GameManager.developer_mode = false
	_clean_up()
	var passed := _failures.is_empty()
	print("Editor campaign levels: %s" % ("PASS" if passed else "FAIL (%s)" % "; ".join(_failures)))
	get_tree().quit(0 if passed else 1)


## Level 12's two files copied into WORK_DIRECTORY, the copy of the data
## pointing at the copy of the scene, and Campaign reading from there.
func _prepare_copies() -> void:
	_clean_up()
	DirAccess.make_dir_recursive_absolute(WORK_DIRECTORY + "backups")
	var real_data := load(Campaign.level_path(LEVEL_INDEX)) as LevelData
	var scene_copy := WORK_DIRECTORY + "campaign_12.tscn"
	DirAccess.copy_absolute(real_data.scene_path, scene_copy)
	var data_copy := real_data.duplicate() as LevelData
	data_copy.scene_path = scene_copy
	ResourceSaver.save(data_copy, WORK_DIRECTORY + "campaign_12_data.tres")
	Campaign.level_data_pattern = WORK_DIRECTORY + "campaign_%02d_data.tres"
	Campaign.save_path = WORK_DIRECTORY + "progress.cfg"
	CampaignLevelStore.backup_directory = WORK_DIRECTORY + "backups/"


func _check_open() -> void:
	_editor.open_campaign_level(LEVEL_INDEX)
	var original := CampaignLevelStore.read(LEVEL_INDEX)
	_check(_editor.get_entrance_count() == 2, "opening level 12 brings its two entrances (got %d)" % _editor.get_entrance_count())
	var drawing := _editor.get_drawing()
	var facings: Array = drawing.entrances.map(func(entrance: Dictionary) -> bool: return entrance.faces_left)
	_check(facings.has(true) and facings.has(false), "one entrance faces left, the other right")
	_check(_editor.has_exit(), "and its exit")
	_check(drawing.total_lemmings == original.total_lemmings, "and its lemming count (%d)" % original.total_lemmings)
	var same_tools := true
	for tool_id in drawing.skill_counts:
		same_tools = same_tools and int(drawing.skill_counts[tool_id]) == int(original.skill_counts.get(tool_id, 0))
	_check(same_tools, "and its tools")
	_check(_editor.terrain.get_used_cells().size() == _cells_of(original).size(), "and every terrain cell")


func _find_empty_cells() -> void:
	for row in range(1, 40):
		for column in range(1, 70):
			if _is_empty(Vector2i(column, row)) and _is_empty(Vector2i(column + 2, row)):
				_mark_cell = Vector2i(column, row)
				_brick_cell = Vector2i(column + 2, row)
				return


func _is_empty(cell: Vector2i) -> bool:
	return _editor.terrain.get_cell_source_id(cell) == -1 and not _editor.terrain.is_solid_in_rect(Rect2(Vector2(cell) * _editor.terrain.get_cell_size(), _editor.terrain.get_cell_size()))


func _check_save() -> void:
	_find_empty_cells()
	_editor.terrain.build_cell_at(_cell_centre(_mark_cell), TerrainDestructible.TerrainMaterial.CONCRETE)
	var brick_at := _cell_centre(_brick_cell)
	_check(EditorBrush.new(_editor.terrain).paint_brick(brick_at), "a brick can be painted in the sky")
	_editor.toolbar.set_counts(7, {"digger": 4})
	var backup := _editor.save_campaign_level(LEVEL_INDEX)
	_check(backup != "", "saving over level 12 works")
	_check(FileAccess.file_exists(backup.path_join(CampaignLevelStore.BACKUP_SCENE_FILE)) and FileAccess.file_exists(backup.path_join(CampaignLevelStore.BACKUP_DATA_FILE)), "the old version is backed up (scene and data)")
	_check(CampaignLevelStore.list_backups(LEVEL_INDEX).size() == 1, "one backup listed")

	var data := Campaign.load_level_data(LEVEL_INDEX)
	_check(data.total_lemmings == 7 and data.available_skills == ["digger"] and int(data.skill_counts.digger) == 4, "the level's data has the new counts (got %d, %s)" % [data.total_lemmings, data.skill_counts])
	_check(data.level_name == (load(backup.path_join(CampaignLevelStore.BACKUP_DATA_FILE)) as LevelData).level_name, "and keeps its name")
	# The scene the game loads: the terrain enters the tree and lays its
	# bricks as in a level.
	var level := (load(data.scene_path) as PackedScene).instantiate()
	var terrain: TerrainDestructible = level.get_node("Terrain")
	_check(terrain.get_cell_source_id(_mark_cell) != -1, "the saved scene has the painted block")
	_check(terrain.initial_bricks.size() == 1, "and the brick")
	var spawns := level.get_children().filter(func(child: Node) -> bool: return child is SpawnPoint)
	_check(spawns.size() == 2 and spawns[0].lemming_count + spawns[1].lemming_count == 7, "the two entrances share the 7 lemmings")
	_check(level.get_children().any(func(child: Node) -> bool: return child is ExitPoint), "and the exit is there")
	level.free()
	await get_tree().process_frame


func _check_backup_round_trip() -> void:
	var backups := CampaignLevelStore.list_backups(LEVEL_INDEX)
	_editor.open_campaign_level(LEVEL_INDEX, backups[0].folder)
	_check(_editor.terrain.get_cell_source_id(_mark_cell) == -1, "the backup opens as the level was, without the painted block")
	_check(_editor.terrain.get_bricks().is_empty(), "and without the brick")
	_check(_editor.get_drawing().total_lemmings != 7, "and with its old lemming count")
	_check(_editor.save_campaign_level(LEVEL_INDEX) != "", "saving the backup back works")
	_check(CampaignLevelStore.list_backups(LEVEL_INDEX).size() == 2, "and backs up the version it replaces (2 backups)")
	var restored := (load(Campaign.load_level_data(LEVEL_INDEX).scene_path) as PackedScene).instantiate()
	_check((restored.get_node("Terrain") as TileMapLayer).get_cell_source_id(_mark_cell) == -1, "the level is back as it was")
	restored.free()


func _check_shared_troop() -> void:
	_editor.toolbar.set_counts(9, {})
	_editor.play()
	await get_tree().process_frame
	var spawns := _editor.play_session.get_children().filter(func(child: Node) -> bool: return child is SpawnPoint)
	_check(spawns.size() == 2, "a test run has both entrances")
	if spawns.size() == 2:
		_check(spawns[0].lemming_count + spawns[1].lemming_count == 9 and spawns[0].faces_left != spawns[1].faces_left, "sharing the troop and keeping their facing")
	_editor.restart()


func _check_unlock_all() -> void:
	Campaign.reset_progress()
	_check(not Campaign.is_unlocked(5), "without progress, level 6 is locked")
	Campaign.set_all_unlocked(true)
	_check(Campaign.is_unlocked(5) and not Campaign.is_cleared(5), "unlock all opens it without a star")
	Campaign.set_all_unlocked(false)
	_check(not Campaign.is_unlocked(5), "and it locks again")


func _cells_of(drawing: Dictionary) -> Array[Vector2i]:
	var layer := TileMapLayer.new()
	layer.tile_map_data = drawing.tile_map_data
	var cells := layer.get_used_cells()
	layer.free()
	return cells


func _cell_centre(cell: Vector2i) -> Vector2:
	return (Vector2(cell) + Vector2(0.5, 0.5)) * _editor.terrain.get_cell_size()


func _clean_up() -> void:
	Campaign.level_data_pattern = Campaign.LEVEL_DATA_PATH
	Campaign.save_path = Campaign.SAVE_PATH
	CampaignLevelStore.backup_directory = CampaignLevelStore.BACKUP_DIRECTORY
	if DirAccess.dir_exists_absolute(WORK_DIRECTORY):
		OS.move_to_trash(ProjectSettings.globalize_path(WORK_DIRECTORY))


func _check(condition: bool, description: String) -> void:
	print("  [%s] %s" % ["ok" if condition else "FAIL", description])
	if not condition:
		_failures.append(description)
