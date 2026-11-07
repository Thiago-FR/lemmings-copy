class_name MainMenuController
extends Control
## Main menu, over the levels' own sky and hills: the title, the game modes
## as big buttons (the roguelike, the main one, in green), the tool levels
## as a grid of tool icons (the level's name in the tooltip: the user wants
## as little text as possible) and, in the corner, Settings and Quit.

const TUTORIAL_LEVEL_PATH := "res://resources/levels/level_01_data.tres"
## The free mode level editor. Opened as a scene of its own rather than as a
## level, since its scenario is drawn by the player.
const EDITOR_SCENE_PATH := "res://scenes/editor/level_editor.tscn"
## Game modes built on the core (see CLAUDE.md, "Modos de jogo"). Each is a
## scene a button opens; a mode whose folder is gone simply has no button.
## [name, scene, icon, main action].
const MODES: Array = [
	["Roguelike", "res://modes/roguelike/scenes/roguelike_run.tscn", "give_up", true],
]

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
	"res://resources/levels/level_15_data.tres",
	"res://resources/levels/level_16_data.tres",
]

const TITLE := "Lemmings-copy"
const TOOL_COLUMNS := 6
const SECTION_COLOUR := Color(1.0, 0.86, 0.45)
const CORNER_MARGIN := 12

var _column: VBoxContainer


func _ready() -> void:
	# Back at the menu, no saved game is being played (the save button of a
	# tool level must not write into the campaign's).
	SaveSlots.close()
	AudioManager.play_music_track(&"menu_theme")
	add_child(LevelBackground.new())
	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(centre)
	_column = VBoxContainer.new()
	_column.add_theme_constant_override("separation", 18)
	centre.add_child(_column)

	_add_title()
	var modes := _add_panel()
	_add_mode_button(modes, "Tutorial", "editor_play", false, LevelLoader.load_level.bind(load(TUTORIAL_LEVEL_PATH)))
	var campaign := _add_mode_button(modes, "Fases", "campaign", false, func() -> void: CampaignMenu.open(get_tree(), false))
	campaign.name = "CampaignButton"
	for mode in MODES:
		if ResourceLoader.exists(mode[1]):
			_add_mode_button(modes, mode[0], mode[2], mode[3], get_tree().change_scene_to_file.bind(mode[1]))
	var editor := _add_mode_button(modes, "Modo livre", "editor_earth", false, get_tree().change_scene_to_file.bind(EDITOR_SCENE_PATH))
	editor.tooltip_text = "Desenhe um cenário e teste"
	editor.disabled = not ResourceLoader.exists(EDITOR_SCENE_PATH)

	_add_tool_levels()
	_add_corner_buttons()


func _add_title() -> void:
	_column.add_child(UiStyle.make_menu_title(TITLE))


## A wooden panel in the menu column, holding a column of its own.
func _add_panel() -> VBoxContainer:
	return UiStyle.add_menu_panel(_column)


func _add_mode_button(parent: Container, text: String, icon_id: String, primary: bool, action: Callable) -> Button:
	var button := UiStyle.make_menu_button(text, icon_id, primary)
	button.pressed.connect(action)
	parent.add_child(button)
	return button


## One icon per tool level, its name in the tooltip.
func _add_tool_levels() -> void:
	var panel := _add_panel()
	var label := Label.new()
	label.text = "Ferramentas"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", SECTION_COLOUR)
	panel.add_child(label)
	var grid := GridContainer.new()
	grid.columns = TOOL_COLUMNS
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	panel.add_child(grid)
	for path in TOOL_LEVEL_PATHS:
		var level_data: LevelData = load(path)
		var icon_id: String = level_data.available_skills[0] if not level_data.available_skills.is_empty() else ""
		var button := UiStyle.make_icon_button(icon_id, level_data.level_name)
		button.pressed.connect(LevelLoader.load_level.bind(level_data))
		grid.add_child(button)


func _add_corner_buttons() -> void:
	var corner := HBoxContainer.new()
	corner.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	corner.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	corner.grow_vertical = Control.GROW_DIRECTION_BEGIN
	corner.offset_right = -CORNER_MARGIN
	corner.offset_bottom = -CORNER_MARGIN
	corner.add_theme_constant_override("separation", 6)
	add_child(corner)
	var settings := UiStyle.make_icon_button("settings", "Configurações")
	settings.name = "SettingsButton"
	settings.pressed.connect(func() -> void: add_child(SettingsMenu.new()))
	corner.add_child(settings)
	# Phones and browsers have their own way out of an app; a quit button
	# there would only close it abruptly.
	if not OS.has_feature("mobile") and not OS.has_feature("web"):
		var quit := UiStyle.make_icon_button("editor_exit", "Sair do jogo")
		quit.name = "QuitButton"
		quit.pressed.connect(func() -> void:
			AudioManager.save_settings()
			get_tree().quit())
		corner.add_child(quit)
