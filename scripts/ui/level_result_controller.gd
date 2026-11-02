class_name LevelResultController
extends CanvasLayer
## The end of a level, over the dimmed level: a wooden panel that pops in
## with a big animated badge (a star that spins in and keeps pulsing for a
## win, a lost lemming that drops and shakes for a loss), the share saved
## counting up next to the goal, as icons and numbers, and icon buttons
## (retry, back) with the next level as the main action. Its own
## process_mode is ALWAYS, so it works while gameplay is paused behind it.
##
## In a campaign level (Campaign) a win is recorded, which opens the next
## level, and the screen offers going straight to it; after the last level
## the main action opens the congratulations screen. Its back button leads
## to the level select instead of the main menu.

const BACKDROP_COLOUR := Color(0.03, 0.03, 0.06, 0.6)
const PANEL_PADDING := 22
const TITLE_FONT_SIZE := 28
const TITLE_COLOUR := Color(1.0, 0.9, 0.55)
const LOST_TITLE_COLOUR := Color(1.0, 0.62, 0.5)
const FACT_FONT_SIZE := 24
const SAVED_WON_COLOUR := Color(0.7, 1.0, 0.6)
const SAVED_LOST_COLOUR := Color(1.0, 0.55, 0.45)
const BADGE_SIZE := Vector2(96, 96)
const POP_SECONDS := 0.22
const POP_START_SCALE := 0.8
const BADGE_IN_SECONDS := 0.55
const PULSE_SCALE := 1.08
const PULSE_SECONDS := 0.7
const SHAKE_PIXELS := 6.0
const COUNT_UP_SECONDS := 0.8
const WON_TITLE := "Fase concluída!"
const LOST_TITLE := "Fase perdida"

var _level_manager: LevelManager
## Index of the level in the campaign, -1 outside it.
var _campaign_index := -1
var _panel: PanelContainer
var _badge: TextureRect
var _title_label: Label
var _saved_label: Label
var _goal_label: Label
var _next_button: Button


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_level_manager = get_tree().get_first_node_in_group("level_manager")
	assert(_level_manager != null, "LevelResultController requires a LevelManager in the 'level_manager' group")
	_campaign_index = Campaign.index_of(_level_manager.level_data)
	_build()
	visible = false
	_level_manager.level_completed.connect(_on_level_completed)
	_level_manager.level_failed.connect(_on_level_failed)


func _build() -> void:
	var backdrop := ColorRect.new()
	backdrop.color = BACKDROP_COLOUR
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)
	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(centre)
	_panel = PanelContainer.new()
	_panel.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	centre.add_child(_panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, PANEL_PADDING)
	_panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	margin.add_child(column)

	# The badge moves and turns inside a plain holder: a container would put
	# it back in place every time the layout changes.
	var holder := Control.new()
	holder.custom_minimum_size = BADGE_SIZE
	holder.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(holder)
	_badge = TextureRect.new()
	_badge.size = BADGE_SIZE
	_badge.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_badge.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_badge.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	holder.add_child(_badge)
	_title_label = Label.new()
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", TITLE_FONT_SIZE)
	column.add_child(_title_label)
	column.add_child(_make_facts())
	column.add_child(_make_buttons())


## Saved and goal, each an icon and a percentage, explained in the tooltip.
func _make_facts() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 28)
	_saved_label = _add_fact(row, "hud_saved", "Salvos")
	_goal_label = _add_fact(row, "hud_goal", "Meta")
	return row


func _add_fact(row: HBoxContainer, icon_id: String, tooltip: String) -> Label:
	var item := HBoxContainer.new()
	item.tooltip_text = tooltip
	item.mouse_filter = Control.MOUSE_FILTER_STOP
	item.add_theme_constant_override("separation", 6)
	row.add_child(item)
	var icon := TextureRect.new()
	icon.texture = UiStyle.icon(icon_id)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	item.add_child(icon)
	var label := Label.new()
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", FACT_FONT_SIZE)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	item.add_child(label)
	return label


func _make_buttons() -> HBoxContainer:
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 12)
	var retry := UiStyle.make_icon_button("editor_restart", "Jogar de novo")
	retry.name = "RetryButton"
	retry.pressed.connect(GameManager.restart_level)
	buttons.add_child(retry)
	var in_campaign := _campaign_index >= 0
	var back := UiStyle.make_icon_button("campaign" if in_campaign else "editor_menu", "Fases" if in_campaign else "Menu")
	back.name = "MenuButton"
	back.pressed.connect(_on_back_pressed)
	buttons.add_child(back)
	_next_button = UiStyle.make_text_button("Próxima", true)
	_next_button.name = "NextButton"
	_next_button.icon = UiStyle.icon("next")
	_next_button.visible = false
	_next_button.pressed.connect(_on_next_pressed)
	buttons.add_child(_next_button)
	return buttons


