extends Node
## Shared scaffolding for the tests that play roguelike stages end to end
## with a scripted bot: the stage's recorded solution (from the maze
## generator's solver) says which tool to hand out where, and the bot hands
## it through SkillManager exactly as a click on a lemming does, to the first
## walking lemming in that spot, once the bar has a charge. The player is not
## bound to that solution; the bot only proves one exists in the real game.
##
## A scenario: {"source": "handmade" or "procedural", "stage_index", "seed"
## (procedural), "troop": "single" or "full"}. A "custom" scenario brings its
## own "definition", "plan" and "bar" (tool id -> charges to start with).
## - single: one lemming and a bar already full of four tools the solution
##   does not use (so every item picked up has to push one out); it must get
##   out.
## - full: the troop the run guarantees by then (one recruit per cleared
##   stage) with an empty bar; the scenario passes as soon as one gets out.
##
## Runs SPEEDUP times faster than real time with the same physics step (more
## ticks per second, scaled time), so the simulation is identical to play.
## Exits 0 when every scenario passes, 1 otherwise. Deaths and whoever is
## still out at the end are printed; set the environment variable
## ROGUELIKE_TRACE=1 to also print every lemming state change.

const SPEEDUP := 6
const PHYSICS_TICKS := 60
## A little past the stage's own time limit, so a stage that never resolves
## is reported instead of hanging.
const TIMEOUT_MARGIN_SECONDS := 10.0
## Tools that fill the bar in the single scenario, minus any the plan uses.
const FILLER_TOOLS: Array[String] = ["floater", "climber", "block", "tnt", "dynamite", "basher", "builder"]
const FILLER_CHARGES := 2

var _scenarios: Array[Dictionary] = []
var _scenario_index := -1
var _scenario: Dictionary = {}
var _session: RoguelikeStageSession = null
var _plan: Array[Dictionary] = []
var _next_action := 0
var _elapsed := 0.0
var _saved_count := 0
var _failures: Array[String] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Engine.physics_ticks_per_second = PHYSICS_TICKS * SPEEDUP
	Engine.time_scale = SPEEDUP
	Engine.max_physics_steps_per_frame = 8 * SPEEDUP
	get_tree().node_added.connect(_on_node_added)
	_scenarios = _get_scenarios()
	_start_next_scenario()


# --- Hook for the concrete test ----------------------------------------------

func _get_scenarios() -> Array[Dictionary]:
	return []


## A hand-made stage played in both scenarios.
static func handmade_scenarios(stage_index: int) -> Array[Dictionary]:
	return [
		{"source": "handmade", "stage_index": stage_index, "seed": 0, "troop": "single"},
		{"source": "handmade", "stage_index": stage_index, "seed": 0, "troop": "full"},
	]


# --- Runner -----------------------------------------------------------------

func _start_next_scenario() -> void:
	_scenario_index += 1
	if _scenario_index >= _scenarios.size():
		_finish()
		return
	_scenario = _scenarios[_scenario_index]
	_next_action = 0
	_elapsed = 0.0
	_saved_count = 0

	var state := RoguelikeRunState.new()
	state.stage_index = _scenario.stage_index
	state.seed_value = _scenario.seed
	state.use_handmade_stages = _scenario.source == "handmade"
	if _scenario.source == "custom":
		state.stage_definitions[state.stage_index] = _scenario.definition
	var definition := state.get_stage_definition()
	_plan.assign(_scenario.get("plan", definition.get_solution()))
	for tool_id in _scenario.get("bar", {}):
		state.inventory.add_charges(tool_id, _scenario.bar[tool_id])
	if _scenario.troop == "single" and not _scenario.has("bar"):
		state.troop.assign([RoguelikeCharacters.STARTER])
		_fill_bar(state)
	elif _scenario.troop == "single":
		state.troop.assign([RoguelikeCharacters.STARTER])
	else:
		var troop: Array[StringName] = [RoguelikeCharacters.STARTER]
		for index in _scenario.stage_index:
			troop.append(RoguelikeCharacters.UNLOCK_ORDER[index])
		state.troop.assign(troop)
	_scenario["name"] = "%s stage %d%s '%s', %s troop, %d tool uses" % [
		_scenario.source, _scenario.stage_index + 1,
		" seed %d" % _scenario.seed if _scenario.source == "procedural" else "",
		definition.stage_name, _scenario.troop, _plan.size()]
	print(_scenario.name)

	_session = RoguelikeStageSession.new()
	_session.state = state
	_session.show_ui = false
	_session.stage_finished.connect(_on_stage_finished)
	add_child(_session)
	for exit_point in _session.level_manager.get_children():
		if exit_point is ExitPoint:
			exit_point.lemming_exited.connect(_on_lemming_exited)


func _fill_bar(state: RoguelikeRunState) -> void:
	var used: Array[String] = []
	for action in _plan:
		used.append(action.tool)
	for tool_id in FILLER_TOOLS:
		if state.inventory.is_full():
			break
		if not used.has(tool_id):
			state.inventory.add_charges(tool_id, FILLER_CHARGES)
	assert(state.inventory.is_full(), "Not enough filler tools to fill the bar")


