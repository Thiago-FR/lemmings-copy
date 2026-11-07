class_name FolderUtils
extends RefCounted
## Folders on disk (user://): deleting one with everything in it, copying
## the files of one into another.


## Deletes the folder and everything in it; nothing if it does not exist.
static func delete_folder(folder: String) -> void:
	if not DirAccess.dir_exists_absolute(folder):
		return
	for sub_folder in DirAccess.get_directories_at(folder):
		delete_folder(folder.path_join(sub_folder))
	for file in DirAccess.get_files_at(folder):
		DirAccess.remove_absolute(folder.path_join(file))
	DirAccess.remove_absolute(folder)


## Copies the files (not the sub-folders) of one folder into another,
## leaving out the names in skipped.
static func copy_files(from: String, to: String, skipped: Array = []) -> void:
	if not DirAccess.dir_exists_absolute(from):
		return
	for file in DirAccess.get_files_at(from):
		if not skipped.has(file):
			DirAccess.copy_absolute(from.path_join(file), to.path_join(file))
