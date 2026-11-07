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
## Lays the items found in broken blocks (null when the level has none).
var dig_dropper: DigDropper = null

## Screen space taken by the HUD at the top and the tool panel at the
## bottom, which the camera can scroll past the level's edges (LevelCamera).
const HUD_TOP_MARGIN := 48.0
const TOOL_PANEL_BOTTOM_MARGIN := 64.0
## Rows above the top of an authored level only hold boundary walls that
## keep lemmings from climbing out; the view starts this far above the
## highest entrance or exit instead of at the top of those walls.
const VIEW_HEADROOM := 64.0

## How long a sacrifice plays before it can end the level (just over
## SacrificeEffect's lifetime).
const SACRIFICE_RESOLVE_DELAY_SECONDS := 0.9

var _spawn_points: Array = []
## Lemmings spawned that have neither died nor got out yet.
var _lemmings_out: Array[LemmingController] = []
var _ending_now: bool = false
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
	_apply_art_theme(LevelEnvironment.by_kind(level_data.environment_kind).terrain_theme)


## The setting's blocks, entrance and exit, for the ones the scene left on
## the default look. Done here, before the children's _ready(), which is
## when each of them reads its theme.
func _apply_art_theme(theme: StringName) -> void:
	if theme == &"":
		return
	for child in get_children():
		if child is TerrainDestructible or child is SpawnPoint or child is ExitPoint:
			if child.art_theme == &"":
				child.art_theme = theme


## The small puff of a tool hitting the unbreakable border.
const REFUSAL_BLAST_RADIUS := 14.0
const REFUSAL_REPEAT_MS := 600
var _last_refusals: Dictionary = {}


func _ready() -> void:
	_spawn_points = get_tree().get_nodes_in_group("spawn_points")
	assert(not _spawn_points.is_empty(), "LevelManager requires at least one SpawnPoint in the 'spawn_points' group")

	for exit_point in get_tree().get_nodes_in_group("exit_points"):
		exit_point.lemming_exited.connect(_on_lemming_exited)

	for spawn_point in _spawn_points:
		spawn_point.lemming_spawned.connect(_on_lemming_spawned)
		spawn_point.all_lemmings_spawned.connect(_on_spawn_point_finished)
		spawn_point.start(level_data.spawn_rate, level_data.total_lemmings)

	for terrain in get_tree().get_nodes_in_group("terrain"):
		(terrain as TerrainDestructible).unbreakable_hit.connect(_on_unbreakable_hit)
		if level_data.dressing.has("area"):
			StageDressing.apply(terrain as TerrainDestructible, level_data.dressing)

	AudioManager.play_music_track(&"level_theme")
	_set_up_view()
	_add_solution_overlay()
	_add_dig_dropper()
	_add_item_collector()


## Items that turn up where blocks break, when the level has a table for
## them. Whoever hands items out sets the dropper's inventory and takes its
## pickups (ItemCollector here, a mode's session there).
func _add_dig_dropper() -> void:
	if level_data.dig_drops == null:
		return
	dig_dropper = DigDropper.new(self, level_data.dig_drops)
	add_child(dig_dropper)


## A level whose tools come from items gets its items, its tool bar and
## the bookkeeping between them (ItemCollector). So does a fixed-bar level
## whose finds the core hands out (LevelData.drops_on_fixed_bar), without
## the bar that grows.
func _add_item_collector() -> void:
	var takes_drops := level_data.dig_drops != null and level_data.drops_on_fixed_bar
	if not level_data.tools_from_items and not takes_drops:
		return
	var collector := ItemCollector.new(self)
	collector.name = "ItemCollector"
	add_child(collector)


## In developer mode, the recorded solution can be shown over the level, to
## tell an impossible stage from a tool given in the wrong place.
func _add_solution_overlay() -> void:
	if not GameManager.developer_mode or level_data.solution.is_empty():
		return
	var overlay := SolutionOverlay.new()
	overlay.name = "SolutionOverlay"
	overlay.steps = level_data.solution
	overlay.caption = level_data.solution_note
	add_child(overlay)


## A tool bit into the border, which nothing breaks: it blows up in a small
## puff there (once per spot, however many times the tool tried).
func _on_unbreakable_hit(world_position: Vector2) -> void:
	var now := Time.get_ticks_msec()
	if _last_refusals.get(world_position, -100000) > now - REFUSAL_REPEAT_MS:
		return
	_last_refusals[world_position] = now
	ExplosionEffect.spawn(self, world_position, REFUSAL_BLAST_RADIUS)
	AudioManager.play_sound(&"explosion")


