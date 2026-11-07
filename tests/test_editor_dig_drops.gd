extends Node
## What broken blocks give, chosen in the editor ("Modo livre"): the shares
## always add up to 100%, the panel changes the drawing's table (and can
## switch it off), the table is saved and opened with the drawing, a drawing
## saved before the table existed opens with none, and a test run of the
## drawing drops from it and hands the finds out on the fixed bar. Works in
## a folder of its own; never touches the player's drawings. Run via:
##   godot --headless res://tests/test_editor_dig_drops.tscn
## Exits 0 on success, 1 otherwise.

const EDITOR_SCENE_PATH := "res://scenes/editor/level_editor.tscn"
const TEST_DIRECTORY := "user://test_editor_dig_drops/"
const FLOOR_Y := 368.0
const ENTRANCE_CLICK := Vector2(80, 272)
const BROKEN_CELL := Vector2i(10, 11)

var _editor: LevelEditorController
var _failures: Array[String] = []


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	_clear_directory()
	FreeLevelCollection.directory = TEST_DIRECTORY
	_check_shares()
	_editor = (load(EDITOR_SCENE_PATH) as PackedScene).instantiate()
	add_child(_editor)
	await _frames(2)
	_expect(_editor.get_dig_drops() != null, "a new drawing starts with the campaign's table")
	_draw_level()
	await _check_panel()
	_check_save_and_open()
	_check_old_drawing()
	await _check_play()
	_clear_directory()
	FreeLevelCollection.directory = FreeLevelCollection.DIRECTORY
	_finish()


func _check_shares() -> void:
	var shares := DigDropShares.from_table(DigDropTable.for_campaign())
	_expect(shares.enabled, "the campaign table is on")
	_expect(shares.earth_percent == 4 and shares.concrete_percent == 12, "earth 4%%, concrete 12%%, got %d/%d" % [shares.earth_percent, shares.concrete_percent])
	_expect(_share_list(shares) == [58, 26, 16], "the campaign's 22:10:6 is 58/26/16, got %s" % [_share_list(shares)])
	var moved := shares.set_share(ItemSpec.Kind.TOOL, 78)
	_expect(_total(shares) == 100, "raising one keeps the total at 100, got %d" % _total(shares))
	_expect(int(shares.shares[ItemSpec.Kind.TOOL]) == 78 and not moved.is_empty(), "raised to 78, the others gave way")
	shares.set_share(ItemSpec.Kind.TOOL, 100)
	_expect(_share_list(shares) == [100, 0, 0], "one item can take it all, got %s" % [_share_list(shares)])
	shares.set_share(ItemSpec.Kind.TOOL, 90)
	_expect(_total(shares) == 100 and int(shares.shares[ItemSpec.Kind.TIME]) == 5, "lowering from 100 splits evenly, got %s" % [_share_list(shares)])
	var table := shares.to_table()
	_expect(table.entries.size() == 3, "every item with a share is in the table")
	_expect(DigDropShares.from_table(null).enabled == false, "no table: switched off")
	_expect(_share_list(DigDropShares.from_table(table)) == _share_list(shares), "shares survive the round trip through a table")


func _draw_level() -> void:
	_editor.select_tool(EditorTool.Kind.BLOCK)
	_editor.paint_line(Vector2(16, FLOOR_Y), Vector2(784, FLOOR_Y))
	_editor.select_tool(EditorTool.Kind.ENTRANCE)
	_editor.paint_at(ENTRANCE_CLICK)
	# Only the shovel in the bar: a tool charge found can only be one.
	_editor.toolbar.set_counts(1, {"digger": 2})


## Through the panel's own buttons: earth up, the tool charge up to 100%,
## off and on again.
func _check_panel() -> void:
	_editor.toolbar.dig_drops_requested.emit()
	await _frames(1)
	var panel := _editor.get_node_or_null("DigDropsPanel") as EditorDigDropsPanel
	_expect(panel != null, "the drops button opens the panel")
	if panel == null:
		return
	var earth := panel.find_child("EarthChance", true, false) as EditorCounter
	(earth.find_child("Increase", true, false) as Button).pressed.emit()
	_expect(is_equal_approx(_editor.get_dig_drops().earth_chance, 0.05), "earth + gives 5%%, got %s" % _editor.get_dig_drops().earth_chance)
	var tool_share := panel.find_child("Share_item_tool_charge", true, false) as EditorCounter
	for _press in 10:
		(tool_share.find_child("Increase", true, false) as Button).pressed.emit()
	var drops := _editor.get_dig_drops()
	_expect(drops.entries.size() == 1 and int(drops.entries[0].kind) == ItemSpec.Kind.TOOL, "only tool charges left, got %s" % [drops.entries])
	var none := panel.find_child("NoneButton", true, false) as Button
	none.button_pressed = true
	_expect(_editor.get_dig_drops() == null, "the nothing switch turns the table off")
	none.button_pressed = false
	_expect(_editor.get_dig_drops() != null and is_equal_approx(_editor.get_dig_drops().earth_chance, 0.05), "switching back on keeps the numbers")
	# Off (a level that drops nothing opens like this): a number still
	# answers, and touching it switches the items back on.
	none.button_pressed = true
	(earth.find_child("Increase", true, false) as Button).pressed.emit()
	_expect(_editor.get_dig_drops() != null and is_equal_approx(_editor.get_dig_drops().earth_chance, 0.06), "a number changed while off switches the items on")
	_expect(not none.button_pressed, "the nothing switch goes off with it")
	(panel.find_child("CloseButton", true, false) as Button).pressed.emit()
	await _frames(1)
	_expect(not is_instance_valid(panel), "the close button closes the panel")


