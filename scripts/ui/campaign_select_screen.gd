class_name CampaignSelectScreen
extends Control
## The campaign's level select: the levels as numbered buttons, a column
## of three per setting (the biomes' order), each column topped by a strip
## in that setting's colours. A won
## level shows a star, the first one not won yet is green, the ones after it
## are locked. The level's name is in the tooltip, and pointing at a button
## turns the background into that level's setting: little text, as the user
## asked.

const TITLE := "Fases"
const TITLE_FONT_SIZE := 44
const TITLE_OUTLINE_SIZE := 8
const TITLE_COLOUR := Color(1.0, 0.9, 0.55)
const LEVEL_BUTTON_SIZE := Vector2(92, 52)
const LEVEL_FONT_SIZE := 22
const WORLD_STRIP_HEIGHT := 10
const CORNER_MARGIN := 12
const COMPLETE_PULSE_SCALE := 1.06
const COMPLETE_PULSE_SECONDS := 0.6

var _background: LevelBackground
var _buttons: Array[Button] = []


func _ready() -> void:
	AudioManager.play_music_track(&"menu_theme")
	_background = LevelBackground.new()
	_background.environment = _environment_of(Campaign.current_index())
	add_child(_background)

	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(centre)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 18)
	centre.add_child(column)
	column.add_child(_make_title())
	column.add_child(_make_level_grid())
	if Campaign.is_complete():
		column.add_child(_make_complete_button())
	_add_corner_buttons()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_go_back()


## The button of a level (zero-based), for tests.
func get_level_button(index: int) -> Button:
	return _buttons[index]


func _make_title() -> Label:
	var title := Label.new()
	title.text = TITLE
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", TITLE_FONT_SIZE)
	title.add_theme_color_override("font_color", TITLE_COLOUR)
	title.add_theme_constant_override("outline_size", TITLE_OUTLINE_SIZE)
	return title


func _make_level_grid() -> Control:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	panel.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	panel.add_child(margin)
	var worlds := HBoxContainer.new()
	worlds.add_theme_constant_override("separation", 14)
	margin.add_child(worlds)
	var current := Campaign.current_index()
	for world in Campaign.LEVEL_COUNT / Campaign.LEVELS_PER_WORLD:
		var levels := VBoxContainer.new()
		levels.add_theme_constant_override("separation", 8)
		worlds.add_child(levels)
		var first := world * Campaign.LEVELS_PER_WORLD
		levels.add_child(_make_world_strip(_environment_of(first)))
		for index in range(first, first + Campaign.LEVELS_PER_WORLD):
			var button := _make_level_button(index, current)
			levels.add_child(button)
			_buttons.append(button)
	return panel


## A strip with the setting's sky and ground colours over its column.
func _make_world_strip(environment: LevelEnvironment) -> Control:
	var strip := HBoxContainer.new()
	strip.add_theme_constant_override("separation", 0)
	strip.custom_minimum_size = Vector2(LEVEL_BUTTON_SIZE.x, WORLD_STRIP_HEIGHT)
	for colour in [environment.sky_top, environment.sky_bottom, environment.far_layer, environment.near_layer]:
		var piece := ColorRect.new()
		piece.color = colour
		piece.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		piece.mouse_filter = Control.MOUSE_FILTER_IGNORE
		strip.add_child(piece)
	return strip


func _make_level_button(index: int, current: int) -> Button:
	var level_data := Campaign.load_level_data(index)
	var unlocked := Campaign.is_unlocked(index)
	var cleared := Campaign.is_cleared(index)
	var button := UiStyle.make_text_button(str(index + 1), index == current and not cleared)
	button.name = "Level%02d" % (index + 1)
	button.custom_minimum_size = LEVEL_BUTTON_SIZE
	button.add_theme_font_size_override("font_size", LEVEL_FONT_SIZE)
	button.icon_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	button.disabled = not unlocked
	if not unlocked:
		button.icon = UiStyle.icon("lock")
		button.tooltip_text = level_data.level_name
	elif cleared:
		button.icon = UiStyle.icon("star")
		button.tooltip_text = "%s  (%d%%)" % [level_data.level_name, roundi(Campaign.best_percentage(index) * 100.0)]
	else:
		button.tooltip_text = level_data.level_name
	button.mouse_entered.connect(func() -> void: _background.environment = LevelEnvironment.by_kind(level_data.environment_kind))
	button.pressed.connect(func() -> void: LevelLoader.load_level(level_data))
	return button


## Once every level is won: the way back to the congratulations and
## credits, a gold star that keeps pulsing.
func _make_complete_button() -> Button:
	var button := UiStyle.make_text_button("Parabéns", true)
	button.name = "CompleteButton"
	button.icon = UiStyle.icon("star")
	button.tooltip_text = "Parabéns e créditos"
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.pressed.connect(func() -> void: get_tree().change_scene_to_file(Campaign.COMPLETE_SCENE_PATH))
	button.resized.connect(func() -> void: button.pivot_offset = button.size / 2.0)
	button.ready.connect(func() -> void:
		var tween := button.create_tween().set_loops()
		tween.tween_property(button, "scale", Vector2.ONE * COMPLETE_PULSE_SCALE, COMPLETE_PULSE_SECONDS).set_trans(Tween.TRANS_SINE)
		tween.tween_property(button, "scale", Vector2.ONE, COMPLETE_PULSE_SECONDS).set_trans(Tween.TRANS_SINE))
	return button


## Menu, and in developer mode also: open every level (or lock them again)
## and erase the progress.
func _add_corner_buttons() -> void:
	var corner := HBoxContainer.new()
	corner.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	corner.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	corner.grow_vertical = Control.GROW_DIRECTION_BEGIN
	corner.offset_right = -CORNER_MARGIN
	corner.offset_bottom = -CORNER_MARGIN
	corner.add_theme_constant_override("separation", 6)
	add_child(corner)
	if GameManager.developer_mode:
		var unlock := UiStyle.make_icon_button("lock", "Trancar as fases de novo" if Campaign.is_all_unlocked() else "Liberar todas as fases")
		unlock.name = "UnlockAllButton"
		unlock.modulate = Color(1, 1, 1, 0.5) if Campaign.is_all_unlocked() else Color.WHITE
		unlock.pressed.connect(func() -> void:
			Campaign.set_all_unlocked(not Campaign.is_all_unlocked())
			get_tree().reload_current_scene())
		corner.add_child(unlock)
		var reset := UiStyle.make_icon_button("editor_restart", "Zerar o progresso")
		reset.name = "ResetProgressButton"
		reset.pressed.connect(_confirm_reset)
		corner.add_child(reset)
	var back := UiStyle.make_icon_button("editor_menu", "Menu")
	back.name = "BackButton"
	back.pressed.connect(_go_back)
	corner.add_child(back)


func _confirm_reset() -> void:
	var cleared := 0
	for index in Campaign.LEVEL_COUNT:
		if Campaign.is_cleared(index):
			cleared += 1
	var modal := ConfirmModal.new("editor_restart", "Zerar o progresso?", "Zerar")
	modal.add_fact("star", -cleared, "Estrelas apagadas")
	modal.confirmed.connect(func() -> void:
		Campaign.reset_progress()
		get_tree().reload_current_scene())
	add_child(modal)


## Back to the campaign's menu (new game, load, settings, main menu).
func _go_back() -> void:
	if get_node_or_null("CampaignMenu") == null:
		CampaignMenu.open(get_tree(), false)


func _environment_of(index: int) -> LevelEnvironment:
	return LevelEnvironment.by_kind(Campaign.load_level_data(index).environment_kind)
