extends Node
## Plays the "Escada vertical" level end to end, the way a player would: the
## level is loaded through GameManager like the main menu does, and the
## ladder is handed out through SkillManager exactly as a click on a lemming
## does. Passes only if the level is won. Run via:
##   godot --headless res://tests/test_level_ladder_vertical.tscn
## Exits 0 on success, 1 otherwise.
##
## This is the check that the level is actually solvable with its one tool,
## which the tool's own unit test (test_tool_ladder_vertical) cannot show.

const LEVEL_DATA_PATH := "res://resources/levels/level_06_data.tres"
const TOOL_ID := "ladder_vertical"
## Hand the ladder to the first lemming walking on the floor, left of the
## platform. It carries the ladder until it walks into the platform's wall.
const MIN_X := 64.0
const MAX_X := 440.0
const TIMEOUT_SECONDS := 100.0

var _level_manager: LevelManager = null
var _tool_given := false
var _elapsed := 0.0
var _result := ""


func _ready() -> void:
	# The result screen pauses the tree when the level ends; this test has to
	# keep running to read the outcome.
	process_mode = Node.PROCESS_MODE_ALWAYS
	var level_data: LevelData = load(LEVEL_DATA_PATH)
	GameManager.current_level_data = level_data
	add_child((load(level_data.scene_path) as PackedScene).instantiate())
	_level_manager = get_tree().get_first_node_in_group("level_manager")
	_level_manager.level_completed.connect(func(p: float) -> void: _result = "won with %d%% saved" % round(p * 100.0))
	_level_manager.level_failed.connect(func(p: float) -> void: _result = "lost with %d%% saved" % round(p * 100.0))
	print("Playing '%s'" % level_data.level_name)


func _physics_process(delta: float) -> void:
	_elapsed += delta
	if not _tool_given:
		_try_give_tool()

	if _result != "":
		_finish(_result.begins_with("won"))
	elif _elapsed >= TIMEOUT_SECONDS:
		_result = "level never ended (saved %d, lost %d)" % [_level_manager.lemmings_saved_count, _level_manager.lemmings_lost_count]
		_finish(false)


func _try_give_tool() -> void:
	for node in get_tree().get_nodes_in_group("lemmings"):
		var lemming := node as LemmingController
		if lemming.state_machine.current_state != LemmingStateMachine.State.WALKING:
			continue
		if lemming.global_position.x < MIN_X or lemming.global_position.x > MAX_X:
			continue
		SkillManager.select_skill(TOOL_ID)
		if SkillManager.try_assign_to(lemming):
			_tool_given = true
			print("  t=%.1fs ladder given at x=%.0f" % [_elapsed, lemming.global_position.x])
			return


func _finish(passed: bool) -> void:
	set_physics_process(false)
	print("  %s" % _result)
	print("Level '%s': %s" % [GameManager.current_level_data.level_name, "PASS" if passed else "FAIL"])
	get_tree().paused = false
	get_tree().quit(0 if passed else 1)
