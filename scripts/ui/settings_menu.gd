class_name SettingsMenu
extends CanvasLayer
## The settings screen ("Configurações"), shown over whatever screen opened
## it (the main menu, or a level, which it pauses). It has the display
## (full screen or window, saved by DisplayScaler) and the audio settings:
## overall, music and effects volume and a mute switch, applied live and
## saved by AudioManager. Opened from a game mode's menu, also that mode's
## automatic save (save_mode). Further sections (controls) go below the
## audio one.
##
## Built in code so new settings are a few lines each. Emits closed when the
## player leaves it, and frees itself.

signal closed

const PANEL_WIDTH := 420.0
const SLIDER_STEP := 5.0
const TITLE_FONT_SIZE := 22
const SECTION_FONT_SIZE := 18
const SECTION_COLOUR := Color(1.0, 0.86, 0.45)
const BACKDROP_COLOUR := Color(0, 0, 0, 0.6)
## Above the HUD and the result screen.
const OVERLAY_LAYER := 20

var _was_paused := false
## Opened from a game mode's menu: its saved games' settings (the automatic
## save) show too. "" for none. Set before adding to the tree.
var save_mode := ""


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
	panel.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	centre.add_child(panel)

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	panel.add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	margin.add_child(column)

	var title := Label.new()
	title.text = "Configurações"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", TITLE_FONT_SIZE)
	column.add_child(title)

	_add_section(column, "Tela", "display")
	var fullscreen := CheckBox.new()
	fullscreen.name = "FullscreenCheckBox"
	fullscreen.text = "Tela cheia (F11)"
	fullscreen.button_pressed = DisplayScaler.is_fullscreen()
	fullscreen.toggled.connect(func(on: bool) -> void: DisplayScaler.set_fullscreen(on))
	column.add_child(fullscreen)

	_add_section(column, "Áudio", "sound_on")
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

	if save_mode != "":
		_add_section(column, "Jogo salvo", "level_save")
		var auto_save := CheckBox.new()
		auto_save.name = "AutoSaveCheckBox"
		auto_save.text = "Salvar sozinho ao fim de cada fase"
		auto_save.button_pressed = SaveSlots.is_auto_save_on(save_mode)
		auto_save.toggled.connect(func(on: bool) -> void: SaveSlots.set_auto_save(save_mode, on))
		column.add_child(auto_save)

	_add_section(column, "Desenvolvedor", "dev")
	var developer := CheckBox.new()
	developer.name = "DeveloperCheckBox"
	developer.text = "Modo desenvolvedor (ferramentas de teste)"
	developer.button_pressed = GameManager.developer_mode
	developer.toggled.connect(GameManager.set_developer_mode)
	column.add_child(developer)

	var back := UiStyle.make_text_button("Voltar", true)
	back.name = "BackButton"
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.pressed.connect(close)
	column.add_child(back)


## A section heading: its icon, its name and a line under them.
func _add_section(parent: Node, text: String, icon_id: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)
	var icon := TextureRect.new()
	icon.texture = UiStyle.icon(icon_id)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	row.add_child(icon)
	var label := Label.new()
	label.text = text
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", SECTION_FONT_SIZE)
	label.add_theme_color_override("font_color", SECTION_COLOUR)
	row.add_child(label)
	parent.add_child(HSeparator.new())


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
