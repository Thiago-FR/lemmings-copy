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

var mode: Mode = Mode.EDITING
var current_tool: EditorTool.Kind = EditorTool.Kind.BLOCK
var play_session: LevelManager = null

@onready var edit_layer: Node2D = $EditLayer
@onready var terrain: TerrainDestructible = $EditLayer/Terrain
@onready var toolbar: EditorToolbar = $Toolbar
@onready var _grid_overlay: EditorGridOverlay = $EditLayer/GridOverlay

var _brush: EditorBrush
var _entrance: SpawnPoint = null
var _exit: ExitPoint = null
var _is_stroking := false
var _stroke_tool: EditorTool.Kind = EditorTool.Kind.BLOCK
var _last_stroke_position := Vector2.ZERO
## The run's latest status line, shown again when a paused run resumes.
var _run_status_text := ""


func _ready() -> void:
	# The toolbar and this controller must keep answering clicks while the
	# test run is paused; the run itself is made pausable in play().
	process_mode = Node.PROCESS_MODE_ALWAYS
	_brush = EditorBrush.new(terrain)
	_grid_overlay.area = get_paint_area()
	_grid_overlay.cell_size = terrain.get_cell_size()

	toolbar.tool_selected.connect(select_tool)
	toolbar.play_requested.connect(play)
	toolbar.pause_requested.connect(pause)
	toolbar.restart_requested.connect(restart)
	toolbar.menu_requested.connect(go_to_main_menu)
	toolbar.select_tool(current_tool)
	_enter_editing_mode()


## The area that can be painted: the visible screen.
func get_paint_area() -> Rect2:
	return Rect2(Vector2.ZERO, get_viewport_rect().size)


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
	return _entrance != null


func has_exit() -> bool:
	return _exit != null


func get_entrance_position() -> Vector2:
	return _entrance.position if has_entrance() else Vector2.ZERO


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
	toolbar.set_status("Pausado. Jogar continua, Reiniciar volta ao desenho.")


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


func _place_entrance(world_position: Vector2) -> void:
	var cell_rect := terrain.cell_rect_at(world_position)
	# A lemming released inside rock would be stuck there from its first
	# frame.
	if terrain.is_solid_in_rect(cell_rect.grow(-1.0)):
		toolbar.set_status("A entrada precisa ficar num espaço vazio.")
		return
	if _entrance == null:
		_entrance = SPAWN_POINT_SCENE.instantiate()
		edit_layer.add_child(_entrance)
	_entrance.position = cell_rect.get_center()


func _place_exit(world_position: Vector2) -> void:
	var cell_rect := terrain.cell_rect_at(world_position)
	if _exit == null:
		_exit = EXIT_POINT_SCENE.instantiate()
		edit_layer.add_child(_exit)
	_exit.position = Vector2(cell_rect.get_center().x, cell_rect.end.y - EXIT_HALF_HEIGHT)


func _start_run() -> void:
	if not has_entrance():
		toolbar.set_status("Coloque a entrada antes de jogar.")
		return
	if toolbar.get_lemming_count() <= 0:
		toolbar.set_status("Escolha pelo menos 1 boneco antes de jogar.")
		return

	_is_stroking = false
	_grid_overlay.hide_preview()
	GameManager.current_level_data = EditorPlaySession.make_level_data(
		toolbar.get_lemming_count(), toolbar.get_skill_counts(), scene_file_path
	)
	var exit_positions: Array[Vector2] = []
	if has_exit():
		exit_positions.append(_exit.position)
	play_session = EditorPlaySession.build(terrain, _entrance.position, exit_positions)
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


func _resume() -> void:
	GameManager.resume_game()
	mode = Mode.PLAYING
	toolbar.update_for_state(false, false)
	toolbar.set_status(_run_status_text)


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
	toolbar.set_status("Desenhando: escolha uma ferramenta e clique ou arraste. Botão direito apaga.")


func _on_counts_changed(saved_count: int, lost_count: int, spawned_count: int, total_count: int) -> void:
	var out_count := spawned_count - saved_count - lost_count
	_show_run_status("Jogando. Na fase: %d   Salvos: %d   Perdidos: %d   Total: %d" % [out_count, saved_count, lost_count, total_count])


## Not a result screen: the run just stops counting and the player decides
## when to restart, so the editor never blocks on a win/lose dialog.
func _on_run_finished(_percentage_saved: float) -> void:
	_show_run_status("Fim do teste. Salvos: %d de %d. Reiniciar volta ao desenho." % [
		play_session.lemmings_saved_count, play_session.level_data.total_lemmings
	])


func _show_run_status(text: String) -> void:
	_run_status_text = text
	# While paused the status line explains how to continue instead.
	if mode != Mode.PAUSED:
		toolbar.set_status(text)
