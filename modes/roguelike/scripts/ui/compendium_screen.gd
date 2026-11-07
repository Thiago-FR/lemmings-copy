class_name RoguelikeCompendiumScreen
extends RoguelikeOverlayScreen
## Everything the roguelike has: characters, their abilities, tools, the
## items found in a stage, the reward cards and the relics. Little text, as
## the user asked: a row of category icons (each with discovered/total) and
## a grid of slot tiles, each its picture and name; what it does is the
## tile's tooltip.
##
## The player opens it from the character screen, given the profile's
## is_discovered: an entry not discovered yet shows only its black
## silhouette and "???" (the user's idea: the player unlocks entries by
## finding and using things; the rules are in RoguelikeDiscovery). The
## developer screen opens it without one, showing everything.
##
## The last category is the dig-drop table (RoguelikeDigDrops): the chance a
## broken block of earth or concrete gives an item, and each item's weight
## and share. Read-only for the player; with the developer mode on, every
## value is a slider and a number field, saved at once so the next stages
## use it, and a button puts the approved table back.

signal closed

const ENTRY_ICON_SIZE := Vector2(48, 48)
const TILE_SIZE := Vector2(112, 92)
const GRID_COLUMNS := 6
const GRID_SIZE := Vector2(720, 330)
const NAME_FONT_SIZE := 13
const NAME_COLOUR := Color(1.0, 0.86, 0.45)
const UNKNOWN_NAME := "???"
const CATEGORY_BUTTON_SIZE := Vector2(84, 40)
const SILHOUETTE := Color(0, 0, 0, 1)
## [category, icon of its button] in order.
const CATEGORIES: Array = [
	["Personagens", "hud_troop"],
	["Habilidades", "ability_teleport"],
	["Ferramentas", "digger"],
	["Itens da fase", "ability_charge"],
	["Cartas", "editor_counts"],
	["Relíquias", "hud_clock"],
	["Itens ao cavar", "miner"],
]
const DIG_DROPS_CATEGORY := 6
const DIG_ROW_ICON_SIZE := Vector2(32, 32)
const CHANCE_SLIDER_WIDTH := 150.0
const WEIGHT_SLIDER_WIDTH := 330.0
const SHARE_LABEL_WIDTH := 56.0
const CHANCE_STEP := 0.5
const MAX_WEIGHT := 100.0
## [TerrainDestructible.TerrainMaterial, node name, icon, tooltip].
const DIG_MATERIALS: Array = [
	[TerrainDestructible.TerrainMaterial.EARTH, "EarthChance", "editor_earth", "Terra: chance de item"],
	[TerrainDestructible.TerrainMaterial.CONCRETE, "ConcreteChance", "editor_concrete", "Concreto: chance de item"],
]

## What a tool does, in the player's words (the core tools have only a name).
const TOOL_DESCRIPTIONS := {
	"digger": "Cava um buraco reto para baixo. Para no concreto.",
	"builder": "Monta uma escada diagonal de tábuas para subir.",
	"ladder_vertical": "Encosta numa parede e monta uma escada para cima.",
	"bridge": "Atravessa o próximo buraco com uma ponte.",
	"floater": "Paraquedas: cai de qualquer altura sem morrer. Fica para sempre.",
	"climber": "Garras: sobe qualquer parede. Fica para sempre.",
	"block": "Põe um bloco de terra na frente e dá meia-volta.",
	"dynamite": "Deixa uma dinamite: explosão pequena, quebra terra e concreto.",
	"tnt": "Deixa um TNT: explosão grande.",
	"basher": "Britadeira: cava um túnel reto na parede, até no concreto.",
	"miner": "Picareta: cava um túnel na parede de terra.",
}

## [kind, name, icon, description] of every item that can lie in a stage.
const STAGE_ITEMS: Array = [
	[ItemSpec.Kind.TOOL, "Ferramenta", "digger", "+1 carga da ferramenta (entra na barra se for nova)."],
	[ItemSpec.Kind.REVIVE, "Pena da fênix", "hud_rescue", "No fim da fase, traz de volta um boneco perdido."],
	[ItemSpec.Kind.TIME, "Ampulheta", "hud_clock", "Mais tempo na fase."],
	[ItemSpec.Kind.CHARGE_BAG, "Bolsa", "editor_counts", "+1 carga em cada ferramenta da barra."],
	[ItemSpec.Kind.COINS, "Moedas", "hud_coin", "Moedas para a loja (mais com a Ganância)."],
	[ItemSpec.Kind.ABILITY_CHARGE, "Recarga", RoguelikeAbilities.CHARGE_ICON, "+1 carga da habilidade do personagem nesta fase."],
]

