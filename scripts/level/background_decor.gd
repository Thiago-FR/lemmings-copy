class_name BackgroundDecor
extends Node2D
## Scenery painted behind the terrain: pines, palms, snowy pines, giant
## mushrooms (TreeArt). Nothing here is solid and nothing carries items:
## it only dresses the stage. Added as a child of the TerrainDestructible
## with a lower z, so the ground is drawn over the trees' feet.
##
## trees: TreeArt trees ({"kind", "box", "crown", "trunk", "seed"}).

var trees: Array[Dictionary] = []

var _textures: Array[ImageTexture] = []


func _ready() -> void:
	z_index = -1
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var terrain := get_parent() as TerrainDestructible
	var cell_size := int(terrain.get_cell_size().x) if terrain != null else int(Constants.TERRAIN_TILE_SIZE)
	for tree in trees:
		_textures.append(TreeArt.build(tree, cell_size))


func _draw() -> void:
	var size := Constants.TERRAIN_TILE_SIZE
	for index in trees.size():
		var box: Rect2i = trees[index].box
		draw_texture(_textures[index], Vector2(box.position) * size)
