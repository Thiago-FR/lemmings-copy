extends Node
## Plays a tool's level and saves screenshots along the way, to check a
## tool's look by eye. The tool goes to the first lemming walking right,
## as the level's own playthrough test does. Needs a real renderer (no
## --headless). Run via:
##   godot --path . --windowed --resolution 1280x720 res://tools/capture_tool_level.tscn -- <level data> <tool id> <output dir> <seconds...>
## Writes <tool id>_<seconds>s.png for each moment.

var _tool_id := ""
var _tool_given := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	assert(args.size() >= 4, "usage: <level data> <tool id> <output dir> <seconds...>")
	_tool_id = args[1]
	var output_dir: String = args[2]
	var moments: Array[float] = []
	for index in range(3, args.size()):
		moments.append(float(args[index]))
	get_tree().current_scene = null
	LevelLoader.load_level(load(args[0]))
	var elapsed := 0.0
	for moment in moments:
		while elapsed < moment:
			await get_tree().physics_frame
			elapsed += get_physics_process_delta_time()
			_give_tool()
		await get_tree().process_frame
		var image := get_viewport().get_texture().get_image()
		var path := output_dir.path_join("%s_%ds.png" % [_tool_id, int(moment)])
		image.save_png(path)
		print("saved %s" % path)
	get_tree().quit()


func _give_tool() -> void:
	if _tool_given:
		return
	for node in get_tree().get_nodes_in_group("lemmings"):
		var lemming := node as LemmingController
		if lemming.state_machine.current_state == LemmingStateMachine.State.WALKING and lemming.direction > 0:
			SkillManager.select_skill(_tool_id)
			_tool_given = SkillManager.try_assign_to(lemming)
			return
