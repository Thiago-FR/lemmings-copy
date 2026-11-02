class_name RoguelikeDevScreen
extends RoguelikeOverlayScreen
## Developer tools for testing a run (shown when the developer mode is on
## in the settings). On the left, the run as it stands (character, stage,
## troop, tools, relics, rescues, coins, vault), refreshed after every
## action; on the right, one section per kind of change, each with icons:
##   - the run's character (any of them, locked or not): the whole troop
##     becomes that character, since a run is played with one;
##   - the troop, tool charges, rescues, coins and the vault, by the amount
##     in the Quantity field, added or removed (the Add / Remove switch);
##   - the stage to go to, and generated or hand-made stages;
##   - relics: each one, lit once owned (pressing an owned one removes it).
## Actions stay on this screen, so several can be stacked before going on.

signal stage_chosen(stage_index: int)
signal reward_screen_requested
signal closed

const SECTION_FONT_SIZE := 16
const SECTION_COLOUR := Color(1.0, 0.86, 0.45)
const PORTRAIT_SIZE := Vector2(64, 64)
const STATE_WIDTH := 260.0
const OWNED_TINT := Color(1, 1, 1)
const NOT_OWNED_TINT := Color(0.45, 0.45, 0.45)
const MAX_AMOUNT := 999

var _state: RoguelikeRunState
var _profile: RoguelikeProfile
var _state_panel: VBoxContainer
var _character_buttons: Dictionary = {}
var _relic_buttons: Dictionary = {}
var _source_buttons: Dictionary = {}
var _amount_field: SpinBox
var _removing := false


## profile: the coin vault, for the vault button (optional).
func _init(state: RoguelikeRunState, profile: RoguelikeProfile = null) -> void:
	super()
	_state = state
	_profile = profile
	add_title("Modo desenvolvedor")
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 24)
	content.add_child(columns)

	_state_panel = VBoxContainer.new()
	_state_panel.custom_minimum_size.x = STATE_WIDTH
	_state_panel.add_theme_constant_override("separation", 6)
	columns.add_child(_state_panel)
	columns.add_child(VSeparator.new())

	var actions := VBoxContainer.new()
	actions.add_theme_constant_override("separation", 6)
	columns.add_child(actions)
	_build_amount_section(actions)
	_build_character_section(actions)
	_build_troop_section(actions)
	_build_stage_section(actions)
	_build_tool_section(actions)
	_build_relic_section(actions)
	_build_item_section(actions)

	add_buttons([
		["Compêndio", _open_compendium],
		["Ver tela de recompensa", reward_screen_requested.emit],
		["Voltar", closed.emit],
	])
	_refresh()


# --- Sections ---------------------------------------------------------------

func _build_character_section(parent: VBoxContainer) -> void:
	_add_section_title(parent, "Personagem da run (troca a tropa toda)")
	var row := _add_row(parent)
	for character in RoguelikeCharacters.ALL:
		var button := _make_texture_button(RoguelikeCharacters.get_portrait(character), RoguelikeCharacters.get_display_name(character), PORTRAIT_SIZE)
		button.name = "Character_%s" % character
		button.toggle_mode = true
		button.pressed.connect(_set_character.bind(character))
		row.add_child(button)
		_character_buttons[character] = button


## How much each of the buttons below adds or removes.
func _build_amount_section(parent: VBoxContainer) -> void:
	var row := _add_row(parent)
	var group := ButtonGroup.new()
	for entry in [["+ Adicionar", "AddMode", false], ["− Remover", "RemoveMode", true]]:
		var button := _make_text_button(entry[0], entry[1], func() -> void: _removing = entry[2])
		button.toggle_mode = true
		button.button_group = group
		button.button_pressed = not entry[2]
		row.add_child(button)
	var label := Label.new()
	label.text = "Quantidade"
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(label)
	_amount_field = SpinBox.new()
	_amount_field.name = "Amount"
	_amount_field.min_value = 1
	_amount_field.max_value = MAX_AMOUNT
	_amount_field.value = 1
	row.add_child(_amount_field)


## The amount to apply: the field's value, negative while removing.
func _amount() -> int:
	var amount := int(_amount_field.value)
	return -amount if _removing else amount


