class_name RoguelikeHandmadeStages
extends RefCounted
## The five hand-made labyrinths of the roguelike (the alternative to the
## procedural stages, chosen in the developer screen). Each is drawn with
## the core's MazeLayout, so it follows the same rules as the generated ones
## and goes through the same solver before it is painted.
##
## Room (c, b) is column c (0-4, left to right) of band b (0 top, 2 bottom).
## Every stage has one-way choices that strand whoever takes them, and
## branches with rewards that cost charges to reach; the tests in
## modes/roguelike/tests/ win each one with a single lemming.

const NAMES: Array[String] = ["Primeiro labirinto", "A subida", "Galerias cruzadas", "O poço fundo", "A escalada"]
const STAGE_COUNT := 5

const EARTH := MazeLayout.EARTH
const CONCRETE := MazeLayout.CONCRETE


static func build(stage_index: int) -> MazeLayout:
	match stage_index:
		0:
			return _first_maze()
		1:
			return _the_climb()
		2:
			return _crossed_galleries()
		3:
			return _deep_well()
	return _the_ascent()


static func _room(column: int, band: int) -> int:
	return MazeLayout.room_id(column, band)


## Concrete floors and separators in the deeper stages; only patches to dig
## stay earth.
static func _materials(layout: MazeLayout, concrete: bool) -> void:
	var material := CONCRETE if concrete else EARTH
	layout.floor_materials.fill(material)
	for band in MazeLayout.ROOM_ROWS:
		for separator in range(1, MazeLayout.SEPARATOR_COLUMNS.size() - 1):
			layout.separator_materials["%d:%d" % [band, separator]] = material


## Start at the top. Pickaxe through the wall, dig down past the staircase,
## bridge the trough to the exit. Off the way: a dead-end pit on the far
## left (dig there and that lemming is stuck with what it finds) and a room
## on the right with the bridge.
static func _first_maze() -> MazeLayout:
	var layout := MazeLayout.new()
	_materials(layout, false)
	layout.add_open(0, 0)
	layout.add_wall(1, 0, EARTH)
	layout.add_open(2, 0)
	layout.add_open(3, 0)
	layout.add_stairs(3, 0, 1)
	layout.add_trough(2, 1, 1, 2)
	layout.add_stairs(0, 0, -1)
	layout.add_wall(1, 1, CONCRETE)
	layout.add_open(0, 1)
	layout.spawn_room = _room(1, 0)
	layout.exit_room = _room(2, 1)
	layout.add_tool_spot(_room(1, 0), "miner", 2)
	layout.add_tool_spot(_room(2, 0), "digger", 2)
	layout.add_tool_spot(_room(4, 0), "bridge", 1)
	layout.add_bonus_spot(_room(4, 0))
	layout.add_bonus_spot(_room(0, 1))
	return layout


## Start at the bottom left, exit at the top right: two ladders and a wall
## between them. Digging down from the middle gallery leads to a trough and
## rewards, but not back up.
static func _the_climb() -> MazeLayout:
	var layout := MazeLayout.new()
	_materials(layout, false)
	layout.add_open(0, 2)
	layout.add_ladder(1, 1, 1)
	layout.add_wall(2, 1, EARTH)
	layout.add_ladder(3, 0, 1)
	layout.add_stairs(3, 1, -1)
	layout.add_trough(3, 2, 2, 1)
	layout.spawn_room = _room(0, 2)
	layout.exit_room = _room(4, 0)
	layout.add_tool_spot(_room(0, 2), "ladder_vertical", 1)
	layout.add_tool_spot(_room(1, 2), "ladder_vertical", 1)
	layout.add_tool_spot(_room(2, 1), "miner", 1)
	layout.add_tool_spot(_room(3, 1), "ladder_vertical", 1)
	layout.add_tool_spot(_room(3, 1), "digger", 1, false)
	layout.add_bonus_spot(_room(1, 2))
	layout.add_bonus_spot(_room(4, 2))
	return layout


