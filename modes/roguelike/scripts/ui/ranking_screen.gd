class_name RoguelikeRankingScreen
extends RoguelikeOverlayScreen
## The best runs (RoguelikeProfile.ranking), best first: the position (the
## first three in gold, silver and bronze), the character's portrait, the
## score, and how far it got (a crown for a won run, the stage reached
## otherwise), with the date in the tooltip. The run just finished, when it
## made it, slides in and glows. Shown over the screen that opened it.

signal closed

const ROW_SEPARATION := 6
const PORTRAIT_SIZE := Vector2(36, 36)
const POSITION_WIDTH := 44.0
const SCORE_WIDTH := 110.0
const SCORE_FONT_SIZE := 20
const MEDAL_COLOURS: Array[Color] = [Color(1.0, 0.84, 0.3), Color(0.82, 0.84, 0.9), Color(0.85, 0.55, 0.3)]
const PLAIN_COLOUR := Color(0.9, 0.86, 0.76)
const HIGHLIGHT_GLOW := Color(1.6, 1.4, 0.8)
const SLIDE_PIXELS := 60.0
const SLIDE_SECONDS := 0.4
const GLOW_SECONDS := 0.6


func _init(profile: RoguelikeProfile, highlight: int = -1) -> void:
	super()
	layer += 1
	add_title("Ranking")
	if profile.ranking.is_empty():
		var empty := TextureRect.new()
		empty.texture = UiStyle.icon("trophy")
		empty.modulate = Color(1, 1, 1, 0.35)
		empty.custom_minimum_size = Vector2(64, 64)
		empty.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		empty.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		empty.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		empty.tooltip_text = "Nenhuma run ainda"
		content.add_child(empty)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", ROW_SEPARATION)
	content.add_child(rows)
	for index in profile.ranking.size():
		var row := _make_row(index, profile.ranking[index])
		rows.add_child(row)
		if index == highlight:
			_celebrate.call_deferred(row)
	var back := UiStyle.make_text_button("Voltar", true)
	back.name = "Back"
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.pressed.connect(closed.emit)
	content.add_child(back)


func _make_row(index: int, entry: Dictionary) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = "Row%d" % (index + 1)
	panel.add_theme_stylebox_override("panel", UiStyle._nine_slice("slot.png", UiStyle.SLOT_MARGIN, UiStyle.SLOT_MARGIN + 4))
	panel.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	panel.tooltip_text = String(entry.get("date", ""))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	panel.add_child(row)

	var colour: Color = MEDAL_COLOURS[index] if index < MEDAL_COLOURS.size() else PLAIN_COLOUR
	var position := Label.new()
	position.text = "%dº" % (index + 1)
	position.custom_minimum_size.x = POSITION_WIDTH
	position.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	position.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	position.add_theme_font_size_override("font_size", SCORE_FONT_SIZE)
	position.add_theme_color_override("font_color", colour)
	row.add_child(position)

	var character := StringName(entry.get("character", RoguelikeCharacters.STARTER))
	if not RoguelikeCharacters.DEFINITIONS.has(character):
		character = RoguelikeCharacters.STARTER
	var portrait := TextureRect.new()
	portrait.texture = RoguelikeCharacters.get_portrait(character)
	portrait.custom_minimum_size = PORTRAIT_SIZE
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	portrait.tooltip_text = RoguelikeCharacters.get_display_name(character)
	row.add_child(portrait)

	var score := Label.new()
	score.text = str(int(entry.get("score", 0)))
	score.custom_minimum_size.x = SCORE_WIDTH
	score.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	score.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	score.add_theme_font_size_override("font_size", SCORE_FONT_SIZE)
	row.add_child(score)

	var reached := HBoxContainer.new()
	reached.add_theme_constant_override("separation", 4)
	row.add_child(reached)
	var won := bool(entry.get("won", false))
	var icon := TextureRect.new()
	icon.texture = UiStyle.icon("star" if won else "give_up")
	icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	reached.add_child(icon)
	var stage := Label.new()
	stage.text = "%d/%d" % [int(entry.get("stage", 1)), RoguelikeRunState.STAGE_COUNT]
	stage.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	reached.add_child(stage)
	reached.tooltip_text = "Venceu a run" if won else "Fase alcançada"
	return panel


## The run just made slides in from the side and glows a few times.
func _celebrate(row: Control) -> void:
	row.modulate.a = 0.0
	var rest := row.position.x
	row.position.x = rest + SLIDE_PIXELS
	var tween := row.create_tween()
	tween.tween_property(row, "position:x", rest, SLIDE_SECONDS).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(row, "modulate:a", 1.0, SLIDE_SECONDS)
	for _glow in 3:
		tween.tween_property(row, "modulate", HIGHLIGHT_GLOW, GLOW_SECONDS / 2.0)
		tween.tween_property(row, "modulate", Color.WHITE, GLOW_SECONDS / 2.0)
