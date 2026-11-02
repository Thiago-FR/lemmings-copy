class_name LevelEditorController
extends Node2D
## "Modo livre": paint a scenario, place an entrance and an exit, choose how
## many lemmings and tools there are, then test it with Play / Pause /
## Restart.
##
## The drawing lives under EditLayer and is never played on directly. Play
## takes EditLayer out of the tree and builds a separate level from copies of
## it (EditorPlaySession), so the regular LevelManager, SpawnPoint, ExitPoint
## and SkillPanel run unchanged and only ever see the copies. Restart frees
## that level and puts EditLayer back, which restores the drawing exactly as
## it was without having to undo anything the lemmings did.
##
## Entrances: a click with the Entrance tool moves the nearest one (or
## makes the first), Shift+click adds another, a click on an entrance turns
## it to face the other way (the arrow shows which), and the right button
## on one removes it while others are left. Several entrances share the
## troop.
##
## Developer mode adds Open and Save: any of the 15 campaign levels (or a
## backup of one) can be opened here, and the drawing saved over any of
## them; the level replaced is backed up first (CampaignLevelStore).

enum Mode { EDITING, PLAYING, PAUSED }

const SPAWN_POINT_SCENE := preload("res://scenes/level/spawn_point.tscn")
const EXIT_POINT_SCENE := preload("res://scenes/level/exit_point.tscn")
const MAIN_MENU_SCENE_PATH := "res://scenes/main/main_menu.tscn"
## Half the exit's 48px height (exit_point.tscn): the exit is placed with its
## bottom on the bottom of the clicked cell, so it stands on the floor below.
const EXIT_HALF_HEIGHT := 24.0
## A fast drag can skip cells between two mouse events; the stroke is filled
## in at this spacing (a quarter cell, the brick height).
const STROKE_STEP := 8.0
## Size of the drawing, in blocks: much bigger than one screen, scrolled
## with the camera (arrow keys/WASD, middle mouse drag, window edges).
const MAP_SIZE_TILES := Vector2i(120, 60)
## Screen space covered by the toolbar at the top and the counters at the
## bottom, which the camera can scroll past the drawing's edges.
const TOOLBAR_TOP_MARGIN := 84.0
const COUNTERS_BOTTOM_MARGIN := 120.0

var mode: Mode = Mode.EDITING
var current_tool: EditorTool.Kind = EditorTool.Kind.BLOCK
var play_session: LevelManager = null

@onready var edit_layer: Node2D = $EditLayer
@onready var terrain: TerrainDestructible = $EditLayer/Terrain
@onready var toolbar: EditorToolbar = $Toolbar
@onready var _grid_overlay: EditorGridOverlay = $EditLayer/GridOverlay

var _brush: EditorBrush
var _entrances: Array[SpawnPoint] = []
var _exit: ExitPoint = null
var _is_stroking := false
var _stroke_tool: EditorTool.Kind = EditorTool.Kind.BLOCK
var _last_stroke_position := Vector2.ZERO
## The campaign level last opened or saved (developer mode), -1 if none.
var _campaign_index := -1


func _ready() -> void:
	AudioManager.play_music_track(&"menu_theme")
	# The toolbar and this controller must keep answering clicks while the
	# test run is paused; the run itself is made pausable in play().
	process_mode = Node.PROCESS_MODE_ALWAYS
	_brush = EditorBrush.new(terrain)
	_grid_overlay.area = get_paint_area()
	_grid_overlay.cell_size = terrain.get_cell_size()
	_set_up_view()

	toolbar.tool_selected.connect(select_tool)
	toolbar.play_requested.connect(play)
	toolbar.pause_requested.connect(pause)
	toolbar.restart_requested.connect(restart)
	toolbar.menu_requested.connect(go_to_main_menu)
	toolbar.open_level_requested.connect(_open_level_picker)
	toolbar.save_level_requested.connect(_save_level_picker)
	toolbar.select_tool(current_tool)
	_enter_editing_mode()


## The area that can be painted: the whole drawing, not just the screen.
func get_paint_area() -> Rect2:
	return Rect2(Vector2.ZERO, Vector2(MAP_SIZE_TILES) * terrain.get_cell_size())


## Backdrop and camera over the drawing. Children of the editor, not of
## EditLayer, so they stay while a test run replaces EditLayer; the run's
## LevelManager sees this camera and does not make its own.
func _set_up_view() -> void:
	add_child(LevelBackground.new())
	var backdrop := LevelBackdrop.new()
	backdrop.area = get_paint_area()
	add_child(backdrop)
	var camera := LevelCamera.new()
	# The left button paints here.
	camera.left_drag = false
	camera.name = "Camera"
	camera.bounds = get_paint_area()
	camera.top_margin = TOOLBAR_TOP_MARGIN
	camera.bottom_margin = COUNTERS_BOTTOM_MARGIN
	add_child(camera)
	# Start at the bottom-left corner, where a floor usually goes first.
	camera.focus_on(Vector2(0.0, get_paint_area().end.y))


