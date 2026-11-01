extends Node
## Drives the level editor ("Modo livre") the way a player would: paints a
## floor, ladder and bricks, places the entrance and exit, sets the counts,
## then checks Play, Pause, Play again and Restart. Run via:
##   godot --headless res://tests/test_level_editor.tscn
## Exits 0 on success, 1 otherwise.

const EDITOR_SCENE_PATH := "res://scenes/editor/level_editor.tscn"
const LEMMING_COUNT := 3
const DIGGER_COUNT := 2
const FLOOR_Y := 368.0          # centre of row 11
const ENTRANCE_CLICK := Vector2(80, 272)
const EXIT_CLICK := Vector2(304, 336)
const LADDER_CLICK := Vector2(720, 80)
const BRICK_CLICKS: Array[Vector2] = [Vector2(400, 100), Vector2(432, 103)]
const SCRATCH_CLICK := Vector2(560, 200)
const SCRATCH_BRICK_CLICK := Vector2(600, 140)
const RUN_BEFORE_PAUSE_FRAMES := 90
const PAUSE_FRAMES := 30
const ALL_SAVED_TIMEOUT_FRAMES := 60 * 20

var _editor: LevelEditorController
var _failures: Array[String] = []


func _ready() -> void:
	# Pause freezes the tree; this test must keep running to look at it.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run.call_deferred()


func _run() -> void:
	_editor = (load(EDITOR_SCENE_PATH) as PackedScene).instantiate()
	add_child(_editor)
	await _frames(2)

	_check_painting()
	var drawing := _snapshot(_editor.terrain)

	_editor.play()
	_expect(_editor.mode == LevelEditorController.Mode.EDITING, "Play without an entrance must stay in editing mode")

	_editor.select_tool(EditorTool.Kind.ENTRANCE)
	_editor.paint_at(ENTRANCE_CLICK)
	_editor.select_tool(EditorTool.Kind.EXIT)
	_editor.paint_at(EXIT_CLICK)
	_expect(_editor.get_entrance_position() == Vector2(80, 272), "entrance at the clicked cell's centre, got %s" % _editor.get_entrance_position())
	_expect(_editor.get_exit_position() == Vector2(304, 328), "exit standing on the floor below the clicked cell, got %s" % _editor.get_exit_position())
	_editor.toolbar.lemming_counter.value = LEMMING_COUNT
	_editor.toolbar.skill_counters["digger"].value = DIGGER_COUNT
	_editor.toolbar.lemming_counter.value = 99
	_expect(_editor.toolbar.lemming_counter.value == 50, "counters clamp to 50")
	_editor.toolbar.lemming_counter.value = LEMMING_COUNT

	await _check_play_and_pause()
	await _check_lemmings_reach_exit()
	await _check_restart(drawing)
	await _check_second_run()
	_finish()


func _check_painting() -> void:
	var terrain := _editor.terrain
	_editor.select_tool(EditorTool.Kind.BLOCK)
	_editor.paint_line(Vector2(16, FLOOR_Y), Vector2(784, FLOOR_Y))
	_expect(_count_terrain_cells(terrain) == 25, "a floor 25 cells wide, got %d" % _count_terrain_cells(terrain))

	_editor.select_tool(EditorTool.Kind.LADDER)
	_editor.paint_at(LADDER_CLICK)
	_expect(terrain.is_ladder_at(LADDER_CLICK), "ladder painted")

	_editor.select_tool(EditorTool.Kind.BRICK)
	for click in BRICK_CLICKS:
		_editor.paint_at(click)
	var bricks := terrain.get_bricks()
	_expect(bricks.size() == 2, "two bricks painted, got %d" % bricks.size())
	_expect(bricks.has(Rect2(384, 96, 32, 8)) and bricks.has(Rect2(416, 96, 32, 8)), "bricks snapped to the column and 8px row, got %s" % [bricks])

	# Eraser: paint something, erase it, nothing left behind.
	_editor.select_tool(EditorTool.Kind.BLOCK)
	_editor.paint_at(SCRATCH_CLICK)
	_expect(terrain.is_solid_at(SCRATCH_CLICK), "scratch block painted")
	_editor.select_tool(EditorTool.Kind.BRICK)
	_editor.paint_at(SCRATCH_BRICK_CLICK)
	_editor.select_tool(EditorTool.Kind.ERASER)
	_editor.paint_at(SCRATCH_CLICK)
	_editor.paint_at(SCRATCH_BRICK_CLICK)
	_expect(not terrain.is_solid_at(SCRATCH_CLICK), "eraser removes a block")
	_expect(terrain.get_bricks().size() == 2, "eraser removes a brick")
	_editor.paint_at(LADDER_CLICK)
	_expect(not terrain.is_ladder_at(LADDER_CLICK), "eraser removes a ladder")
	_editor.select_tool(EditorTool.Kind.LADDER)
	_editor.paint_at(LADDER_CLICK)