func _check_save_and_open() -> void:
	var collection := FreeLevelCollection.new()
	var saved := _editor.get_dig_drops()
	_expect(_editor.save_level(collection, 0) != "", "the drawing is saved")
	var file := LevelCollection._load_fresh(TEST_DIRECTORY.path_join("level_01.tres")) as LevelDrawing
	_expect(file != null and file.dig_drops != null, "the saved file has the table")
	_editor.new_drawing()
	_expect(_editor.get_dig_drops() != null and is_equal_approx(_editor.get_dig_drops().earth_chance, 0.04), "a new drawing goes back to the campaign's table")
	_editor.open_level(collection, 0)
	var opened := _editor.get_dig_drops()
	_expect(opened != null, "the opened drawing has a table")
	if opened != null:
		_expect(is_equal_approx(opened.earth_chance, saved.earth_chance) and is_equal_approx(opened.concrete_chance, saved.concrete_chance), "chances kept")
		_expect(opened.entries == saved.entries, "items kept, got %s" % [opened.entries])
	# Saved off, opened off.
	_editor.set_dig_drops(null)
	_editor.save_level(collection, 1)
	_editor.open_level(collection, 0)
	_editor.open_level(collection, 1)
	_expect(_editor.get_dig_drops() == null, "a drawing saved with nothing opens with nothing")
	_editor.open_level(collection, 0)


## A drawing file from before the table existed has no dig_drops at all.
func _check_old_drawing() -> void:
	var path := TEST_DIRECTORY.path_join("level_03.tres")
	var old := FileAccess.open(path, FileAccess.WRITE)
	old.store_string("[gd_resource type=\"Resource\" script_class=\"LevelDrawing\" load_steps=2 format=3]\n\n"
		+ "[ext_resource type=\"Script\" path=\"res://scripts/level/collections/level_drawing.gd\" id=\"1\"]\n\n"
		+ "[resource]\nscript = ExtResource(\"1\")\nentrances = Array[Dictionary]([{\"faces_left\": false, \"position\": Vector2(80, 272)}])\n")
	old.close()
	var collection := FreeLevelCollection.new()
	_editor.open_level(collection, 2)
	_expect(_editor.get_dig_drops() == null, "an old drawing opens with nothing coming out of the blocks")
	_editor.open_level(collection, 0)


## The run's level carries the table; a broken block gives a tool charge
## and picking it up adds it to the fixed bar.
func _check_play() -> void:
	var drops := _editor.get_dig_drops()
	drops.earth_chance = 1.0
	_editor.set_dig_drops(drops)
	_editor.play()
	await _frames(2)
	var level := _editor.play_session
	_expect(level != null, "the drawing plays")
	if level == null:
		return
	_expect(level.level_data.dig_drops != null and is_equal_approx(level.level_data.dig_drops.earth_chance, 1.0), "the run's level carries the drawing's table")
	_expect(level.dig_dropper != null, "the run drops items")
	_expect(level.get_node_or_null("ItemCollector") != null, "the core hands the finds out on the fixed bar")
	var panel := level.find_child("SkillPanel", true, false)
	_expect(panel == null or (panel as CanvasLayer).visible, "the fixed bar stays")
	var before := SkillManager.get_remaining_count("digger")
	var terrain := level.get_node("Terrain") as TerrainDestructible
	terrain.cell_broken.emit(BROKEN_CELL, TerrainDestructible.TerrainMaterial.EARTH, &"miner")
	await _frames(2)
	var pickups := get_tree().get_nodes_in_group("item_pickups")
	_expect(pickups.size() == 1, "one item turned up, got %d" % pickups.size())
	if pickups.size() == 1:
		var pickup := pickups[0] as ItemPickup
		_expect(pickup.spec.kind == ItemSpec.Kind.TOOL and pickup.spec.tool_id == "digger", "a charge of the tool in the bar, got %s" % pickup.spec.describe())
		pickup.collected.emit(pickup, null)
		_expect(SkillManager.get_remaining_count("digger") == before + 1, "picked up: one more digger, got %d" % SkillManager.get_remaining_count("digger"))
	_editor.restart()
	await _frames(1)
	_expect(is_equal_approx(_editor.get_dig_drops().earth_chance, 1.0), "the drawing keeps its own table after the run")


func _share_list(shares: DigDropShares) -> Array:
	return DigDropShares.KINDS.map(func(kind: ItemSpec.Kind) -> int: return int(shares.shares[kind]))


func _total(shares: DigDropShares) -> int:
	var total := 0
	for value in _share_list(shares):
		total += value
	return total


func _clear_directory() -> void:
	if not DirAccess.dir_exists_absolute(TEST_DIRECTORY):
		return
	for file in DirAccess.get_files_at(TEST_DIRECTORY):
		DirAccess.remove_absolute(TEST_DIRECTORY.path_join(file))
	DirAccess.remove_absolute(TEST_DIRECTORY)


func _frames(count: int) -> void:
	for _frame in count:
		await get_tree().process_frame


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
		push_error("FAIL: " + message)


func _finish() -> void:
	if _failures.is_empty():
		print("test_editor_dig_drops: OK")
		get_tree().quit(0)
	else:
		print("test_editor_dig_drops: %d failure(s)" % _failures.size())
		for failure in _failures:
			print("  - " + failure)
		get_tree().quit(1)
