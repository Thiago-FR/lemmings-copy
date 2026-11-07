class_name UiStyle
extends RefCounted
## The game's interface look in one place: the wooden panel behind bars, the
## item slots (normal, hover, selected, disabled), the 32x32 icon of each
## tool and editor piece, and the theme every control uses (build_theme),
## all drawn by tools/build_ui_art.py. Bars ask here
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
## Theme (build_theme): the wooden button's 9-slice margin and the room
## around its text, the slider groove's margin.
const BUTTON_MARGIN := 6
const BUTTON_CONTENT_MARGIN := 10
const SLIDER_MARGIN := 4
const FONT_SIZE := 16
const TEXT_BUTTON_MIN_SIZE := Vector2(120, 36)
const TEXT_COLOUR := Color(0.96, 0.92, 0.82)
const TEXT_HOVER_COLOUR := Color(1.0, 0.95, 0.7)
const TEXT_DISABLED_COLOUR := Color(0.6, 0.58, 0.55)
const TEXT_OUTLINE_COLOUR := Color(0.1, 0.06, 0.04)
const TEXT_OUTLINE_SIZE := 3
## Theme type variation for a screen's main action (green button).
const PRIMARY_BUTTON := &"PrimaryButton"


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


## The look of every control in the game, set once on the window
## (GameManager): wooden buttons, the wooden panel, check boxes, sliders,
## number fields and tooltips, so a screen built in code gets it without
## styling each control. A screen's main action uses the green
## PRIMARY_BUTTON variation (button.theme_type_variation).
static func build_theme() -> Theme:
	var theme := Theme.new()
	theme.default_font_size = FONT_SIZE
	_add_button_styles(theme, &"Button", "button")
	theme.set_type_variation(PRIMARY_BUTTON, &"Button")
	_add_button_styles(theme, PRIMARY_BUTTON, "button_primary")
	theme.set_stylebox("disabled", PRIMARY_BUTTON, _nine_slice("button_disabled.png", BUTTON_MARGIN, BUTTON_CONTENT_MARGIN))
	for type in [&"Button", PRIMARY_BUTTON]:
		theme.set_color("font_color", type, TEXT_COLOUR)
		theme.set_color("font_hover_color", type, TEXT_HOVER_COLOUR)
		theme.set_color("font_pressed_color", type, TEXT_COLOUR)
		theme.set_color("font_hover_pressed_color", type, TEXT_HOVER_COLOUR)
		theme.set_color("font_disabled_color", type, TEXT_DISABLED_COLOUR)
		theme.set_color("font_outline_color", type, TEXT_OUTLINE_COLOUR)
		theme.set_constant("outline_size", type, TEXT_OUTLINE_SIZE)
		theme.set_constant("h_separation", type, 6)

	theme.set_stylebox("panel", &"PanelContainer", panel_style())
	theme.set_stylebox("panel", &"TooltipPanel", panel_style())
	theme.set_color("font_color", &"TooltipLabel", TEXT_COLOUR)
	theme.set_color("font_color", &"Label", TEXT_COLOUR)
	theme.set_color("font_outline_color", &"Label", TEXT_OUTLINE_COLOUR)

	for type in [&"CheckBox", &"CheckButton"]:
		theme.set_icon("checked", type, load(UI_DIR + "check_on.png"))
		theme.set_icon("unchecked", type, load(UI_DIR + "check_off.png"))
		for state in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
			theme.set_stylebox(state, type, StyleBoxEmpty.new())
		theme.set_color("font_color", type, TEXT_COLOUR)
		theme.set_color("font_hover_color", type, TEXT_HOVER_COLOUR)
		theme.set_color("font_pressed_color", type, TEXT_COLOUR)
		theme.set_color("font_hover_pressed_color", type, TEXT_HOVER_COLOUR)
		theme.set_constant("h_separation", type, 8)

	theme.set_stylebox("slider", &"HSlider", _nine_slice("slider_track.png", SLIDER_MARGIN, SLIDER_MARGIN))
	theme.set_stylebox("grabber_area", &"HSlider", _nine_slice("slider_fill.png", SLIDER_MARGIN, SLIDER_MARGIN))
	theme.set_stylebox("grabber_area_highlight", &"HSlider", _nine_slice("slider_fill.png", SLIDER_MARGIN, SLIDER_MARGIN))
	theme.set_icon("grabber", &"HSlider", load(UI_DIR + "slider_knob.png"))
	theme.set_icon("grabber_highlight", &"HSlider", load(UI_DIR + "slider_knob_hover.png"))

	var field := _nine_slice("slot.png", SLOT_MARGIN, SLOT_MARGIN + 2)
	theme.set_stylebox("normal", &"LineEdit", field)
	theme.set_stylebox("focus", &"LineEdit", _nine_slice("slot_selected.png", SLOT_MARGIN, SLOT_MARGIN + 2))
	theme.set_color("font_color", &"LineEdit", TEXT_COLOUR)
	return theme


static func _add_button_styles(theme: Theme, type: StringName, prefix: String) -> void:
	theme.set_stylebox("normal", type, _nine_slice(prefix + ".png", BUTTON_MARGIN, BUTTON_CONTENT_MARGIN))
	theme.set_stylebox("hover", type, _nine_slice(prefix + "_hover.png", BUTTON_MARGIN, BUTTON_CONTENT_MARGIN))
	theme.set_stylebox("pressed", type, _nine_slice(prefix + "_pressed.png", BUTTON_MARGIN, BUTTON_CONTENT_MARGIN))
	theme.set_stylebox("hover_pressed", type, _nine_slice(prefix + "_pressed.png", BUTTON_MARGIN, BUTTON_CONTENT_MARGIN))
	theme.set_stylebox("disabled", type, _nine_slice("button_disabled.png", BUTTON_MARGIN, BUTTON_CONTENT_MARGIN))
	theme.set_stylebox("focus", type, StyleBoxEmpty.new())


## A button of text only (or icon and text) in the game's look, with the
## minimum size that keeps a row of them even.
static func make_text_button(text: String, primary: bool = false) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = TEXT_BUTTON_MIN_SIZE
	button.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if primary:
		button.theme_type_variation = PRIMARY_BUTTON
	return button


## The menus' look (the main menu, a game mode's menu): a big outlined
## title, wooden panels and wide buttons with an icon and a word.
const MENU_TITLE_FONT_SIZE := 56
const MENU_TITLE_OUTLINE_SIZE := 10
const MENU_TITLE_COLOUR := Color(1.0, 0.9, 0.55)
const MENU_BUTTON_SIZE := Vector2(300, 52)
const MENU_FONT_SIZE := 20


static func make_menu_title(text: String) -> Label:
	var title := Label.new()
	title.text = text
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", MENU_TITLE_FONT_SIZE)
	title.add_theme_color_override("font_color", MENU_TITLE_COLOUR)
	title.add_theme_constant_override("outline_size", MENU_TITLE_OUTLINE_SIZE)
	return title


## A wooden panel added to parent, holding a column of its own (returned).
static func add_menu_panel(parent: Node) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	panel.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	parent.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 14)
	panel.add_child(margin)
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 10)
	margin.add_child(inner)
	return inner


static func make_menu_button(text: String, icon_id: String, primary: bool = false) -> Button:
	var button := make_text_button(text, primary)
	button.icon = icon(icon_id)
	button.custom_minimum_size = MENU_BUTTON_SIZE
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.add_theme_font_size_override("font_size", MENU_FONT_SIZE)
	return button


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
