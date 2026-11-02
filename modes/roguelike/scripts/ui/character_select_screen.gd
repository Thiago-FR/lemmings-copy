class_name RoguelikeCharacterSelectScreen
extends RoguelikeOverlayScreen
## The first screen of a run: every character side by side, each with its
## portrait, name and what it does. Unlocked ones have a Play button; locked
## ones show only their silhouette (the portrait in black), their price and
## a Buy button paid from the coin vault (RoguelikeProfile), so the player
## always sees what there is to unlock and what it would bring. The book
## icon opens the compendium of what the player has discovered.

signal character_chosen(character_id: StringName)
signal developer_requested

const CARD_WIDTH := 190.0
const PORTRAIT_SIZE := Vector2(128, 128)
const CARD_SEPARATION := 12
const NAME_FONT_SIZE := 20
const SILHOUETTE_COLOUR := Color(0, 0, 0, 1)
const LOCKED_TEXT_COLOUR := Color(0.7, 0.66, 0.6)
## Play and Buy: the same size, the full width of the card.
const ACTION_BUTTON_SIZE := Vector2(0, 44)
const ACTION_FONT_SIZE := 18

var _profile: RoguelikeProfile
var _vault_label: Label
var _cards: HBoxContainer


func _init(profile: RoguelikeProfile) -> void:
	super()
	_profile = profile
	add_title("Escolha seu personagem")
	_vault_label = _add_vault_row()
	_cards = HBoxContainer.new()
	_cards.add_theme_constant_override("separation", CARD_SEPARATION)
	_cards.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_child(_cards)
	var buttons: Array = [
		["editor_menu", "Menu", GameManager.go_to_main_menu, "Menu"],
		["compendium", "Compêndio", open_compendium, "Compendium"],
		["trophy", "Ranking", _open_ranking, "Ranking"],
	]
	if GameManager.developer_mode:
		buttons.append(["dev", "Modo desenvolvedor", developer_requested.emit, "Dev"])
	add_icon_buttons(buttons)
	_rebuild()


## The player's compendium, over this screen: only what the profile has
## discovered (the developer screen's shows everything).
func open_compendium() -> void:
	var compendium := RoguelikeCompendiumScreen.new(_profile.is_discovered)
	compendium.name = "CompendiumScreen"
	compendium.layer = layer + 1
	compendium.closed.connect(compendium.queue_free)
	add_child(compendium)


func _add_vault_row() -> Label:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.tooltip_text = "Cofre: as moedas que sobram no fim de cada run ficam guardadas aqui para liberar personagens."
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	content.add_child(row)
	var icon := TextureRect.new()
	icon.texture = UiStyle.icon("hud_coin")
	icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon)
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(label)
	return label


func _rebuild() -> void:
	_vault_label.text = str(_profile.vault_coins)
	# Out of the tree at once, or the new cards could not take their names.
	for child in _cards.get_children():
		_cards.remove_child(child)
		child.queue_free()
	for character in RoguelikeCharacters.ALL:
		_cards.add_child(_make_card(character))


func _make_card(character: StringName) -> PanelContainer:
	var unlocked := _profile.is_unlocked(character)
	var card := PanelContainer.new()
	card.name = "Card_%s" % character
	card.custom_minimum_size.x = CARD_WIDTH
	card.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	card.add_child(column)

	var portrait := TextureRect.new()
	portrait.texture = RoguelikeCharacters.get_portrait(character)
	portrait.custom_minimum_size = PORTRAIT_SIZE
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	if not unlocked:
		portrait.self_modulate = SILHOUETTE_COLOUR
	column.add_child(portrait)

	var title := Label.new()
	title.text = RoguelikeCharacters.get_display_name(character)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", NAME_FONT_SIZE)
	title.add_theme_color_override("font_color", RoguelikeCharacters.get_colour(character).lightened(0.3) if unlocked else LOCKED_TEXT_COLOUR)
	column.add_child(title)

	column.add_child(_make_ability_badge(character, unlocked))
	var description := Label.new()
	# The passive bonus only (the ability is the badge above); empty for
	# a character without one, keeping the cards the same height.
	description.text = RoguelikeCharacters.get_short_passive(character)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	description.custom_minimum_size.x = CARD_WIDTH - 24.0
	description.size_flags_vertical = Control.SIZE_EXPAND_FILL
	description.tooltip_text = RoguelikeCharacters.get_ability(character)
	description.mouse_filter = Control.MOUSE_FILTER_STOP
	if not unlocked:
		description.add_theme_color_override("font_color", LOCKED_TEXT_COLOUR)
	column.add_child(description)

	column.add_child(_make_play_button(character) if unlocked else _make_buy_button(character))
	return card


## The character's ability as its slot icon and name, as it shows in the
## tool bar; what it does is the tooltip (few words on screen).
func _make_ability_badge(character: StringName, unlocked: bool) -> HBoxContainer:
	var ability := RoguelikeCharacters.get_special(character)
	var row := HBoxContainer.new()
	row.name = "Ability"
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	row.tooltip_text = "%s: %s" % [RoguelikeAbilities.get_display_name(ability), RoguelikeAbilities.get_description(ability)]
	var icon := TextureRect.new()
	icon.texture = UiStyle.icon(RoguelikeAbilities.get_icon_id(ability))
	icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not unlocked:
		icon.self_modulate = SILHOUETTE_COLOUR
	row.add_child(icon)
	var label := Label.new()
	label.text = RoguelikeAbilities.get_display_name(ability)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_color_override("font_color", RoguelikeCharacters.get_colour(character).lightened(0.4) if unlocked else LOCKED_TEXT_COLOUR)
	row.add_child(label)
	return row


func _make_play_button(character: StringName) -> Button:
	var button := UiStyle.make_text_button("Jogar", true)
	button.name = "Play"
	button.custom_minimum_size = ACTION_BUTTON_SIZE
	button.add_theme_font_size_override("font_size", ACTION_FONT_SIZE)
	button.pressed.connect(character_chosen.emit.bind(character))
	return button


func _make_buy_button(character: StringName) -> Button:
	var price := RoguelikeCharacters.get_price(character)
	var button := UiStyle.make_text_button(str(price))
	button.name = "Buy"
	button.icon = UiStyle.icon("hud_coin")
	button.custom_minimum_size = ACTION_BUTTON_SIZE
	button.add_theme_font_size_override("font_size", ACTION_FONT_SIZE)
	button.disabled = not _profile.can_buy(character)
	button.tooltip_text = "Comprar" if not button.disabled else "Faltam %d moedas no cofre" % (price - _profile.vault_coins)
	button.pressed.connect(func() -> void:
		if _profile.buy(character):
			AudioManager.play_sound(&"select_tool")
			_rebuild())
	return button


func _open_ranking() -> void:
	var ranking := RoguelikeRankingScreen.new(_profile)
	ranking.closed.connect(ranking.queue_free)
	add_child(ranking)
