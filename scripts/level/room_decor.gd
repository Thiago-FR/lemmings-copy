class_name RoomDecor
extends Node2D
## Furniture painted on the back wall of rooms inside a building or a ship:
## reactors in an engine room, consoles and a big window on a bridge,
## tables in a mess hall, bunks in the quarters, tanks in a lab, plant racks
## in a greenhouse, shelves in a cargo hold, a bed in a sick bay. Nothing
## here is solid: it only tells the rooms apart. Drawn behind the lemmings
## and the portals; a few parts move (a reactor's glow, bubbles, screens).
##
## rooms: {"kind": one of the kind names, "rect": Rect2i in cells, the air
## of the room, its floor just below}.

const ENGINE := &"engine"
const BRIDGE := &"bridge"
const MESS := &"mess"
const QUARTERS := &"quarters"
const LAB := &"lab"
const GREENHOUSE := &"greenhouse"
const CARGO := &"cargo"
const SICK_BAY := &"sick_bay"
## The rooms a ship's middle is made of, besides the engine room and bridge.
const SHIP_ROOMS: Array[StringName] = [MESS, QUARTERS, LAB, GREENHOUSE, CARGO, SICK_BAY]

const OUTLINE := Color(0.06, 0.07, 0.10)
const METAL := Color(0.42, 0.46, 0.54)
const METAL_DARK := Color(0.28, 0.31, 0.38)
const METAL_LIGHT := Color(0.62, 0.66, 0.74)
const GLOW := Color(0.40, 0.90, 1.0)
const LAMP := Color(1.0, 0.94, 0.70)
const WOOD := Color(0.52, 0.36, 0.22)
const HAZARD := Color(0.96, 0.78, 0.18)
const PLANT := Color(0.30, 0.66, 0.30)
const PLANT_DARK := Color(0.18, 0.46, 0.22)
const LIQUID := Color(0.36, 0.92, 0.52, 0.85)
const BLANKETS: Array[Color] = [Color(0.72, 0.30, 0.28), Color(0.28, 0.46, 0.74), Color(0.36, 0.62, 0.38), Color(0.78, 0.62, 0.30)]
const SCREENS: Array[Color] = [Color(0.40, 0.90, 1.0), Color(0.50, 1.0, 0.56), Color(1.0, 0.70, 0.30), Color(1.0, 0.42, 0.42)]
## Behind the portals (-1), over the room's back wall (TerrainSkin, -2).
const DECOR_Z := -2

var rooms: Array[Dictionary] = []

var _cell := Constants.TERRAIN_TILE_SIZE
var _time := 0.0


func _ready() -> void:
	z_index = DECOR_Z
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	for room in rooms:
		var rect: Rect2i = room.rect
		var area := Rect2(Vector2(rect.position) * _cell, Vector2(rect.size) * _cell)
		match room.kind:
			ENGINE:
				_engine_room(area)
			BRIDGE:
				_bridge(area)
			MESS:
				_mess(area)
			QUARTERS:
				_quarters(area)
			LAB:
				_lab(area)
			GREENHOUSE:
				_greenhouse(area)
			CARGO:
				_cargo(area)
			SICK_BAY:
				_sick_bay(area)
		_ceiling_lamps(area, room.kind == GREENHOUSE)


# --- Shared parts ------------------------------------------------------------

func _box(rect: Rect2, colour: Color) -> void:
	draw_rect(rect.grow(1.5), OUTLINE)
	draw_rect(rect, colour)


func _ceiling_lamps(area: Rect2, grow_lights: bool) -> void:
	var count := maxi(1, int(area.size.x / (_cell * 4.0)))
	var gap := area.size.x / count
	for index in count:
		var x := area.position.x + gap * (index + 0.5)
		var colour := Color(0.86, 0.46, 1.0) if grow_lights else LAMP
		draw_rect(Rect2(x - 10, area.position.y, 20, 4), OUTLINE)
		draw_rect(Rect2(x - 8, area.position.y + 1, 16, 3), colour)
		# A soft cone of light under it.
		var cone := PackedVector2Array([Vector2(x - 8, area.position.y + 4), Vector2(x + 8, area.position.y + 4), Vector2(x + 26, area.position.y + 30), Vector2(x - 26, area.position.y + 30)])
		draw_colored_polygon(cone, Color(colour, 0.07))


