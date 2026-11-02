extends Node
## Saves a picture of every roguelike stage, whole (the camera zoomed out to
## fit it), with its items and the troop coming out, so the stages can be
## looked at without playing them. Needs a real renderer (a window opens):
##   godot --path . --resolution 1920x1080 res://modes/roguelike/tools/capture_stages.tscn -- <output dir> [seed] [first stage] [last stage]
## Stage numbers start at 1. Writes <nn>_<biome>_<stage name>.png.

const SETTLE_SECONDS := 2.5
const MARGIN := 1.04


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var output_dir: String = args[0] if args.size() > 0 else OS.get_user_data_dir()
	var seed_value := int(args[1]) if args.size() > 1 else 1
	var first := int(args[2]) if args.size() > 2 else 1
	var last := int(args[3]) if args.size() > 3 else RoguelikeRunState.STAGE_COUNT
	DirAccess.make_dir_recursive_absolute(output_dir)
	for number in range(first, last + 1):
		var state := RoguelikeRunState.new()
		state.seed_value = seed_value
		state.stage_index = number - 1
		state.troop.assign([RoguelikeCharacters.STARTER, RoguelikeCharacters.STARTER, RoguelikeCharacters.STARTER])
		var session := RoguelikeStageSession.new()
		session.state = state
		session.show_ui = false
		add_child(session)
		await get_tree().create_timer(SETTLE_SECONDS).timeout
		_fit_camera(session.definition.maze)
		await get_tree().create_timer(0.3).timeout
		var biome := BiomeStageGenerator.biome_of(number - 1)
		var file := "%02d_%s_%s.png" % [number, biome.id, session.definition.stage_name.to_lower().replace(" ", "_")]
		get_viewport().get_texture().get_image().save_png(output_dir.path_join(file))
		print("saved ", file)
		remove_child(session)
		session.queue_free()
		GameManager.resume_game()
		await get_tree().process_frame
	get_tree().quit(0)


func _fit_camera(maze: MazeStageData) -> void:
	var camera := get_viewport().get_camera_2d()
	if camera == null:
		return
	camera.set_process(false)
	var level_size := Vector2(maze.columns, maze.rows) * Constants.TERRAIN_TILE_SIZE
	var screen := get_viewport().get_visible_rect().size
	camera.zoom = Vector2.ONE * minf(screen.x / level_size.x, screen.y / level_size.y) / MARGIN
	camera.limit_left = -100000
	camera.limit_top = -100000
	camera.limit_right = 100000
	camera.limit_bottom = 100000
	camera.global_position = level_size / 2.0
