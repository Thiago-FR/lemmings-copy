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

const SPEED_UP := 4.0
const GAME_TICKS_PER_SECOND := 60
const TILE := 32.0
## Winning records progress; never in the player's own file.
const TEST_SAVE_PATH := "user://test_campaign_playthrough.cfg"

var _done_steps: Dictionary = {}
## tool id -> {lemming instance id: true}
var _given_to: Dictionary = {}


func _ready() -> void:
	Engine.physics_ticks_per_second = int(GAME_TICKS_PER_SECOND * SPEED_UP)
	Engine.time_scale = SPEED_UP
	Campaign.save_path = TEST_SAVE_PATH
	super._ready()
	print("  %d lemmings, %d%% needed, %ds, tools %s" % [level_data.total_lemmings, roundi(level_data.required_percentage * 100.0), level_data.time_limit_seconds, level_data.skill_counts])


func _get_level_data_path() -> String:
	return "res://resources/levels/campaign/campaign_%02d_data.tres" % _get_level_number()


func _get_level_number() -> int:
	return 0


## Whether a step of give_once has already happened (to order steps).
func is_done(step: String) -> bool:
	return _done_steps.has(step)


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


func _finish(passed: bool) -> void:
	print("  level time used: %.0fs of %ds" % [level_data.time_limit_seconds - level_manager.time_remaining, level_data.time_limit_seconds])
	Engine.time_scale = 1.0
	super._finish(passed)
