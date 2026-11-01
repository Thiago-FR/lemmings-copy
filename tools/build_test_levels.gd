extends SceneTree
## One-off build script: generates the 4 MVP test level scenes (terrain +
## spawn/exit points + HUD + skill panel). Building the TileMapLayer's
## painted cells through the actual TileMapLayer API avoids hand-authoring
## its binary tile_data by hand in a .tscn. Run via:
##   godot --headless --script res://tools/build_test_levels.gd
## Safe to re-run any time the layouts below change; further tuning is
## expected to happen by hand in the editor afterward.

const TILE_SET_PATH := "res://resources/tilesets/terrain_tileset.tres"


var _res: Dictionary = {}


func _initialize() -> void:
	_res = {
		"tile_set": load(TILE_SET_PATH),
		"level_manager_script": load("res://scripts/level/level_manager.gd"),
		"terrain_script": load("res://scripts/level/terrain_destructible.gd"),
		"spawn_point_scene": load("res://scenes/level/spawn_point.tscn"),
		"exit_point_scene": load("res://scenes/level/exit_point.tscn"),
		"hud_scene": load("res://scenes/ui/hud.tscn"),
		"skill_panel_scene": load("res://scenes/ui/skill_panel.tscn"),
		"level_result_screen_scene": load("res://scenes/ui/level_result_screen.tscn"),
	}

	_build_level_01()
	_build_level_02()
	_build_level_03()
	_build_level_04()
	_build_level_05()

	quit()


func _new_level_root(level_name: String) -> Node2D:
	var root := Node2D.new()
	root.name = level_name
	root.set_script(_res.level_manager_script)
	return root


func _new_terrain() -> TileMapLayer:
	var terrain := TileMapLayer.new()
	terrain.name = "Terrain"
	terrain.tile_set = _res.tile_set
	terrain.set_script(_res.terrain_script)
	return terrain


func _paint_rect(terrain: TileMapLayer, from_column: int, to_column: int, from_row: int, to_row: int) -> void:
	for x in range(from_column, to_column + 1):
		for y in range(from_row, to_row + 1):
			terrain.set_cell(Vector2i(x, y), 0, Vector2i.ZERO)


func _add_child_owned(root: Node, child: Node) -> void:
	root.add_child(child)
	child.owner = root


func _add_spawn(root: Node, world_position: Vector2) -> void:
	var spawn: Node2D = _res.spawn_point_scene.instantiate()
	spawn.position = world_position
	_add_child_owned(root, spawn)


func _add_exit(root: Node, world_position: Vector2) -> void:
	var exit_point: Node2D = _res.exit_point_scene.instantiate()
	exit_point.position = world_position
	_add_child_owned(root, exit_point)


func _add_ui(root: Node) -> void:
	_add_child_owned(root, _res.hud_scene.instantiate())
	_add_child_owned(root, _res.skill_panel_scene.instantiate())
	_add_child_owned(root, _res.level_result_screen_scene.instantiate())


func _save_level(root: Node, path: String) -> void:
	var packed := PackedScene.new()
	var err := packed.pack(root)
	if err != OK:
		push_error("Failed to pack %s: %d" % [path, err])
		return
	err = ResourceSaver.save(packed, path)
	print("%s save result: %d" % [path, err])
	root.free()


## Levels are laid out on the 32px terrain grid against the 800x450 viewport,
## which is 25 columns by 14 rows. Vertical gaps a lemming has to drop through
## are at least two rows: one row is 32px and the body is 30 tall, which
## Constants.MAX_BODY_HEIGHT rules out as too tight to pass.


## Tutorial: flat floor, no obstacles, no skills.
func _build_level_01() -> void:
	var root := _new_level_root("Level01")
	var terrain := _new_terrain()
	_paint_rect(terrain, 0, 24, 5, 6)
	_add_child_owned(root, terrain)

	_add_spawn(root, Vector2(48, 120))
	_add_exit(root, Vector2(640, 136))
	_add_ui(root)

	_save_level(root, "res://scenes/levels/level_01.tscn")


