class_name LevelResultController
extends CanvasLayer
## Shows a pass/fail overlay when the level ends (LevelManager.level_completed
## / level_failed) and offers retry-or-menu. Its own process_mode is ALWAYS
## so the buttons stay clickable while gameplay is paused behind it.

@onready var _panel: Control = $Panel
@onready var _title_label: Label = $Panel/VBoxContainer/TitleLabel
@onready var _percentage_label: Label = $Panel/VBoxContainer/PercentageLabel
@onready var _retry_button: Button = $Panel/VBoxContainer/HBoxContainer/RetryButton
@onready var _menu_button: Button = $Panel/VBoxContainer/HBoxContainer/MenuButton

var _level_manager: LevelManager


func _ready() -> void:
	_panel.visible = false

	_level_manager = get_tree().get_first_node_in_group("level_manager")
	assert(_level_manager != null, "LevelResultController requires a LevelManager in the 'level_manager' group")

	_level_manager.level_completed.connect(_on_level_completed)
	_level_manager.level_failed.connect(_on_level_failed)
	_retry_button.pressed.connect(_on_retry_pressed)
	_menu_button.pressed.connect(_on_menu_pressed)


func _on_level_completed(percentage_saved: float) -> void:
	_show_result("Nivel concluido!", percentage_saved)


func _on_level_failed(percentage_saved: float) -> void:
	_show_result("Nivel falhou", percentage_saved)


func _show_result(title: String, percentage_saved: float) -> void:
	_title_label.text = title
	_percentage_label.text = "Salvos: %d%%" % round(percentage_saved * 100.0)
	_panel.visible = true
	get_tree().paused = true


func _on_retry_pressed() -> void:
	GameManager.restart_level()


func _on_menu_pressed() -> void:
	GameManager.go_to_main_menu()