func _physics_process(delta: float) -> void:
	if _session == null:
		return
	_elapsed += delta
	if _next_action < _plan.size():
		_try_next_action()
	if _elapsed > _session.definition.time_limit_seconds + TIMEOUT_MARGIN_SECONDS:
		_record("stage never ended")
		_end_scenario()


func _try_next_action() -> void:
	var action: Dictionary = _plan[_next_action]
	if SkillManager.get_remaining_count(action.tool) <= 0 or _items_left_to_collect(action):
		return
	for node in get_tree().get_nodes_in_group("lemmings"):
		var lemming := node as LemmingController
		if not lemming.state_machine.is_alive() or lemming.state_machine.current_state != LemmingStateMachine.State.WALKING:
			continue
		if action.direction != 0 and lemming.direction != action.direction:
			continue
		var body := lemming.get_body_rect()
		if roundi(body.end.y / Constants.TERRAIN_TILE_SIZE) != action.row:
			continue
		var column := int(body.get_center().x / Constants.TERRAIN_TILE_SIZE)
		if column < action.from_column or column > action.to_column:
			continue
		SkillManager.select_skill(action.tool)
		if SkillManager.try_assign_to(lemming):
			print("  t=%.1fs %s given at column %d, row %d: %s" % [_elapsed, action.tool, column, action.row, action.why])
			_next_action += 1
			return


## The solution counts on the items its pen held being picked up before
## leaving it (a later obstacle may need them): wait until they are.
func _items_left_to_collect(action: Dictionary) -> bool:
	var wanted: Array = action.get("collect_first", [])
	if wanted.is_empty():
		return false
	for node in get_tree().get_nodes_in_group("roguelike_pickups"):
		var pickup := node as RoguelikePickup
		if pickup.is_queued_for_deletion():
			continue
		if wanted.has(Vector2i(pickup.spec.column, pickup.spec.row)):
			return true
	return false


## Every death is printed with its cause and place, so a failing plan says
## where it went wrong.
func _on_node_added(node: Node) -> void:
	var lemming := node as LemmingController
	if lemming == null:
		return
	if OS.has_environment("ROGUELIKE_TRACE"):
		lemming.ready.connect(func() -> void:
			lemming.state_machine.state_changed.connect(func(_from: int, to: int) -> void:
				var b := lemming.get_body_rect()
				print("    trace t=%.2f %s at (%.0f, %.0f)" % [_elapsed, LemmingStateMachine.State.keys()[to], b.get_center().x, b.end.y])))
	lemming.died.connect(func(cause: LemmingController.DeathCause) -> void:
		var body := lemming.get_body_rect()
		print("  t=%.1fs a lemming died (%s) at column %d, row %d" % [
			_elapsed, LemmingController.DeathCause.keys()[cause],
			int(body.get_center().x / Constants.TERRAIN_TILE_SIZE), int(body.end.y / Constants.TERRAIN_TILE_SIZE)
		]))


## With the whole troop, one lemming out is enough: the rest may wander
## for the stage's full time, which would only slow the test down.
func _on_lemming_exited(_lemming: LemmingController) -> void:
	_saved_count += 1
	if _scenario.troop == "full" and _session != null:
		print("  t=%.1fs a lemming got out" % _elapsed)
		_end_scenario.call_deferred()


func _on_stage_finished(saved: Array[StringName], lost: Array[StringName]) -> void:
	if _session == null:
		return
	print("  t=%.1fs saved %s, lost %s" % [_elapsed, saved, lost])
	for node in get_tree().get_nodes_in_group("lemmings"):
		var lemming := node as LemmingController
		if lemming.state_machine.is_alive():
			var body := lemming.get_body_rect()
			print("  still out: %s facing %d at column %d, row %d" % [
				LemmingStateMachine.State.keys()[lemming.state_machine.current_state], lemming.direction,
				int(body.get_center().x / Constants.TERRAIN_TILE_SIZE), int(body.end.y / Constants.TERRAIN_TILE_SIZE)
			])
	if saved.is_empty():
		_record("nobody got out")
	if _next_action < _plan.size():
		_record("plan stopped at action %d (%s: %s)" % [_next_action, _plan[_next_action].tool, _plan[_next_action].why])
	_end_scenario()


func _record(problem: String) -> void:
	var message := "%s: %s" % [_scenario.name, problem]
	print("  FAIL " + message)
	_failures.append(message)


func _end_scenario() -> void:
	if _session == null:
		return
	# Out of the tree at once: the next stage's lemmings look the terrain up
	# by group, and must not find this one's.
	remove_child(_session)
	_session.queue_free()
	_session = null
	GameManager.resume_game()
	_start_next_scenario.call_deferred()


func _finish() -> void:
	set_physics_process(false)
	Engine.time_scale = 1.0
	var passed := _failures.is_empty()
	print("Stage playthrough: %s" % ("PASS" if passed else "FAIL (%s)" % "; ".join(_failures)))
	get_tree().quit(0 if passed else 1)