func select_tool(kind: EditorTool.Kind) -> void:
	current_tool = kind
	_grid_overlay.hide_preview()


## Applies the current tool at world_position, as a click there would.
func paint_at(world_position: Vector2) -> void:
	_apply_tool(current_tool, world_position)


## Applies the current tool along a straight line, as a drag would.
func paint_line(from_position: Vector2, to_position: Vector2) -> void:
	_apply_tool_along(current_tool, from_position, to_position)


func has_entrance() -> bool:
	return not _entrances.is_empty()


func get_entrance_count() -> int:
	return _entrances.size()


func has_exit() -> bool:
	return _exit != null


func get_entrance_position() -> Vector2:
	return _entrances[0].position if has_entrance() else Vector2.ZERO


func get_exit_position() -> Vector2:
	return _exit.position if has_exit() else Vector2.ZERO


## Starts a test run of the drawing, or continues a paused one.
func play() -> void:
	match mode:
		Mode.PAUSED:
			_resume()
		Mode.EDITING:
			_start_run()


func pause() -> void:
	if mode != Mode.PLAYING:
		return
	GameManager.pause_game()
	mode = Mode.PAUSED
	toolbar.update_for_state(false, true)


## Ends the test run and returns to the drawing exactly as it was painted.
func restart() -> void:
	if mode == Mode.EDITING:
		return
	_end_run()
	_enter_editing_mode()


func go_to_main_menu() -> void:
	_end_run()
	get_tree().change_scene_to_file(MAIN_MENU_SCENE_PATH)


func _unhandled_input(event: InputEvent) -> void:
	if mode != Mode.EDITING:
		return

	var mouse_button := event as InputEventMouseButton
	if mouse_button != null:
		_handle_mouse_button(mouse_button)
		return

	var motion := event as InputEventMouseMotion
	if motion != null:
		_handle_mouse_motion()


func _handle_mouse_button(event: InputEventMouseButton) -> void:
	if event.button_index != MOUSE_BUTTON_LEFT and event.button_index != MOUSE_BUTTON_RIGHT:
		return
	if not event.pressed:
		_is_stroking = false
		return

	var world_position := get_global_mouse_position()
	if not get_paint_area().has_point(world_position):
		return
	# Right button erases with any tool, so a mistake can be fixed without
	# going back to the toolbar.
	_stroke_tool = EditorTool.Kind.ERASER if event.button_index == MOUSE_BUTTON_RIGHT else current_tool
	if _stroke_tool == EditorTool.Kind.ENTRANCE and event.shift_pressed:
		add_entrance(world_position)
		get_viewport().set_input_as_handled()
		return
	if _stroke_tool == EditorTool.Kind.ERASER and remove_entrance_at(world_position):
		get_viewport().set_input_as_handled()
		return
	_apply_tool(_stroke_tool, world_position)
	_is_stroking = EditorTool.paints_on_drag(_stroke_tool)
	_last_stroke_position = world_position
	get_viewport().set_input_as_handled()


func _handle_mouse_motion() -> void:
	var world_position := get_global_mouse_position()
	if not get_paint_area().has_point(world_position):
		_grid_overlay.hide_preview()
		return
	_grid_overlay.show_preview(_brush.target_rect(current_tool, world_position))
	if _is_stroking:
		_apply_tool_along(_stroke_tool, _last_stroke_position, world_position)
		_last_stroke_position = world_position


func _apply_tool_along(kind: EditorTool.Kind, from_position: Vector2, to_position: Vector2) -> void:
	var step_count := maxi(1, ceili(from_position.distance_to(to_position) / STROKE_STEP))
	for step in range(step_count + 1):
		_apply_tool(kind, from_position.lerp(to_position, float(step) / step_count))


func _apply_tool(kind: EditorTool.Kind, world_position: Vector2) -> void:
	assert(mode == Mode.EDITING, "The drawing can only change while editing")
	match kind:
		EditorTool.Kind.ENTRANCE:
			_place_entrance(world_position)
		EditorTool.Kind.EXIT:
			_place_exit(world_position)
		_:
			_brush.apply(kind, world_position)


