class_name RoguelikeRelicBar
extends CanvasLayer
## The cards the run holds for good (its relics), down the left side of a
## stage: one slot each with the relic's picture and its level in roman
## numerals in the corner; the tooltip says what it does at that level.
## Hidden while the run has none. Built once per stage: relics only change
## between stages.

const MARGIN := 8
## Below the HUD's top bar.
const TOP_OFFSET := 64.0
const SLOT_SEPARATION := 4
const ART_INSET := 4

var _state: RoguelikeRunState


func _init(state: RoguelikeRunState) -> void:
	_state = state
	name = "RoguelikeRelicBar"


func _ready() -> void:
	if _state.relics.is_empty():
		return
	var panel := PanelContainer.new()
	panel.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	panel.position = Vector2(MARGIN, TOP_OFFSET)
	add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", SLOT_SEPARATION)
	panel.add_child(column)
	for relic_id in _state.relics:
		column.add_child(_make_slot(relic_id))


func _make_slot(relic_id: StringName) -> Control:
	var level := _state.get_relic_level(relic_id)
	var slot := Button.new()
	slot.name = "Relic_%s" % relic_id
	slot.focus_mode = Control.FOCUS_NONE
	slot.custom_minimum_size = UiStyle.SLOT_SIZE
	slot.tooltip_text = "%s\n%s" % [RoguelikeRelics.get_title_at(relic_id, level), RoguelikeRelics.get_effect(relic_id, level)]
	# Shows, does not act: a click here must not reach the level behind it.
	slot.mouse_filter = Control.MOUSE_FILTER_STOP
	UiStyle.apply_slot_style(slot)
	var art := TextureRect.new()
	art.texture = load(RoguelikeCard.make(RoguelikeCard.Kind.RELIC, relic_id).get_art_path())
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	art.offset_left = ART_INSET
	art.offset_top = ART_INSET
	art.offset_right = -ART_INSET
	art.offset_bottom = -ART_INSET
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(art)
	UiStyle.add_count_label(slot).text = RoguelikeRelics.roman(level)
	return slot