## How many copies of a piece of furniture this wide fit, and where each one
## starts, spread evenly across the room.
func _slots(area: Rect2, width: float) -> Array[float]:
	var slots: Array[float] = []
	var count := maxi(1, int((area.size.x - 8.0) / width))
	var spare := area.size.x - count * width
	for index in count:
		slots.append(area.position.x + spare / 2.0 + index * width)
	return slots


# --- Rooms -------------------------------------------------------------------

## Reactors with a pulsing core, pipes along the ceiling into them, warning
## stripes on their bases.
func _engine_room(area: Rect2) -> void:
	var floor_y := area.end.y
	for pipe in 2:
		var y := area.position.y + 8.0 + pipe * 9.0
		_box(Rect2(area.position.x, y, area.size.x, 5), METAL_DARK if pipe == 0 else METAL)
	var pulse := 0.6 + 0.4 * sin(_time * 3.0)
	for x in _slots(area, _cell * 5.0):
		var body := Rect2(x + 24, floor_y - _cell * 3.6, _cell * 2.6, _cell * 3.6)
		_box(Rect2(body.position.x + body.size.x / 2.0 - 4, area.position.y + 8, 8, body.position.y - area.position.y - 8), METAL_DARK)
		_box(body, METAL)
		draw_rect(Rect2(body.position.x, body.position.y, 6, body.size.y), METAL_LIGHT)
		draw_rect(Rect2(body.end.x - 8, body.position.y, 8, body.size.y), METAL_DARK)
		for band in 3:
			draw_rect(Rect2(body.position.x, body.position.y + 12 + band * 34, body.size.x, 3), METAL_DARK)
		var core := Rect2(body.position.x + 22, body.position.y + 22, body.size.x - 44, body.size.y - 52)
		draw_rect(core.grow(2), OUTLINE)
		draw_rect(core, Color(GLOW, 0.35 + 0.5 * pulse))
		draw_rect(Rect2(core.get_center().x - 3, core.position.y, 6, core.size.y), Color(1, 1, 1, 0.5 + 0.4 * pulse))
		draw_circle(core.get_center(), core.size.x * 1.2, Color(GLOW, 0.06 * pulse))
		var base := Rect2(body.position.x - 6, floor_y - 12, body.size.x + 12, 12)
		_box(base, HAZARD)
		for stripe in int(base.size.x / 12.0):
			draw_colored_polygon(PackedVector2Array([
				Vector2(base.position.x + stripe * 12, base.end.y), Vector2(base.position.x + stripe * 12 + 6, base.end.y),
				Vector2(base.position.x + stripe * 12 + 12, base.position.y), Vector2(base.position.x + stripe * 12 + 6, base.position.y)]), OUTLINE)


## A long window onto the stars, consoles under it with blinking screens,
## seats in front of them.
func _bridge(area: Rect2) -> void:
	var floor_y := area.end.y
	var window := Rect2(area.position.x + 16, area.position.y + 16, area.size.x - 32, area.size.y * 0.42)
	_box(window, Color(0.03, 0.04, 0.10))
	for star in 18:
		var at := window.position + Vector2(fmod(star * 53.7, window.size.x - 4) + 2, fmod(star * 31.3, window.size.y - 4) + 2)
		draw_rect(Rect2(at, Vector2(2, 2)), Color(1, 1, 1, 0.5 + 0.5 * sin(_time * 1.5 + star)))
	for strut in range(1, int(window.size.x / 70.0) + 1):
		draw_rect(Rect2(window.position.x + strut * 70, window.position.y, 4, window.size.y), METAL_DARK)
	for x in _slots(area, _cell * 3.0):
		var desk := Rect2(x + 8, floor_y - 30, _cell * 2.2, 30)
		_box(desk, METAL_DARK)
		_box(Rect2(desk.position.x + 6, desk.position.y - 16, desk.size.x - 12, 14), Color(0.05, 0.08, 0.12))
		for light in 4:
			var lit := sin(_time * 2.0 + x * 0.1 + light * 1.7) > -0.2
			var colour := SCREENS[(int(x) / 7 + light) % SCREENS.size()]
			draw_rect(Rect2(desk.position.x + 10 + light * 12, desk.position.y - 12, 8, 6), colour if lit else colour.darkened(0.6))
		draw_rect(Rect2(desk.position.x + 6, desk.position.y + 8, desk.size.x - 12, 3), GLOW)
		# The seat.
		var seat_x := desk.get_center().x + 26
		_box(Rect2(seat_x - 2, floor_y - 18, 4, 18), METAL_DARK)
		_box(Rect2(seat_x - 10, floor_y - 22, 20, 6), Color(0.62, 0.20, 0.22))
		_box(Rect2(seat_x + 8, floor_y - 40, 6, 22), Color(0.62, 0.20, 0.22))