func _build_troop_section(parent: VBoxContainer) -> void:
	_add_section_title(parent, "Tropa")
	var row := _add_row(parent)
	var troop := UiStyle.make_icon_button("hud_troop", "Bonecos do personagem da run")
	troop.name = "Troop"
	troop.pressed.connect(_change_troop)
	row.add_child(troop)


func _build_stage_section(parent: VBoxContainer) -> void:
	_add_section_title(parent, "Fase")
	var row := _add_row(parent)
	for index in RoguelikeRunState.STAGE_COUNT:
		row.add_child(_make_text_button("Fase %d" % (index + 1), "Stage_%d" % (index + 1), stage_chosen.emit.bind(index)))
	row.add_child(VSeparator.new())
	# Which stages the run plays: generated from the run's seed, or the five
	# hand-made labyrinths. Kept for the next runs of the session.
	var group := ButtonGroup.new()
	for entry in [["Procedurais", false], ["Prontas", true]]:
		var button := _make_text_button(entry[0], entry[0], _choose_stage_source.bind(entry[1]))
		button.toggle_mode = true
		button.button_group = group
		row.add_child(button)
		_source_buttons[entry[1]] = button


func _build_tool_section(parent: VBoxContainer) -> void:
	_add_section_title(parent, "Ferramentas (cargas)")
	var row := _add_row(parent)
	for tool_id in RoguelikeCardPool.TOOL_POOL:
		var button := UiStyle.make_icon_button(tool_id, SkillManager.get_display_name(tool_id))
		button.name = "Tool_%s" % tool_id
		button.pressed.connect(_change_tool.bind(tool_id))
		row.add_child(button)


func _build_relic_section(parent: VBoxContainer) -> void:
	_add_section_title(parent, "Relíquias")
	var row := _add_row(parent)
	for relic_id in RoguelikeRelics.DEFINITIONS:
		var card := RoguelikeCard.make(RoguelikeCard.Kind.RELIC, relic_id)
		var button := _make_texture_button(load(card.get_art_path()), "%s: %s" % [card.get_title(), card.get_description()], UiStyle.SLOT_SIZE)
		button.name = "Relic_%s" % relic_id
		button.pressed.connect(_toggle_relic.bind(card))
		row.add_child(button)
		_relic_buttons[relic_id] = button


func _build_item_section(parent: VBoxContainer) -> void:
	_add_section_title(parent, "Itens")
	var row := _add_row(parent)
	var rescue := UiStyle.make_icon_button("hud_rescue", "Penas da fênix")
	rescue.name = "Rescues"
	rescue.pressed.connect(func() -> void:
		_state.revive_tokens = maxi(_state.revive_tokens + _amount(), 0)
		_refresh())
	row.add_child(rescue)
	var coins := UiStyle.make_icon_button("hud_coin", "Moedas da run (para a loja)")
	coins.name = "Coins"
	coins.pressed.connect(func() -> void:
		_state.coins = maxi(_state.coins + _amount(), 0)
		_refresh())
	row.add_child(coins)
	if _profile != null:
		var vault := UiStyle.make_icon_button("hud_coin", "Cofre (moedas entre as runs, para liberar personagens)")
		vault.name = "Vault"
		vault.modulate = Color(1.0, 0.8, 0.5)
		vault.pressed.connect(func() -> void:
			_profile.vault_coins = maxi(_profile.vault_coins + _amount(), 0)
			_profile.save()
			_refresh())
		row.add_child(vault)


# --- Actions ----------------------------------------------------------------

## The run is played with one character: every lemming of the troop, the
## recruits to come and the recruit cards switch to it.
func _set_character(character: StringName) -> void:
	_state.character_id = character
	for index in _state.troop.size():
		_state.troop[index] = character
	_state.unlocked_characters.assign([character])
	_refresh()


## Lemmings of the run's character in or out; never below one, since a
## run with no troop is over.
func _change_troop() -> void:
	var amount := _amount()
	for _step in absi(amount):
		if amount > 0:
			_state.recruit(_state.character_id)
		elif _state.troop.size() > 1:
			_state.troop.pop_back()
	_refresh()


