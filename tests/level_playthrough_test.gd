extends Node
## Shared scaffolding for the tests that play a level end to end, the way a
## player would: the level is loaded through GameManager like the main menu
## does, and tools are handed out through SkillManager exactly as a click on
## a lemming does. Passes only if the level is won. Exits 0 on success, 1
## otherwise.
##
## A level test extends this script, names its level data and decides each
## frame whom to give the tool to (_play_frame). This is the check that a
## level is actually solvable with its one tool, which the tool's own test
## cannot show.

## A little past the level's own time limit, so a level that never resolves
## is reported instead of hanging.
const TIMEOUT_MARGIN_SECONDS := 5.0

var level_manager: LevelManager = null
var level_data: LevelData = null
var elapsed := 0.0

var _result := ""


func _ready() -> void:
	# The result screen pauses the tree when the level ends; this test has to
	# keep running to read the outcome.
	process_mode = Node.PROCESS_MODE_ALWAYS
	level_data = load(_get_level_data_path())
	GameManager.current_level_data = level_data
	add_child((load(level_data.scene_path) as PackedScene).instantiate())
	level_manager = get_tree().get_first_node_in_group("level_manager")
	level_manager.level_completed.connect(func(p: float) -> void: _result = "won with %d%% saved" % round(p * 100.0))
	level_manager.level_failed.connect(func(p: float) -> void: _result = "lost with %d%% saved" % round(p * 100.0))
	print("Playing '%s'" % level_data.level_name)


# --- Hooks for the concrete test -------------------------------------------

func _get_level_data_path() -> String:
	return ""


## Called every physics frame until the level ends: hand out tools here.
func _play_frame() -> void:
	pass


# --- Helpers ----------------------------------------------------------------

func get_lemmings() -> Array[LemmingController]:
	var lemmings: Array[LemmingController] = []
	for node in get_tree().get_nodes_in_group("lemmings"):
		var lemming := node as LemmingController
		if lemming.state_machine.is_alive():
			lemmings.append(lemming)
	return lemmings


## Selects the level's tool and clicks the lemming with it. Returns whether
## the lemming took it (and a charge was spent).
func give_tool(tool_id: String, lemming: LemmingController, why: String) -> bool:
	SkillManager.select_skill(tool_id)
	if not SkillManager.try_assign_to(lemming):
		return false
	var body := lemming.get_body_rect()
	print("  t=%.1fs %s given at (%.0f, %.0f): %s" % [elapsed, tool_id, body.get_center().x, body.end.y, why])
	return true


func is_walking(lemming: LemmingController) -> bool:
	return lemming.state_machine.current_state == LemmingStateMachine.State.WALKING


# --- Runner -----------------------------------------------------------------

func _physics_process(delta: float) -> void:
	elapsed += delta
	if _result == "":
		_play_frame()

	if _result != "":
		_finish(_result.begins_with("won"))
	elif elapsed >= level_data.time_limit_seconds + TIMEOUT_MARGIN_SECONDS:
		_result = "level never ended (saved %d, lost %d; still out: %s)" % [level_manager.lemmings_saved_count, level_manager.lemmings_lost_count, _describe_remaining()]
		_finish(false)


func _finish(passed: bool) -> void:
	set_physics_process(false)
	print("  %s (saved %d, lost %d)" % [_result, level_manager.lemmings_saved_count, level_manager.lemmings_lost_count])
	print("Level '%s': %s" % [level_data.level_name, "PASS" if passed else "FAIL"])
	get_tree().paused = false
	get_tree().quit(0 if passed else 1)


func _describe_remaining() -> String:
	var parts: Array[String] = []
	for lemming in get_lemmings():
		var body := lemming.get_body_rect()
		parts.append("%s facing %d at (%.0f, %.0f)" % [
			LemmingStateMachine.State.keys()[lemming.state_machine.current_state], lemming.direction, body.get_center().x, body.end.y
		])
	return ", ".join(parts)
