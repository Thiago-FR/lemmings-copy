class_name LevelCollection
extends RefCounted
## A set of numbered level slots the editor can open from and save into:
## the free mode's own drawings, the campaign's 15 levels, a game mode's
## stages. The editor lists every collection by itself (all()): the core's,
## plus one from each game mode that has a res://modes/<mode>/level_collection.gd
## extending this class (the core never names a mode).
##
## Saving over a slot backs up what was there first, so any version can be
## opened again (list_backups / read_backup) and saved back. Only the newest
## MAX_BACKUPS of a slot are kept (keep_newest_backups): every save made a
## new one, and a slot saved often listed so many the list ran off the
## screen.

const MODES_DIRECTORY := "res://modes/"
const MODE_COLLECTION_FILE := "level_collection.gd"
const BACKUP_ROOT := "user://level_backups/"
## Tests point it elsewhere.
static var backup_root := BACKUP_ROOT
## Backups kept per slot; older ones are deleted.
const MAX_BACKUPS := 5


## Every collection the editor can use now (some only in developer mode).
static func all() -> Array[LevelCollection]:
	var collections: Array[LevelCollection] = [FreeLevelCollection.new(), CampaignLevelCollection.new()]
	for mode in DirAccess.get_directories_at(MODES_DIRECTORY):
		var path := MODES_DIRECTORY.path_join(mode).path_join(MODE_COLLECTION_FILE)
		if ResourceLoader.exists(path):
			var collection = load(path).new()
			if collection is LevelCollection:
				collections.append(collection)
	return collections.filter(func(collection: LevelCollection) -> bool:
		return GameManager.developer_mode or not collection.requires_developer_mode())


# --- To override ---------------------------------------------------------------

func get_display_name() -> String:
	return ""


func get_icon_id() -> String:
	return "campaign"


## Only offered in developer mode (levels that ship with the game).
func requires_developer_mode() -> bool:
	return true


func get_slot_count() -> int:
	return 0


## The level's name in a slot, for the tooltip ("" for an empty slot).
func get_slot_name(_index: int) -> String:
	return ""


## Whether there is something to open in the slot.
func has_level(index: int) -> bool:
	return get_slot_name(index) != ""


## The level in the slot as an editor drawing.
func read(_index: int) -> Dictionary:
	return {}


## Writes a drawing over the slot (backing up what was there). Returns the
## backup folder, or "" if nothing was written.
func write(_index: int, _drawing: Dictionary) -> String:
	return ""


## Backups of a slot, newest first: [{"folder", "label"}]. Older ones than
## the newest MAX_BACKUPS are deleted on the way.
func list_backups(index: int) -> Array[Dictionary]:
	return keep_newest_backups(_list_backups_in(_backup_directory(index)))


## Deletes the backup folders past the newest MAX_BACKUPS of a list sorted
## newest first, and returns the ones kept.
static func keep_newest_backups(backups: Array[Dictionary]) -> Array[Dictionary]:
	for index in range(MAX_BACKUPS, backups.size()):
		FolderUtils.delete_folder(String(backups[index].folder))
	return backups.slice(0, MAX_BACKUPS)


func read_backup(_folder: String) -> Dictionary:
	return {}


# --- Shared --------------------------------------------------------------------

## A short name used for this collection's backup folder.
func _backup_id() -> String:
	return "collection"


func _backup_directory(index: int) -> String:
	return backup_root.path_join(_backup_id()).path_join("slot_%02d" % (index + 1))


## Copies the given files into a new dated folder of the slot's backups.
## Returns the folder ("" on failure); nothing to copy gives "".
func _back_up_files(index: int, paths: Array[String]) -> String:
	var existing := paths.filter(func(path: String) -> bool: return FileAccess.file_exists(path))
	if existing.is_empty():
		return ""
	var stamp := Time.get_datetime_string_from_system(false, true).replace(":", "-").replace(" ", "_")
	var folder := _backup_directory(index).path_join(_new_backup_name(index, stamp))
	if DirAccess.make_dir_recursive_absolute(folder) != OK:
		return ""
	for path in existing:
		if DirAccess.copy_absolute(path, folder.path_join(path.get_file())) != OK:
			return ""
	return folder


## A folder name that sorts after every backup of the slot: the stamp, or
## for a second save within the same second the stamp and a number past
## the highest one there. Reusing a free name instead ("stamp" again once
## the oldest backups were deleted) sorted the newest backup as the oldest,
## and it was the next one deleted.
func _new_backup_name(index: int, stamp: String) -> String:
	var directory := _backup_directory(index)
	if not DirAccess.dir_exists_absolute(directory):
		return stamp
	var highest := -1
	for folder in DirAccess.get_directories_at(directory):
		if folder == stamp:
			highest = maxi(highest, 1)
		elif folder.begins_with(stamp + "_"):
			highest = maxi(highest, folder.trim_prefix(stamp + "_").to_int())
	return stamp if highest < 0 else "%s_%03d" % [stamp, highest + 1]


static func _list_backups_in(directory: String) -> Array[Dictionary]:
	var backups: Array[Dictionary] = []
	if not DirAccess.dir_exists_absolute(directory):
		return backups
	for folder in DirAccess.get_directories_at(directory):
		backups.append({"folder": directory.path_join(folder), "label": backup_label(folder)})
	backups.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.folder > b.folder)
	return backups


## "2026-11-02_18-04-29" -> "02/11/2026 18:04".
static func backup_label(stamp: String) -> String:
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
