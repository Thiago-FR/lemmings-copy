extends Node
## Diagnostic for "some lemmings go through the floor". Loads a real level,
## hands out Diggers the way a player would, and watches every live lemming
## every physics frame. Run via:
##   godot --headless res://tests/diagnose_falling_through.tscn
##
## Records, per lemming, the first frame on which its body was inside solid
## terrain or below the lowest solid row, and prints the frames leading up to
## it so the trajectory is visible rather than guessed at.

const LEVEL_DATA_PATH := "res://resources/levels/level_02_data.tres"
const RUN_SECONDS := 18.0
const TRAIL_LENGTH := 10

## Only lemmings standing on the upper platform get a Digger, matching how
## the level is meant to be played. Digging through the lower floor drops a
## lemming out of the level by design, which would otherwise show up here as
## a false positive.
const UPPER_PLATFORM_MAX_Y := 240.0

var _elapsed := 0.0
var _terrain: TerrainDestructible = null
var _lowest_solid_y := 0.0
var _watched: Dictionary = {}
var _dug_count := 0
var _finished := false


func _ready() -> void:
	# The level result screen pauses the tree when the level resolves. Without
	# this the diagnostic stops receiving physics frames at that moment and
	# simply appears to hang.
	process_mode = Node.PROCESS_MODE_ALWAYS

	var level_data: LevelData = load(LEVEL_DATA_PATH)
	GameManager.current_level_data = level_data
	add_child((load(level_data.scene_path) as PackedScene).instantiate())
	print("Diagnosing %s for %.0fs" % [level_data.level_name, RUN_SECONDS])


func _physics_process(delta: float) -> void:
	if _finished:
		return
	_elapsed += delta

	if _terrain == null:
		_terrain = get_tree().get_first_node_in_group("terrain")
		if _terrain == null:
			return
		var used := _terrain.get_used_rect()
		_lowest_solid_y = float(used.end.y * _terrain.tile_set.tile_size.y)
		print("lowest solid terrain edge: y=%.0f" % _lowest_solid_y)

	_hand_out_diggers()
	_watch_lemmings()

	if _elapsed >= RUN_SECONDS:
		_finished = true
		_report()


func _hand_out_diggers() -> void:
	if _dug_count >= 3:
		return
	for node in get_tree().get_nodes_in_group("lemmings"):
		var lemming: LemmingController = node
		if not is_instance_valid(lemming):
			continue
		if lemming.state_machine.current_state != LemmingStateMachine.State.WALKING:
			continue
		if lemming.global_position.y > UPPER_PLATFORM_MAX_Y:
			continue
		var entry: Dictionary = _entry_for(lemming)
		if entry.dug:
			continue
		entry.dug = true
		_dug_count += 1
		var digger := SkillDigger.new()
		digger.skill_id = "digger"
		lemming.current_skill = digger
		digger.apply_to(lemming)
		print("  t=%.1f  digger given to lemming %d at %s" % [_elapsed, entry.index, lemming.global_position])
		return


func _entry_for(lemming: LemmingController) -> Dictionary:
	var key := lemming.get_instance_id()
	if not _watched.has(key):
		_watched[key] = {
			"index": _watched.size() + 1,
			"dug": false,
			"trail": [],
			"failure": "",
			"failure_time": 0.0,
		}
	return _watched[key]


func _watch_lemmings() -> void:
	for node in get_tree().get_nodes_in_group("lemmings"):
		var lemming: LemmingController = node
		if not is_instance_valid(lemming):
			continue

		var entry: Dictionary = _entry_for(lemming)
		var body := lemming.get_body_rect()

		var trail: Array = entry.trail
		trail.append("t=%.2f feet=%.1f vy=%.0f state=%d on_floor=%s" % [
			_elapsed, body.end.y, lemming.velocity.y,
			lemming.state_machine.current_state, lemming.is_on_floor()
		])
		if trail.size() > TRAIL_LENGTH:
			trail.pop_front()

		if entry.failure != "":
			continue

		# Shrunk so merely resting on a surface does not read as being inside it.
		if _terrain.is_solid_in_rect(body.grow(-3.0)):
			entry.failure = "body inside solid terrain"
			entry.failure_time = _elapsed
		elif body.position.y > _lowest_solid_y:
			entry.failure = "body below the lowest solid row"
			entry.failure_time = _elapsed


func _report() -> void:
	set_physics_process(false)
	print("")

	var failed := 0
	for key in _watched:
		var entry: Dictionary = _watched[key]
		if entry.failure == "":
			continue
		failed += 1
		print("LEMMING %d — %s at t=%.2f" % [entry.index, entry.failure, entry.failure_time])
		for line in entry.trail:
			print("    %s" % line)
		print("")

	print("%d lemmings watched, %d went through terrain" % [_watched.size(), failed])
	get_tree().quit(0 if failed == 0 else 1)
