extends Node
## Automated check of the settings screen (audio section). Run via:
##   godot --headless res://tests/test_settings.tscn
## Exits 0 when every check passes, 1 otherwise.
##
## Checked, driving the screen's own controls:
##   - moving the music slider changes the Music bus volume;
##   - the mute box mutes the Master bus;
##   - the values are saved and come back after reloading the settings;
##   - unticking full screen saves the window choice for the next start;
##   - opened over a level it pauses the game, and closing resumes it.
## The player's own settings file is put back afterwards.

var _failures: Array[String] = []
var _saved_settings := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_saved_settings = FileAccess.get_file_as_string(AudioManager.SETTINGS_PATH) if FileAccess.file_exists(AudioManager.SETTINGS_PATH) else ""
	_run.call_deferred()


func _run() -> void:
	# Loading a level frees the current scene; this test must survive it.
	get_tree().current_scene = null
	var menu := SettingsMenu.new()
	add_child(menu)
	await get_tree().process_frame

	var music_slider := menu.find_child("MusicSlider", true, false) as HSlider
	var mute_box := menu.find_child("MuteCheckBox", true, false) as CheckBox
	if music_slider == null or mute_box == null:
		_fail("the settings screen is missing its music slider or mute box")
		_finish()
		return

	music_slider.value = 25
	var music_db := AudioServer.get_bus_volume_db(AudioServer.get_bus_index(&"Music"))
	if absf(music_db - linear_to_db(0.25)) > 0.1:
		_fail("music at 25%% set the bus to %.1f dB, expected %.1f" % [music_db, linear_to_db(0.25)])

	var was_muted := AudioManager.is_muted
	mute_box.button_pressed = not was_muted
	if AudioServer.is_bus_mute(AudioServer.get_bus_index(&"Master")) == was_muted:
		_fail("the mute box did not change the Master bus")
	mute_box.button_pressed = was_muted

	var fullscreen_box := menu.find_child("FullscreenCheckBox", true, false) as CheckBox
	if fullscreen_box == null:
		_fail("the settings screen has no full screen box")
	else:
		fullscreen_box.button_pressed = true
		fullscreen_box.button_pressed = false
		var config := ConfigFile.new()
		config.load(AudioManager.SETTINGS_PATH)
		if config.get_value("display", "fullscreen", true) != false:
			_fail("unticking full screen did not save the window choice")

	menu.close()
	AudioManager.set_volume(AudioManager.Channel.MUSIC, 0.9)
	AudioManager.load_settings()
	if absf(AudioManager.get_volume(AudioManager.Channel.MUSIC) - 0.25) > 0.001:
		_fail("the music volume was not saved (reloaded %.2f)" % AudioManager.get_volume(AudioManager.Channel.MUSIC))

	await _check_pauses_level()
	_finish()


func _check_pauses_level() -> void:
	LevelLoader.load_level(load("res://resources/levels/level_07_data.tres"))
	for _frame in 10:
		await get_tree().process_frame
	var menu := SettingsMenu.new()
	get_tree().root.add_child(menu)
	await get_tree().process_frame
	if not get_tree().paused:
		_fail("the settings screen did not pause the level")
	menu.close()
	await get_tree().process_frame
	if get_tree().paused:
		_fail("closing the settings screen did not resume the level")


func _fail(reason: String) -> void:
	_failures.append(reason)
	print("  FAIL — %s" % reason)


func _finish() -> void:
	if _saved_settings.is_empty():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(AudioManager.SETTINGS_PATH))
	else:
		var file := FileAccess.open(AudioManager.SETTINGS_PATH, FileAccess.WRITE)
		file.store_string(_saved_settings)
		file.close()
	if _failures.is_empty():
		print("Settings: all checks passed")
		get_tree().quit(0)
		return
	print("Settings: %d checks failed" % _failures.size())
	get_tree().quit(1)
