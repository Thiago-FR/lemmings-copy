extends LevelCollection
## The roguelike's 30 stages, for the editor (developer mode). A stage
## nobody has drawn opens as the generator makes it (with seed 1); saving
## one in the editor makes it a fixed stage, kept in STAGE_DIRECTORY, that
## every run then plays in that place instead of a generated one
## (RoguelikeStageFactory asks override_maze()). The tools the drawing
## counts become items on the floors nearest the entrance.

const STAGE_DIRECTORY := "res://modes/roguelike/resources/stages/"
const PREVIEW_SEED := 1


func get_display_name() -> String:
	return "Roguelike"


func get_icon_id() -> String:
	return "give_up"


func get_slot_count() -> int:
	return RoguelikeRunState.stage_count()


func get_slot_name(index: int) -> String:
	var biome := BiomeStageGenerator.biome_of(index)
	var stage_name: String = biome.stages[BiomeStageGenerator.tier_of(index)]
	return "%s: %s%s" % [biome.name, stage_name, " (desenhada)" if FileAccess.file_exists(stage_path(index)) else ""]


func has_level(_index: int) -> bool:
	return true


func read(index: int) -> Dictionary:
	if FileAccess.file_exists(stage_path(index)):
		return (LevelCollection._load_fresh(stage_path(index)) as LevelDrawing).to_dictionary()
	return LevelDrawing.dictionary_from_maze(BiomeStageGenerator.generate(PREVIEW_SEED, index))


func write(index: int, drawing: Dictionary) -> String:
	var path := stage_path(index)
	var backup := _back_up_files(index, [path])
	DirAccess.make_dir_recursive_absolute(STAGE_DIRECTORY)
	var file := LevelDrawing.from_dictionary(drawing)
	if ResourceSaver.save(file, path) != OK:
		return ""
	file.take_over_path(path)
	return backup if backup != "" else path


func read_backup(folder: String) -> Dictionary:
	var files := DirAccess.get_files_at(folder)
	if files.is_empty():
		return {}
	return (LevelCollection._load_fresh(folder.path_join(files[0])) as LevelDrawing).to_dictionary()


func _backup_id() -> String:
	return "roguelike"


static func stage_path(index: int) -> String:
	return STAGE_DIRECTORY.path_join("stage_%02d.tres" % (index + 1))


## The stage drawn in the editor for that place, as stage data with its
## tool items, or null when the generator makes it.
static func override_maze(index: int) -> MazeStageData:
	if not FileAccess.file_exists(stage_path(index)):
		return null
	var drawing := (LevelCollection._load_fresh(stage_path(index)) as LevelDrawing).to_dictionary()
	if (drawing.entrances as Array).is_empty():
		return null
	var maze := LevelDrawing.maze_from_dictionary(drawing)
	# A generated stage saved as it was keeps its own items and solution.
	if not maze.item_spots.is_empty():
		if maze.stage_name.is_empty():
			maze.stage_name = BiomeStageGenerator.biome_of(index).stages[BiomeStageGenerator.tier_of(index)]
		return maze
	var floors: Array[Vector2i] = []
	for row in range(2, maze.rows - 1):
		for column in range(1, maze.columns - 1):
			if maze.is_solid(column, row) and not maze.is_solid(column, row - 1) and not maze.is_solid(column, row - 2):
				floors.append(Vector2i(column, row))
	floors.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.distance_squared_to(maze.spawn_cell) < b.distance_squared_to(maze.spawn_cell))
	var next := 1
	for tool_id in drawing.skill_counts:
		for charge in int(drawing.skill_counts[tool_id]):
			if next >= floors.size():
				break
			maze.item_spots.append({"column": floors[next].x, "row": floors[next].y, "kind": MazeLayout.SpotKind.TOOL, "tool_id": tool_id, "amount": 1, "required": false, "spot_index": maze.item_spots.size()})
			next += 2
	var biome := BiomeStageGenerator.biome_of(index)
	maze.stage_name = biome.stages[BiomeStageGenerator.tier_of(index)]
	maze.suggested_time_seconds = 300
	return maze
