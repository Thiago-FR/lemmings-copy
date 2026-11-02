class_name LevelBackground
extends CanvasLayer
## Fills the whole screen behind the level, so no part of the window is ever
## empty: a gradient, maybe a sun, and two layers of silhouettes (hills,
## dunes, mountain peaks or stalactites) that scroll slower than the level as
## the camera moves, which gives depth. Some settings add life on top:
## twinkling lights, falling snow or rising embers, crystal shards. Everything
## comes from the LevelEnvironment and is drawn in code, so there is no art to
## keep in step with the tiles.

## Behind every other layer.
const BACKGROUND_LAYER := -10
## How much each silhouette layer moves per pixel the camera moves.
const FAR_PARALLAX := 0.15
const NEAR_PARALLAX := 0.35
## Shape of the silhouettes: a sum of slow waves, in screen pixels.
const SILHOUETTE_STEP := 8.0
## Mountain peaks: one every PEAK_SPACING pixels, give or take.
const PEAK_SPACING := 150.0
## How far down from the tip the snow on a peak reaches, as a share of the
## peak's height.
const PEAK_CAP_SHARE := 0.28
const SPARKLE_SIZE := 2.0
const DRIFT_SIZE := 2.0
const SHARD_SPACING := 90.0

var environment: LevelEnvironment = LevelEnvironment.surface()

var _canvas: Control
var _time := 0.0


func _ready() -> void:
	layer = BACKGROUND_LAYER
	_canvas = Control.new()
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_canvas.draw.connect(_draw_background)
	add_child(_canvas)


func _process(delta: float) -> void:
	_time += delta
	_canvas.queue_redraw()


func _draw_background() -> void:
	var size := _canvas.size
	var camera := get_viewport().get_camera_2d()
	var scroll := camera.get_screen_center_position() if camera != null else Vector2.ZERO
	_draw_gradient(size)
	if environment.sparkle_count > 0:
		_draw_sparkles(size)
	if environment.sun_radius > 0.0:
		_draw_sun(size)
	match environment.skyline:
		LevelEnvironment.Skyline.HANGING:
			_draw_hanging(size, scroll * FAR_PARALLAX, environment.far_layer, 0.30, 1.0)
			_draw_hanging(size, scroll * NEAR_PARALLAX, environment.near_layer, 0.18, 2.3)
		LevelEnvironment.Skyline.DUNES:
			_draw_hills(size, scroll * FAR_PARALLAX, environment.far_layer, 0.62, 0.45)
			_draw_hills(size, scroll * NEAR_PARALLAX, environment.near_layer, 0.76, 0.8)
		LevelEnvironment.Skyline.PEAKS:
			_draw_peaks(size, scroll * FAR_PARALLAX, environment.far_layer, 0.30, 0.62, 1)
			_draw_peaks(size, scroll * NEAR_PARALLAX, environment.near_layer, 0.55, 0.78, 2)
		_:
			_draw_hills(size, scroll * FAR_PARALLAX, environment.far_layer, 0.58, 1.0)
			_draw_hills(size, scroll * NEAR_PARALLAX, environment.near_layer, 0.72, 2.1)
	if environment.shard_colour.a > 0.0:
		_draw_shards(size, scroll * NEAR_PARALLAX)
	if environment.drift_count > 0:
		_draw_drift(size)


func _draw_gradient(size: Vector2) -> void:
	var colors := PackedColorArray([environment.sky_top, environment.sky_top, environment.sky_bottom, environment.sky_bottom])
	var points := PackedVector2Array([Vector2.ZERO, Vector2(size.x, 0), size, Vector2(0, size.y)])
	_canvas.draw_polygon(points, colors)


## A soft halo and a disc; fixed on the screen, as a far-away sun is.
func _draw_sun(size: Vector2) -> void:
	var centre := size * environment.sun_position
	var halo := environment.sun_colour
	for ring in range(4, 0, -1):
		halo.a = environment.sun_colour.a * 0.08
		_canvas.draw_circle(centre, environment.sun_radius * (1.0 + ring * 0.35), halo)
	_canvas.draw_circle(centre, environment.sun_radius, environment.sun_colour)


## Rolling hills rising from the bottom, their crest around height_fraction
## of the screen. seed_shift changes the wave; below 1 it also smooths it
## (dunes).
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


