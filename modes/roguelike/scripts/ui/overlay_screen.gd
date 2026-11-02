class_name RoguelikeOverlayScreen
extends CanvasLayer
## A full-screen panel between stages (stage intro, rewards, run over,
## victory): a dark backdrop with a wooden panel in the middle that screens
## fill with a title, text and buttons. Runs while the tree is paused.

const BACKDROP_COLOUR := Color(0.05, 0.06, 0.1, 0.92)
const TITLE_FONT_SIZE := 28
const PANEL_MIN_WIDTH := 520.0
const CONTENT_SEPARATION := 14

var content: VBoxContainer


func _init() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	var backdrop := ColorRect.new()
	backdrop.color = BACKDROP_COLOUR
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)
	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(centre)
	var panel := PanelContainer.new()
	panel.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	panel.custom_minimum_size.x = PANEL_MIN_WIDTH
	centre.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	panel.add_child(margin)
	content = VBoxContainer.new()
	content.add_theme_constant_override("separation", CONTENT_SEPARATION)
	margin.add_child(content)


func add_title(text: String) -> Label:
	var label := add_text(text)
	label.add_theme_font_size_override("font_size", TITLE_FONT_SIZE)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label


func add_text(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = PANEL_MIN_WIDTH - 40.0
	content.add_child(label)
	return label


## A row of buttons, centred. Each entry: [text, Callable], or
## [text, Callable, true] for the screen's main action (green).
func add_buttons(entries: Array) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	for entry in entries:
		var button := UiStyle.make_text_button(entry[0], entry.size() > 2 and entry[2])
		button.custom_minimum_size = Vector2(140, 36)
		button.pressed.connect(entry[1])
		row.add_child(button)
	content.add_child(row)
	return row


## A row of icon buttons, centred (Menu, Dev...). Each entry:
## [icon id, tooltip, Callable, node name].
func add_icon_buttons(entries: Array) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 6)
	for entry in entries:
		var button := UiStyle.make_icon_button(entry[0], entry[1])
		button.name = entry[3]
		button.pressed.connect(entry[2])
		row.add_child(button)
	content.add_child(row)
	return row


## One line per troop member: name and ability, in the character's colour.
func add_troop_list(troop: Array[StringName]) -> void:
	for character in troop:
		var label := add_text("• %s: %s" % [RoguelikeCharacters.get_display_name(character), RoguelikeCharacters.get_ability(character)])
		label.add_theme_color_override("font_color", RoguelikeCharacters.get_colour(character).lightened(0.3))
