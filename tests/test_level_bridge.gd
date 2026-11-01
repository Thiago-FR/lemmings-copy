extends Node
## Plays the "Ponte" level end to end, the way a player would: the level is
## loaded through GameManager like the main menu does, and the bridge is
## handed out through SkillManager exactly as a click on a lemming does.
## Passes only if the level is won. Run via:
##   godot --headless res://tests/test_level_bridge.tscn
## Exits 0 on success, 1 otherwise.
##
## This is the check that the level is actually solvable with its one tool,
## which the tool's own unit test (test_tool_bridge) cannot show.

const LEVEL_DATA_PATH := "res://resources/levels/level_07_data.tres"
const TOOL_ID := "bridge"
## Where the gap starts. The bridge goes to the first lemming walking towards
## it on the floor, as soon as one lands: the lemmings behind it reach the
## gap while the bridge is still being built, so the earlier it starts the
## fewer of them walk off its unfinished end.
const GAP_EDGE_X := 288.0
## A little past the level's own time limit, so a level that never resolves
## is reported instead of hanging.
const TIMEOUT_MARGIN_SECONDS := 5.0

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
	elif _elapsed >= GameManager.current_level_data.time_limit_seconds + TIMEOUT_MARGIN_SECONDS:
		_result = "level never ended (saved %d, lost %d; still out: %s)" % [_level_manager.lemmings_saved_count, _level_manager.lemmings_lost_count, _describe_remaining()]
		_finish(false)


func _try_give_tool() -> void:
	for node in get_tree().get_nodes_in_group("lemmings"):
		var lemming := node as LemmingController
		if lemming.state_machine.current_state != LemmingStateMachine.State.WALKING:
			continue
		if lemming.direction <= 0:
			continue
		var distance := GAP_EDGE_X - lemming.get_body_rect().end.x
		if distance < 0.0:
			continue
		SkillManager.select_skill(TOOL_ID)
		if SkillManager.try_assign_to(lemming):
			_tool_given = true
			print("  t=%.1fs bridge given %.0fpx from the gap" % [_elapsed, distance])
			return


func _finish(passed: bool) -> void:
	set_physics_process(false)
	print("  %s (saved %d, lost %d)" % [_result, _level_manager.lemmings_saved_count, _level_manager.lemmings_lost_count])
	print("Level '%s': %s" % [GameManager.current_level_data.level_name, "PASS" if passed else "FAIL"])
	get_tree().paused = false
	get_tree().quit(0 if passed else 1)


func _describe_remaining() -> String:
	var parts: Array[String] = []
	for node in get_tree().get_nodes_in_group("lemmings"):
		var lemming := node as LemmingController
		var body := lemming.get_body_rect()
		parts.append("%s facing %d at (%.0f, %.0f)" % [
			LemmingStateMachine.State.keys()[lemming.state_machine.current_state], lemming.direction, body.get_center().x, body.end.y
		])
	return ", ".join(parts)
