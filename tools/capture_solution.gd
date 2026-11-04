extends Node
## Screenshots of campaign levels with the developer's solution view on
## (SolutionOverlay), the camera zoomed out to the whole level. Needs a real
## renderer (a window opens). Run via:
##   godot --path . --windowed --resolution 1920x1080 res://tools/capture_solution.tscn -- <output dir> [level numbers...]

const SETTLE_FRAMES := 20


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var output_dir: String = args[0] if not args.is_empty() else OS.get_user_data_dir()
	# Keeps this node alive while the levels replace the current scene.
	get_tree().current_scene = null
	var was_developer := GameManager.developer_mode
	GameManager.developer_mode = true
	for arg in args.slice(1):
		var number := int(arg)
		LevelLoader.load_level(Campaign.load_level_data(number - 1))
		await _frames(SETTLE_FRAMES)
		get_tree().paused = true
		var level := get_tree().get_first_node_in_group("level_manager") as LevelManager
		var overlay := level.get_node_or_null("SolutionOverlay") as SolutionOverlay if level != null else null
		var camera := get_viewport().get_camera_2d()
		if overlay == null or camera == null:
			print("level %d: no solution view" % number)
			get_tree().paused = false
			continue
		overlay.set_shown(true)
		var terrain := get_tree().get_first_node_in_group("terrain") as TerrainDestructible
		var area := Rect2(Vector2(terrain.get_used_rect().position) * terrain.get_cell_size(), Vector2(terrain.get_used_rect().size) * terrain.get_cell_size())
		var view := get_viewport().get_visible_rect().size
		camera.process_mode = Node.PROCESS_MODE_DISABLED
		camera.zoom = Vector2.ONE * minf(view.x / area.size.x, view.y / area.size.y)
		camera.limit_left = -100000
		camera.limit_top = -100000
		camera.limit_right = 100000
		camera.limit_bottom = 100000
		camera.global_position = area.get_center()
		await _frames(5)
		var path := output_dir.path_join("solution_%02d.png" % number)
		get_viewport().get_texture().get_image().save_png(path)
		print("saved ", path)
		get_tree().paused = false
	GameManager.developer_mode = was_developer
	get_tree().quit()


func _frames(count: int) -> void:
	for _frame in count:
		await get_tree().process_frame
