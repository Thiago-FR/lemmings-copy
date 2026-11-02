class_name LevelResultController
extends CanvasLayer
## Shows a pass/fail overlay when the level ends (LevelManager.level_completed
## / level_failed) and offers retry-or-menu. Its own process_mode is ALWAYS
## so the buttons stay clickable while gameplay is paused behind it.
##
## In a campaign level (Campaign) a win is recorded, which opens the next
## level, and the screen offers going straight to it; its menu button leads
## back to the level select instead of the main menu.

@onready var _panel: Control = $Panel
@onready var _title_label: Label = $Panel/VBoxContainer/TitleLabel
@onready var _percentage_label: Label = $Panel/VBoxContainer/PercentageLabel
@onready var _buttons: HBoxContainer = $Panel/VBoxContainer/HBoxContainer
@onready var _retry_button: Button = $Panel/VBoxContainer/HBoxContainer/RetryButton
@onready var _menu_button: Button = $Panel/VBoxContainer/HBoxContainer/MenuButton

const TITLE_FONT_SIZE := 28
const TITLE_COLOUR := Color(1.0, 0.9, 0.55)
const PANEL_PADDING := 18

var _level_manager: LevelManager
var _next_button: Button
## Index of the level in the campaign, -1 outside it.
var _campaign_index := -1


func _ready() -> void:
	_panel.visible = false
	_frame_contents()

	_level_manager = get_tree().get_first_node_in_group("level_manager")
	assert(_level_manager != null, "LevelResultController requires a LevelManager in the 'level_manager' group")

	_level_manager.level_completed.connect(_on_level_completed)
	_level_manager.level_failed.connect(_on_level_failed)
	_retry_button.pressed.connect(_on_retry_pressed)
	_menu_button.pressed.connect(_on_menu_pressed)

	_campaign_index = Campaign.index_of(_level_manager.level_data)
	if _campaign_index >= 0:
		_menu_button.text = "Fases"
	_next_button = UiStyle.make_text_button("Próxima", true)
	_next_button.name = "NextButton"
	_next_button.icon = UiStyle.icon("next")
	_next_button.visible = false
	_next_button.pressed.connect(_on_next_pressed)
	_buttons.add_child(_next_button)


## Puts the title, percentage and buttons on the game's wooden panel, in
## the middle of the screen, over the dimmed level.
func _frame_contents() -> void:
	var column := _title_label.get_parent() as Control
	var frame := PanelContainer.new()
	frame.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, PANEL_PADDING)
	frame.add_child(margin)
	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	centre.add_child(frame)
	_panel.add_child(centre)
	column.reparent(margin, false)
	column.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	_title_label.add_theme_font_size_override("font_size", TITLE_FONT_SIZE)
	_title_label.add_theme_color_override("font_color", TITLE_COLOUR)


func _on_level_completed(percentage_saved: float) -> void:
	if _campaign_index >= 0:
		Campaign.record_win(_campaign_index, percentage_saved)
		_next_button.visible = Campaign.has_next(_campaign_index)
	_show_result("Fase concluída!", percentage_saved)


func _on_level_failed(percentage_saved: float) -> void:
	_show_result("Fase perdida", percentage_saved)


func _show_result(title: String, percentage_saved: float) -> void:
	_title_label.text = title
	_percentage_label.text = "Salvos: %d%%   Meta: %d%%" % [roundi(percentage_saved * 100.0), roundi(_level_manager.level_data.required_percentage * 100.0)]
	_panel.visible = true
	get_tree().paused = true


func _on_retry_pressed() -> void:
	GameManager.restart_level()


func _on_menu_pressed() -> void:
	if _campaign_index >= 0:
		GameManager.go_to_scene(Campaign.SELECT_SCENE_PATH)
	else:
		GameManager.go_to_main_menu()


func _on_next_pressed() -> void:
	GameManager.load_level(Campaign.load_level_data(_campaign_index + 1))