## Returns whether an entry id (RoguelikeDiscovery) has been discovered;
## an empty Callable shows everything.
var _is_discovered: Callable
var _category_row: HBoxContainer
var _pages: Control
var _category_group := ButtonGroup.new()
var _dig_drops: RoguelikeDigDrops
## The dig-drop values can be changed (developer mode).
var _dig_drops_editable := false
## ItemSpec.Kind -> the Label with its share of the finds.
var _share_labels: Dictionary = {}


## dig_drops_path: where the tuned dig-drop table is kept (tests use their
## own file).
func _init(is_discovered: Callable = Callable(), dig_drops_path: String = RoguelikeDigDrops.DEFAULT_PATH) -> void:
	super()
	_is_discovered = is_discovered
	_dig_drops = RoguelikeDigDrops.load_from(dig_drops_path)
	_dig_drops_editable = GameManager.developer_mode
	add_title("Compêndio")
	_category_row = HBoxContainer.new()
	_category_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_category_row.add_theme_constant_override("separation", 6)
	content.add_child(_category_row)
	_pages = Control.new()
	_pages.custom_minimum_size = GRID_SIZE
	content.add_child(_pages)
	_build_characters()
	_build_abilities()
	_build_tools()
	_build_stage_items()
	_build_cards()
	_build_relics()
	_build_dig_drops()
	_refresh_category_counts()
	show_category(0)
	var back := UiStyle.make_text_button("Voltar", true)
	back.name = "Back"
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.pressed.connect(closed.emit)
	content.add_child(back)


func get_category_count() -> int:
	return _pages.get_child_count()


func show_category(index: int) -> void:
	for page_index in _pages.get_child_count():
		(_pages.get_child(page_index) as Control).visible = page_index == index
	for button_index in _category_row.get_child_count():
		(_category_row.get_child(button_index) as Button).set_pressed_no_signal(button_index == index)


func _build_characters() -> void:
	var list := _add_category(0)
	for character in RoguelikeCharacters.ALL:
		_add_entry(list, RoguelikeDiscovery.character(character), RoguelikeCharacters.get_portrait(character), RoguelikeCharacters.get_display_name(character), RoguelikeCharacters.get_ability(character))


## Each character's ability, with whose it is and its charges per stage.
func _build_abilities() -> void:
	var list := _add_category(1)
	for character in RoguelikeCharacters.ALL:
		var ability := RoguelikeCharacters.get_special(character)
		var charges := RoguelikeAbilities.get_base_charges(ability)
		var description := "%s · %s %d %s por fase." % [RoguelikeCharacters.get_display_name(character), RoguelikeAbilities.get_description(ability), charges, "carga" if charges == 1 else "cargas"]
		_add_entry(list, RoguelikeDiscovery.ability(ability), UiStyle.icon(RoguelikeAbilities.get_icon_id(ability)), RoguelikeAbilities.get_display_name(ability), description)


func _build_tools() -> void:
	var list := _add_category(2)
	for tool_id in RoguelikeCardPool.TOOL_POOL:
		_add_entry(list, RoguelikeDiscovery.tool(tool_id), UiStyle.icon(tool_id), SkillManager.get_display_name(tool_id), TOOL_DESCRIPTIONS.get(tool_id, ""))


func _build_stage_items() -> void:
	var list := _add_category(3)
	for item in STAGE_ITEMS:
		_add_entry(list, RoguelikeDiscovery.stage_item(item[0]), UiStyle.icon(item[2]), item[1], item[3])


func _build_cards() -> void:
	var list := _add_category(4)
	var examples: Array[RoguelikeCard] = [
		RoguelikeCard.make(RoguelikeCard.Kind.CHARGES, "digger", RoguelikeCardPool.CHARGES_AMOUNT),
		RoguelikeCard.make(RoguelikeCard.Kind.NEW_TOOL, "bridge", RoguelikeCardPool.NEW_TOOL_AMOUNT),
		RoguelikeCard.make(RoguelikeCard.Kind.RECRUIT, RoguelikeCharacters.STARTER),
		RoguelikeCard.make(RoguelikeCard.Kind.REVIVE),
	]
	var names := ["Cargas", "Ferramenta nova", "Recruta", "Pena da fênix"]
	for index in examples.size():
		var card := examples[index]
		_add_entry(list, RoguelikeDiscovery.card_kind(card.kind), load(card.get_art_path()), names[index], card.get_description())


