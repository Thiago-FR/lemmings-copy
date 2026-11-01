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
	_build_level_06()
	_build_level_07()
	_build_level_08()
	_build_level_09()
	_build_level_10()
	_build_level_11()
	_build_level_12()
	_build_level_13()
	_build_level_14()

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


func _paint_rect(terrain: TileMapLayer, from_column: int, to_column: int, from_row: int, to_row: int, material: TerrainDestructible.TerrainMaterial = TerrainDestructible.TerrainMaterial.EARTH) -> void:
	for x in range(from_column, to_column + 1):
		for y in range(from_row, to_row + 1):
			terrain.set_cell(Vector2i(x, y), 0, Vector2i(0, material))


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


## The boundary walls every level from 6 on uses: they go well above the
## screen so nothing walks or climbs out over them.
func _paint_boundary_walls(terrain: TileMapLayer) -> void:
	_paint_rect(terrain, -1, -1, -20, 13)  # left boundary wall
	_paint_rect(terrain, 25, 25, -20, 13)  # right boundary wall


## Parachute: the entrance is on a ledge eight tiles (256px) above the floor
## the exit stands on, far beyond the safe fall height. Lemmings walk off the
## ledge's end; only the ones holding a parachute survive the drop.
func _build_level_08() -> void:
	var root := _new_level_root("Level08")
	var terrain := _new_terrain()
	_paint_rect(terrain, 0, 7, 3, 4)      # high ledge, entrance side
	_paint_rect(terrain, 0, 24, 11, 12)   # floor, exit side
	_paint_boundary_walls(terrain)
	_add_child_owned(root, terrain)

	_add_spawn(root, Vector2(80, 40))
	_add_exit(root, Vector2(640, 328))
	_add_ui(root)

	_save_level(root, "res://scenes/levels/level_08.tscn")


## Climber: the same layout as the vertical ladder's level, a platform five
## tiles tall with the exit on top, but nothing gets built: a lemming with
## the climber goes straight up the platform's wall. The exit is reached
## before the right boundary wall, which a climber would otherwise go up too.
func _build_level_09() -> void:
	var root := _new_level_root("Level09")
	var terrain := _new_terrain()
	_paint_rect(terrain, 0, 24, 11, 12)   # floor
	_paint_rect(terrain, 15, 24, 6, 10)   # high platform, exit on top
	_paint_boundary_walls(terrain)
	_add_child_owned(root, terrain)

	_add_spawn(root, Vector2(80, 296))
	_add_exit(root, Vector2(640, 168))
	_add_ui(root)

	_save_level(root, "res://scenes/levels/level_09.tscn")


## Blocker: lemmings start in the middle of the floor walking right, towards
## a gap with nothing under it at the floor's end. The exit is behind them,
## at the left. A blocker placed between the entrance and the gap turns
## everyone else back towards the exit. The gap starts eight tiles past the
## entrance, giving the player a few seconds to react.
func _build_level_10() -> void:
	var root := _new_level_root("Level10")
	var terrain := _new_terrain()
	_paint_rect(terrain, 0, 19, 11, 12)   # floor, bottomless gap beyond it
	_paint_boundary_walls(terrain)
	_add_child_owned(root, terrain)

	_add_spawn(root, Vector2(400, 296))
	_add_exit(root, Vector2(80, 328))
	_add_ui(root)

	_save_level(root, "res://scenes/levels/level_10.tscn")


## Dynamite: lemmings walk on a floor one block thick; the exit is in a
## room one block tall right under it. A charge blows a hole through the
## floor and they drop the 64px into the room, a safe fall. The room is that
## low on purpose: a blast always takes the floor too, and any deeper drop
## (or a crater with 32px walls) would kill or trap them.
func _build_level_11() -> void:
	var root := _new_level_root("Level11")
	var terrain := _new_terrain()
	_paint_rect(terrain, 0, 24, 9, 9)     # floor the lemmings walk on
	_paint_rect(terrain, 0, 24, 11, 12)   # floor of the room underneath
	_paint_boundary_walls(terrain)
	_add_child_owned(root, terrain)

	_add_spawn(root, Vector2(80, 232))
	_add_exit(root, Vector2(640, 328))
	_add_ui(root)

	_save_level(root, "res://scenes/levels/level_11.tscn")


## TNT: the same idea as dynamite, with the floor the lemmings walk on made
## of concrete (explosives break it like earth). The bigger blast also kills
## more of the lemmings walking near the charge, so it is best set down
## away from the others.
func _build_level_14() -> void:
	var root := _new_level_root("Level14")
	var terrain := _new_terrain()
	_paint_rect(terrain, 0, 24, 9, 9, TerrainDestructible.TerrainMaterial.CONCRETE)
	_paint_rect(terrain, 0, 24, 11, 12)   # floor of the room underneath
	_paint_boundary_walls(terrain)
	_add_child_owned(root, terrain)

	_add_spawn(root, Vector2(80, 232))
	_add_exit(root, Vector2(640, 328))
	_add_ui(root)

	_save_level(root, "res://scenes/levels/level_14.tscn")


## Jackhammer: a concrete wall three tiles thick and six tall stands on the
## floor between the entrance and the exit, too tall to climb onto and too
## thick for anything but a tunnel. Concrete, so only the jackhammer gets
## through it.
func _build_level_12() -> void:
	var root := _new_level_root("Level12")
	var terrain := _new_terrain()
	_paint_rect(terrain, 0, 24, 11, 12)   # floor
	_paint_rect(terrain, 14, 16, 5, 10, TerrainDestructible.TerrainMaterial.CONCRETE)   # thick wall
	_paint_boundary_walls(terrain)
	_add_child_owned(root, terrain)

	_add_spawn(root, Vector2(80, 296))
	_add_exit(root, Vector2(640, 328))
	_add_ui(root)

	_save_level(root, "res://scenes/levels/level_12.tscn")


## Pickaxe: a hill of earth four tiles thick and six tall stands on the
## floor between the entrance and the exit, too tall to climb onto; the way
## through is a tunnel dug straight ahead at walking height.
func _build_level_13() -> void:
	var root := _new_level_root("Level13")
	var terrain := _new_terrain()
	_paint_rect(terrain, 0, 24, 11, 12)   # floor
	_paint_rect(terrain, 13, 16, 5, 10)   # hill of earth
	_paint_boundary_walls(terrain)
	_add_child_owned(root, terrain)

	_add_spawn(root, Vector2(80, 296))
	_add_exit(root, Vector2(640, 328))
	_add_ui(root)

	_save_level(root, "res://scenes/levels/level_13.tscn")
