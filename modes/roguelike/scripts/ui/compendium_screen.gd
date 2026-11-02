class_name RoguelikeCompendiumScreen
extends RoguelikeOverlayScreen
## Everything the roguelike has, to read what each thing does: characters,
## tools, the items found in a stage, the reward cards and the relics, one
## tab each, every entry with its picture, name and description.
##
## For now it opens from the developer screen, where everything is shown.
## Made for the player too: given an is_discovered callable, an entry not
## discovered yet shows only its black silhouette and "???" (the user's
## idea: the player unlocks entries by finding and using things).

signal closed

const ENTRY_ICON_SIZE := Vector2(48, 48)
const LIST_SIZE := Vector2(720, 380)
const NAME_FONT_SIZE := 18
const UNKNOWN_NAME := "???"
const UNKNOWN_TEXT := "Ainda não descoberto."
const SILHOUETTE := Color(0, 0, 0, 1)

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
	["item_tool", "Ferramenta", "digger", "+1 carga da ferramenta (entra na barra se for nova)."],
	["item_rescue", "Pena da fênix", "hud_rescue", "No fim da fase, traz de volta um boneco perdido."],
	["item_time", "Ampulheta", "hud_clock", "Mais tempo na fase."],
	["item_bag", "Bolsa", "editor_counts", "+1 carga em cada ferramenta da barra."],
]

## Returns whether an entry id (see _entry ids below) has been discovered;
## null shows everything.
var _is_discovered: Callable
var _tabs: TabContainer


func _init(is_discovered: Callable = Callable()) -> void:
	super()
	_is_discovered = is_discovered
	add_title("Compêndio")
	_tabs = TabContainer.new()
	_tabs.custom_minimum_size = LIST_SIZE
	content.add_child(_tabs)
	_build_characters()
	_build_tools()
	_build_stage_items()
	_build_cards()
	_build_relics()
	var back := UiStyle.make_text_button("Voltar", true)
	back.name = "Back"
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.pressed.connect(closed.emit)
	content.add_child(back)


func _build_characters() -> void:
	var list := _add_tab("Personagens")
	for character in RoguelikeCharacters.ALL:
		_add_entry(list, "character_%s" % character, RoguelikeCharacters.get_portrait(character), RoguelikeCharacters.get_display_name(character), RoguelikeCharacters.get_ability(character))


func _build_tools() -> void:
	var list := _add_tab("Ferramentas")
	for tool_id in RoguelikeCardPool.TOOL_POOL:
		_add_entry(list, "tool_%s" % tool_id, UiStyle.icon(tool_id), SkillManager.get_display_name(tool_id), TOOL_DESCRIPTIONS.get(tool_id, ""))


func _build_stage_items() -> void:
	var list := _add_tab("Itens da fase")
	for item in STAGE_ITEMS:
		_add_entry(list, item[0], UiStyle.icon(item[2]), item[1], item[3])


func _build_cards() -> void:
	var list := _add_tab("Cartas")
	var examples: Array[RoguelikeCard] = [
		RoguelikeCard.make(RoguelikeCard.Kind.CHARGES, "digger", RoguelikeCardPool.CHARGES_AMOUNT),
		RoguelikeCard.make(RoguelikeCard.Kind.NEW_TOOL, "bridge", RoguelikeCardPool.NEW_TOOL_AMOUNT),
		RoguelikeCard.make(RoguelikeCard.Kind.RECRUIT, RoguelikeCharacters.STARTER),
		RoguelikeCard.make(RoguelikeCard.Kind.REVIVE),
	]
	var names := ["Cargas", "Ferramenta nova", "Recruta", "Pena da fênix"]
	for index in examples.size():
		var card := examples[index]
		_add_entry(list, "card_%s" % RoguelikeCard.Kind.keys()[card.kind].to_lower(), load(card.get_art_path()), names[index], card.get_description())


func _build_relics() -> void:
	var list := _add_tab("Relíquias")
	for relic_id in RoguelikeRelics.DEFINITIONS:
		var card := RoguelikeCard.make(RoguelikeCard.Kind.RELIC, relic_id)
		_add_entry(list, "relic_%s" % relic_id, load(card.get_art_path()), RoguelikeRelics.get_title(relic_id), RoguelikeRelics.get_description(relic_id))


func _add_tab(title: String) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.name = title
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_tabs.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 10)
	scroll.add_child(list)
	return list


func _add_entry(list: VBoxContainer, entry_id: String, texture: Texture2D, title: String, description: String) -> void:
	var known := not _is_discovered.is_valid() or bool(_is_discovered.call(entry_id))
	var row := HBoxContainer.new()
	row.name = entry_id
	row.add_theme_constant_override("separation", 12)
	list.add_child(row)
	var icon := TextureRect.new()
	icon.texture = texture
	icon.custom_minimum_size = ENTRY_ICON_SIZE
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if not known:
		icon.self_modulate = SILHOUETTE
	row.add_child(icon)
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text)
	var name_label := Label.new()
	name_label.text = title if known else UNKNOWN_NAME
	name_label.add_theme_font_size_override("font_size", NAME_FONT_SIZE)
	name_label.add_theme_color_override("font_color", Color(1.0, 0.86, 0.45))
	text.add_child(name_label)
	var description_label := Label.new()
	description_label.text = description if known else UNKNOWN_TEXT
	description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.add_child(description_label)