## Tables with stools and plates, a food dispenser and a picture on the wall.
func _mess(area: Rect2) -> void:
	var floor_y := area.end.y
	var dispenser := Rect2(area.position.x + 12, floor_y - 92, 34, 92)
	_box(dispenser, METAL)
	_box(Rect2(dispenser.position.x + 6, dispenser.position.y + 10, 22, 16), Color(0.05, 0.08, 0.12))
	draw_rect(Rect2(dispenser.position.x + 9, dispenser.position.y + 14, 16, 3), Color(1.0, 0.70, 0.30))
	_box(Rect2(dispenser.position.x + 8, dispenser.position.y + 48, 18, 14), Color(0.10, 0.12, 0.16))
	var picture := Rect2(area.get_center().x - 22, area.position.y + 26, 44, 30)
	_box(picture, Color(0.10, 0.12, 0.30))
	draw_circle(picture.get_center(), 9, Color(0.86, 0.54, 0.30))
	for x in _slots(Rect2(area.position.x + 56, area.position.y, area.size.x - 56, area.size.y), _cell * 4.0):
		var top := Rect2(x + 16, floor_y - 30, _cell * 3.0, 6)
		_box(top, WOOD)
		_box(Rect2(top.position.x + 8, top.end.y, 5, floor_y - top.end.y), WOOD.darkened(0.3))
		_box(Rect2(top.end.x - 13, top.end.y, 5, floor_y - top.end.y), WOOD.darkened(0.3))
		for plate in 3:
			var at := Vector2(top.position.x + 18 + plate * 26, top.position.y - 3)
			draw_rect(Rect2(at.x - 7, at.y, 14, 3), Color(0.92, 0.92, 0.90))
			draw_rect(Rect2(at.x - 3, at.y - 2, 6, 2), [Color(0.86, 0.40, 0.28), Color(0.50, 0.76, 0.34), Color(0.94, 0.80, 0.40)][plate])
		for side in [-1, 1]:
			var stool_x: float = top.get_center().x + side * (top.size.x / 2.0 + 10)
			_box(Rect2(stool_x - 8, floor_y - 18, 16, 4), METAL_LIGHT)
			_box(Rect2(stool_x - 2, floor_y - 14, 4, 14), METAL_DARK)


## Bunk beds with blankets and pillows, lockers between them.
func _quarters(area: Rect2) -> void:
	var floor_y := area.end.y
	for index in _slots(area, _cell * 4.0).size():
		var x: float = _slots(area, _cell * 4.0)[index]
		var bunk := Rect2(x + 6, floor_y - _cell * 3.2, _cell * 2.8, _cell * 3.2)
		_box(Rect2(bunk.position.x, bunk.position.y, 5, bunk.size.y), METAL_DARK)
		_box(Rect2(bunk.end.x - 5, bunk.position.y, 5, bunk.size.y), METAL_DARK)
		for level in 2:
			var y := bunk.position.y + 18 + level * 48
			var blanket := BLANKETS[(index * 2 + level) % BLANKETS.size()]
			_box(Rect2(bunk.position.x + 5, y + 10, bunk.size.x - 10, 6), METAL)
			_box(Rect2(bunk.position.x + 5, y, bunk.size.x - 10, 10), blanket)
			draw_rect(Rect2(bunk.position.x + 5, y, bunk.size.x - 10, 3), blanket.lightened(0.2))
			_box(Rect2(bunk.position.x + 8, y - 5, 16, 7), Color(0.92, 0.92, 0.88))
		var locker := Rect2(bunk.end.x + 8, floor_y - 84, 22, 84)
		if locker.end.x < area.end.x - 2:
			_box(locker, Color(0.34, 0.44, 0.58))
			for vent in 3:
				draw_rect(Rect2(locker.position.x + 5, locker.position.y + 8 + vent * 5, 12, 2), OUTLINE)
			draw_rect(Rect2(locker.end.x - 6, locker.get_center().y, 3, 8), METAL_LIGHT)