## Digger: lemmings land on a walled-in platform with no way down except
## digging through it. The platform is two tiles thick, and the drop to the
## floor below is two tiles — within the safe fall height, so getting through
## is a matter of digging rather than of surviving the landing.
func _build_level_02() -> void:
	var root := _new_level_root("Level02")
	var terrain := _new_terrain()
	_paint_rect(terrain, 0, 24, 5, 6)    # upper platform, must be dug through
	_paint_rect(terrain, 0, 24, 9, 10)   # lower floor
	_paint_rect(terrain, -1, -1, 0, 13)  # left boundary wall
	_paint_rect(terrain, 25, 25, 0, 13)  # right boundary wall
	_add_child_owned(root, terrain)

	_add_spawn(root, Vector2(48, 120))
	_add_exit(root, Vector2(400, 264))
	_add_ui(root)

	_save_level(root, "res://scenes/levels/level_02.tscn")


## Builder: a pit lemmings cannot cross on foot, with the far platform higher
## than the near one.
##
## NOTE: the builder step is now a full tile (32px) rather than the 8px it was
## when this layout was first sized, so the gap and rise here no longer match
## the staircase the Builder actually produces. Re-tune when the Builder is
## the skill being validated — see the protocol in docs/game_design.md.
func _build_level_03() -> void:
	var root := _new_level_root("Level03")
	var terrain := _new_terrain()
	_paint_rect(terrain, 0, 7, 7, 8)    # lower floor (spawn side)
	_paint_rect(terrain, 12, 24, 5, 6)  # upper floor (exit side)
	_add_child_owned(root, terrain)

	_add_spawn(root, Vector2(48, 184))
	_add_exit(root, Vector2(640, 136))
	_add_ui(root)

	_save_level(root, "res://scenes/levels/level_03.tscn")


## Combination: Climber up a wall onto a ledge, then Builder across a pit onto
## a higher ledge to reach the exit. Carries the same Builder caveat as
## level 3.
func _build_level_04() -> void:
	var root := _new_level_root("Level04")
	var terrain := _new_terrain()
	_paint_rect(terrain, 0, 4, 10, 11)  # Floor A (spawn side)
	_paint_rect(terrain, 5, 5, 4, 9)    # climbable wall
	_paint_rect(terrain, 5, 8, 4, 4)    # Ledge B (post-climb landing)
	_paint_rect(terrain, 12, 24, 2, 2)  # Ledge C (post-builder landing, exit)
	_add_child_owned(root, terrain)

	_add_spawn(root, Vector2(48, 280))
	_add_exit(root, Vector2(600, 40))
	_add_ui(root)

	_save_level(root, "res://scenes/levels/level_04.tscn")


## Sandbox: all 8 skills unlocked with generous counts. The exit sits on the
## far side of a gap, NOT on the trivial walking path, so lemmings actually
## need a skill to get across instead of reaching it within a few steps of
## spawning. A climbable wall past the gap is there for Climber; the thick
## main floor works for Digger/Basher/Miner.
func _build_level_05() -> void:
	var root := _new_level_root("Level05")
	var terrain := _new_terrain()
	_paint_rect(terrain, 0, 9, 5, 6)     # main floor, spawn side
	_paint_rect(terrain, 14, 24, 5, 6)   # main floor, far side (exit)
	_paint_rect(terrain, 10, 13, 9, 9)   # catch floor under the gap
	_paint_rect(terrain, -1, -1, 0, 13)  # left boundary wall
	_paint_rect(terrain, 25, 25, 0, 13)  # right boundary wall
	_paint_rect(terrain, 21, 21, 1, 4)   # climbable wall
	_paint_rect(terrain, 21, 24, 1, 1)   # ledge after climbing
	_add_child_owned(root, terrain)

	_add_spawn(root, Vector2(48, 120))
	_add_exit(root, Vector2(620, 136))
	_add_ui(root)

	_save_level(root, "res://scenes/levels/level_05.tscn")
