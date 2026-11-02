class_name CampaignLevelStore
extends RefCounted
## Reads a campaign level into a plain drawing (the editor's "Modo livre"
## opens it) and writes a drawing over one of the 15 levels, developer mode
## only. Before a level is replaced, its two files (the scene and its
## LevelData) are copied to a backup folder of their own under
## BACKUP_DIRECTORY, so any earlier version can be opened again and saved
## back.
##
## A drawing is a Dictionary:
##   tile_map_data: PackedByteArray   the terrain's cells
##   bricks: Array[Rect2]             bridges and steps (world rects)
##   entrances: Array[Dictionary]     {"position": Vector2, "faces_left": bool}
##   exit: Vector2 or null            the exit's position
##   total_lemmings: int
##   skill_counts: Dictionary         tool id -> charges (0 = not offered)
##
## What the editor does not edit (name, hint, goal %, time, setting, release
## rate) is kept from the level being replaced.

const BACKUP_DIRECTORY := "user://campaign_backups/"
## Tests point it elsewhere.
static var backup_directory := BACKUP_DIRECTORY
const BACKUP_SCENE_FILE := "scene.tscn"
const BACKUP_DATA_FILE := "data.tres"
const LEVEL_MANAGER_SCRIPT := preload("res://scripts/level/level_manager.gd")
const TERRAIN_SCRIPT := preload("res://scripts/level/terrain_destructible.gd")
const TILE_SET := preload("res://resources/tilesets/terrain_tileset.tres")
const SPAWN_POINT_SCENE := preload("res://scenes/level/spawn_point.tscn")
const EXIT_POINT_SCENE := preload("res://scenes/level/exit_point.tscn")
const HUD_SCENE := preload("res://scenes/ui/hud.tscn")
const SKILL_PANEL_SCENE := preload("res://scenes/ui/skill_panel.tscn")
const RESULT_SCREEN_SCENE := preload("res://scenes/ui/level_result_screen.tscn")


## The level as it is now.
static func read(index: int) -> Dictionary:
	var data := _load_fresh(Campaign.level_path(index)) as LevelData
	return _read_files(data.scene_path, data)


## A backup folder (from list_backups) as a drawing.
static func read_backup(folder: String) -> Dictionary:
	var data := _load_fresh(folder.path_join(BACKUP_DATA_FILE)) as LevelData
	return _read_files(folder.path_join(BACKUP_SCENE_FILE), data)


## The level's backups, newest first: [{"folder", "label"}], the label
## being the date and time it was replaced.
static func list_backups(index: int) -> Array[Dictionary]:
	var backups: Array[Dictionary] = []
	var prefix := _backup_prefix(index)
	if not DirAccess.dir_exists_absolute(backup_directory):
		return backups
	for folder in DirAccess.get_directories_at(backup_directory):
		if folder.begins_with(prefix):
			backups.append({"folder": backup_directory + folder, "label": _label_of(folder.trim_prefix(prefix))})
	backups.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.folder > b.folder)
	return backups


## Writes the drawing over the level, after backing the level up. Returns
## the backup folder ("" if writing failed).
static func write(index: int, drawing: Dictionary) -> String:
	assert(drawing.entrances.size() > 0, "A level needs an entrance")
	var data_path := Campaign.level_path(index)
	var old_data := _load_fresh(data_path) as LevelData
	var backup := _back_up(index, old_data)
	if backup == "":
		return ""
	var packed := PackedScene.new()
	var root := _build_scene(index, drawing)
	var error := packed.pack(root)
	root.free()
	if error != OK or ResourceSaver.save(packed, old_data.scene_path) != OK:
		push_error("Could not write %s" % old_data.scene_path)
		return ""
	# The game keeps loaded resources cached: from now on the new ones are
	# what the paths give.
	packed.take_over_path(old_data.scene_path)
	var data := old_data.duplicate() as LevelData
	data.total_lemmings = drawing.total_lemmings
	var offered: Array[String] = []
	var counts := {}
	for tool_id in drawing.skill_counts:
		if int(drawing.skill_counts[tool_id]) > 0:
			offered.append(tool_id)
			counts[tool_id] = int(drawing.skill_counts[tool_id])
	data.available_skills = offered
	data.skill_counts = counts
	if ResourceSaver.save(data, data_path) != OK:
		push_error("Could not write %s" % data_path)
		return ""
	data.take_over_path(data_path)
	return backup


