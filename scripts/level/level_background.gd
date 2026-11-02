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
## The sun's halo breathes: its rings grow and shrink by this share, this
## fast (radians per second).
const SUN_PULSE_SHARE := 0.08
const SUN_PULSE_SPEED := 1.2
## Clouds: how fast they drift (pixels per second, before the per-cloud
## spread) and how big, as a share of the screen width.
const CLOUD_SPEED := 9.0
const CLOUD_WIDTH_SHARE := 0.10
## Birds: speed (pixels per second), flapping (radians per second), wing
## span (pixels) and the height band they fly in (share of the screen).
const BIRD_SPEED := 42.0
const BIRD_FLAP_SPEED := 9.0
const BIRD_SPAN := 9.0
const BIRD_BAND := Vector2(0.10, 0.42)

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
	if not environment.nebula_colours.is_empty():
		_draw_nebula(size, scroll * 0.05)
	if environment.sparkle_count > 0:
		_draw_sparkles(size)
	if environment.sun_radius > 0.0:
		_draw_sun(size)
	if environment.ringed_planet:
		_draw_ringed_planet(size, scroll * 0.03)
	if environment.cloud_count > 0:
		_draw_clouds(size)
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
		LevelEnvironment.Skyline.BUILDINGS:
			_draw_buildings(size, scroll * FAR_PARALLAX, environment.far_layer, 0.40, 1)
			_draw_buildings(size, scroll * NEAR_PARALLAX, environment.near_layer, 0.58, 2)
		LevelEnvironment.Skyline.NONE:
			pass
		_:
			_draw_hills(size, scroll * FAR_PARALLAX, environment.far_layer, 0.58, 1.0)
			_draw_hills(size, scroll * NEAR_PARALLAX, environment.near_layer, 0.72, 2.1)
	if environment.bird_count > 0:
		_draw_birds(size)
	if environment.shard_colour.a > 0.0:
		_draw_shards(size, scroll * NEAR_PARALLAX)
	if environment.drift_count > 0:
		_draw_drift(size)


## Towers of different heights side by side, some windows lit.
func _draw_buildings(size: Vector2, scroll: Vector2, colour: Color, top_share: float, seed_offset: int) -> void:
	const TOWER_WIDTH := 70.0
	var first := floori(scroll.x / TOWER_WIDTH) - 1
	var count := ceili(size.x / TOWER_WIDTH) + 2
	for index in range(first, first + count):
		var width := TOWER_WIDTH * (0.6 + 0.5 * _hash01(index, 61 + seed_offset))
		var height := size.y * (1.0 - top_share) * (0.45 + 0.75 * _hash01(index, 67 + seed_offset))
		var x := index * TOWER_WIDTH - scroll.x
		var top := size.y - height
		_canvas.draw_rect(Rect2(x, top, width, height), colour)
		for row in int(height / 18.0):
			for column in int(width / 14.0):
				if _hash01(index * 131 + row * 7 + column, 71 + seed_offset) < 0.22:
					_canvas.draw_rect(Rect2(x + 4.0 + column * 14.0, top + 8.0 + row * 18.0, 5.0, 7.0), Color(1.0, 0.86, 0.5, 0.55 / seed_offset))


## Clouds of coloured gas: many large, faint discs that add up to soft
## shapes, drifting very slowly with the camera.
func _draw_nebula(size: Vector2, scroll: Vector2) -> void:
	# A few clouds, each many faint discs stepping inwards, so the edge
	# fades instead of showing a circle.
	for cloud in 7:
		var colour: Color = environment.nebula_colours[cloud % environment.nebula_colours.size()]
		var centre := Vector2(_hash01(cloud, 81) * size.x * 1.2 - size.x * 0.1, _hash01(cloud, 83) * size.y) - scroll
		var radius := size.y * (0.25 + 0.25 * _hash01(cloud, 87))
		for puff in 9:
			var offset := Vector2(_hash01(cloud * 11 + puff, 89) - 0.5, _hash01(cloud * 11 + puff, 91) - 0.5) * radius * 1.4
			for ring in 6:
				_canvas.draw_circle(centre + offset, radius * (0.55 - ring * 0.08), colour)


## A ringed planet high in the sky: a banded disc behind its ring.
func _draw_ringed_planet(size: Vector2, scroll: Vector2) -> void:
	var centre := Vector2(size.x * 0.78, size.y * 0.24) - scroll
	var radius := size.y * 0.09
	var ring := Color(0.95, 0.82, 0.60, 0.55)
	_draw_ellipse_ring(centre, Vector2(radius * 2.1, radius * 0.55), ring, true)
	_canvas.draw_circle(centre, radius, Color(0.86, 0.62, 0.40))
	for band in 3:
		var y := centre.y - radius * 0.5 + band * radius * 0.45
		var half := sqrt(maxf(0.0, radius * radius - (y - centre.y) ** 2))
		_canvas.draw_rect(Rect2(centre.x - half, y, half * 2.0, radius * 0.14), Color(0.70, 0.46, 0.30))
	_draw_ellipse_ring(centre, Vector2(radius * 2.1, radius * 0.55), ring, false)


