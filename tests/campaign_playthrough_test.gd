extends "res://tests/level_playthrough_test.gd"
## Base of the robot playthroughs of the campaign levels
## (tests/test_campaign_<nn>.gd): plays the level with a scripted solution
## and passes only if it is won, that is, the level's required percentage
## was saved in time.
##
## The game runs SPEED_UP times faster than real time with the physics
## ticking SPEED_UP times as often, so each physics step is still 1/60 s,
## exactly what the game simulates: the same frames, only sooner.
##
## A solution is a list of hand-outs checked every frame:
##   give_once("name", tool, condition): the first lemming meeting the
##     condition gets the tool, once;
##   give_each(tool, condition): every lemming meeting it gets the tool, once
##     each.
## Conditions are Callables taking the lemming, built from the helpers below.
##
## A test of a naive solution (one that looks right and must not work)
## overrides _expects_win() to return false: it then passes only if the
## level is lost, which is what keeps a puzzle from being trivial.

## CAMPAIGN_SPEED_UP=<n> runs faster (the campaign builder plays every level).
var SPEED_UP := float(OS.get_environment("CAMPAIGN_SPEED_UP")) if OS.has_environment("CAMPAIGN_SPEED_UP") else 4.0
const GAME_TICKS_PER_SECOND := 60
const TILE := 32.0
## Winning records progress; never in the player's own file.
const TEST_SAVE_PATH := "user://test_campaign_playthrough.cfg"

var _done_steps: Dictionary = {}
## tool id -> {lemming instance id: true}
var _given_to: Dictionary = {}
## Lemmings already watched for their death (to report where each died).
var _watched: Dictionary = {}


func _ready() -> void:
	Engine.physics_ticks_per_second = int(GAME_TICKS_PER_SECOND * SPEED_UP)
	Engine.time_scale = SPEED_UP
	Campaign.save_path = TEST_SAVE_PATH
	super._ready()
	print("  %d lemmings, %d%% needed, %ds, tools %s" % [level_data.total_lemmings, roundi(level_data.required_percentage * 100.0), level_data.time_limit_seconds, level_data.skill_counts])
	if OS.has_environment("CAMPAIGN_COMPARE"):
		_start_comparing()


func _get_level_data_path() -> String:
	return "res://resources/levels/campaign/campaign_%02d_data.tres" % _get_level_number()


func _get_level_number() -> int:
	return 0


## Whether the scripted solution should win the level (false for a naive
## solution that must fail).
func _expects_win() -> bool:
	return true


## Whether a step of give_once has already happened (to order steps).
func is_done(step: String) -> bool:
	return _done_steps.has(step)


var _next_trace := 0.0


func _physics_process(delta: float) -> void:
	_watch_deaths()
	_compare_with_solver()
	# CAMPAIGN_TRACE=1 prints where the first lemming is every 2 seconds
	# (CAMPAIGN_TRACE_PERIOD=<seconds> for another period).
	if OS.has_environment("CAMPAIGN_TRACE") and elapsed >= _next_trace:
		_next_trace = elapsed + (float(OS.get_environment("CAMPAIGN_TRACE_PERIOD")) if OS.has_environment("CAMPAIGN_TRACE_PERIOD") else 2.0)
		var lemmings := get_lemmings()
		if not lemmings.is_empty():
			var body := lemmings[0].get_body_rect()
			print("  trace t=%.1fs x %.0f (column %d), feet %.2f rows, %s, facing %d" % [elapsed, body.get_center().x, int(body.get_center().x / TILE), body.end.y / TILE, LemmingStateMachine.State.keys()[lemmings[0].state_machine.current_state], lemmings[0].direction])
	super._physics_process(delta)


## Reports every death with its time and place: what a failing solution
## needs to be fixed.
func _watch_deaths() -> void:
	for lemming in get_lemmings():
		var key := lemming.get_instance_id()
		if _watched.has(key):
			continue
		_watched[key] = true
		lemming.died.connect(func(cause: LemmingController.DeathCause) -> void:
			var body := lemming.get_body_rect()
			print("  t=%.1fs died (%s) at (%.0f, %.0f), column %d" % [elapsed, LemmingController.DeathCause.keys()[cause], body.get_center().x, body.end.y, int(body.get_center().x / TILE)]))


