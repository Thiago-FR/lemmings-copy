class_name StageDressing
extends RefCounted
## What a generated stage has beyond its cells, as one plain Dictionary that
## travels with it everywhere (the game, the editor, a saved drawing):
##   skins: cell -> TerrainSkin name    tree bark, building walls, hull, crates
##   backdrop: cell -> TerrainSkin name drawn behind empty cells
##   inside_wall: StringName            the wall behind enclosed air
##   decor_trees: Array[Dictionary]     scenery trees (BackgroundDecor)
##   rooms: Array[Dictionary]           furnished rooms (RoomDecor)
##   unbreakable: cell -> true          the border nothing breaks
##   ramps: Array[Rect2]                soil steps up one-block rises
##   area: Rect2i                       the stage's cells
## apply() dresses a terrain with it before the terrain enters the tree;
## strip() takes it off again (the editor loading another drawing).

## Names of the nodes apply() adds, so strip() finds them.
const NODE_NAMES: Array[String] = ["Decor", "Skin", "Rooms"]


static func from_maze(maze: MazeStageData) -> Dictionary:
	return {
		"skins": maze.skins, "backdrop": maze.backdrop, "inside_wall": maze.inside_wall,
		"decor_trees": maze.decor_trees, "rooms": maze.rooms, "unbreakable": maze.unbreakable,
		"ramps": maze.ramps, "area": Rect2i(0, 0, maze.columns, maze.rows),
	}


## Puts the dressing back on stage data (a drawing turned into a stage).
static func onto_maze(maze: MazeStageData, dressing: Dictionary) -> void:
	maze.skins = dressing.get("skins", {})
	maze.backdrop = dressing.get("backdrop", {})
	maze.inside_wall = dressing.get("inside_wall", &"")
	maze.decor_trees.assign(dressing.get("decor_trees", []))
	maze.rooms.assign(dressing.get("rooms", []))
	maze.unbreakable = dressing.get("unbreakable", {})
	maze.ramps.assign(dressing.get("ramps", []))


## Dresses a terrain that has its cells but is not in the tree yet.
static func apply(terrain: TerrainDestructible, dressing: Dictionary) -> void:
	if dressing.is_empty():
		return
	var skins: Dictionary = dressing.get("skins", {})
	var backdrop: Dictionary = dressing.get("backdrop", {})
	var inside_wall: StringName = dressing.get("inside_wall", &"")
	var decor_trees: Array = dressing.get("decor_trees", [])
	var rooms: Array = dressing.get("rooms", [])
	# Ramps are bricks: laid by the terrain when it enters the tree, or at
	# once if it already has (the editor).
	if terrain.is_inside_tree():
		for ramp: Rect2 in dressing.get("ramps", []):
			terrain.place_brick(ramp, true)
	else:
		terrain.initial_ramps.assign(dressing.get("ramps", []))
	terrain.unbreakable_cells = dressing.get("unbreakable", {})
	if not decor_trees.is_empty():
		var decor := BackgroundDecor.new()
		decor.name = "Decor"
		decor.trees.assign(decor_trees)
		terrain.add_child(decor)
	if not skins.is_empty() or not backdrop.is_empty() or inside_wall != &"":
		var skin := TerrainSkin.new()
		skin.name = "Skin"
		skin.skins = skins
		skin.backdrop = backdrop
		skin.inside_wall = inside_wall
		skin.area = dressing.get("area", Rect2i())
		for cell: Vector2i in skins:
			if skins[cell] in TerrainSkin.SELF_DRAWN:
				terrain.self_drawn_cells[cell] = true
		terrain.add_child(skin)
	if not rooms.is_empty():
		var furniture := RoomDecor.new()
		furniture.name = "Rooms"
		furniture.rooms.assign(rooms)
		terrain.add_child(furniture)


## Takes a dressing off a terrain, ramps included.
static func strip(terrain: TerrainDestructible) -> void:
	for ramp in terrain.get_ramps():
		terrain.remove_bricks_in(ramp)
	for node_name in NODE_NAMES:
		var node := terrain.get_node_or_null(node_name)
		if node != null:
			terrain.remove_child(node)
			node.queue_free()
	terrain.unbreakable_cells = {}
	terrain.self_drawn_cells = {}