## Half an ellipse's outline: the back half (top) or the front half (bottom).
func _draw_ellipse_ring(centre: Vector2, radii: Vector2, colour: Color, back: bool) -> void:
	var points := PackedVector2Array()
	for step in 33:
		var angle := PI + PI * step / 32.0 if back else PI * step / 32.0
		points.append(centre + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	_canvas.draw_polyline(points, colour, 3.0)


func _draw_gradient(size: Vector2) -> void:
	var colors := PackedColorArray([environment.sky_top, environment.sky_top, environment.sky_bottom, environment.sky_bottom])
	var points := PackedVector2Array([Vector2.ZERO, Vector2(size.x, 0), size, Vector2(0, size.y)])
	_canvas.draw_polygon(points, colors)


## A soft halo and a disc; fixed on the screen, as a far-away sun is.
func _draw_sun(size: Vector2) -> void:
	var centre := size * environment.sun_position
	var halo := environment.sun_colour
	var pulse := 1.0 + SUN_PULSE_SHARE * sin(_time * SUN_PULSE_SPEED)
	for ring in range(4, 0, -1):
		halo.a = environment.sun_colour.a * 0.08
		_canvas.draw_circle(centre, environment.sun_radius * (1.0 + ring * 0.35 * pulse), halo)
	_canvas.draw_circle(centre, environment.sun_radius, environment.sun_colour)


## Soft clouds drifting left to right at their own pace and coming back
## round. Each is a few discs over a flat base, painted in one colour (the
## cloud mixed with the sky behind it) so the discs merge into one shape
## instead of showing their overlaps.
func _draw_clouds(size: Vector2) -> void:
	var width := size.x * CLOUD_WIDTH_SHARE
	for index in environment.cloud_count:
		var speed := CLOUD_SPEED * (0.6 + _hash01(index, 41))
		var scale := 0.6 + 0.7 * _hash01(index, 53)
		var cloud_width := width * scale
		var span := size.x + cloud_width * 2.0
		var x := fposmod(_hash01(index, 43) * span + speed * _time, span) - cloud_width
		var y := size.y * (0.08 + 0.26 * _hash01(index, 47))
		var sky := environment.sky_top.lerp(environment.sky_bottom, clampf(y / size.y, 0.0, 1.0))
		var colour := sky.lerp(Color(environment.cloud_colour, 1.0), environment.cloud_colour.a)
		# A flat bottom with rounded ends (a rectangle with a disc at each
		# end), inside the puffs' reach so no square corner pokes out.
		var base_half_height := cloud_width * 0.08
		var base_left := x - cloud_width * 0.34
		var base_right := x + cloud_width * 0.34
		_canvas.draw_rect(Rect2(base_left, y - base_half_height, base_right - base_left, base_half_height * 2.0), colour)
		_canvas.draw_circle(Vector2(base_left, y), base_half_height, colour)
		_canvas.draw_circle(Vector2(base_right, y), base_half_height, colour)
		for puff in 4:
			var radius := cloud_width * (0.13 + 0.06 * float(puff % 2))
			var centre := Vector2(x + (float(puff) - 1.5) * cloud_width * 0.24, y - radius * 0.35)
			_canvas.draw_circle(centre, radius, colour)


## Small birds: two wing strokes flapping, flying across in a loose line and
## bobbing a little, then coming round again from the other side.
func _draw_birds(size: Vector2) -> void:
	var span := size.x + BIRD_SPAN * 8.0
	for index in environment.bird_count:
		var speed := BIRD_SPEED * (0.7 + 0.6 * _hash01(index, 61))
		var x := fposmod(_hash01(index, 67) * span + speed * _time, span) - BIRD_SPAN * 4.0
		var band := lerpf(BIRD_BAND.x, BIRD_BAND.y, _hash01(index, 71))
		var y := size.y * band + sin(_time * 1.5 + index * 2.0) * 4.0
		var flap := sin(_time * BIRD_FLAP_SPEED + index * 1.7)
		var body := Vector2(x, y)
		var tip_y := -flap * BIRD_SPAN * 0.6
		_canvas.draw_polyline(PackedVector2Array([body + Vector2(-BIRD_SPAN, tip_y), body + Vector2(-BIRD_SPAN * 0.4, tip_y * 0.3 - 1.0), body]), environment.bird_colour, 1.5)
		_canvas.draw_polyline(PackedVector2Array([body, body + Vector2(BIRD_SPAN * 0.4, tip_y * 0.3 - 1.0), body + Vector2(BIRD_SPAN, tip_y)]), environment.bird_colour, 1.5)


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
