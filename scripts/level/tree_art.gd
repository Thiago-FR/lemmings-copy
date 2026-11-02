class_name TreeArt
extends RefCounted
## Paints a whole scenery tree (crown and trunk) into one image, in the
## game's pixel style: dark outline, a base colour, light on the upper left.
## Drawn behind the terrain by BackgroundDecor; never solid. The trunk runs
## up into the crown, so there is no gap between them.
##
## A tree: {"kind": one of the kinds below, "box": Rect2i in cells (crown
## and trunk), "crown": Array[Vector2i] of the crown's cells, "trunk":
## Array[Vector2i] of the cells the trunk passes (drawn behind lemmings),
## "seed": int}.

const PINE := &"pine"
const SNOW_PINE := &"snow_pine"
const PALM := &"palm"
const MUSHROOM := &"mushroom"

const OUTLINE := Color(0.08, 0.05, 0.06)
const BARK := [Color(0.42, 0.26, 0.14), Color(0.27, 0.16, 0.09), Color(0.56, 0.37, 0.21)]
const PALM_BARK := [Color(0.62, 0.46, 0.26), Color(0.44, 0.31, 0.16), Color(0.76, 0.60, 0.36)]
const STEM := [Color(0.80, 0.78, 0.66), Color(0.58, 0.56, 0.46), Color(0.94, 0.92, 0.82)]
## base, dark, light, highlight
const LEAVES := {
	PINE: [Color(0.13, 0.42, 0.28), Color(0.07, 0.27, 0.18), Color(0.22, 0.56, 0.34), Color(0.36, 0.68, 0.40)],
	SNOW_PINE: [Color(0.16, 0.40, 0.34), Color(0.09, 0.26, 0.22), Color(0.26, 0.54, 0.44), Color(0.96, 0.98, 1.0)],
	PALM: [Color(0.36, 0.62, 0.24), Color(0.20, 0.42, 0.14), Color(0.54, 0.78, 0.32), Color(0.72, 0.88, 0.40)],
	MUSHROOM: [Color(0.66, 0.24, 0.62), Color(0.44, 0.12, 0.44), Color(0.84, 0.44, 0.80), Color(0.40, 1.0, 0.86)],
}

var _image: Image
var _rng := RandomNumberGenerator.new()
var _cell := 32
var _origin := Vector2i.ZERO


static func build(tree: Dictionary, cell_size: int) -> ImageTexture:
	var art := TreeArt.new()
	return ImageTexture.create_from_image(art._paint(tree, cell_size))


func _paint(tree: Dictionary, cell_size: int) -> Image:
	_cell = cell_size
	var box: Rect2i = tree.box
	_origin = box.position
	_rng.seed = int(tree.get("seed", 0))
	_image = Image.create(box.size.x * _cell, box.size.y * _cell, false, Image.FORMAT_RGBA8)
	_image.fill(Color(0, 0, 0, 0))
	var crown: Array = tree.crown
	var trunk: Array = tree.trunk
	match tree.kind:
		PINE, SNOW_PINE:
			_trunk(trunk, BARK, 10)
			_pine(crown, LEAVES[tree.kind], tree.kind == SNOW_PINE)
		PALM:
			_trunk(trunk, PALM_BARK, 8)
			_palm(crown, LEAVES[PALM])
		MUSHROOM:
			_trunk(trunk, STEM, 12)
			_mushroom(crown, LEAVES[MUSHROOM])
	return _image


# --- Parts --------------------------------------------------------------------

func _trunk(cells: Array, colours: Array, width: int) -> void:
	if cells.is_empty():
		return
	var top := _local(cells[0]).y
	var bottom := top
	var x := _local(cells[0]).x + _cell / 2
	for cell in cells:
		top = mini(top, _local(cell).y)
		bottom = maxi(bottom, _local(cell).y + _cell)
	var left := x - width / 2
	_rect(left - 1, top, width + 2, bottom - top, OUTLINE)
	_rect(left, top, width, bottom - top, colours[0])
	_rect(left + 2, top, 2, bottom - top, colours[2])
	_rect(left + width - 3, top, 2, bottom - top, colours[1])
	# Roots spreading at the foot.
	_rect(left - 3, bottom - 4, width + 6, 4, OUTLINE)
	_rect(left - 2, bottom - 3, width + 4, 3, colours[1])


## Pine: a stack of tiers, one per crown row, each a wide drooping triangle
## over the row's cells; the snowy one wears white on every tier.
func _pine(cells: Array, colours: Array, snowy: bool) -> void:
	var rows := {}
	for cell in cells:
		var local := _local(cell)
		var span: Vector2i = rows.get(local.y, Vector2i(local.x, local.x + _cell))
		rows[local.y] = Vector2i(mini(span.x, local.x), maxi(span.y, local.x + _cell))
	var keys := rows.keys()
	keys.sort()
	for y in keys:
		var span: Vector2i = rows[y]
		var centre := (span.x + span.y) / 2.0
		var half := (span.y - span.x) / 2.0 + 3.0
		var tip := float(y) - 10.0
		var base := float(y) + _cell - 2.0
		_triangle(centre, tip - 2.0, half + 2.0, base + 2.0, OUTLINE)
		_triangle(centre, tip, half, base, colours[1])
		_triangle(centre - 2.0, tip + 3.0, half * 0.7, base - 3.0, colours[0])
		_triangle(centre - 4.0, tip + 6.0, half * 0.3, base - 8.0, colours[2])
		if snowy:
			_triangle(centre, tip, half * 0.5, tip + (base - tip) * 0.45, colours[3])
			for drift in 3:
				_disc(centre + _rng.randf_range(-half * 0.8, half * 0.8), base - 2.0, 3.0, colours[3])


