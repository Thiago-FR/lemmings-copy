class_name EditorGridOverlay
extends Node2D
## Draws the terrain grid and a highlight where the current tool would paint,
## so the player can see the 32px cells (and the brick sub-rows) before
## clicking. Purely visual: it never reads input or touches the terrain.

const GRID_COLOUR := Color(1.0, 1.0, 1.0, 0.08)
const PREVIEW_COLOUR := Color(1.0, 0.9, 0.3, 0.35)
const PREVIEW_BORDER_COLOUR := Color(1.0, 0.9, 0.3, 0.9)

var area := Rect2()
var cell_size := Vector2(32, 32)

var _preview_rect := Rect2()


func show_preview(rect: Rect2) -> void:
	if rect == _preview_rect:
		return
	_preview_rect = rect
	queue_redraw()


func hide_preview() -> void:
	show_preview(Rect2())


func _draw() -> void:
	_draw_grid()
	if _preview_rect.has_area():
		draw_rect(_preview_rect, PREVIEW_COLOUR)
		draw_rect(_preview_rect, PREVIEW_BORDER_COLOUR, false, 1.0)


func _draw_grid() -> void:
	if not area.has_area():
		return
	var x := area.position.x
	while x <= area.end.x:
		draw_line(Vector2(x, area.position.y), Vector2(x, area.end.y), GRID_COLOUR)
		x += cell_size.x
	var y := area.position.y
	while y <= area.end.y:
		draw_line(Vector2(area.position.x, y), Vector2(area.end.x, y), GRID_COLOUR)
		y += cell_size.y