static func _read_files(scene_path: String, data: LevelData) -> Dictionary:
	var scene := (_load_fresh(scene_path) as PackedScene).instantiate()
	var drawing := {
		"tile_map_data": PackedByteArray(),
		"bricks": [] as Array[Rect2],
		"entrances": [] as Array[Dictionary],
		"exit": null,
		"total_lemmings": data.total_lemmings,
		"skill_counts": data.skill_counts.duplicate(),
		"environment_kind": data.environment_kind,
	}
	for child in scene.get_children():
		if child is TileMapLayer:
			drawing.tile_map_data = (child as TileMapLayer).tile_map_data
			drawing.bricks.assign(child.get("initial_bricks"))
		elif child is SpawnPoint:
			drawing.entrances.append({"position": child.position, "faces_left": child.faces_left})
		elif child is ExitPoint:
			drawing.exit = child.position
	scene.free()
	return drawing


static func _build_scene(index: int, drawing: Dictionary) -> Node2D:
	var root := Node2D.new()
	root.name = "Campaign%02d" % (index + 1)
	root.set_script(LEVEL_MANAGER_SCRIPT)
	var terrain := TileMapLayer.new()
	terrain.name = "Terrain"
	terrain.tile_set = TILE_SET
	terrain.set_script(TERRAIN_SCRIPT)
	terrain.tile_map_data = drawing.tile_map_data
	terrain.set("initial_bricks", drawing.bricks)
	_add_owned(root, terrain)
	var entrances: Array = drawing.entrances
	for entrance_index in entrances.size():
		var spawn := SPAWN_POINT_SCENE.instantiate()
		spawn.position = entrances[entrance_index].position
		spawn.faces_left = entrances[entrance_index].faces_left
		# One entrance releases the whole troop; several share it.
		if entrances.size() > 1:
			spawn.lemming_count = _share(drawing.total_lemmings, entrances.size(), entrance_index)
		_add_owned(root, spawn)
	if drawing.exit != null:
		var exit_point := EXIT_POINT_SCENE.instantiate()
		exit_point.position = drawing.exit
		_add_owned(root, exit_point)
	_add_owned(root, HUD_SCENE.instantiate())
	_add_owned(root, SKILL_PANEL_SCENE.instantiate())
	_add_owned(root, RESULT_SCREEN_SCENE.instantiate())
	return root


## The troop split as evenly as possible, the first entrances taking the
## remainder.
static func _share(total: int, parts: int, part: int) -> int:
	return total / parts + (1 if part < total % parts else 0)


static func _back_up(index: int, data: LevelData) -> String:
	var stamp := Time.get_datetime_string_from_system(false, true).replace(":", "-").replace(" ", "_")
	var folder := backup_directory + _backup_prefix(index) + stamp
	# Two saves in the same second keep both versions.
	var repeat := 2
	while DirAccess.dir_exists_absolute(folder):
		folder = backup_directory + _backup_prefix(index) + "%s_%d" % [stamp, repeat]
		repeat += 1
	if DirAccess.make_dir_recursive_absolute(folder) != OK:
		push_error("Could not make %s" % folder)
		return ""
	var copied_scene := DirAccess.copy_absolute(data.scene_path, folder.path_join(BACKUP_SCENE_FILE))
	var copied_data := DirAccess.copy_absolute(Campaign.level_path(index), folder.path_join(BACKUP_DATA_FILE))
	if copied_scene != OK or copied_data != OK:
		push_error("Could not back up level %d into %s" % [index + 1, folder])
		return ""
	return folder


static func _backup_prefix(index: int) -> String:
	return "campaign_%02d_" % (index + 1)


## "2026-11-02_18-04-29" -> "02/11/2026 18:04".
static func _label_of(stamp: String) -> String:
	var parts := stamp.split("_")
	if parts.size() < 2:
		return stamp
	var day := parts[0].split("-")
	var time := parts[1].split("-")
	if day.size() < 3 or time.size() < 2:
		return stamp
	return "%s/%s/%s %s:%s" % [day[2], day[1], day[0], time[0], time[1]]


static func _load_fresh(path: String) -> Resource:
	return ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REPLACE)


static func _add_owned(root: Node, child: Node) -> void:
	root.add_child(child)
	child.owner = root
