class_name LevelCamera
extends Camera2D
## The camera over a level or the editor. The world is drawn at its real
## pixel size (no zoom; see DisplayScaler), so the screen shows as much of
## the level as fits. A level smaller than the screen sits centred; a bigger
## one scrolls:
##   - arrow keys or WASD;
##   - dragging with the middle mouse button, or with one finger on a touch
##     screen;
##   - pushing the mouse against an edge of the window.
## It never scrolls past the level's bounds, plus the margins kept for the
## bars drawn over the top and bottom of the screen, so the level's edges
## can always be brought out from under them.

## Area of the world that can be shown.
var bounds: Rect2 = Rect2()
## World pixels at the top and bottom covered by bars (HUD, tool panel,
## editor toolbar): the camera can scroll this much past the bounds so
## nothing stays hidden under them.
var top_margin: float = 0.0
var bottom_margin: float = 0.0

## Scroll speed with the keys or the window edge, in world pixels per
## second. Positions, drags and the visible size all arrive in world pixels
## (the viewport's own units), whatever DisplayScaler's factor.
const SCROLL_SPEED := 600.0
## How close to a window edge, in screen pixels, the mouse starts scrolling.
const EDGE_SCROLL_ZONE := 12.0
## A touch has to move this far before it counts as a drag, so a tap on a
## lemming still selects it.
const TOUCH_DRAG_THRESHOLD := 12.0

var _dragging := false
var _touch_start := Vector2.ZERO
var _touch_dragging := false


func _ready() -> void:
	# Keeps scrolling while the game is paused.
	process_mode = Node.PROCESS_MODE_ALWAYS
	position_smoothing_enabled = false
	anchor_mode = Camera2D.ANCHOR_MODE_DRAG_CENTER
	make_current()
	get_viewport().size_changed.connect(_clamp_to_bounds)
	_clamp_to_bounds()


## Centres the view on a point (e.g. the entrance), within the bounds.
func focus_on(world_position: Vector2) -> void:
	position = world_position
	_clamp_to_bounds()


func _process(delta: float) -> void:
	var direction := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_LEFT) or Input.is_physical_key_pressed(KEY_A):
		direction.x -= 1
	if Input.is_physical_key_pressed(KEY_RIGHT) or Input.is_physical_key_pressed(KEY_D):
		direction.x += 1
	if Input.is_physical_key_pressed(KEY_UP) or Input.is_physical_key_pressed(KEY_W):
		direction.y -= 1
	if Input.is_physical_key_pressed(KEY_DOWN) or Input.is_physical_key_pressed(KEY_S):
		direction.y += 1
	direction += _edge_scroll_direction()
	if direction != Vector2.ZERO:
		position += direction.limit_length(1.0) * SCROLL_SPEED * delta
		_clamp_to_bounds()


func _unhandled_input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if button != null and button.button_index == MOUSE_BUTTON_MIDDLE:
		_dragging = button.pressed
		return
	var motion := event as InputEventMouseMotion
	if motion != null and _dragging:
		_scroll_by_screen(-motion.relative)
		return
	var touch := event as InputEventScreenTouch
	if touch != null:
		_touch_start = touch.position
		_touch_dragging = false
		return
	var drag := event as InputEventScreenDrag
	if drag != null:
		if not _touch_dragging and drag.position.distance_to(_touch_start) < TOUCH_DRAG_THRESHOLD:
			return
		_touch_dragging = true
		_scroll_by_screen(-drag.relative)


func _scroll_by_screen(screen_offset: Vector2) -> void:
	position += screen_offset
	_clamp_to_bounds()


## The mouse pushed against an edge of the window scrolls that way. Only
## when the window has focus and the mouse is inside it.
func _edge_scroll_direction() -> Vector2:
	if not get_window().has_focus() or DisplayServer.is_touchscreen_available():
		return Vector2.ZERO
	var size := get_viewport().get_visible_rect().size
	var mouse := get_viewport().get_mouse_position()
	if mouse.x < 0 or mouse.y < 0 or mouse.x > size.x or mouse.y > size.y:
		return Vector2.ZERO
	var direction := Vector2.ZERO
	if mouse.x < EDGE_SCROLL_ZONE:
		direction.x -= 1
	elif mouse.x > size.x - EDGE_SCROLL_ZONE:
		direction.x += 1
	if mouse.y < EDGE_SCROLL_ZONE:
		direction.y -= 1
	elif mouse.y > size.y - EDGE_SCROLL_ZONE:
		direction.y += 1
	return direction


## Keeps the view inside the bounds (grown by the bar margins). Along an
## axis where the level is smaller than the view, the level is centred.
func _clamp_to_bounds() -> void:
	if not bounds.has_area():
		return
	var view := get_viewport().get_visible_rect().size
	var area := bounds
	area.position.y -= top_margin
	area.size.y += top_margin + bottom_margin
	var half := view / 2.0
	for axis in [0, 1]:
		if area.size[axis] <= view[axis]:
			position[axis] = area.get_center()[axis]
		else:
			position[axis] = clampf(position[axis], area.position[axis] + half[axis], area.end[axis] - half[axis])
	position = position.round()