func _build_relics() -> void:
	var list := _add_category(5)
	for relic_id in RoguelikeRelics.DEFINITIONS:
		var card := RoguelikeCard.make(RoguelikeCard.Kind.RELIC, relic_id)
		_add_entry(list, RoguelikeDiscovery.relic(relic_id), load(card.get_art_path()), RoguelikeRelics.get_title(relic_id), RoguelikeRelics.get_description(relic_id))


# --- Dig drops ------------------------------------------------------------

## A row per material (its chance) and a row per item (its weight, and the
## share that makes), each led by its icon.
func _build_dig_drops() -> void:
	_add_category_button(DIG_DROPS_CATEGORY, false)
	var page := VBoxContainer.new()
	page.name = "DigDrops"
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	page.add_theme_constant_override("separation", 8)
	_pages.add_child(page)

	var chances := HBoxContainer.new()
	chances.alignment = BoxContainer.ALIGNMENT_CENTER
	chances.add_theme_constant_override("separation", 10)
	page.add_child(chances)
	for material in DIG_MATERIALS:
		var percent := 100.0 * _dig_drops_chance(material[0])
		var spin := _add_dig_row(chances, UiStyle.icon(material[2]), material[3], material[1], percent, 100.0, CHANCE_STEP, CHANCE_SLIDER_WIDTH)
		spin.suffix = "%"
		spin.value_changed.connect(_on_chance_changed.bind(material[0]))
	page.add_child(HSeparator.new())

	for kind in RoguelikeDigDrops.KINDS:
		var item: Array = _stage_item(kind)
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 10)
		page.add_child(row)
		var known := not _is_discovered.is_valid() or bool(_is_discovered.call(RoguelikeDiscovery.stage_item(kind)))
		var spin := _add_dig_row(row, UiStyle.icon(item[2]), item[1] if known else UNKNOWN_NAME, "Weight_%s" % _kind_key(kind), float(_dig_drops.weights[kind]), MAX_WEIGHT, 1.0, WEIGHT_SLIDER_WIDTH)
		if not known:
			(row.get_child(0) as TextureRect).self_modulate = SILHOUETTE
		spin.value_changed.connect(_on_weight_changed.bind(kind))
		var share := Label.new()
		share.name = "Share_%s" % _kind_key(kind)
		share.custom_minimum_size.x = SHARE_LABEL_WIDTH
		share.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		share.add_theme_color_override("font_color", NAME_COLOUR)
		row.add_child(share)
		_share_labels[kind] = share
	_refresh_shares()

	if _dig_drops_editable:
		var restore := UiStyle.make_icon_button("editor_restart", "Voltar ao padrão")
		restore.name = "RestoreDefaults"
		restore.size_flags_horizontal = Control.SIZE_SHRINK_END
		restore.pressed.connect(restore_dig_drop_defaults)
		page.add_child(restore)


## An icon, a slider and a number field sharing one value. Returns the field.
func _add_dig_row(row: HBoxContainer, texture: Texture2D, tooltip: String, node_name: String, value: float, max_value: float, step: float, slider_width: float) -> SpinBox:
	var icon := TextureRect.new()
	icon.texture = texture
	icon.custom_minimum_size = DIG_ROW_ICON_SIZE
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.tooltip_text = tooltip
	row.add_child(icon)
	var slider := HSlider.new()
	slider.custom_minimum_size.x = slider_width
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.focus_mode = Control.FOCUS_NONE
	slider.tooltip_text = tooltip
	row.add_child(slider)
	var spin := SpinBox.new()
	spin.name = node_name
	spin.tooltip_text = tooltip
	spin.select_all_on_focus = true
	row.add_child(spin)
	for range_control: Range in [slider, spin]:
		range_control.min_value = 0.0
		range_control.max_value = max_value
		range_control.step = step
	# Sharing makes them one value: moving either moves the other.
	slider.share(spin)
	spin.set_value_no_signal(value)
	slider.editable = _dig_drops_editable
	spin.editable = _dig_drops_editable
	return spin


## Puts the approved table back, saved, and shows it.
func restore_dig_drop_defaults() -> void:
	_dig_drops.restore_defaults()
	_dig_drops.save()
	for material in DIG_MATERIALS:
		_dig_field(material[1]).set_value_no_signal(100.0 * _dig_drops_chance(material[0]))
	for kind in RoguelikeDigDrops.KINDS:
		_dig_field("Weight_%s" % _kind_key(kind)).set_value_no_signal(float(_dig_drops.weights[kind]))
	_refresh_shares()