## Glass tanks of green liquid with rising bubbles, a bench with flasks, a
## monitor with a moving line.
func _lab(area: Rect2) -> void:
	var floor_y := area.end.y
	var slots := _slots(area, _cell * 3.0)
	for index in slots.size():
		var x: float = slots[index]
		if index % 2 == 0:
			var tank := Rect2(x + 22, floor_y - _cell * 3.0, 44, _cell * 3.0 - 14)
			_box(Rect2(tank.position.x - 4, tank.end.y, tank.size.x + 8, 14), METAL_DARK)
			_box(Rect2(tank.position.x - 4, tank.position.y - 10, tank.size.x + 8, 10), METAL_DARK)
			draw_rect(tank.grow(1.5), OUTLINE)
			draw_rect(tank, Color(0.70, 0.86, 0.90, 0.25))
			var liquid := Rect2(tank.position.x, tank.position.y + 12, tank.size.x, tank.size.y - 12)
			draw_rect(liquid, LIQUID)
			for bubble in 4:
				var rise := fmod(_time * 22.0 + bubble * 19.0 + x, liquid.size.y)
				draw_circle(Vector2(liquid.position.x + 8 + bubble * 9, liquid.end.y - rise), 2.5, Color(0.9, 1, 0.9, 0.7))
			draw_rect(Rect2(tank.position.x + 4, tank.position.y, 4, tank.size.y), Color(1, 1, 1, 0.3))
		else:
			var bench := Rect2(x + 8, floor_y - 32, _cell * 2.4, 6)
			_box(bench, METAL)
			_box(Rect2(bench.position.x + 4, bench.end.y, 5, 26), METAL_DARK)
			_box(Rect2(bench.end.x - 9, bench.end.y, 5, 26), METAL_DARK)
			for flask in 3:
				var at := Vector2(bench.position.x + 14 + flask * 18, bench.position.y)
				draw_rect(Rect2(at.x - 5, at.y - 10, 10, 10), OUTLINE)
				draw_rect(Rect2(at.x - 4, at.y - 9, 8, 9), SCREENS[flask].lightened(0.2))
				draw_rect(Rect2(at.x - 2, at.y - 16, 4, 7), Color(0.80, 0.90, 0.95))
			var monitor := Rect2(bench.position.x + 6, area.position.y + 22, bench.size.x - 12, 34)
			_box(monitor, Color(0.04, 0.08, 0.10))
			var points := PackedVector2Array()
			for step in 12:
				var t := float(step) / 11.0
				points.append(Vector2(monitor.position.x + 4 + t * (monitor.size.x - 8), monitor.get_center().y + sin(t * 9.0 + _time * 3.0) * 9.0))
			draw_polyline(points, SCREENS[1], 2.0)


## Racks of plants in rows, under the violet grow lights.
func _greenhouse(area: Rect2) -> void:
	var floor_y := area.end.y
	for x in _slots(area, _cell * 3.5):
		var rack := Rect2(x + 10, floor_y - _cell * 3.4, _cell * 2.8, _cell * 3.4)
		_box(Rect2(rack.position.x, rack.position.y, 4, rack.size.y), METAL_DARK)
		_box(Rect2(rack.end.x - 4, rack.position.y, 4, rack.size.y), METAL_DARK)
		for shelf in 3:
			var y := rack.position.y + 30 + shelf * 36
			_box(Rect2(rack.position.x, y, rack.size.x, 6), Color(0.42, 0.30, 0.20))
			for plant in 4:
				var px := rack.position.x + 12 + plant * 18
				var sway := sin(_time * 1.4 + plant + shelf) * 1.5
				draw_rect(Rect2(px - 6 + sway, y - 14, 12, 10), PLANT_DARK)
				draw_rect(Rect2(px - 4 + sway, y - 18, 8, 8), PLANT)
				draw_rect(Rect2(px - 1, y - 6, 2, 6), PLANT_DARK)