func _on_level_completed(percentage_saved: float) -> void:
	if _campaign_index >= 0:
		Campaign.record_win(_campaign_index, percentage_saved)
		_next_button.visible = true
		if not Campaign.has_next(_campaign_index):
			_next_button.text = "Parabéns"
			_next_button.icon = UiStyle.icon("star")
	_show_result(true, percentage_saved)


func _on_level_failed(percentage_saved: float) -> void:
	_show_result(false, percentage_saved)


func _show_result(won: bool, percentage_saved: float) -> void:
	_title_label.text = WON_TITLE if won else LOST_TITLE
	_title_label.add_theme_color_override("font_color", TITLE_COLOUR if won else LOST_TITLE_COLOUR)
	_badge.texture = UiStyle.icon("star" if won else "hud_lost")
	_saved_label.add_theme_color_override("font_color", SAVED_WON_COLOUR if won else SAVED_LOST_COLOUR)
	_goal_label.text = "%d%%" % roundi(_level_manager.level_data.required_percentage * 100.0)
	visible = true
	get_tree().paused = true
	_pop_in()
	_count_up(roundi(percentage_saved * 100.0))
	if won:
		_spin_badge_in()
	else:
		_drop_badge_in()


## The panel grows from a little smaller to full size, from its centre.
func _pop_in() -> void:
	_panel.pivot_offset = _panel.size / 2.0
	_panel.scale = Vector2.ONE * POP_START_SCALE
	_panel.modulate.a = 0.0
	var tween := create_tween().set_parallel()
	tween.tween_property(_panel, "scale", Vector2.ONE, POP_SECONDS).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(_panel, "modulate:a", 1.0, POP_SECONDS)


## The saved share counts up from zero instead of just appearing.
func _count_up(percent: int) -> void:
	var tween := create_tween()
	tween.tween_method(func(value: float) -> void: _saved_label.text = "%d%%" % roundi(value), 0.0, float(percent), COUNT_UP_SECONDS)


## A win: the star spins in from nothing, then keeps pulsing.
func _spin_badge_in() -> void:
	_badge.pivot_offset = BADGE_SIZE / 2.0
	_badge.scale = Vector2.ZERO
	_badge.rotation = -PI
	var tween := create_tween().set_parallel()
	tween.tween_property(_badge, "scale", Vector2.ONE, BADGE_IN_SECONDS).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(_badge, "rotation", 0.0, BADGE_IN_SECONDS).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.chain().tween_callback(_pulse_badge)


func _pulse_badge() -> void:
	var tween := create_tween().set_loops()
	tween.tween_property(_badge, "scale", Vector2.ONE * PULSE_SCALE, PULSE_SECONDS).set_trans(Tween.TRANS_SINE)
	tween.tween_property(_badge, "scale", Vector2.ONE, PULSE_SECONDS).set_trans(Tween.TRANS_SINE)


## A loss: the lost lemming drops in, lands with a bounce and shakes.
func _drop_badge_in() -> void:
	_badge.pivot_offset = BADGE_SIZE / 2.0
	_badge.scale = Vector2.ONE
	_badge.position.y = -40.0
	_badge.modulate.a = 0.0
	var tween := create_tween()
	tween.set_parallel()
	tween.tween_property(_badge, "position:y", 0.0, BADGE_IN_SECONDS).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tween.tween_property(_badge, "modulate:a", 1.0, BADGE_IN_SECONDS * 0.5)
	tween.set_parallel(false)
	for side in [1.0, -1.0, 1.0, -0.5]:
		tween.tween_property(_badge, "rotation", 0.12 * side, 0.07)
	tween.tween_property(_badge, "rotation", 0.0, 0.07)


func _on_back_pressed() -> void:
	if _campaign_index >= 0:
		GameManager.go_to_scene(Campaign.SELECT_SCENE_PATH)
	else:
		GameManager.go_to_main_menu()


func _on_next_pressed() -> void:
	if Campaign.has_next(_campaign_index):
		GameManager.load_level(Campaign.load_level_data(_campaign_index + 1))
	else:
		GameManager.go_to_scene(Campaign.COMPLETE_SCENE_PATH)
