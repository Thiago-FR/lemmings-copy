extends SceneTree
## Renders a sample of every kind of terrain edge next to the wizard and
## saves it as a PNG, to judge terrain art at game scale. Needs a real
## renderer, so run it WITHOUT --headless (a window opens for a moment):
##   godot --path . --resolution 800x450 --script res://tools/capture_terrain_preview.gd -- <output.png>
## Default output: user://terrain_preview.png
##
## The sample: ground with grass, a wall, a floating platform with a ladder,
## a pit crossed by a bridge, a few diagonal-ladder steps, a shaft being dug,
## a tunnel being dug sideways through a mound, and a concrete pillar.

const TILE_SET := preload("res://resources/tilesets/terrain_tileset.tres")
const WIZARD_TEXTURE := preload("res://assets/sprites/characters/wizard/walk_aligned_0.png")
const WIZARD_SCALE := 0.15
## Distance from the lemming's origin to its feet (collision box bottom).
const WIZARD_FEET_OFFSET := 17.0
const TERRAIN_ORIGIN := Vector2(64, 48)
const CELL := 32
const EARTH := TerrainDestructible.TerrainMaterial.EARTH
const CONCRETE := TerrainDestructible.TerrainMaterial.CONCRETE
## Frames to wait so the first edge refresh (which decides where grass
## grows) runs before anything is dug.
const FRAMES_BEFORE_DIGGING := 3
const FRAMES_BEFORE_CAPTURE := 8

var _terrain: TerrainDestructible
var _frame := 0
var _output_path := "user://terrain_preview.png"


func _initialize() -> void:
	var arguments := OS.get_cmdline_user_args()
	if not arguments.is_empty():
		_output_path = arguments[0]
	_terrain = TerrainDestructible.new()
	_terrain.tile_set = TILE_SET
	_terrain.position = TERRAIN_ORIGIN
	root.add_child(_terrain)
	_build_sample()


func _process(_delta: float) -> bool:
	_frame += 1
	if _frame == FRAMES_BEFORE_DIGGING:
		_dig_sample()
		_place_wizards()
	if _frame == FRAMES_BEFORE_CAPTURE:
		root.get_texture().get_image().save_png(_output_path)
		print("terrain preview saved to ", ProjectSettings.globalize_path(_output_path))
		return true
	return false


func _fill(from: Vector2i, to: Vector2i, material: int = EARTH) -> void:
	for y in range(from.y, to.y + 1):
		for x in range(from.x, to.x + 1):
			_terrain.set_cell(Vector2i(x, y), TerrainDestructible.TERRAIN_SOURCE_ID, Vector2i(0, material))


func _build_sample() -> void:
	_fill(Vector2i(0, 9), Vector2i(20, 10))          # ground
	_fill(Vector2i(0, 2), Vector2i(0, 8))            # left wall
	_fill(Vector2i(4, 4), Vector2i(8, 4))            # floating platform
	_fill(Vector2i(13, 6), Vector2i(17, 8))          # mound to tunnel through
	_fill(Vector2i(19, 5), Vector2i(20, 8), CONCRETE)  # concrete pillar
	_fill(Vector2i(19, 9), Vector2i(20, 9), CONCRETE)
	for y in range(5, 9):                             # ladder up to the platform
		_terrain.set_cell(Vector2i(9, y), TerrainDestructible.LADDER_SOURCE_ID, Vector2i.ZERO)
	for x in [6, 7]:                                  # pit
		for y in [9, 10]:
			_terrain.erase_cell(Vector2i(x, y))


func _dig_sample() -> void:
	var origin := TERRAIN_ORIGIN
	# Bridge over the pit: pieces hang just under the floor line.
	for x in [6, 7]:
		_terrain.place_brick(Rect2(origin + Vector2(x * CELL, 9 * CELL), Vector2(CELL, 8)))
	# Diagonal-ladder steps going up to the right from the wall.
	for step in 3:
		_terrain.place_brick(Rect2(origin + Vector2((1 + step) * CELL, 9 * CELL - 8 * (step + 1)), Vector2(CELL, 8)))
	# A shaft: one cell dug out, the one under it half dug.
	var shaft := origin + Vector2(11 * CELL + 16, 9 * CELL + 4)
	for i in 4:
		_terrain.dig_stage_in_rect(Rect2(shaft - Vector2(8, 4), Vector2(16, 8)))
	_terrain.dig_stage_in_rect(Rect2(shaft + Vector2(-8, CELL - 4), Vector2(16, 8)))
	_terrain.dig_stage_in_rect(Rect2(shaft + Vector2(-8, CELL - 4), Vector2(16, 8)))
	# A tunnel dug from the left through the bottom row of the mound.
	for x in [13, 14]:
		for i in 4:
			_terrain.dig_side_stage_at(origin + Vector2(x * CELL + 16, 8 * CELL + 16), 1)
	for i in 2:
		_terrain.dig_side_stage_at(origin + Vector2(15 * CELL + 16, 8 * CELL + 16), 1)
	# Concrete cut by the jackhammer from the left.
	_terrain.dig_side_stage_at(origin + Vector2(19 * CELL + 16, 6 * CELL + 16), 1, true)


func _place_wizards() -> void:
	var origin := TERRAIN_ORIGIN
	_add_wizard(origin + Vector2(5.5 * CELL, 4 * CELL), false)    # on the platform
	_add_wizard(origin + Vector2(6.5 * CELL, 9 * CELL), false)    # on the bridge
	_add_wizard(origin + Vector2(14.3 * CELL, 9 * CELL), false)   # in the tunnel
	_add_wizard(origin + Vector2(11.5 * CELL, 10 * CELL + 16), true)  # in the shaft
	_add_wizard(origin + Vector2(18 * CELL, 9 * CELL), true)      # by the concrete


func _add_wizard(feet: Vector2, flipped: bool) -> void:
	var sprite := Sprite2D.new()
	sprite.texture = WIZARD_TEXTURE
	sprite.scale = Vector2(WIZARD_SCALE, WIZARD_SCALE)
	sprite.flip_h = flipped
	sprite.position = feet - Vector2(0, WIZARD_FEET_OFFSET)
	root.add_child(sprite)
