extends SceneTree
## One-off build script: generates the test level scenes (terrain +
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
	_build_level_06()
	_build_level_07()

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


## Diagonal ladder: lemmings walk along a floor towards a platform exactly
## three tiles high, which is one full staircase (12 steps, each a quarter
## tile tall and a full tile wide, so 12 tiles long), with the exit on top.
## The platform starts 12 tiles from the left wall, so a staircase begun by a
## lemming walking right near the entrance ends at the platform's edge. Begun
## further along, it stops at the platform's wall; if that leaves less than a
## step's worth of wall above it, the lemming walks up the rest.
func _build_level_03() -> void:
	var root := _new_level_root("Level03")
	var terrain := _new_terrain()
	_paint_rect(terrain, 0, 24, 11, 12)    # floor
	_paint_rect(terrain, 15, 24, 8, 10)    # platform, three tiles high
	_paint_rect(terrain, -1, -1, -20, 13)  # left boundary wall
	_paint_rect(terrain, 25, 25, -20, 13)  # right boundary wall
	_add_child_owned(root, terrain)

	_add_spawn(root, Vector2(80, 296))
	_add_exit(root, Vector2(640, 232))
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


## Vertical ladder: lemmings walk along a floor towards a platform five
## tiles tall, and the exit is on top of it. Nothing is in the way to dig
## through; the only route up is a ladder raised against the platform's wall.
## The boundary walls go well above the screen so a lemming carrying the
## ladder into one of them finds it too tall and keeps the ladder for the
## platform.
func _build_level_06() -> void:
	var root := _new_level_root("Level06")
	var terrain := _new_terrain()
	_paint_rect(terrain, 0, 24, 11, 12)    # floor
	_paint_rect(terrain, 15, 24, 6, 10)    # high platform, exit on top
	_paint_rect(terrain, -1, -1, -20, 13)  # left boundary wall
	_paint_rect(terrain, 25, 25, -20, 13)  # right boundary wall
	_add_child_owned(root, terrain)

	_add_spawn(root, Vector2(80, 296))
	_add_exit(root, Vector2(640, 168))
	_add_ui(root)

	_save_level(root, "res://scenes/levels/level_06.tscn")


## Bridge: lemmings walk along a floor broken by a gap six tiles wide with
## nothing underneath, so a lemming walking into it falls out of the level.
## The exit is on the floor beyond the gap. Six tiles is six bridge pieces,
## well within one bridge (12 pieces), so a bridge begun anywhere before the
## gap reaches the far side. The boundary walls go well above the screen, as
## in level 6.
func _build_level_07() -> void:
	var root := _new_level_root("Level07")
	var terrain := _new_terrain()
	_paint_rect(terrain, 0, 8, 11, 12)     # floor, entrance side
	_paint_rect(terrain, 15, 24, 11, 12)   # floor beyond the gap, exit side
	_paint_rect(terrain, -1, -1, -20, 13)  # left boundary wall
	_paint_rect(terrain, 25, 25, -20, 13)  # right boundary wall
	_add_child_owned(root, terrain)

	_add_spawn(root, Vector2(80, 296))
	_add_exit(root, Vector2(640, 328))
	_add_ui(root)

	_save_level(root, "res://scenes/levels/level_07.tscn")
