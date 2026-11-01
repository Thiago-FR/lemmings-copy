class_name LevelManager
extends Node2D
## Root script for level scenes. Starts the SpawnPoint(s), counts lemmings
## saved (via ExitPoint) and lost (on death), ticks down the level timer,
## and decides victory/defeat once every lemming has spawned and resolved.
##
## This is the one place that wires the self-contained pieces together:
## entrances, exits and lemmings only emit signals, and the level decides
## what they mean (a click assigns the selected skill, an exit counts as
## saved, a death counts as lost).

signal counts_changed(saved_count: int, lost_count: int, spawned_count: int, total_count: int)
signal time_remaining_changed(seconds_remaining: float)
signal level_completed(percentage_saved: float)
signal level_failed(percentage_saved: float)

var level_data: LevelData
var lemmings_spawned_count: int = 0
var lemmings_saved_count: int = 0
var lemmings_lost_count: int = 0
var time_remaining: float = 0.0

var _spawn_points: Array = []
var _finished_spawn_point_count: int = 0
var _level_ended: bool = false


func _enter_tree() -> void:
	# _enter_tree runs parent-first (unlike _ready, which runs child-first),
	# so level_data/time_remaining and the group membership are already in
	# place by the time children like Hud/SkillPanel reach their own _ready().
	add_to_group("level_manager")

	level_data = GameManager.current_level_data
	assert(level_data != null, "LevelManager requires GameManager.current_level_data to be set before the level scene loads")
	time_remaining = float(level_data.time_limit_seconds)
	SkillManager.initialize_for_level(level_data)


func _ready() -> void:
	_spawn_points = get_tree().get_nodes_in_group("spawn_points")
	assert(not _spawn_points.is_empty(), "LevelManager requires at least one SpawnPoint in the 'spawn_points' group")

	for exit_point in get_tree().get_nodes_in_group("exit_points"):
		exit_point.lemming_exited.connect(_on_lemming_exited)

	for spawn_point in _spawn_points:
		spawn_point.lemming_spawned.connect(_on_lemming_spawned)
		spawn_point.all_lemmings_spawned.connect(_on_spawn_point_finished)
		spawn_point.start(level_data.spawn_rate, level_data.total_lemmings)


func _process(delta: float) -> void:
	if _level_ended:
		return

	time_remaining = max(time_remaining - delta, 0.0)
	time_remaining_changed.emit(time_remaining)

	if time_remaining <= 0.0:
		_finish_level()


func _on_lemming_spawned(lemming: LemmingController) -> void:
	lemmings_spawned_count += 1
	lemming.died.connect(_on_lemming_died)
	lemming.clicked.connect(SkillManager.try_assign_to)


func _on_lemming_died(_cause: LemmingController.DeathCause) -> void:
	lemmings_lost_count += 1
	_emit_counts_changed()
	_check_level_resolved()


func _on_lemming_exited(_lemming: LemmingController) -> void:
	lemmings_saved_count += 1
	_emit_counts_changed()
	_check_level_resolved()


func _emit_counts_changed() -> void:
	counts_changed.emit(lemmings_saved_count, lemmings_lost_count, lemmings_spawned_count, level_data.total_lemmings)


func _on_spawn_point_finished() -> void:
	_finished_spawn_point_count += 1
	_check_level_resolved()


func _check_level_resolved() -> void:
	var all_spawned := _finished_spawn_point_count >= _spawn_points.size()
	var all_resolved := (lemmings_saved_count + lemmings_lost_count) >= lemmings_spawned_count
	if all_spawned and all_resolved:
		_finish_level()


func _finish_level() -> void:
	if _level_ended:
		return
	_level_ended = true

	var percentage_saved := 0.0
	if level_data.total_lemmings > 0:
		percentage_saved = float(lemmings_saved_count) / float(level_data.total_lemmings)

	if percentage_saved >= level_data.required_percentage:
		level_completed.emit(percentage_saved)
	else:
		level_failed.emit(percentage_saved)
