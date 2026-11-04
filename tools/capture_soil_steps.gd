extends Node
## Close-up screenshots of the soil steps (half-block ramps) in campaign
## levels, one image per level, to check how their edge art meets the
## blocks beside them. Needs a real renderer (a window opens). Run via:
##   godot --path . --windowed --resolution 1280x720 res://tools/capture_soil_steps.tscn -- <output dir> [level numbers...]

const SETTLE_FRAMES := 20
const ZOOM := 4.0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var output_dir: String = args[0] if not args.is_empty() else OS.get_user_data_dir()
	# Keeps this node alive while the levels replace the current scene.
	get_tree().current_scene = null
	for arg in args.slice(1):
		var number := int(arg)
		LevelLoader.load_level(Campaign.load_level_data(number - 1))
		await _frames(SETTLE_FRAMES)
		get_tree().paused = true
		var terrain := get_tree().get_first_node_in_group("terrain") as TerrainDestructible
		var camera := get_viewport().get_camera_2d()
		if terrain == null or camera == null or terrain.get_ramps().is_empty():
			print("level %d: no ramps" % number)
			continue
		camera.process_mode = Node.PROCESS_MODE_DISABLED
		camera.zoom = Vector2.ONE * ZOOM
		camera.limit_left = -100000
		camera.limit_top = -100000
		camera.limit_right = 100000
		camera.limit_bottom = 100000
		var ramps := terrain.get_ramps()
		var ramp: Rect2 = ramps[ramps.size() / 2]
		camera.global_position = ramp.get_center()
		await _frames(5)
		var image := get_viewport().get_texture().get_image()
		var path := output_dir.path_join("soil_%02d.png" % number)
		image.save_png(path)
		print("saved ", path)
		get_tree().paused = false
	get_tree().quit()


func _frames(count: int) -> void:
	for _frame in count:
		await get_tree().process_frame