## Moves the nearest entrance here (makes the first one if there is none);
## on an entrance's own cell, turns it around instead.
func _place_entrance(world_position: Vector2) -> void:
	var on_cell := _entrance_at(world_position)
	if on_cell != null:
		_set_facing(on_cell, not on_cell.faces_left)
		return
	if not _can_hold_entrance(world_position):
		return
	if _entrances.is_empty():
		_make_entrance(terrain.cell_rect_at(world_position).get_center(), false)
		return
	var nearest := _entrances[0]
	for entrance in _entrances:
		if entrance.position.distance_to(world_position) < nearest.position.distance_to(world_position):
			nearest = entrance
	nearest.position = terrain.cell_rect_at(world_position).get_center()


## Another entrance (Shift+click with the Entrance tool).
func add_entrance(world_position: Vector2) -> void:
	if _entrance_at(world_position) != null or not _can_hold_entrance(world_position):
		return
	_make_entrance(terrain.cell_rect_at(world_position).get_center(), false)


## Removes the entrance on that cell while another is left; returns whether
## one was removed (otherwise the eraser works on the terrain as usual).
func remove_entrance_at(world_position: Vector2) -> bool:
	var entrance := _entrance_at(world_position)
	if entrance == null or _entrances.size() <= 1:
		return false
	_entrances.erase(entrance)
	entrance.queue_free()
	return true


## A lemming released inside rock would be stuck there from its first
## frame.
func _can_hold_entrance(world_position: Vector2) -> bool:
	if terrain.is_solid_in_rect(terrain.cell_rect_at(world_position).grow(-1.0)):
		toolbar.flash(&"entrance")
		return false
	return true


## The entrance standing in the clicked cell, if any. Campaign levels put
## entrances higher than the cell centre, so the entrance's own cell counts
## too.
func _entrance_at(world_position: Vector2) -> SpawnPoint:
	var cell := terrain.cell_rect_at(world_position)
	for entrance in _entrances:
		if cell.has_point(entrance.position) or terrain.cell_rect_at(entrance.position).has_point(world_position):
			return entrance
	return null


func _make_entrance(at: Vector2, faces_left: bool) -> SpawnPoint:
	var entrance: SpawnPoint = SPAWN_POINT_SCENE.instantiate()
	entrance.position = at
	var arrow := EntranceArrow.new()
	arrow.name = "FacingArrow"
	entrance.add_child(arrow)
	edit_layer.add_child(entrance)
	_entrances.append(entrance)
	_set_facing(entrance, faces_left)
	return entrance


func _set_facing(entrance: SpawnPoint, faces_left: bool) -> void:
	entrance.faces_left = faces_left
	var arrow := entrance.get_node_or_null("FacingArrow") as EntranceArrow
	if arrow != null:
		arrow.faces_left = faces_left
		arrow.queue_redraw()


## Which way the lemmings of an entrance will walk out, drawn beside it.
class EntranceArrow extends Node2D:
	const COLOUR := Color(1.0, 0.86, 0.3)
	const OUTLINE := Color(0.1, 0.06, 0.08)
	var faces_left := false

	func _draw() -> void:
		var side := -1.0 if faces_left else 1.0
		var tip := Vector2(side * 40.0, 0.0)
		var points := PackedVector2Array([tip, Vector2(side * 26.0, -8.0), Vector2(side * 26.0, 8.0)])
		draw_colored_polygon(points, COLOUR)
		points.append(tip)
		draw_polyline(points, OUTLINE, 1.5)


func _place_exit(world_position: Vector2) -> void:
	var cell_rect := terrain.cell_rect_at(world_position)
	if _exit == null:
		_exit = EXIT_POINT_SCENE.instantiate()
		edit_layer.add_child(_exit)
	_exit.position = Vector2(cell_rect.get_center().x, cell_rect.end.y - EXIT_HALF_HEIGHT)


func _start_run() -> void:
	if not has_entrance():
		toolbar.flash(&"entrance")
		return
	if toolbar.get_lemming_count() <= 0:
		toolbar.flash(&"lemmings")
		return

	_is_stroking = false
	_grid_overlay.hide_preview()
	GameManager.current_level_data = EditorPlaySession.make_level_data(
		toolbar.get_lemming_count(), toolbar.get_skill_counts(), scene_file_path
	)
	var exit_positions: Array[Vector2] = []
	if has_exit():
		exit_positions.append(_exit.position)
	play_session = EditorPlaySession.build(terrain, _entrance_specs(), exit_positions, toolbar.get_lemming_count())
	play_session.process_mode = Node.PROCESS_MODE_PAUSABLE
	play_session.counts_changed.connect(_on_counts_changed)
	play_session.level_completed.connect(_on_run_finished)
	play_session.level_failed.connect(_on_run_finished)

	# Out of the tree, the drawing's terrain, entrance and exit leave their
	# groups, so the run's lemmings and LevelManager only find the copies.
	remove_child(edit_layer)
	add_child(play_session)
	move_child(play_session, 0)

	mode = Mode.PLAYING
	toolbar.update_for_state(false, false)
	_on_counts_changed(0, 0, play_session.lemmings_spawned_count, toolbar.get_lemming_count())


