extends Node
## Backups of the free mode's drawings: saving over a slot keeps only the
## newest LevelCollection.MAX_BACKUPS versions (older ones are deleted from
## disk), and the list of versions scrolls instead of running off the
## screen. Works in folders of its own; never touches the player's drawings
## or backups. Run via:
##   godot --headless res://tests/test_editor_backups.tscn
## Exits 0 on success, 1 otherwise.

const TEST_DIRECTORY := "user://test_editor_backups/"
const TEST_BACKUP_ROOT := "user://test_editor_backups_old/"
const SAVES := 8

var _failures: Array[String] = []


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	_clear(TEST_DIRECTORY)
	_clear(TEST_BACKUP_ROOT)
	FreeLevelCollection.directory = TEST_DIRECTORY
	LevelCollection.backup_root = TEST_BACKUP_ROOT
	var collection := FreeLevelCollection.new()
	for save in SAVES:
		var drawing := LevelDrawing.new().to_dictionary()
		drawing.total_lemmings = save + 1
		collection.write(0, drawing)
	var backups := collection.list_backups(0)
	_expect(backups.size() == LevelCollection.MAX_BACKUPS, "%d saves keep %d backups, got %d" % [SAVES, LevelCollection.MAX_BACKUPS, backups.size()])
	var on_disk := DirAccess.get_directories_at(TEST_BACKUP_ROOT.path_join("free").path_join("slot_01"))
	_expect(on_disk.size() == LevelCollection.MAX_BACKUPS, "the older backups are deleted from disk, %d left" % on_disk.size())
	if not backups.is_empty():
		var newest := collection.read_backup(String(backups[0].folder))
		_expect(int(newest.get("total_lemmings", -1)) == SAVES - 1, "the newest backup is the version before the last save, got %s" % newest.get("total_lemmings"))
	await _check_versions_scroll(collection)
	_clear(TEST_DIRECTORY)
	_clear(TEST_BACKUP_ROOT)
	FreeLevelCollection.directory = FreeLevelCollection.DIRECTORY
	LevelCollection.backup_root = LevelCollection.BACKUP_ROOT
	_finish()


## Many versions (more than a slot keeps, as if listed before the cap) do
## not make the panel taller than the screen: the list scrolls.
func _check_versions_scroll(collection: FreeLevelCollection) -> void:
	var picker := EditorLevelPicker.new(EditorLevelPicker.Purpose.OPEN, collection, 0)
	add_child(picker)
	await get_tree().process_frame
	var many: Array[Dictionary] = []
	for index in 40:
		many.append({"folder": "none_%d" % index, "label": "01/01/2026 00:%02d" % index})
	picker._show_versions(collection, 0, many)
	await get_tree().process_frame
	var scroll := picker.find_child("Scroll", true, false) as ScrollContainer
	_expect(scroll != null, "the versions are in a scrolling list")
	if scroll != null:
		var limit := get_viewport().get_visible_rect().size.y * EditorLevelPicker.LIST_MAX_SCREEN_SHARE
		_expect(scroll.size.y <= limit + 1.0, "the list is no taller than %.0f, got %.0f" % [limit, scroll.size.y])
		_expect(scroll.find_child("Current", true, false) != null, "the current version is in the list")
	picker.queue_free()


func _clear(directory: String) -> void:
	if DirAccess.dir_exists_absolute(directory):
		FolderUtils.delete_folder(directory)


func _expect(condition: bool, description: String) -> void:
	if not condition:
		_failures.append(description)


func _finish() -> void:
	if _failures.is_empty():
		print("test_editor_backups: OK")
		get_tree().quit(0)
	else:
		for failure in _failures:
			print("FAIL: ", failure)
		get_tree().quit(1)
