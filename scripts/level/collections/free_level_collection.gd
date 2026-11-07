class_name FreeLevelCollection
extends LevelCollection
## The free mode's own drawings, kept on the player's machine
## (user://free_levels/level_NN.tres): the slots in use and one more,
## empty, to save a new drawing into. Anyone can use it.

const DIRECTORY := "user://free_levels/"
const MAX_SLOTS := 99
## Tests point it elsewhere.
static var directory := DIRECTORY


func get_display_name() -> String:
	return "Modo livre"


func get_icon_id() -> String:
	return "editor_earth"


func requires_developer_mode() -> bool:
	return false


func get_slot_count() -> int:
	var used := 0
	for index in MAX_SLOTS:
		if FileAccess.file_exists(_path(index)):
			used = index + 1
	return mini(used + 1, MAX_SLOTS)


func get_slot_name(index: int) -> String:
	return "Desenho %d" % (index + 1) if FileAccess.file_exists(_path(index)) else ""


func read(index: int) -> Dictionary:
	return (LevelCollection._load_fresh(_path(index)) as LevelDrawing).to_dictionary()


func write(index: int, drawing: Dictionary) -> String:
	var path := _path(index)
	var backup := _back_up_files(index, [path])
	list_backups(index)
	DirAccess.make_dir_recursive_absolute(directory)
	var file := LevelDrawing.from_dictionary(drawing)
	if ResourceSaver.save(file, path) != OK:
		return ""
	file.take_over_path(path)
	# A first save has nothing to back up: it still succeeded.
	return backup if backup != "" else path


func read_backup(folder: String) -> Dictionary:
	var files := DirAccess.get_files_at(folder)
	if files.is_empty():
		return {}
	return (LevelCollection._load_fresh(folder.path_join(files[0])) as LevelDrawing).to_dictionary()


func _backup_id() -> String:
	return "free"


func _path(index: int) -> String:
	return directory.path_join("level_%02d.tres" % (index + 1))