func give_once(step: String, tool_id: String, condition: Callable) -> bool:
	if is_done(step):
		return false
	for lemming in get_lemmings():
		if lemming.is_entering_exit or not condition.call(lemming):
			continue
		if give_tool(tool_id, lemming, step):
			_done_steps[step] = elapsed
			return true
	return false


func give_each(tool_id: String, condition: Callable) -> void:
	var given: Dictionary = _given_to.get_or_add(tool_id, {})
	for lemming in get_lemmings():
		var key := lemming.get_instance_id()
		if given.has(key) or lemming.is_entering_exit or not condition.call(lemming):
			continue
		if give_tool(tool_id, lemming, "each"):
			given[key] = true


## Plays a generated level's recorded solution (LevelData.solution), one
## step after another: each tool to the first lemming walking at its
## column, its way, on its floor.
##
## The solver follows one lemming, so every step goes to the same one (the
## first to take a tool) while it is still in the level, and only once it
## carries no unused tool from the step before: handed out to whoever was
## nearest, a second lemming took a jackhammer into the first one's tunnel
## and handed over a second carried tool replaced the first.
func play_recorded_solution() -> void:
	var steps := level_data.solution
	var next := _done_steps.size()
	if next >= steps.size():
		return
	var step: Dictionary = steps[next]
	var condition := near_floor(walking_in(step.from_column, step.to_column, step.direction), step.row)
	if is_instance_valid(_pioneer) and not _pioneer.is_entering_exit:
		var pioneer := _pioneer
		# Climber and floater stay with a carried tool; a held tool would
		# replace it.
		var held := SkillManager.create_skill(step.tool).is_held_tool()
		var carries_unused: bool = held and _pioneer.pending_wall_tool != null
		condition = both(condition, func(lemming: LemmingController) -> bool: return lemming == pioneer and not carries_unused)
	var step_name := "step %d (%s)" % [next + 1, step.tool]
	for lemming in get_lemmings():
		if not is_done(step_name) and condition.call(lemming) and not lemming.is_entering_exit and give_tool(step.tool, lemming, step_name):
			_done_steps[step_name] = elapsed
			if not is_instance_valid(_pioneer):
				_pioneer = lemming
				_pioneer_chosen = true
			return


## The lemming the recorded solution is played with (see play_recorded_solution).
var _pioneer: LemmingController = null
var _pioneer_chosen := false

# --- Comparing with the solver ------------------------------------------------
# CAMPAIGN_COMPARE=1: where the solver expected the lemming playing the
# recorded solution to walk (CellStageSolver.follow), checked against where
# it walks in the game; the first place it walks that the solver never
# expected is printed once, with the expected walk around it. That is where
# the solver's model and the game part ways.

const UNIT := 8.0
var _expected: Dictionary = {}
var _expected_path: Array[Vector3i] = []
var _last_matched := -1
var _diverged := false
var _mismatched_frames := 0
const MISMATCH_FRAMES_TO_REPORT := 30


func _start_comparing() -> void:
	var maze := LevelDrawing.maze_from_dictionary(CampaignLevelStore.read(_get_level_number() - 1))
	var followed := CellStageSolver.follow(maze, level_data.solution)
	_expected_path = followed.path
	for index in _expected_path.size():
		var point := _expected_path[index]
		if not _expected.has(point):
			_expected[point] = index
	print("  solver: %d points, %d of %d steps used, ends '%s'" % [_expected_path.size(), followed.steps_used, level_data.solution.size(), followed.end])
	# CAMPAIGN_COMPARE=2 also prints the whole expected walk.
	if OS.get_environment("CAMPAIGN_COMPARE") == "2":
		var walk := PackedStringArray()
		for point in _expected_path:
			walk.append("%d,%.2f%s" % [point.x, point.y / 4.0, ">" if point.z > 0 else "<"])
		print("  solver walk: ", " ".join(walk))


