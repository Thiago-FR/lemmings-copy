class_name SaveSlots
extends RefCounted
## Saved games: SLOT_COUNT slots per game mode ("campaign", a game mode's
## own id), each a separate game with its own progress.
##
## A mode never writes into a slot directly. While a game is played its
## files live in the mode's working folder (working_path()); saving copies
## the working folder into the slot, loading copies the slot into the
## working folder. So turning off the automatic save really keeps the slot
## as it was until the player presses Save, whatever the mode writes in the
## meantime.
##
##   user://saves/<mode>/settings.cfg   automatic save on or off
##   user://saves/<mode>/working/       the game being played
##   user://saves/<mode>/slot_N/        a saved game, plus meta.cfg (when it
##                                      was saved and a one-line summary)
##
## Nothing here knows a mode's files: the mode reads and writes its own,
## under working_path(), and hands a summary for the slot list
## (open()'s summary_provider).

const SLOT_COUNT := 5
const ROOT := "user://saves/"
const WORKING_FOLDER := "working"
const META_FILE := "meta.cfg"
const SETTINGS_FILE := "settings.cfg"
const SECTION := "save"

## Where everything is kept. Tests point it elsewhere so they never touch
## the player's saves.
static var root := ROOT
## The mode and slot being played (open()); "" and -1 when none.
static var active_mode := ""
static var active_slot := -1
## Returns the one-line summary of the game being played, for the slot list.
static var summary_provider: Callable = Callable()


## Starts playing a slot: its files become the working copy (an empty slot
## starts a new game with none). A new game is saved at once, so the slot
## shows as taken.
static func open(mode: String, slot: int, provider: Callable = Callable()) -> void:
	assert(slot >= 0 and slot < SLOT_COUNT, "No save slot %d" % slot)
	active_mode = mode
	active_slot = slot
	summary_provider = provider
	var working := _working_directory(mode)
	FolderUtils.delete_folder(working)
	DirAccess.make_dir_recursive_absolute(working)
	var slot_directory := _slot_directory(mode, slot)
	if is_used(mode, slot):
		FolderUtils.copy_files(slot_directory, working, [META_FILE])
	else:
		save()


static func is_active(mode: String = "") -> bool:
	return active_mode != "" and active_slot >= 0 and (mode == "" or mode == active_mode)


## Stops playing a slot (back to the main menu): nothing is saved.
static func close() -> void:
	active_mode = ""
	active_slot = -1
	summary_provider = Callable()


## A file of the game being played (the mode decides the names).
static func working_path(file_name: String, mode: String = "") -> String:
	return _working_directory(mode if mode != "" else active_mode).path_join(file_name)


## Copies the game being played into its slot. False if no slot is open.
static func save() -> bool:
	if not is_active():
		return false
	var slot_directory := _slot_directory(active_mode, active_slot)
	FolderUtils.delete_folder(slot_directory)
	DirAccess.make_dir_recursive_absolute(slot_directory)
	FolderUtils.copy_files(_working_directory(active_mode), slot_directory, [])
	var meta := ConfigFile.new()
	meta.set_value(SECTION, "saved_at", Time.get_datetime_string_from_system(false, true))
	meta.set_value(SECTION, "summary", String(summary_provider.call()) if summary_provider.is_valid() else "")
	meta.save(slot_directory.path_join(META_FILE))
	return true


## Saves, unless the player turned the automatic save off for this mode.
## For the moments a mode reaches a point worth keeping (a level won, a
## stage finished).
static func auto_save() -> bool:
	if not is_active() or not is_auto_save_on(active_mode):
		return false
	return save()


static func is_used(mode: String, slot: int) -> bool:
	return FileAccess.file_exists(_slot_directory(mode, slot).path_join(META_FILE))


## {"saved_at": "YYYY-MM-DD HH:MM:SS", "summary": String} of a used slot.
static func get_info(mode: String, slot: int) -> Dictionary:
	var meta := ConfigFile.new()
	meta.load(_slot_directory(mode, slot).path_join(META_FILE))
	return {
		"saved_at": String(meta.get_value(SECTION, "saved_at", "")),
		"summary": String(meta.get_value(SECTION, "summary", "")),
	}


## "2026-11-06 18:04:29" -> "06/11/2026 18:04".
static func date_label(saved_at: String) -> String:
	var parts := saved_at.split(" ")
	if parts.size() < 2:
		return saved_at
	var day := parts[0].split("-")
	if day.size() < 3:
		return saved_at
	return "%s/%s/%s %s" % [day[2], day[1], day[0], parts[1].substr(0, 5)]


static func delete(mode: String, slot: int) -> void:
	FolderUtils.delete_folder(_slot_directory(mode, slot))


static func is_auto_save_on(mode: String) -> bool:
	var settings := ConfigFile.new()
	settings.load(_mode_directory(mode).path_join(SETTINGS_FILE))
	return bool(settings.get_value(SECTION, "auto_save", true))


static func set_auto_save(mode: String, enabled: bool) -> void:
	var path := _mode_directory(mode).path_join(SETTINGS_FILE)
	var settings := ConfigFile.new()
	settings.load(path)
	settings.set_value(SECTION, "auto_save", enabled)
	DirAccess.make_dir_recursive_absolute(_mode_directory(mode))
	settings.save(path)


## A game saved before there were slots (one file) becomes slot 1, once:
## only when the mode has no saves folder yet. summary: its line in the list.
static func adopt_legacy_file(mode: String, legacy_path: String, file_name: String, summary: String) -> void:
	if DirAccess.dir_exists_absolute(_mode_directory(mode)) or not FileAccess.file_exists(legacy_path):
		return
	var slot_directory := _slot_directory(mode, 0)
	DirAccess.make_dir_recursive_absolute(slot_directory)
	DirAccess.copy_absolute(legacy_path, slot_directory.path_join(file_name))
	var meta := ConfigFile.new()
	meta.set_value(SECTION, "saved_at", Time.get_datetime_string_from_system(false, true))
	meta.set_value(SECTION, "summary", summary)
	meta.save(slot_directory.path_join(META_FILE))


static func _mode_directory(mode: String) -> String:
	return root.path_join(mode)


static func _working_directory(mode: String) -> String:
	return _mode_directory(mode).path_join(WORKING_FOLDER)


static func _slot_directory(mode: String, slot: int) -> String:
	return _mode_directory(mode).path_join("slot_%d" % (slot + 1))
