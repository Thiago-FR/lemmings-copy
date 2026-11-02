class_name GameControlsController
extends HBoxContainer
## Pause/continue, restart and back-to-menu buttons, available at any moment
## during a level. Lives in the HUD so every level gets them without each
## level scene having to include them. Runs while the tree is paused (set in
## the scene), otherwise the Continue button could never be pressed.
##
## Keyboard shortcuts do the same: P pauses, R restarts, Esc goes back to
## the menu. Config opens the settings screen (volumes; M, handled by
## AudioManager, mutes). Not Space: it already presses whichever button has focus.

@onready var _pause_button: Button = $PauseButton
@onready var _restart_button: Button = $RestartButton
@onready var _menu_button: Button = $MenuButton
@onready var _settings_button: Button = $SettingsButton


func _ready() -> void:
	_pause_button.pressed.connect(GameManager.toggle_pause)
	_restart_button.pressed.connect(GameManager.restart_level)
	_menu_button.pressed.connect(GameManager.go_to_main_menu)
	_settings_button.pressed.connect(_open_settings)
	GameManager.game_paused.connect(_refresh_pause_button)
	GameManager.game_resumed.connect(_refresh_pause_button)
	_refresh_pause_button()

	# Pausing after the level has ended would fight the result screen, which
	# keeps the game paused behind it.
	var level_manager: LevelManager = get_tree().get_first_node_in_group("level_manager")
	if level_manager != null:
		level_manager.level_completed.connect(_on_level_ended)
		level_manager.level_failed.connect(_on_level_ended)


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_P:
			if not _pause_button.disabled:
				GameManager.toggle_pause()
		KEY_R:
			GameManager.restart_level()
		KEY_ESCAPE:
			GameManager.go_to_main_menu()
		_:
			return
	get_viewport().set_input_as_handled()


## Opens over the level and pauses it; closing resumes unless the game was
## already paused.
func _open_settings() -> void:
	get_tree().root.add_child(SettingsMenu.new())


func _refresh_pause_button() -> void:
	_pause_button.text = "Continuar" if GameManager.is_paused else "Pausar"


func _on_level_ended(_percentage_saved: float) -> void:
	_pause_button.disabled = true
