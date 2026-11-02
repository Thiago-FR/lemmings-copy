class_name UiStyle
extends RefCounted
## The game's interface look in one place: the wooden panel behind bars, the
## item slots (normal, hover, selected, disabled) and the 32x32 icon of each
## tool and editor piece, all drawn by tools/build_ui_art.py. Bars ask here
## instead of loading files themselves, so restyling is one file.
##
## The art is pixel art meant to be shown at whole multiples, so every
## control styled here draws its textures with nearest filtering (set on the
## container, inherited by its children).

const UI_DIR := "res://assets/sprites/ui/"
const ICON_PATH := UI_DIR + "icons/%s.png"
## 9-slice margins of the art (see docs/art_pipeline.md, "Interface").
const PANEL_MARGIN := 8
const SLOT_MARGIN := 4
## A 32px icon in a slot with 4px borders.
const SLOT_SIZE := Vector2(40, 40)
const COUNT_FONT_SIZE := 11
const COUNT_COLOUR := Color(1, 1, 1)
const COUNT_OUTLINE_COLOUR := Color(0, 0, 0)
const COUNT_OUTLINE_SIZE := 4


## The wooden frame for a bar or panel.
static func panel_style() -> StyleBoxTexture:
	return _nine_slice("panel.png", PANEL_MARGIN, PANEL_MARGIN)


## Styles a button as an item slot: wood when idle, lighter on hover, a gold
## border when selected (pressed), grey when disabled.
static func apply_slot_style(button: BaseButton) -> void:
	var normal := _nine_slice("slot.png", SLOT_MARGIN, SLOT_MARGIN)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	button.add_theme_stylebox_override("hover", _nine_slice("slot_hover.png", SLOT_MARGIN, SLOT_MARGIN))
	button.add_theme_stylebox_override("pressed", _nine_slice("slot_selected.png", SLOT_MARGIN, SLOT_MARGIN))
	button.add_theme_stylebox_override("hover_pressed", _nine_slice("slot_selected.png", SLOT_MARGIN, SLOT_MARGIN))
	button.add_theme_stylebox_override("disabled", _nine_slice("slot_disabled.png", SLOT_MARGIN, SLOT_MARGIN))
	button.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


## The icon for a tool id ("digger") or editor piece ("editor_earth"), or
## null if there is none, in which case callers fall back to text.
static func icon(icon_id: String) -> Texture2D:
	var path := ICON_PATH % icon_id
	return load(path) if ResourceLoader.exists(path) else null


## A slot button showing an icon, with the name as its tooltip. Falls back
## to the name as text when there is no icon yet.
static func make_icon_button(icon_id: String, tooltip: String) -> Button:
	var button := Button.new()
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = SLOT_SIZE
	button.tooltip_text = tooltip
	var texture := icon(icon_id)
	if texture != null:
		button.icon = texture
		button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	else:
		button.text = tooltip
	apply_slot_style(button)
	return button


## A small number in the slot's bottom-right corner (charges left, a count).
static func add_count_label(button: Control) -> Label:
	var label := Label.new()
	label.name = "Count"
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", COUNT_FONT_SIZE)
	label.add_theme_color_override("font_color", COUNT_COLOUR)
	label.add_theme_color_override("font_outline_color", COUNT_OUTLINE_COLOUR)
	label.add_theme_constant_override("outline_size", COUNT_OUTLINE_SIZE)
	label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	label.offset_right = -2
	label.offset_bottom = 1
	button.add_child(label)
	return label


static func _nine_slice(file_name: String, margin: int, content_margin: int) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = load(UI_DIR + file_name)
	style.texture_margin_left = margin
	style.texture_margin_right = margin
	style.texture_margin_top = margin
	style.texture_margin_bottom = margin
	style.content_margin_left = content_margin
	style.content_margin_right = content_margin
	style.content_margin_top = content_margin
	style.content_margin_bottom = content_margin
	return style