func _on_chance_changed(percent: float, material: TerrainDestructible.TerrainMaterial) -> void:
	if material == TerrainDestructible.TerrainMaterial.CONCRETE:
		_dig_drops.concrete_chance = percent / 100.0
	else:
		_dig_drops.earth_chance = percent / 100.0
	_dig_drops.save()


func _on_weight_changed(weight: float, kind: ItemSpec.Kind) -> void:
	_dig_drops.weights[kind] = weight
	_dig_drops.save()
	_refresh_shares()


func _refresh_shares() -> void:
	for kind in _share_labels:
		(_share_labels[kind] as Label).text = "%d%%" % roundi(100.0 * _dig_drops.get_share(kind))


func _dig_drops_chance(material: TerrainDestructible.TerrainMaterial) -> float:
	return _dig_drops.concrete_chance if material == TerrainDestructible.TerrainMaterial.CONCRETE else _dig_drops.earth_chance


func _dig_field(node_name: String) -> SpinBox:
	return _pages.find_child(node_name, true, false) as SpinBox


static func _stage_item(kind: ItemSpec.Kind) -> Array:
	for item in STAGE_ITEMS:
		if item[0] == kind:
			return item
	assert(false, "No stage item for kind %d" % kind)
	return []


static func _kind_key(kind: ItemSpec.Kind) -> String:
	return String(ItemSpec.Kind.find_key(kind)).to_lower()


# --- Building blocks --------------------------------------------------------

## A category's icon button in the row; counted: with discovered/total.
func _add_category_button(index: int, counted: bool) -> void:
	var title: String = CATEGORIES[index][0]
	var button := UiStyle.make_icon_button(CATEGORIES[index][1], title)
	button.name = "Category%d" % index
	button.toggle_mode = true
	button.button_group = _category_group
	button.pressed.connect(show_category.bind(index))
	if counted:
		# Room for the icon and its discovered/total side by side.
		button.custom_minimum_size = CATEGORY_BUTTON_SIZE
		button.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
		UiStyle.add_count_label(button)
	_category_row.add_child(button)


## A category: its icon button in the row (with discovered/total) and its
## page, a scrolling grid of tiles.
func _add_category(index: int) -> GridContainer:
	_add_category_button(index, true)
	var title: String = CATEGORIES[index][0]
	var scroll := ScrollContainer.new()
	scroll.name = title
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pages.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = GRID_COLUMNS
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	scroll.add_child(grid)
	return grid


## Discovered/total on each category button.
func _refresh_category_counts() -> void:
	for index in _pages.get_child_count():
		if not _pages.get_child(index) is ScrollContainer:
			continue
		var tiles := (_pages.get_child(index) as ScrollContainer).get_child(0).get_children()
		var known := tiles.filter(func(tile: Node) -> bool: return tile.get_meta("known", true)).size()
		var count := _category_row.get_child(index).get_node("Count") as Label
		count.text = "%d/%d" % [known, tiles.size()]


## A slot tile: picture and name, what it does in the tooltip. Undiscovered:
## the picture's black silhouette, "???", no tooltip.
func _add_entry(list: GridContainer, entry_id: String, texture: Texture2D, title: String, description: String) -> void:
	var known := not _is_discovered.is_valid() or bool(_is_discovered.call(entry_id))
	var tile := Button.new()
	tile.name = entry_id
	tile.focus_mode = Control.FOCUS_NONE
	tile.custom_minimum_size = TILE_SIZE
	tile.tooltip_text = "%s
%s" % [title, description] if known else UNKNOWN_NAME
	tile.set_meta("known", known)
	UiStyle.apply_slot_style(tile)
	list.add_child(tile)
	var column := VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.add_child(column)
	var icon := TextureRect.new()
	icon.texture = texture
	icon.custom_minimum_size = ENTRY_ICON_SIZE
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not known:
		icon.self_modulate = SILHOUETTE
	column.add_child(icon)
	var name_label := Label.new()
	name_label.text = title if known else UNKNOWN_NAME
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.custom_minimum_size.x = TILE_SIZE.x - 8.0
	name_label.add_theme_font_size_override("font_size", NAME_FONT_SIZE)
	name_label.add_theme_color_override("font_color", NAME_COLOUR)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(name_label)