## Shelves of boxes and barrels on the back wall; the crates on the floor
## are real cells (TerrainSkin.CRATE).
func _cargo(area: Rect2) -> void:
	var floor_y := area.end.y
	for x in _slots(area, _cell * 4.0):
		var shelf := Rect2(x + 8, area.position.y + 20, _cell * 3.4, area.size.y - 20)
		_box(Rect2(shelf.position.x, shelf.position.y, 4, shelf.size.y), METAL_DARK)
		_box(Rect2(shelf.end.x - 4, shelf.position.y, 4, shelf.size.y), METAL_DARK)
		for level in 2:
			var y := shelf.position.y + 34 + level * 44
			_box(Rect2(shelf.position.x, y, shelf.size.x, 4), METAL)
			for box in 3:
				var size := 18.0 + float((int(x) + box * 7 + level * 3) % 3) * 4.0
				var colour := [Color(0.62, 0.46, 0.28), Color(0.50, 0.38, 0.24), Color(0.40, 0.52, 0.40)][(box + level) % 3] as Color
				_box(Rect2(shelf.position.x + 8 + box * 34, y - size, size + 6, size), colour)
		var barrel := Rect2(shelf.get_center().x - 10, floor_y - 28, 20, 28)
		_box(barrel, Color(0.30, 0.44, 0.62))
		draw_rect(Rect2(barrel.position.x, barrel.position.y + 6, barrel.size.x, 3), METAL_DARK)
		draw_rect(Rect2(barrel.position.x, barrel.end.y - 9, barrel.size.x, 3), METAL_DARK)


## A bed with a sheet, a heart monitor with a beating line, a cabinet with a
## cross on it.
func _sick_bay(area: Rect2) -> void:
	var floor_y := area.end.y
	var slots := _slots(area, _cell * 4.0)
	for index in slots.size():
		var x: float = slots[index]
		var bed := Rect2(x + 10, floor_y - 34, _cell * 2.6, 12)
		_box(bed, Color(0.92, 0.94, 0.96))
		draw_rect(Rect2(bed.position.x + 20, bed.position.y, bed.size.x - 20, 6), Color(0.56, 0.78, 0.86))
		_box(Rect2(bed.position.x + 4, bed.position.y - 6, 16, 7), Color(1, 1, 1))
		_box(Rect2(bed.position.x + 6, bed.end.y, 4, floor_y - bed.end.y), METAL_DARK)
		_box(Rect2(bed.end.x - 10, bed.end.y, 4, floor_y - bed.end.y), METAL_DARK)
		var monitor := Rect2(bed.end.x + 8, floor_y - 92, 36, 26)
		_box(Rect2(monitor.get_center().x - 2, monitor.end.y, 4, floor_y - monitor.end.y), METAL_DARK)
		_box(monitor, Color(0.03, 0.08, 0.06))
		var beat := fmod(_time * 1.2, 1.0)
		var points := PackedVector2Array()
		for step in 10:
			var t := float(step) / 9.0
			var y := monitor.get_center().y
			if absf(t - beat) < 0.06:
				y -= 9.0
			points.append(Vector2(monitor.position.x + 3 + t * (monitor.size.x - 6), y))
		draw_polyline(points, SCREENS[1], 2.0)
		if index == 0:
			var cabinet := Rect2(area.end.x - 44, area.position.y + 24, 32, 40)
			if cabinet.position.x > monitor.end.x + 6:
				_box(cabinet, Color(0.94, 0.94, 0.94))
				draw_rect(Rect2(cabinet.get_center().x - 3, cabinet.position.y + 8, 6, 24), Color(0.86, 0.22, 0.24))
				draw_rect(Rect2(cabinet.get_center().x - 12, cabinet.get_center().y - 3, 24, 6), Color(0.86, 0.22, 0.24))