## Start in the middle right. The shovel is in reach at once, and the patch
## by the entrance looks like the way, but under it waits a trough with no
## bridge anywhere. The way is the pickaxe through the wall on the left, then
## the patch in the far gallery. Rooms behind a second wall hold extras.
static func _crossed_galleries() -> MazeLayout:
	var layout := MazeLayout.new()
	_materials(layout, true)
	layout.add_open(3, 1)
	layout.add_wall(2, 1, EARTH)
	layout.add_stairs(4, 1, 1)
	layout.add_trough(3, 2, 1, 2)
	layout.add_wall(2, 2, CONCRETE)
	layout.add_stairs(2, 1, -1)
	layout.add_open(1, 1)
	layout.add_wall(0, 1, EARTH)
	layout.spawn_room = _room(3, 1)
	layout.exit_room = _room(2, 2)
	layout.add_tool_spot(_room(4, 1), "digger", 1)
	layout.add_tool_spot(_room(3, 1), "miner", 1)
	layout.add_tool_spot(_room(2, 1), "basher", 1, false)
	layout.add_bonus_spot(_room(1, 1))
	layout.add_bonus_spot(_room(0, 1))
	layout.add_bonus_spot(_room(4, 2))
	return layout


## From the top left corner to the bottom right one, five tools on the way:
## dig, bridge, dig, then the jackhammer through two walls. A second way
## along the top (through a concrete wall) and down the right side is
## shorter, for a run that brought a jackhammer.
static func _deep_well() -> MazeLayout:
	var layout := MazeLayout.new()
	_materials(layout, true)
	layout.add_open(0, 0)
	layout.add_stairs(1, 0, 1)
	layout.add_trough(0, 1, 1, 2)
	layout.add_stairs(0, 1, -1)
	layout.add_wall(0, 2, EARTH)
	layout.add_open(1, 2)
	layout.add_wall(2, 2, CONCRETE)
	layout.add_open(3, 2)
	layout.add_wall(1, 0, CONCRETE)
	layout.add_open(2, 0)
	layout.add_stairs(3, 0, -1)
	layout.add_open(3, 1)
	layout.add_stairs(4, 1, 1)
	layout.spawn_room = _room(0, 0)
	layout.exit_room = _room(4, 2)
	layout.add_tool_spot(_room(0, 0), "digger", 1)
	layout.add_tool_spot(_room(1, 0), "bridge", 1)
	layout.add_tool_spot(_room(0, 1), "digger", 1)
	layout.add_tool_spot(_room(0, 2), "basher", 2)
	layout.add_bonus_spot(_room(2, 0))
	layout.add_bonus_spot(_room(3, 1))
	return layout


## From the bottom right to the top left: a ladder, a tunnel, the jackhammer
## through concrete and the last ladder. The patch in the middle gallery is a
## trap down to a trough and a room of rewards that has no way back.
static func _the_ascent() -> MazeLayout:
	var layout := MazeLayout.new()
	_materials(layout, true)
	layout.add_ladder(4, 1, -1)
	layout.add_wall(2, 1, EARTH)
	layout.add_stairs(2, 1, -1)
	layout.add_wall(1, 1, CONCRETE)
	layout.add_ladder(1, 0, -1)
	layout.add_trough(2, 2, 2, 1)
	layout.spawn_room = _room(4, 2)
	layout.exit_room = _room(0, 0)
	layout.add_tool_spot(_room(4, 2), "ladder_vertical", 1)
	layout.add_tool_spot(_room(3, 1), "miner", 1)
	layout.add_tool_spot(_room(2, 1), "basher", 1)
	layout.add_tool_spot(_room(2, 1), "digger", 1, false)
	layout.add_tool_spot(_room(1, 1), "ladder_vertical", 1)
	layout.add_bonus_spot(_room(2, 2))
	layout.add_bonus_spot(_room(3, 2))
	return layout