## Charges of a tool in or out (a new slot if it was not carried yet).
func _change_tool(tool_id: String) -> void:
	var amount := _amount()
	if amount > 0:
		_state.inventory.add_charges(tool_id, amount)
	else:
		for _step in -amount:
			if not _state.inventory.spend(tool_id):
				break
	_refresh()


## An owned relic is taken away; any other is given.
func _toggle_relic(card: RoguelikeCard) -> void:
	if _state.relics.has(StringName(card.subject)):
		_state.relics.erase(StringName(card.subject))
		_refresh()
		return
	_apply(card)


func _apply(card: RoguelikeCard) -> void:
	card.apply(_state)
	_refresh()


func _choose_stage_source(handmade: bool) -> void:
	_state.set_handmade_stages(handmade)
	_refresh()


## Every entry visible: the developer reads them all.
func _open_compendium() -> void:
	var compendium := RoguelikeCompendiumScreen.new()
	compendium.name = "Compendium"
	compendium.layer = layer + 1
	compendium.closed.connect(compendium.queue_free)
	add_child(compendium)


# --- The run's state --------------------------------------------------------

func _refresh() -> void:
	for character in _character_buttons:
		(_character_buttons[character] as Button).set_pressed_no_signal(character == _state.character_id)
	for relic_id in _relic_buttons:
		(_relic_buttons[relic_id] as Button).self_modulate = OWNED_TINT if _state.relics.has(relic_id) else NOT_OWNED_TINT
	(_source_buttons[_state.use_handmade_stages] as Button).set_pressed_no_signal(true)
	_rebuild_state_panel()


func _rebuild_state_panel() -> void:
	for child in _state_panel.get_children():
		_state_panel.remove_child(child)
		child.queue_free()
	_add_section_title(_state_panel, "Estado da run")
	var portrait := TextureRect.new()
	portrait.texture = RoguelikeCharacters.get_portrait(_state.character_id)
	portrait.custom_minimum_size = PORTRAIT_SIZE
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_state_panel.add_child(portrait)
	_add_state_line("hud_troop", "%s x%d" % [RoguelikeCharacters.get_display_name(_state.character_id), _state.troop.size()])
	_add_state_line("give_up", "Fase %d (%s)" % [_state.stage_index + 1, "pronta" if _state.use_handmade_stages else "procedural"])
	var tools: Array[String] = []
	for tool_id in _state.inventory.get_tool_ids():
		tools.append("%s x%d" % [SkillManager.get_display_name(tool_id), _state.inventory.get_charges(tool_id)])
	_add_state_line("digger", ", ".join(tools) if not tools.is_empty() else "sem ferramentas")
	var relics: Array[String] = []
	for relic_id in _state.relics:
		relics.append(RoguelikeRelics.get_title(relic_id))
	_add_state_line("editor_counts", ", ".join(relics) if not relics.is_empty() else "sem relíquias")
	_add_state_line("hud_rescue", "%d penas da fênix" % _state.revive_tokens)
	_add_state_line("hud_coin", "%d moedas" % _state.coins + ("   cofre: %d" % _profile.vault_coins if _profile != null else ""))


func _add_state_line(icon_id: String, text: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	_state_panel.add_child(row)
	var icon := TextureRect.new()
	icon.texture = UiStyle.icon(icon_id)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	row.add_child(icon)
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = STATE_WIDTH - 40.0
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(label)


# --- Building blocks --------------------------------------------------------

func _add_section_title(parent: VBoxContainer, text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", SECTION_FONT_SIZE)
	label.add_theme_color_override("font_color", SECTION_COLOUR)
	parent.add_child(label)


func _add_row(parent: VBoxContainer) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	parent.add_child(row)
	return row


func _make_text_button(text: String, node_name: String, action: Callable) -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(action)
	return button


## A slot-styled button showing a picture (a portrait, a relic's art).
func _make_texture_button(texture: Texture2D, tooltip: String, size: Vector2) -> Button:
	var button := Button.new()
	button.focus_mode = Control.FOCUS_NONE
	button.tooltip_text = tooltip
	button.icon = texture
	button.expand_icon = true
	button.custom_minimum_size = size + Vector2(8, 8)
	UiStyle.apply_slot_style(button)
	return button