## A mountain range: straight slopes between tips of varied height, each
## drawn as its own triangle so a snow cap can sit on it.
func _draw_peaks(size: Vector2, offset: Vector2, colour: Color, top_fraction: float, base_fraction: float, seed_value: int) -> void:
	var shift := offset.x
	var base_y := clampf(size.y * base_fraction - offset.y * 0.2, 2.0, size.y - 1.0)
	_canvas.draw_rect(Rect2(0, base_y, size.x, size.y - base_y), colour)
	var first := int(floor(shift / PEAK_SPACING)) - 1
	var last := int(ceil((shift + size.x) / PEAK_SPACING)) + 1
	for index in range(first, last + 1):
		var jitter := _hash01(index, seed_value)
		var tip_x := index * PEAK_SPACING + (jitter - 0.5) * PEAK_SPACING * 0.5 - shift
		var tip_y := clampf(size.y * (top_fraction + _hash01(index, seed_value + 7) * 0.18) - offset.y * 0.2, 1.0, base_y - 4.0)
		var half_width := PEAK_SPACING * (0.75 + jitter * 0.5)
		var left := Vector2(tip_x - half_width, base_y + 1.0)
		var right := Vector2(tip_x + half_width, base_y + 1.0)
		var tip := Vector2(tip_x, tip_y)
		_canvas.draw_colored_polygon(PackedVector2Array([left, tip, right]), colour)
		if environment.peak_cap.a > 0.0:
			var share := PEAK_CAP_SHARE * (0.7 + _hash01(index, seed_value + 3) * 0.6)
			var cap_left := tip.lerp(left, share)
			var cap_right := tip.lerp(right, share)
			var notch := tip.lerp((left + right) / 2.0, share * 0.75)
			_canvas.draw_colored_polygon(PackedVector2Array([cap_left, tip, cap_right, notch]), environment.peak_cap)


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


## Crystals growing from the floor of the cavern: thin glowing spikes in
## clusters, with a lighter face on one side.
func _draw_shards(size: Vector2, offset: Vector2) -> void:
	var first := int(floor(offset.x / SHARD_SPACING)) - 1
	var last := int(ceil((offset.x + size.x) / SHARD_SPACING)) + 1
	var light := environment.shard_colour.lightened(0.45)
	for index in range(first, last + 1):
		if _hash01(index, 11) < 0.35:
			continue
		var base_x := index * SHARD_SPACING + _hash01(index, 12) * SHARD_SPACING * 0.6 - offset.x
		for piece in 3:
			var height := 50.0 + _hash01(index * 3 + piece, 13) * 120.0
			var half := 7.0 + _hash01(index * 3 + piece, 14) * 6.0
			var x := base_x + (piece - 1) * half * 1.6
			var lean := (piece - 1) * 12.0
			var bottom := size.y + 2.0
			var tip := Vector2(x + lean, bottom - height)
			_canvas.draw_colored_polygon(PackedVector2Array([Vector2(x - half, bottom), tip, Vector2(x + half, bottom)]), environment.shard_colour)
			_canvas.draw_colored_polygon(PackedVector2Array([Vector2(x - half * 0.2, bottom), tip, Vector2(x + half, bottom)]), Color(light, environment.shard_colour.a * 0.5))


## Points that stay put and fade in and out, each at its own pace.
func _draw_sparkles(size: Vector2) -> void:
	for index in environment.sparkle_count:
		var point := Vector2(_hash01(index, 21) * size.x, _hash01(index, 22) * size.y * 0.85)
		var glow := 0.5 + 0.5 * sin(_time * (0.8 + _hash01(index, 23) * 1.6) + index)
		var colour := environment.sparkle_colour
		colour.a *= 0.25 + 0.75 * glow
		_canvas.draw_rect(Rect2(point, Vector2.ONE * SPARKLE_SIZE), colour)


## Specks carried across the screen at the environment's drift velocity,
## wrapping around its edges, each a little faster or slower than the next.
func _draw_drift(size: Vector2) -> void:
	for index in environment.drift_count:
		var start := Vector2(_hash01(index, 31) * size.x, _hash01(index, 32) * size.y)
		var speed := 0.6 + _hash01(index, 33) * 0.8
		var sway := sin(_time * 1.3 + index) * 6.0
		var point := start + environment.drift_velocity * speed * _time
		point = Vector2(fposmod(point.x + sway, size.x), fposmod(point.y, size.y))
		_canvas.draw_rect(Rect2(point, Vector2.ONE * DRIFT_SIZE), environment.drift_colour)


## Below 1, seed_shift also flattens the small ripples (smooth dunes).
func _wave(x: float, seed_shift: float) -> float:
	var roughness := minf(seed_shift, 1.0)
	return sin(x * 0.006 * seed_shift) * 38.0 + sin(x * 0.017 + seed_shift * 3.0) * 14.0 * roughness + sin(x * 0.041 + seed_shift) * 5.0 * roughness


## A repeatable number in [0, 1) for an index, so the same peak or star is
## always in the same place.
func _hash01(index: int, seed_value: int) -> float:
	var value := sin(float(index) * 12.9898 + float(seed_value) * 78.233) * 43758.5453
	return value - floor(value)