func _compare_with_solver() -> void:
	if _diverged or _expected_path.is_empty():
		return
	var lemming: LemmingController = _pioneer
	if _pioneer_chosen and (not is_instance_valid(lemming) or lemming.is_entering_exit):
		return
	if not is_instance_valid(lemming):
		var lemmings := get_lemmings()
		if lemmings.is_empty():
			return
		lemming = lemmings[0]
	if not is_walking(lemming):
		return
	var body := lemming.get_body_rect()
	var feet := body.end.y / UNIT
	if absf(feet - roundf(feet)) > 0.2:
		return
	var key := Vector2i(int(floor(body.get_center().x / TILE)), roundi(feet))
	# The game moves pixel by pixel, the solver by half blocks: a column or
	# a quarter block either way is the same place.
	for column_offset in [0, -1, 1]:
		for feet_offset in [0, -1, 1, -2, 2]:
			var point := Vector3i(key.x + column_offset, key.y + feet_offset, lemming.direction)
			if _expected.has(point):
				_last_matched = maxi(_last_matched, int(_expected[point]))
				_mismatched_frames = 0
				return
	# A frame or two off the expected walk happens at a ladder's top or a
	# ramp; a real parting of ways lasts.
	_mismatched_frames += 1
	if _mismatched_frames < MISMATCH_FRAMES_TO_REPORT:
		return
	_diverged = true
	var around := PackedStringArray()
	for index in range(maxi(_last_matched - 3, 0), mini(_last_matched + 6, _expected_path.size())):
		var point := _expected_path[index]
		around.append("%s%d,%.2f%s" % ["*" if index == _last_matched else "", point.x, point.y / 4.0, ">" if point.z > 0 else "<"])
	print("  DIVERGED t=%.1fs: walking at column %d, feet %.2f rows, facing %d; solver expected next: %s" % [elapsed, key.x, key.y / 4.0, lemming.direction, " ".join(around)])


## Also standing within half a block of the top of that floor row (on a
## soil ramp the feet are a little above it).
func near_floor(condition: Callable, floor_row: int) -> Callable:
	return func(lemming: LemmingController) -> bool:
		return condition.call(lemming) and absf(lemming.get_body_rect().end.y - floor_row * TILE) <= TILE / 2.0


# --- Conditions ---------------------------------------------------------------

## Walking (not falling, digging, climbing) in direction (+1 right, -1 left,
## 0 either), with its body's centre between columns from_column and
## to_column (inclusive), standing on floor row floor_row (-1: any floor).
func walking_in(from_column: int, to_column: int, direction: int = 0, floor_row: int = -1) -> Callable:
	return func(lemming: LemmingController) -> bool:
		if not is_walking(lemming):
			return false
		if direction != 0 and lemming.direction != direction:
			return false
		var body := lemming.get_body_rect()
		var column := int(floor(body.get_center().x / TILE))
		if column < from_column or column > to_column:
			return false
		return floor_row < 0 or absf(body.end.y - floor_row * TILE) < 4.0


func in_state(state: LemmingStateMachine.State) -> Callable:
	return func(lemming: LemmingController) -> bool:
		return lemming.state_machine.current_state == state


func both(first: Callable, second: Callable) -> Callable:
	return func(lemming: LemmingController) -> bool:
		return first.call(lemming) and second.call(lemming)


## No other lemming within distance pixels (centre to centre): for
## explosives, so the blast takes as few lemmings as possible.
func alone_within(distance: float) -> Callable:
	return func(lemming: LemmingController) -> bool:
		var centre := lemming.get_body_rect().get_center()
		for other in get_lemmings():
			if other != lemming and other.get_body_rect().get_center().distance_to(centre) < distance:
				return false
		return true


## Some other lemming walking the same way (direction) is already past
## column: to hand a tool to the second one while the first goes on.
func someone_ahead_of(column: int, direction: int) -> Callable:
	return func(lemming: LemmingController) -> bool:
		for other in get_lemmings():
			if other == lemming or other.direction != direction:
				continue
			var other_column := int(floor(other.get_body_rect().get_center().x / TILE))
			if (other_column - column) * direction > 0:
				return true
		return false


func _finish(passed: bool) -> void:
	print("  level time used: %.0fs of %ds" % [level_data.time_limit_seconds - level_manager.time_remaining, level_data.time_limit_seconds])
	Engine.time_scale = 1.0
	if not _expects_win():
		var lost := _result.begins_with("lost")
		print("  (a naive solution: it has to lose) %s" % ("lost, as it should" if lost else "it did not lose"))
		passed = lost
	super._finish(passed)