func _check_play_and_pause() -> void:
	_editor.toolbar.play_requested.emit()
	_expect(_editor.mode == LevelEditorController.Mode.PLAYING, "Play button starts the run")
	_expect(_editor.edit_layer.get_parent() == null, "the drawing is out of the tree while playing")
	_expect(get_tree().get_first_node_in_group("terrain") == _editor.play_session.get_node("Terrain"), "lemmings find the run's terrain copy")
	_expect(SkillManager.get_remaining_count("digger") == DIGGER_COUNT, "digger count from the editor")
	_expect(SkillManager.get_remaining_count("bridge") == EditorToolbar.DEFAULT_TOOL_COUNT, "every tool offered")

	await _frames(RUN_BEFORE_PAUSE_FRAMES)
	_editor.toolbar.pause_requested.emit()
	_expect(get_tree().paused, "Pause freezes the tree")
	var before_pause := _lemming_positions()
	_expect(not before_pause.is_empty(), "lemmings are out before the pause")
	await _frames(PAUSE_FRAMES)
	_expect(_lemming_positions() == before_pause, "lemmings do not move while paused")

	_editor.toolbar.play_requested.emit()
	_expect(_editor.mode == LevelEditorController.Mode.PLAYING and not get_tree().paused, "Play after Pause continues")
	await _frames(PAUSE_FRAMES)
	_expect(_lemming_positions() != before_pause, "lemmings move again after Play")


func _check_lemmings_reach_exit() -> void:
	var session := _editor.play_session
	for frame in ALL_SAVED_TIMEOUT_FRAMES:
		if session.lemmings_saved_count + session.lemmings_lost_count >= LEMMING_COUNT:
			break
		await get_tree().physics_frame
	print("  run: saved %d, lost %d" % [session.lemmings_saved_count, session.lemmings_lost_count])
	_expect(session.lemmings_saved_count == LEMMING_COUNT, "all %d lemmings reach the exit" % LEMMING_COUNT)


func _check_restart(drawing: Dictionary) -> void:
	# Change the run's terrain the way the tools would, to prove Restart
	# brings back the drawing rather than what the run left behind.
	var run_terrain: TerrainDestructible = _editor.play_session.get_node("Terrain")
	run_terrain.destroy_rect(run_terrain.cell_rect_at(Vector2(304, FLOOR_Y)))
	run_terrain.destroy_rect(Rect2(384, 96, 32, 8))
	run_terrain.place_brick(Rect2(160, 200, 32, 8))
	run_terrain.place_ladder_at(Vector2(200, 300))

	_editor.toolbar.restart_requested.emit()
	await _frames(2)
	_expect(_editor.mode == LevelEditorController.Mode.EDITING, "Restart goes back to editing")
	_expect(_editor.play_session == null, "the run is gone")
	_expect(_editor.edit_layer.get_parent() == _editor, "the drawing is back")
	_expect(get_tree().get_nodes_in_group("lemmings").is_empty(), "no lemmings left after Restart")
	_expect(not get_tree().paused, "not paused after Restart")
	_expect(get_tree().get_first_node_in_group("terrain") == _editor.terrain, "the drawing's terrain is the active one again")
	var restored := _snapshot(_editor.terrain)
	_expect(restored == drawing, "the drawing is exactly as painted:\n  before %s\n  after  %s" % [drawing, restored])
	_expect(_editor.get_entrance_position() == Vector2(80, 272) and _editor.has_exit(), "entrance and exit kept")
	_expect(_editor.toolbar.get_lemming_count() == LEMMING_COUNT, "counts kept")


func _check_second_run() -> void:
	_editor.play()
	await _frames(2)
	var run_terrain: TerrainDestructible = _editor.play_session.get_node("Terrain")
	_expect(run_terrain.get_bricks().size() == 2, "a second run copies the bricks again")
	_expect(get_tree().get_nodes_in_group("lemmings").size() == 1, "a second run releases lemmings again")
	_editor.pause()
	_editor.restart()
	await _frames(2)
	_expect(_editor.mode == LevelEditorController.Mode.EDITING and not get_tree().paused, "Restart from Pause goes back to editing")


func _snapshot(terrain: TerrainDestructible) -> Dictionary:
	var cells := {}
	for cell in terrain.get_used_cells():
		cells[cell] = [terrain.get_cell_source_id(cell), terrain.get_cell_atlas_coords(cell)]
	return {"cells": cells, "bricks": terrain.get_bricks()}


func _count_terrain_cells(terrain: TerrainDestructible) -> int:
	return terrain.get_used_cells_by_id(TerrainDestructible.TERRAIN_SOURCE_ID).size()


func _lemming_positions() -> Array:
	var positions := []
	for lemming in get_tree().get_nodes_in_group("lemmings"):
		positions.append((lemming as Node2D).global_position)
	return positions


func _frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


func _expect(condition: bool, description: String) -> void:
	if not condition:
		_failures.append(description)
		print("  FAIL: %s" % description)


func _finish() -> void:
	get_tree().paused = false
	if _failures.is_empty():
		print("Level editor: PASS")
		get_tree().quit(0)
	else:
		print("Level editor: FAIL (%d)" % _failures.size())
		get_tree().quit(1)
