class_name MainMenuController
extends Control
## Main menu: the tutorial, the free mode editor, and one test level per
## tool. The list scrolls: it outgrows the window as tools are added.

const TUTORIAL_LEVEL_PATH := "res://resources/levels/level_01_data.tres"
## The free mode level editor. Opened as a scene of its own rather than as a
## level, since its scenario is drawn by the player.
const EDITOR_SCENE_PATH := "res://scenes/editor/level_editor.tscn"
## Game modes built on the core (see CLAUDE.md, "Modos de jogo"). Each is a
## scene a button opens; a mode whose folder is gone simply has no button.
const MODE_SCENES := {
	"Roguelike": "res://modes/roguelike/scenes/roguelike_run.tscn",
}

## One test level per tool, in menu order.
const TOOL_LEVEL_PATHS: Array[String] = [
	"res://resources/levels/level_02_data.tres",
	"res://resources/levels/level_03_data.tres",
	"res://resources/levels/level_06_data.tres",
	"res://resources/levels/level_07_data.tres",
	"res://resources/levels/level_08_data.tres",
	"res://resources/levels/level_09_data.tres",
	"res://resources/levels/level_10_data.tres",
	"res://resources/levels/level_11_data.tres",
	"res://resources/levels/level_12_data.tres",
	"res://resources/levels/level_13_data.tres",
	"res://resources/levels/level_14_data.tres",
]

## Same width for every button, so the list reads as a column.
const MENU_BUTTON_WIDTH := 260.0
const SECTION_LABEL_COLOUR := Color(0.73, 0.78, 0.84)

@onready var _button_container: VBoxContainer = $ScrollContainer/CenterContainer/VBoxContainer


func _ready() -> void:
	AudioManager.play_music_track(&"menu_theme")
	_add_level_button(load(TUTORIAL_LEVEL_PATH))
	_add_mode_buttons()
	_add_editor_button()
	var settings := _add_button("Configurações")
	settings.pressed.connect(func() -> void: add_child(SettingsMenu.new()))

	_add_section_label("Ferramentas")
	for path in TOOL_LEVEL_PATHS:
		_add_level_button(load(path))

	# Phones and browsers have their own way out of an app; a quit button
	# there would only close it abruptly.
	if not OS.has_feature("mobile") and not OS.has_feature("web"):
		_add_section_label("")
		var quit := _add_button("Sair do jogo")
		quit.name = "QuitButton"
		quit.pressed.connect(func() -> void:
			AudioManager.save_settings()
			get_tree().quit())


func _add_level_button(level_data: LevelData) -> void:
	var button := _add_button(level_data.level_name)
	button.pressed.connect(LevelLoader.load_level.bind(level_data))


func _add_mode_buttons() -> void:
	for mode_name in MODE_SCENES:
		var scene_path: String = MODE_SCENES[mode_name]
		if not ResourceLoader.exists(scene_path):
			continue
		var button := _add_button(mode_name)
		button.pressed.connect(func() -> void: get_tree().change_scene_to_file(scene_path))


func _add_editor_button() -> void:
	var button := _add_button("Modo livre (editor)")
	if not ResourceLoader.exists(EDITOR_SCENE_PATH):
		button.disabled = true
		return
	button.pressed.connect(func() -> void: get_tree().change_scene_to_file(EDITOR_SCENE_PATH))


func _add_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.x = MENU_BUTTON_WIDTH
	_button_container.add_child(button)
	return button


func _add_section_label(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", SECTION_LABEL_COLOUR)
	_button_container.add_child(label)

