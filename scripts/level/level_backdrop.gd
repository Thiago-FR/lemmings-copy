class_name LevelBackdrop
extends Node2D
## Solid rock all around the level's area, so the screen is filled even when
## the level is smaller than it (the test levels are) or the screen's shape
## differs from the level's. Inside the area the LevelBackground shows
## through; outside it, rock nobody can dig, drawn from the terrain's own
## earth texture, darker, with a dark seam along the edge so the level's
## limits read clearly.

## Behind the terrain and every other node of the level.
const BACKDROP_Z_INDEX := -100
## How far past the level the rock reaches: more than any screen.
const FRAME_REACH := 4096.0
const TERRAIN_ATLAS_PATH := "res://assets/sprites/terrain/terrain_atlas.png"
## The full earth block in the atlas (first tile, first row).
const ROCK_TILE_REGION := Rect2i(0, 0, 32, 32)
const SEAM_COLOUR := Color(0.06, 0.05, 0.05, 0.9)
const SEAM_WIDTH := 3.0

var area: Rect2 = Rect2()
var environment: LevelEnvironment = LevelEnvironment.surface()

var _rock: Texture2D


func _ready() -> void:
	z_index = BACKDROP_Z_INDEX
	z_as_relative = false
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_rock = _make_rock_texture()


func _draw() -> void:
	if not area.has_area():
		return
	var outer := area.grow(FRAME_REACH)
	var pieces := [
		Rect2(outer.position, Vector2(outer.size.x, area.position.y - outer.position.y)),
		Rect2(Vector2(outer.position.x, area.end.y), Vector2(outer.size.x, outer.end.y - area.end.y)),
		Rect2(Vector2(outer.position.x, area.position.y), Vector2(area.position.x - outer.position.x, area.size.y)),
		Rect2(Vector2(area.end.x, area.position.y), Vector2(outer.end.x - area.end.x, area.size.y)),
	]
	for piece: Rect2 in pieces:
		if _rock != null:
			draw_texture_rect(_rock, piece, true, environment.frame_tint)
		else:
			draw_rect(piece, environment.frame_tint.darkened(0.6))
	draw_rect(area.grow(SEAM_WIDTH / 2.0), SEAM_COLOUR, false, SEAM_WIDTH)


## The earth block cut out of the atlas into a texture of its own, since
## an atlas region cannot be tiled across a rectangle.
func _make_rock_texture() -> Texture2D:
	if not ResourceLoader.exists(TERRAIN_ATLAS_PATH):
		return null
	var atlas := load(TERRAIN_ATLAS_PATH) as Texture2D
	var image := atlas.get_image()
	if image == null:
		return null
	return ImageTexture.create_from_image(image.get_region(ROCK_TILE_REGION))
