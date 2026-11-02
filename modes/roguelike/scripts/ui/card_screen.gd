class_name RoguelikeCardScreen
extends RoguelikeOverlayScreen
## "Choose 1 of 3": the reward cards offered after a stage. Each is drawn
## from the card art (tools/build_card_art.py): a frame per family (tool,
## recruit, relic, rescue) that lights up on hover, the card's illustration
## in its window, the title on the banner and the description on the lower
## panel. Picking one emits card_chosen; the run applies it.

signal card_chosen(card: RoguelikeCard)

const CARDS_DIR := "res://assets/sprites/ui/cards/"
## The art is 120x168 and drawn at twice that, with nearest filtering.
const ART_SCALE := 2
const CARD_ART_SIZE := Vector2(120, 168)
## Areas inside the card art, at 1x (docs/art_pipeline.md, "Cartas").
const TITLE_RECT := Rect2(12, 11, 96, 15)
const WINDOW_RECT := Rect2(28, 34, 64, 64)
const TEXT_RECT := Rect2(12, 108, 96, 50)
const TEXT_INSET := 3.0
## Lines that fit the text panel at TEXT_FONT_SIZE; longer text is cut
## rather than spilling out of the card (prints/bug10.png). The full text
## is the card's tooltip.
const TEXT_MAX_LINES := 5
const CARD_TITLE_FONT_SIZE := 15
const TEXT_FONT_SIZE := 12
const TEXT_COLOUR := Color(0.96, 0.91, 0.80)
const OUTLINE_COLOUR := Color(0.08, 0.05, 0.03)


func _init(cards: Array[RoguelikeCard], header: String) -> void:
	super._init()
	add_title("Escolha uma recompensa")
	add_text(header).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 18)
	content.add_child(row)
	for index in cards.size():
		var card_button := _make_card(cards[index])
		card_button.name = "Card%d" % (index + 1)
		row.add_child(card_button)


func _make_card(card: RoguelikeCard) -> TextureButton:
	var family := card.get_frame_family()
	var button := TextureButton.new()
	button.texture_normal = load(CARDS_DIR + "card_%s.png" % family)
	button.texture_hover = load(CARDS_DIR + "card_%s_hover.png" % family)
	button.texture_pressed = button.texture_hover
	button.ignore_texture_size = true
	button.stretch_mode = TextureButton.STRETCH_SCALE
	button.custom_minimum_size = CARD_ART_SIZE * ART_SCALE
	button.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	button.focus_mode = Control.FOCUS_NONE
	button.tooltip_text = card.get_description()
	button.pressed.connect(func() -> void: card_chosen.emit(card))

	var art := TextureRect.new()
	art.texture = load(card.get_art_path())
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_place(art, WINDOW_RECT)
	button.add_child(art)

	var title := _make_label(card.get_title(), CARD_TITLE_FONT_SIZE)
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.clip_text = true
	_place(title, TITLE_RECT)
	button.add_child(title)

	var description := _make_label(card.get_short_description(), TEXT_FONT_SIZE)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.max_lines_visible = TEXT_MAX_LINES
	description.clip_text = true
	description.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_place(description, TEXT_RECT.grow(-TEXT_INSET))
	button.add_child(description)
	return button


func _make_label(text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", TEXT_COLOUR)
	label.add_theme_color_override("font_outline_color", OUTLINE_COLOUR)
	label.add_theme_constant_override("outline_size", 3)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


## Puts a child over an area of the card art, scaled like the art.
func _place(control: Control, art_rect: Rect2) -> void:
	control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	control.position = art_rect.position * ART_SCALE
	control.size = art_rect.size * ART_SCALE
