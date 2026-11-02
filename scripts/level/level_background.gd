class_name LevelBackground
extends CanvasLayer
## Fills the whole screen behind the level, so no part of the window is ever
## empty: a gradient and two layers of silhouettes (hills on the surface,
## stalactites in a cave) that scroll slower than the level as the camera
## moves, which gives depth. Everything comes from the LevelEnvironment and
## is drawn in code, so there is no art to keep in step with the tiles.

## Behind every other layer.
const BACKGROUND_LAYER := -10
## How much each silhouette layer moves per pixel the camera moves.
const FAR_PARALLAX := 0.15
const NEAR_PARALLAX := 0.35
## Shape of the silhouettes: a sum of slow waves, in screen pixels.
const SILHOUETTE_STEP := 8.0

var environment: LevelEnvironment = LevelEnvironment.surface()

var _canvas: Control


func _ready() -> void:
	layer = BACKGROUND_LAYER
	_canvas = Control.new()
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_canvas.draw.connect(_draw_background)
	add_child(_canvas)


func _process(_delta: float) -> void:
	_canvas.queue_redraw()


func _draw_background() -> void:
	var size := _canvas.size
	var camera := get_viewport().get_camera_2d()
	var scroll := camera.get_screen_center_position() if camera != null else Vector2.ZERO
	_draw_gradient(size)
	if environment.kind == LevelEnvironment.Kind.CAVE:
		_draw_hanging(size, scroll * FAR_PARALLAX, environment.far_layer, 0.30, 1.0)
		_draw_hanging(size, scroll * NEAR_PARALLAX, environment.near_layer, 0.18, 2.3)
	else:
		_draw_hills(size, scroll * FAR_PARALLAX, environment.far_layer, 0.58, 1.0)
		_draw_hills(size, scroll * NEAR_PARALLAX, environment.near_layer, 0.72, 2.1)


func _draw_gradient(size: Vector2) -> void:
	var colors := PackedColorArray([environment.sky_top, environment.sky_top, environment.sky_bottom, environment.sky_bottom])
	var points := PackedVector2Array([Vector2.ZERO, Vector2(size.x, 0), size, Vector2(0, size.y)])
	_canvas.draw_polygon(points, colors)


## Rolling hills rising from the bottom, their crest around height_fraction
## of the screen.
func _draw_hills(size: Vector2, offset: Vector2, colour: Color, height_fraction: float, seed_shift: float) -> void:
	var points := PackedVector2Array()
	points.append(Vector2(0, size.y))
	var x := 0.0
	while x <= size.x + SILHOUETTE_STEP:
		# Kept inside the screen: a crest pushed past the bottom edge makes the
		# polygon cross itself, and Godot refuses to draw it.
		var crest := size.y * height_fraction + _wave(x + offset.x, seed_shift) - offset.y * 0.2
		points.append(Vector2(x, clampf(crest, 1.0, size.y - 1.0)))
		x += SILHOUETTE_STEP
	points.append(Vector2(size.x, size.y))
	_canvas.draw_colored_polygon(points, colour)


## Rock hanging from the top (stalactites), reaching down to about
## depth_fraction of the screen.
func _draw_hanging(size: Vector2, offset: Vector2, colour: Color, depth_fraction: float, seed_shift: float) -> void:
	var points := PackedVector2Array()
	points.append(Vector2(0, 0))
	var x := 0.0
	while x <= size.x + SILHOUETTE_STEP:
		var spikes := absf(sin((x + offset.x) * 0.045 * seed_shift)) * 40.0
		var tip := size.y * depth_fraction + _wave(x + offset.x, seed_shift) * 0.6 + spikes - offset.y * 0.2
		points.append(Vector2(x, clampf(tip, 1.0, size.y - 1.0)))
		x += SILHOUETTE_STEP
	points.append(Vector2(size.x, 0))
	_canvas.draw_colored_polygon(points, colour)


func _wave(x: float, seed_shift: float) -> float:
	return sin(x * 0.006 * seed_shift) * 38.0 + sin(x * 0.017 + seed_shift * 3.0) * 14.0 + sin(x * 0.041 + seed_shift) * 5.0
