class_name RoguelikeRunEndScreen
extends RoguelikeOverlayScreen
## The last screen of a run, won or lost: a big title, the run's character
## (its portrait, greyed out when the troop was lost), then one row per
## result, each an icon and a number with what it means, and what went into
## the coin vault. Replaces a paragraph of text the user found hard to read.

signal play_again_requested
signal ranking_requested

const PORTRAIT_SIZE := Vector2(128, 128)
const TITLE_COLOUR_WON := Color(1.0, 0.86, 0.35)
const TITLE_COLOUR_LOST := Color(0.92, 0.45, 0.4)
const LOST_PORTRAIT_TINT := Color(0.35, 0.35, 0.4)
const STAT_FONT_SIZE := 18
const STATS_SEPARATION := 10


## summary: what the last stage brought, as icons under the portrait.
## deposited: the coins that went into the vault; vault: the vault's total
## after it.
## rank: the position the run took in the ranking (0 is the best), -1 if
## it did not make it.
func _init(state: RoguelikeRunState, won: bool, summary: RoguelikeStageSummary, deposited: int, vault: int, rank: int = -1) -> void:
	super()
	var title := add_title("Vitória!" if won else "Fim da run")
	title.add_theme_color_override("font_color", TITLE_COLOUR_WON if won else TITLE_COLOUR_LOST)

	var portrait := TextureRect.new()
	portrait.texture = RoguelikeCharacters.get_portrait(state.character_id)
	portrait.custom_minimum_size = PORTRAIT_SIZE
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if not won:
		portrait.self_modulate = LOST_PORTRAIT_TINT
	content.add_child(portrait)

	if summary != null:
		content.add_child(summary.build_row())

	var stats := GridContainer.new()
	stats.columns = 2
	stats.add_theme_constant_override("h_separation", 12)
	stats.add_theme_constant_override("v_separation", STATS_SEPARATION)
	stats.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	content.add_child(stats)
	_add_stat(stats, "give_up", "Fase alcançada", "%d de %d" % [mini(state.stage_index + 1, RoguelikeRunState.stage_count()), RoguelikeRunState.stage_count()])
	_add_stat(stats, "hud_saved", "Bonecos salvos na run", str(state.lemmings_saved_total))
	if won:
		_add_stat(stats, "hud_troop", "Chegaram ao fim", str(state.troop.size()))
	_add_stat(stats, "editor_counts", "Pontuação", str(state.score))
	_add_stat(stats, "hud_coin", "Moedas para o cofre", "+%d (cofre: %d)" % [deposited, vault])
	if rank >= 0:
		_add_stat(stats, "trophy", "Ranking", "%dº" % (rank + 1))

	add_buttons([["Jogar de novo", play_again_requested.emit, true], ["Menu", GameManager.go_to_main_menu]])
	add_icon_buttons([["trophy", "Ranking", ranking_requested.emit, "Ranking"]])


func _add_stat(grid: GridContainer, icon_id: String, caption: String, value: String) -> void:
	var left := HBoxContainer.new()
	left.add_theme_constant_override("separation", 8)
	grid.add_child(left)
	var icon := TextureRect.new()
	icon.texture = UiStyle.icon(icon_id)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	left.add_child(icon)
	var caption_label := Label.new()
	caption_label.text = caption
	caption_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	left.add_child(caption_label)
	var value_label := Label.new()
	value_label.text = value
	value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	value_label.add_theme_font_size_override("font_size", STAT_FONT_SIZE)
	grid.add_child(value_label)
