class_name RoguelikeStageSummary
extends RefCounted
## What a finished stage brought, for the screens after it to show as icons
## and numbers instead of sentences (the user wants as little text as
## possible): lemmings saved and lost, coins earned, who came back thanks to
## a phoenix feather, who joined, and whether no one was lost (one more card
## to choose from). build_row() lays it out; revived and joined lemmings
## appear with an animation of their own.

var saved := 0
var lost := 0
var coins := 0
var revived: Array[StringName] = []
var joined: StringName = &""
var perfect := false

const FACT_FONT_SIZE := 20
const PORTRAIT_SIZE := Vector2(40, 40)
const JOIN_POP_SECONDS := 0.35
const JOIN_DELAY_SECONDS := 0.25


## A row of icon + number facts, then the portraits of who joined or came
## back, each popping in.
func build_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.name = "StageSummary"
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 20)
	_add_fact(row, "hud_saved", str(saved), "Salvos")
	_add_fact(row, "hud_lost", str(lost), "Perdidos")
	_add_fact(row, "hud_coin", "+%d" % coins, "Moedas ganhas")
	if perfect:
		_add_fact(row, "star", "+1", "Ninguém perdido: uma carta a mais para escolher")
	var delay := JOIN_DELAY_SECONDS
	for character in revived:
		_add_arrival(row, character, "hud_rescue", "Voltou com a pena da fênix", delay)
		delay += JOIN_DELAY_SECONDS
	if joined != &"":
		_add_arrival(row, joined, "hud_troop", "Entrou na tropa", delay)
	return row


func _add_fact(row: HBoxContainer, icon_id: String, value: String, tooltip: String) -> void:
	var fact := HBoxContainer.new()
	fact.tooltip_text = tooltip
	fact.mouse_filter = Control.MOUSE_FILTER_STOP
	fact.add_theme_constant_override("separation", 4)
	row.add_child(fact)
	var icon := TextureRect.new()
	icon.texture = UiStyle.icon(icon_id)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fact.add_child(icon)
	var label := Label.new()
	label.text = value
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", FACT_FONT_SIZE)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fact.add_child(label)


## A small badge (feather, troop) and the character's portrait, growing in
## from nothing a moment after the screen opens.
func _add_arrival(row: HBoxContainer, character: StringName, badge_id: String, tooltip: String, delay: float) -> void:
	var item := HBoxContainer.new()
	item.name = "Arrival_%s" % character
	item.tooltip_text = "%s: %s" % [tooltip, RoguelikeCharacters.get_display_name(character)]
	item.mouse_filter = Control.MOUSE_FILTER_STOP
	row.add_child(item)
	var badge := TextureRect.new()
	badge.texture = UiStyle.icon(badge_id)
	badge.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	item.add_child(badge)
	var portrait := TextureRect.new()
	portrait.texture = RoguelikeCharacters.get_portrait(character)
	portrait.custom_minimum_size = PORTRAIT_SIZE
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	item.add_child(portrait)
	item.modulate.a = 0.0
	item.ready.connect(func() -> void:
		item.pivot_offset = item.size / 2.0
		item.scale = Vector2.ONE * 0.3
		var tween := item.create_tween().set_parallel()
		tween.tween_property(item, "modulate:a", 1.0, JOIN_POP_SECONDS).set_delay(delay)
		tween.tween_property(item, "scale", Vector2.ONE, JOIN_POP_SECONDS).set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT), CONNECT_ONE_SHOT)
