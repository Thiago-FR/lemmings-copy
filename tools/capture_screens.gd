extends Node
## Saves screenshots of a level and of the editor at the window's size, to
## check layout and scale by eye. Needs a real renderer, so it cannot run
## headless; a window opens briefly. Run via:
##   godot --path . --windowed --resolution 1920x1080 res://tools/capture_screens.tscn -- <output dir>
## Writes level.png, editor.png and cards.png (the roguelike's reward
## screen) into the output directory.

const LEVEL_DATA_PATH := "res://resources/levels/level_07_data.tres"
const EDITOR_SCENE_PATH := "res://scenes/editor/level_editor.tscn"
const ROGUELIKE_SCENE_PATH := "res://modes/roguelike/scenes/roguelike_run.tscn"
## Long enough for the first lemmings to come out of the entrance.
const LEVEL_SETTLE_FRAMES := 240
const EDITOR_SETTLE_FRAMES := 30


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var output_dir: String = args[0] if not args.is_empty() else OS.get_user_data_dir()
	get_tree().current_scene = null

	LevelLoader.load_level(load(LEVEL_DATA_PATH))
	await _frames(LEVEL_SETTLE_FRAMES)
	_save(output_dir.path_join("level.png"))

	get_tree().change_scene_to_file(EDITOR_SCENE_PATH)
	await _frames(EDITOR_SETTLE_FRAMES)
	var editor := get_tree().current_scene as LevelEditorController
	if editor != null:
		var floor_y := editor.get_paint_area().end.y - 16.0
		editor.select_tool(EditorTool.Kind.BLOCK)
		editor.paint_line(Vector2(16, floor_y), Vector2(1200, floor_y))
		editor.select_tool(EditorTool.Kind.CONCRETE)
		editor.paint_line(Vector2(400, floor_y - 32), Vector2(400, floor_y - 160))
		await _frames(5)
	_save(output_dir.path_join("editor.png"))

	# The roguelike is a mode: reached only if its folder is there, and by
	# name rather than by class, so this core tool never depends on it.
	if ResourceLoader.exists(ROGUELIKE_SCENE_PATH):
		get_tree().change_scene_to_file(ROGUELIKE_SCENE_PATH)
		await _frames(EDITOR_SETTLE_FRAMES)
		var run := get_tree().current_scene
		if run != null and run.has_method("_offer_rewards"):
			run.call("_offer_rewards", "Salvos: 3   Perdidos: 1")
			await _frames(5)
		_save(output_dir.path_join("cards.png"))
	get_tree().quit()


func _save(path: String) -> void:
	var image := get_viewport().get_texture().get_image()
	image.save_png(path)
	print("saved %s (%dx%d)" % [path, image.get_width(), image.get_height()])


func _frames(count: int) -> void:
	for _frame in count:
		await get_tree().process_frame