func _entrance_specs() -> Array[Dictionary]:
	var specs: Array[Dictionary] = []
	for entrance in _entrances:
		specs.append({"position": entrance.position, "faces_left": entrance.faces_left})
	return specs


# --- Campaign levels (developer mode) ----------------------------------------

func _open_level_picker() -> void:
	var picker := EditorLevelPicker.new(EditorLevelPicker.Purpose.OPEN, _campaign_index)
	picker.picked.connect(open_campaign_level)
	add_child(picker)


func _save_level_picker() -> void:
	if not has_entrance():
		toolbar.flash(&"entrance")
		return
	var picker := EditorLevelPicker.new(EditorLevelPicker.Purpose.SAVE, _campaign_index)
	picker.picked.connect(func(index: int, _folder: String) -> void: _confirm_save(index))
	add_child(picker)


func _confirm_save(index: int) -> void:
	var modal := ConfirmModal.new("level_save", "Substituir a fase %d?" % (index + 1), "Salvar")
	modal.add_fact("campaign", index + 1, Campaign.load_level_data(index).level_name)
	modal.add_fact("hud_clock", "backup", "A versão de agora fica guardada e pode ser aberta de novo")
	modal.confirmed.connect(func() -> void: save_campaign_level(index))
	add_child(modal)


## Replaces the drawing with a campaign level, or one of its backups.
func open_campaign_level(index: int, backup_folder: String = "") -> void:
	var drawing := CampaignLevelStore.read(index) if backup_folder == "" else CampaignLevelStore.read_backup(backup_folder)
	_load_drawing(drawing)
	_campaign_index = index
	AudioManager.play_sound(&"select_tool")


## Writes the drawing over a campaign level, backing it up first. Returns
## the backup folder, "" if it failed.
func save_campaign_level(index: int) -> String:
	var backup := CampaignLevelStore.write(index, get_drawing())
	if backup == "":
		toolbar.flash(&"entrance")
		return ""
	_campaign_index = index
	AudioManager.play_sound(&"select_tool")
	return backup


## The drawing, as CampaignLevelStore reads and writes it.
func get_drawing() -> Dictionary:
	return {
		"tile_map_data": terrain.tile_map_data,
		"bricks": terrain.get_bricks(),
		"entrances": _entrance_specs(),
		"exit": _exit.position if has_exit() else null,
		"total_lemmings": toolbar.get_lemming_count(),
		"skill_counts": toolbar.get_skill_counts(),
	}


func _load_drawing(drawing: Dictionary) -> void:
	for brick in terrain.get_bricks():
		terrain.remove_bricks_in(brick)
	terrain.clear()
	terrain.tile_map_data = drawing.tile_map_data
	for brick in drawing.bricks:
		terrain.place_brick(brick)
	for entrance in _entrances:
		entrance.queue_free()
	_entrances.clear()
	for entrance in drawing.entrances:
		_make_entrance(entrance.position, entrance.faces_left)
	if drawing.exit == null:
		if _exit != null:
			_exit.queue_free()
		_exit = null
	else:
		if _exit == null:
			_exit = EXIT_POINT_SCENE.instantiate()
			edit_layer.add_child(_exit)
		_exit.position = drawing.exit
	toolbar.set_counts(drawing.total_lemmings, drawing.skill_counts)
	if has_entrance():
		(get_node("Camera") as LevelCamera).focus_on(_entrances[0].position)


func _resume() -> void:
	GameManager.resume_game()
	mode = Mode.PLAYING
	toolbar.update_for_state(false, false)


func _end_run() -> void:
	GameManager.resume_game()
	if play_session != null:
		remove_child(play_session)
		play_session.queue_free()
		play_session = null
	SkillManager.selected_skill_id = ""


func _enter_editing_mode() -> void:
	if edit_layer.get_parent() == null:
		add_child(edit_layer)
		move_child(edit_layer, 0)
	mode = Mode.EDITING
	toolbar.update_for_state(true, false)


func _on_counts_changed(saved_count: int, lost_count: int, spawned_count: int, total_count: int) -> void:
	toolbar.show_run_counts(spawned_count - saved_count - lost_count, saved_count, lost_count, total_count)


## Not a result screen: the run just stops counting (its counts stay on
## screen) and the player decides when to restart, so the editor never
## blocks on a win/lose dialog.
func _on_run_finished(_percentage_saved: float) -> void:
	pass