## Palm: fronds fanning out from the top of the trunk, drooping at the tips.
func _palm(cells: Array, colours: Array) -> void:
	var left := 1 << 20
	var right := -(1 << 20)
	var y := 0
	for cell in cells:
		var local := _local(cell)
		left = mini(left, local.x)
		right = maxi(right, local.x + _cell)
		y = local.y
	var centre := Vector2((left + right) / 2.0, y + _cell * 0.45)
	for frond in 6:
		var side := -1.0 if frond % 2 == 0 else 1.0
		var reach := (right - left) / 2.0 * (0.6 + 0.4 * float(frond / 2) / 2.0)
		var lift := 6.0 - float(frond / 2) * 5.0
		for step in 24:
			var t := float(step) / 23.0
			var point := centre + Vector2(side * reach * t, -lift * sin(t * PI) + t * t * 10.0)
			_disc(point.x, point.y, 6.0 - t * 2.5, OUTLINE)
		for step in 24:
			var t := float(step) / 23.0
			var point := centre + Vector2(side * reach * t, -lift * sin(t * PI) + t * t * 10.0)
			_disc(point.x, point.y, 4.5 - t * 2.0, colours[0] if frond < 4 else colours[2])
	_disc(centre.x, centre.y + 2.0, 5.0, OUTLINE)
	_disc(centre.x - 3.0, centre.y + 3.0, 3.0, Color(0.42, 0.28, 0.14))
	_disc(centre.x + 3.0, centre.y + 3.0, 3.0, Color(0.42, 0.28, 0.14))


## A giant mushroom: a dome over the crown cells with glowing spots.
func _mushroom(cells: Array, colours: Array) -> void:
	var left := 1 << 20
	var right := -(1 << 20)
	var top := 1 << 20
	var bottom := -(1 << 20)
	for cell in cells:
		var local := _local(cell)
		left = mini(left, local.x)
		right = maxi(right, local.x + _cell)
		top = mini(top, local.y)
		bottom = maxi(bottom, local.y + _cell)
	var centre := Vector2((left + right) / 2.0, bottom - 4.0)
	var radii := Vector2((right - left) / 2.0 + 2.0, bottom - top + 2.0)
	_dome(centre, radii + Vector2(2, 2), OUTLINE)
	_dome(centre, radii, colours[1])
	_dome(centre - Vector2(3, 3), radii * Vector2(0.86, 0.85), colours[0])
	_dome(centre - Vector2(radii.x * 0.35, radii.y * 0.45), radii * 0.3, colours[2])
	_rect(int(centre.x - radii.x), int(centre.y - 2), int(radii.x * 2.0), 4, colours[1])
	for spot in 5:
		var at := centre + Vector2(_rng.randf_range(-radii.x * 0.7, radii.x * 0.7), -_rng.randf_range(radii.y * 0.3, radii.y * 0.8))
		_disc(at.x, at.y, 2.5, colours[3])


# --- Pixels -------------------------------------------------------------------

func _local(cell: Vector2i) -> Vector2i:
	return (cell - _origin) * _cell


func _rect(x: int, y: int, width: int, height: int, colour: Color) -> void:
	var area := Rect2i(x, y, width, height).intersection(Rect2i(Vector2i.ZERO, _image.get_size()))
	if area.has_area():
		_image.fill_rect(area, colour)


func _disc(cx: float, cy: float, radius: float, colour: Color) -> void:
	for y in range(floori(cy - radius), ceili(cy + radius) + 1):
		for x in range(floori(cx - radius), ceili(cx + radius) + 1):
			if Vector2(x + 0.5 - cx, y + 0.5 - cy).length() <= radius:
				_put(x, y, colour)


## The top half of an ellipse standing on centre.
func _dome(centre: Vector2, radii: Vector2, colour: Color) -> void:
	for y in range(floori(centre.y - radii.y), ceili(centre.y) + 1):
		for x in range(floori(centre.x - radii.x), ceili(centre.x + radii.x) + 1):
			var offset := Vector2((x + 0.5 - centre.x) / radii.x, (y + 0.5 - centre.y) / radii.y)
			if offset.length() <= 1.0:
				_put(x, y, colour)


## A triangle pointing up: tip at (centre, tip), base from centre - half to
## centre + half at base.
func _triangle(centre: float, tip: float, half: float, base: float, colour: Color) -> void:
	for y in range(floori(tip), ceili(base) + 1):
		var share := clampf((y - tip) / maxf(1.0, base - tip), 0.0, 1.0)
		var reach := half * share
		for x in range(floori(centre - reach), ceili(centre + reach) + 1):
			_put(x, y, colour)


func _put(x: int, y: int, colour: Color) -> void:
	if x >= 0 and y >= 0 and x < _image.get_width() and y < _image.get_height():
		_image.set_pixel(x, y, colour)
