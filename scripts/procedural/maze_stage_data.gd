class_name MazeStageData
extends RefCounted
## A maze stage as plain data, the output of MazeStageGenerator (or of a
## hand-made MazeLayout run through MazeStageGenerator.from_layout): terrain
## cells, ladders and bricks, where the entrance and exit stand, the item
## spots, and the recorded solution. Whoever uses it (a game mode, the
## editor) decides what to put on the spots and builds its own level; the
## data knows nothing about them. paint_onto() puts the terrain on a
## TerrainDestructible.

var columns := MazeLayout.COLUMNS
var rows := MazeLayout.ROWS
## columns * rows cells, row by row: MazeLayout.EMPTY, EARTH or CONCRETE.
var cells := PackedByteArray()
## Cells holding a ladder segment and brick rectangles (in pixels), for
## stages that start with some built; generated ones have none yet.
var ladders: Array[Vector2i] = []
var bricks: Array[Rect2] = []
## Column and floor row (lemmings stand on top of that row) of the entrance
## and of the exit.
var spawn_cell := Vector2i.ZERO
var exit_cell := Vector2i.ZERO
## {"column", "row" (floor row), "kind": MazeLayout.SpotKind, "tool_id",
##  "amount" (1 for a tool: one item per charge), "required" (the solution
##  needs it), "spot_index" (the MazeLayout spot it came from)}.
var item_spots: Array[Dictionary] = []
## The solution, one entry per tool use: {"tool", "from_column",
## "to_column", "row" (floor row the lemming walks on), "direction" (the way
## it must face, 0 either), "why", "collect_first" (cells of the item spots
## to pick up before this click)}. Hand the tool to a walking lemming there.
var solution: Array[Dictionary] = []
## Open sky on the shallow stages, a cave on the deep ones.
var environment_kind: LevelEnvironment.Kind = LevelEnvironment.Kind.SURFACE
## A time limit that leaves room for the solution, scaled by difficulty.
var suggested_time_seconds := 300
## The rooms and links it was painted from (null for a biome stage).
var layout: MazeLayout = null
## A different look for some cells (cell -> TerrainSkin name): tree trunks
## and leaves, building walls, a station's hull.
var skins: Dictionary = {}
## Drawn behind the lemmings on empty cells (cell -> TerrainSkin name).
var backdrop: Dictionary = {}
## Scenery trees painted behind the terrain (TreeArt, BackgroundDecor):
## not solid, no items.
var decor_trees: Array[Dictionary] = []
## Cells nothing breaks (the border), see TerrainDestructible.
var unbreakable: Dictionary = {}
## The entrance releases lemmings walking left.
var spawn_faces_left := false
## The stage's own name (biome stages have one; others get one from the
## game mode).
var stage_name := ""


func cell_at(column: int, row: int) -> int:
	if column < 0 or row < 0 or column >= columns or row >= rows:
		return MazeLayout.CONCRETE
	return cells[row * columns + column]


func is_solid(column: int, row: int) -> bool:
	return cell_at(column, row) != MazeLayout.EMPTY


## Paints the stage onto a terrain, replacing what was there. Best done
## before the terrain enters the tree, so its edge overlay draws once.
func paint_onto(terrain: TerrainDestructible) -> void:
	assert(terrain != null and cells.size() == columns * rows, "Painting needs a terrain and a full grid")
	terrain.clear()
	for row in rows:
		for column in columns:
			var cell := cells[row * columns + column]
			if cell == MazeLayout.EMPTY:
				continue
			var material := TerrainDestructible.TerrainMaterial.CONCRETE if cell == MazeLayout.CONCRETE else TerrainDestructible.TerrainMaterial.EARTH
			terrain.set_cell(Vector2i(column, row), TerrainDestructible.TERRAIN_SOURCE_ID, Vector2i(0, material))
	var tile := Constants.TERRAIN_TILE_SIZE
	for ladder in ladders:
		terrain.place_ladder_at(Vector2((ladder.x + 0.5) * tile, (ladder.y + 0.5) * tile))
	# Bricks need the terrain's brick body, made when it enters the tree.
	terrain.initial_bricks.append_array(bricks)
	terrain.unbreakable_cells = unbreakable
	if not decor_trees.is_empty():
		var decor := BackgroundDecor.new()
		decor.name = "Decor"
		decor.trees = decor_trees
		terrain.add_child(decor)
	if not skins.is_empty() or not backdrop.is_empty():
		var skin := TerrainSkin.new()
		skin.name = "Skin"
		skin.skins = skins
		skin.backdrop = backdrop
		terrain.add_child(skin)


## World position of the middle of a column, at the top of a floor row.
static func surface_point(cell: Vector2i) -> Vector2:
	var tile := Constants.TERRAIN_TILE_SIZE
	return Vector2((cell.x + 0.5) * tile, cell.y * tile)
