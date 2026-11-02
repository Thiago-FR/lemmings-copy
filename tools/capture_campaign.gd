extends Node
## Saves screenshots of the campaign: the level select, and each level a few
## seconds in, as the player sees it and as a whole (the camera zoomed out
## to fit the level). Needs a real renderer, so it cannot run headless; a
## window opens. Run via:
##   godot --path . --windowed --resolution 1920x1080 res://tools/capture_campaign.tscn -- <output dir> [level numbers...]
## Writes menu.png, select.png, campaign_<nn>.png, campaign_<nn>_whole.png,
## result.png and result_lost.png (the first level's result screen after a
## win and after a loss), select_complete.png (every level won) and
## complete.png (the congratulations and credits). The
## player's own progress is not touched (a sample progress file is used).

const SAMPLE_SAVE_PATH := "user://capture_campaign.cfg"
const SETTLE_FRAMES := 30
## Long enough for the first lemmings to come out of the entrance.
const LEVEL_SETTLE_FRAMES := 300
## Long enough for the result screen's badge and count to finish (in
## seconds: frames go by much faster than 60 a second here).
const RESULT_SETTLE_SECONDS := 1.5
## Long enough for the stars and the credits to be in.
const COMPLETE_SETTLE_SECONDS := 4.5


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var output_dir: String = args[0] if not args.is_empty() else OS.get_user_data_dir()
	var numbers: Array[int] = []
	for arg in args.slice(1):
		numbers.append(int(arg))
	if numbers.is_empty():
		numbers.assign(range(1, Campaign.LEVEL_COUNT + 1))
	get_tree().current_scene = null

	Campaign.save_path = SAMPLE_SAVE_PATH
	Campaign.reset_progress()
	for index in 4:
		Campaign.record_win(index, 0.8 + index * 0.05)
	get_tree().change_scene_to_file("res://scenes/main/main_menu.tscn")
	await _frames(SETTLE_FRAMES)
	_save(output_dir.path_join("menu.png"))
	get_tree().change_scene_to_file(Campaign.SELECT_SCENE_PATH)
	await _frames(SETTLE_FRAMES)
	_save(output_dir.path_join("select.png"))

	for number in numbers:
		LevelLoader.load_level(Campaign.load_level_data(number - 1))
		await _frames(LEVEL_SETTLE_FRAMES)
		_save(output_dir.path_join("campaign_%02d.png" % number))
		var camera := get_viewport().get_camera_2d()
		if camera != null:
			camera.set_process(false)
			var level_size := Vector2(2560, 1440)
			var fit := minf(get_viewport().get_visible_rect().size.x / level_size.x, get_viewport().get_visible_rect().size.y / level_size.y)
			camera.zoom = Vector2.ONE * fit
			camera.limit_left = -100000
			camera.limit_top = -100000
			camera.limit_right = 100000
			camera.limit_bottom = 100000
			camera.global_position = level_size / 2.0
			await _frames(5)
			_save(output_dir.path_join("campaign_%02d_whole.png" % number))
		if number == numbers[0]:
			# The result screens of a win and a loss, as LevelManager
			# announces them, once their animation has played.
			var manager := get_tree().get_first_node_in_group("level_manager")
			manager.level_failed.emit(0.4)
			await _seconds(RESULT_SETTLE_SECONDS)
			_save(output_dir.path_join("result_lost.png"))
			GameManager.restart_level()
			await _frames(SETTLE_FRAMES)
			manager = get_tree().get_first_node_in_group("level_manager")
			manager.level_completed.emit(0.9)
			await _seconds(RESULT_SETTLE_SECONDS)
			_save(output_dir.path_join("result.png"))
			GameManager.go_to_scene(Campaign.SELECT_SCENE_PATH)
			await _frames(5)
	for index in Campaign.LEVEL_COUNT:
		Campaign.record_win(index, 1.0)
	get_tree().change_scene_to_file(Campaign.SELECT_SCENE_PATH)
	await _frames(SETTLE_FRAMES)
	_save(output_dir.path_join("select_complete.png"))
	get_tree().change_scene_to_file(Campaign.COMPLETE_SCENE_PATH)
	await _seconds(COMPLETE_SETTLE_SECONDS)
	_save(output_dir.path_join("complete.png"))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAMPLE_SAVE_PATH))
	get_tree().quit()


func _save(path: String) -> void:
	var image := get_viewport().get_texture().get_image()
	image.save_png(path)
	print("saved %s (%dx%d)" % [path, image.get_width(), image.get_height()])


## A real-time wait that also runs while the tree is paused (the result
## screen pauses it).
func _seconds(duration: float) -> void:
	await get_tree().create_timer(duration, true).timeout


func _frames(count: int) -> void:
	for _frame in count:
		await get_tree().process_frame
