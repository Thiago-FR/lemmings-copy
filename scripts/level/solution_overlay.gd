class_name SolutionOverlay
extends Node2D
## Developer view of a level's recorded solution (MazeStageData.solution):
## for every hand-out, a band on the floor where the tool is given, the
## tool's icon above it with its order and the way the lemming must face,
## and a ring on each item to pick up first. Hidden until toggled with the V
## key or its own button, and only made in developer mode (LevelManager).
## Answers at a glance whether a stuck stage is impossible or the tool went
## somewhere else.

const TOGGLE_KEY := KEY_V
const BAND_HEIGHT := 6.0
const ICON_SIZE := 24.0
const ICON_RISE := 44.0
const ICON_BACKDROP := Color(0.08, 0.06, 0.04, 0.85)
const ARROW_SIZE := 7.0
const RING_RADIUS := 12.0
const NUMBER_FONT_SIZE := 14
const CAPTION_FONT_SIZE := 14
const BUTTON_MARGIN := Vector2(12, 64)
## One colour per step, repeating, so neighbouring hand-outs read apart.
const STEP_COLOURS: Array[Color] = [
	Color(1.0, 0.85, 0.2), Color(0.35, 0.85, 1.0), Color(1.0, 0.45, 0.75),
	Color(0.55, 1.0, 0.45), Color(1.0, 0.6, 0.25), Color(0.75, 0.6, 1.0),
]

## The hand-outs, as MazeStageData.solution has them.
var steps: Array[Dictionary] = []
## Where the solution comes from (a run's seed and stage), shown with it.
var caption := ""

var _button: Button
var _caption_label: Label


func _ready() -> void:
	z_index = RenderingServer.CANVAS_ITEM_Z_MAX
	visible = false
	_build_controls()


func _build_controls() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 50
	add_child(layer)
	_button = UiStyle.make_icon_button("dev", "Mostrar a solução gravada (V)")
	_button.name = "SolutionButton"
	_button.toggle_mode = true
	_button.process_mode = Node.PROCESS_MODE_ALWAYS
	_button.position = BUTTON_MARGIN
	_button.toggled.connect(set_shown)
	layer.add_child(_button)
	_caption_label = Label.new()
	_caption_label.position = BUTTON_MARGIN + Vector2(UiStyle.SLOT_SIZE.x + 8.0, 8.0)
	_caption_label.add_theme_font_size_override("font_size", CAPTION_FONT_SIZE)
	_caption_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_caption_label.add_theme_constant_override("outline_size", 4)
	_caption_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_caption_label.visible = false
	layer.add_child(_caption_label)


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo and key.keycode == TOGGLE_KEY:
		set_shown(not visible)
		get_viewport().set_input_as_handled()


func set_shown(shown: bool) -> void:
	visible = shown
	_button.set_pressed_no_signal(shown)
	_caption_label.text = "%s · %d passos" % [caption, steps.size()] if caption != "" else "%d passos" % steps.size()
	_caption_label.visible = shown
	queue_redraw()


func _draw() -> void:
	var tile := Constants.TERRAIN_TILE_SIZE
	var font := ThemeDB.fallback_font
	for index in steps.size():
		var step := steps[index]
		var colour := STEP_COLOURS[index % STEP_COLOURS.size()]
		var floor_y := float(step.row) * tile
		var left := float(step.from_column) * tile
		var right := float(step.to_column + 1) * tile
		draw_rect(Rect2(left, floor_y - BAND_HEIGHT, right - left, BAND_HEIGHT), Color(colour, 0.7))
		var centre := Vector2((left + right) / 2.0, floor_y - ICON_RISE)
		draw_circle(centre, ICON_SIZE * 0.75, ICON_BACKDROP)
		draw_arc(centre, ICON_SIZE * 0.75, 0.0, TAU, 24, colour, 2.0)
		var texture := UiStyle.icon(str(step.tool))
		if texture != null:
			draw_texture_rect(texture, Rect2(centre - Vector2.ONE * ICON_SIZE / 2.0, Vector2.ONE * ICON_SIZE), false)
		draw_line(centre + Vector2(0, ICON_SIZE * 0.75), Vector2(centre.x, floor_y - BAND_HEIGHT), Color(colour, 0.7), 2.0)
		draw_string(font, centre + Vector2(-ICON_SIZE, -ICON_SIZE * 0.6), str(index + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, NUMBER_FONT_SIZE, colour)
		var direction := int(step.get("direction", 0))
		if direction != 0:
			_draw_arrow(centre + Vector2(direction * (ICON_SIZE * 0.75 + ARROW_SIZE + 2.0), 0), direction, colour)
		for cell in step.get("collect_first", []):
			var spot := MazeStageData.surface_point(cell) + Vector2.UP * RING_RADIUS
			draw_arc(spot, RING_RADIUS, 0.0, TAU, 20, colour, 2.0)


func _draw_arrow(tip_base: Vector2, direction: int, colour: Color) -> void:
	var tip := tip_base + Vector2(direction * ARROW_SIZE, 0)
	draw_colored_polygon(PackedVector2Array([
		tip,
		tip_base + Vector2(0, -ARROW_SIZE),
		tip_base + Vector2(0, ARROW_SIZE),
	]), colour)