## The background filling the screen, the rock frame around the level's
## area, and a camera over it, unless a camera is already in charge (the
## editor keeps its own view while testing a drawing).
func _set_up_view() -> void:
	if get_viewport().get_camera_2d() != null:
		return
	var bounds := _compute_view_bounds()
	var environment := LevelEnvironment.by_kind(level_data.environment_kind)
	var background := LevelBackground.new()
	background.environment = environment
	add_child(background)
	if environment.has_frame:
		var backdrop := LevelBackdrop.new()
		backdrop.area = bounds
		backdrop.environment = environment
		add_child(backdrop)
	var camera := LevelCamera.new()
	camera.bounds = bounds
	camera.top_margin = HUD_TOP_MARGIN
	camera.bottom_margin = TOOL_PANEL_BOTTOM_MARGIN
	add_child(camera)
	camera.focus_on(_spawn_points[0].global_position)


## The terrain's extent, plus the entrances and exits, cut at the top a
## little above the highest of those (see VIEW_HEADROOM).
func _compute_view_bounds() -> Rect2:
	var bounds := Rect2()
	var terrain: TerrainDestructible = get_tree().get_first_node_in_group("terrain")
	if terrain != null and terrain.get_used_rect().has_area():
		var cells := terrain.get_used_rect()
		var cell_size := terrain.get_cell_size()
		bounds = Rect2(terrain.to_global(Vector2(cells.position) * cell_size), Vector2(cells.size) * cell_size)
	var markers: Array = _spawn_points + get_tree().get_nodes_in_group("exit_points")
	var highest := INF
	for marker in markers:
		var point: Vector2 = marker.global_position
		bounds = bounds.expand(point) if bounds.has_area() else Rect2(point, Vector2.ONE)
		highest = minf(highest, point.y)
	var top := minf(highest - VIEW_HEADROOM, 0.0)
	if bounds.position.y < top:
		bounds.size.y -= top - bounds.position.y
		bounds.position.y = top
	return bounds


func _process(delta: float) -> void:
	if _level_ended:
		return

	time_remaining = max(time_remaining - delta, 0.0)
	time_remaining_changed.emit(time_remaining)

	if time_remaining <= 0.0:
		_finish_level()


func _on_lemming_spawned(lemming: LemmingController) -> void:
	lemmings_spawned_count += 1
	AudioManager.play_sound(&"spawn")
	_lemmings_out.append(lemming)
	lemming.died.connect(func(_cause: LemmingController.DeathCause) -> void: _lemmings_out.erase(lemming))
	lemming.died.connect(_on_lemming_died)
	lemming.clicked.connect(SkillManager.try_assign_to)
	lemming.carried_tool_dropped.connect(func(skill: SkillBase) -> void: SkillManager.refund_charge(String(skill.id)))
	CarriedToolIndicator.attach_to(lemming)
	# The HUD shows how many are out, which a spawn changes too.
	_emit_counts_changed()


func _on_lemming_died(cause: LemmingController.DeathCause) -> void:
	# An explosion already makes its own sound.
	match cause:
		LemmingController.DeathCause.FALL:
			AudioManager.play_sound(&"splat")
		LemmingController.DeathCause.SACRIFICE:
			AudioManager.play_sound(&"sacrifice")
	lemmings_lost_count += 1
	_emit_counts_changed()
	# A sacrifice may be the level's last lemming; let its animation play
	# before the level ends.
	if cause == LemmingController.DeathCause.SACRIFICE:
		await get_tree().create_timer(SACRIFICE_RESOLVE_DELAY_SECONDS, false).timeout
	_check_level_resolved()


func _on_lemming_exited(lemming: LemmingController) -> void:
	_lemmings_out.erase(lemming)
	lemmings_saved_count += 1
	AudioManager.play_sound(&"saved")
	_emit_counts_changed()
	_check_level_resolved()


## Ends the level at once, for a player whose remaining lemmings are stuck
## and who would otherwise wait for the clock: no more lemmings come out,
## every one still in the level is sacrificed (its own animation plays).
## Whoever got out is kept; the ones never released are simply not saved
## (the percentage is over the level's total).
func end_now() -> void:
	if _level_ended or _ending_now:
		return
	_ending_now = true
	for spawn_point in _spawn_points:
		spawn_point.stop()
	# One already walking into an exit is saved, and die() leaves it alone.
	for lemming in _lemmings_out.duplicate():
		lemming.die(LemmingController.DeathCause.SACRIFICE)
	await get_tree().create_timer(SACRIFICE_RESOLVE_DELAY_SECONDS, false).timeout
	_finish_level()


func is_ending() -> bool:
	return _level_ended or _ending_now


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
		AudioManager.play_sound(&"level_won")
		level_completed.emit(percentage_saved)
	else:
		AudioManager.play_sound(&"level_lost")
		level_failed.emit(percentage_saved)
