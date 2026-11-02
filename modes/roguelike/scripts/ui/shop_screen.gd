class_name RoguelikeShopScreen
extends RoguelikeOverlayScreen
## The shop between stages: the coins the saved lemmings earned buy some of
## a few offers (the same kinds of rewards as the cards: charges, a new tool,
## a rescue, a recruit, a relic), each at its card's price. Buy as many as
## the coins allow, then carry on.

signal closed

const OFFER_SIZE := 4
const ICON_SIZE := Vector2(48, 48)

var _state: RoguelikeRunState
var _coins_label: Label


func _init(state: RoguelikeRunState, offers: Array[RoguelikeCard]) -> void:
	super()
	_state = state
	add_title("Loja")
	_coins_label = add_text("")
	_coins_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	for card in offers:
		content.add_child(_make_offer(card))
	add_buttons([["Seguir para a fase", closed.emit, true]])
	_refresh()


func _make_offer(card: RoguelikeCard) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)

	var art := TextureRect.new()
	art.texture = load(card.get_art_path())
	art.custom_minimum_size = ICON_SIZE
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	row.add_child(art)

	var text := Label.new()
	text.text = "%s\n%s" % [card.get_title(), card.get_short_description()]
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.custom_minimum_size.x = 300
	row.add_child(text)

	var buy := Button.new()
	buy.name = "Buy"
	buy.text = "%d moedas" % card.get_price()
	buy.custom_minimum_size = Vector2(120, 36)
	buy.focus_mode = Control.FOCUS_NONE
	buy.set_meta("price", card.get_price())
	buy.pressed.connect(func() -> void:
		if _state.spend_coins(card.get_price()):
			card.apply(_state)
			buy.text = "Comprado"
			buy.disabled = true
			buy.set_meta("sold", true)
			_refresh())
	row.add_child(buy)
	return row


## Offers the coins cannot pay for are greyed out.
func _refresh() -> void:
	_coins_label.text = "Moedas: %d" % _state.coins
	for button in find_children("Buy", "Button", true, false):
		if not button.get_meta("sold", false):
			button.disabled = int(button.get_meta("price")) > _state.coins
