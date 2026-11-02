class_name SettingsMenu
extends CanvasLayer
## The settings screen ("Configurações"), shown over whatever screen opened
## it (the main menu, or a level, which it pauses). It has the display
## (full screen or window, saved by DisplayScaler) and the audio settings:
## overall, music and effects volume and a mute switch, applied live and
## saved by AudioManager. Further sections (controls) go
## below the audio one.
##
## Built in code so new settings are a few lines each. Emits closed when the
## player leaves it, and frees itself.

signal closed

const PANEL_WIDTH := 420.0
const SLIDER_STEP := 5.0
const TITLE_FONT_SIZE := 22
const SECTION_FONT_SIZE := 16
const SECTION_COLOUR := Color(0.73, 0.78, 0.84)
const BACKDROP_COLOUR := Color(0, 0, 0, 0.6)
## Above the HUD and the result screen.
const OVERLAY_LAYER := 20

var _was_paused := false


func _ready() -> void:
	layer = OVERLAY_LAYER
	# Usable while the game behind it is paused.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_was_paused = GameManager.is_paused
	if get_tree().get_first_node_in_group("level_manager") != null:
		GameManager.pause_game()
	_build()


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo and key.keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()


func close() -> void:
	AudioManager.save_settings()
	if not _was_paused:
		GameManager.resume_game()
	closed.emit()
	queue_free()


func _build() -> void:
	var backdrop := ColorRect.new()
	backdrop.color = BACKDROP_COLOUR
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)

	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(centre)

	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = PANEL_WIDTH
	centre.add_child(panel)

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	panel.add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	margin.add_child(column)

	var title := Label.new()
	title.text = "Configurações"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", TITLE_FONT_SIZE)
	column.add_child(title)

	_add_section(column, "Tela")
	var fullscreen := CheckBox.new()
	fullscreen.name = "FullscreenCheckBox"
	fullscreen.text = "Tela cheia (F11)"
	fullscreen.button_pressed = DisplayScaler.is_fullscreen()
	fullscreen.toggled.connect(func(on: bool) -> void: DisplayScaler.set_fullscreen(on))
	column.add_child(fullscreen)

	_add_section(column, "Áudio")
	_add_volume_slider(column, "Volume geral", AudioManager.Channel.MASTER)
	_add_volume_slider(column, "Música", AudioManager.Channel.MUSIC)
	_add_volume_slider(column, "Efeitos", AudioManager.Channel.EFFECTS)

	var mute := CheckBox.new()
	mute.name = "MuteCheckBox"
	mute.text = "Sem som (tecla M)"
	mute.button_pressed = AudioManager.is_muted
	mute.toggled.connect(func(on: bool) -> void:
		if on != AudioManager.is_muted:
			AudioManager.toggle_mute())
	column.add_child(mute)

	_add_section(column, "Desenvolvedor")
	var developer := CheckBox.new()
	developer.name = "DeveloperCheckBox"
	developer.text = "Modo desenvolvedor (ferramentas de teste)"
	developer.button_pressed = GameManager.developer_mode
	developer.toggled.connect(GameManager.set_developer_mode)
	column.add_child(developer)

	var back := Button.new()
	back.name = "BackButton"
	back.text = "Voltar"
	back.pressed.connect(close)
	column.add_child(back)


func _add_section(parent: Node, text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", SECTION_FONT_SIZE)
	label.add_theme_color_override("font_color", SECTION_COLOUR)
	parent.add_child(label)


## A labelled slider from 0 to 100% for one audio channel, applied as it
## moves. A short test sound plays on release so the effects level can be
## judged.
func _add_volume_slider(parent: Node, text: String, channel: AudioManager.Channel) -> void:
	var row := HBoxContainer.new()
	parent.add_child(row)

	var label := Label.new()
	label.text = text
	label.custom_minimum_size.x = 130
	row.add_child(label)

	var slider := HSlider.new()
	slider.name = "%sSlider" % AudioManager.Channel.keys()[channel].capitalize()
	slider.min_value = 0
	slider.max_value = 100
	slider.step = SLIDER_STEP
	slider.value = AudioManager.get_volume(channel) * 100.0
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(slider)

	var value_label := Label.new()
	value_label.custom_minimum_size.x = 48
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.text = "%d%%" % slider.value
	row.add_child(value_label)

	slider.value_changed.connect(func(value: float) -> void:
		AudioManager.set_volume(channel, value / 100.0)
		value_label.text = "%d%%" % value)
	slider.drag_ended.connect(func(_changed: bool) -> void:
		if channel != AudioManager.Channel.MUSIC:
			AudioManager.play_sound(&"select_tool"))
