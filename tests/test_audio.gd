extends Node
## Automated check of the game's sounds. Run via:
##   godot --headless res://tests/test_audio.tscn
## Exits 0 when every check passes, 1 otherwise.
##
## Checked:
##   - every sound the code plays (each AudioManager.play_sound(&"id"), each
##     *_sound = &"id" a skill hands to it, and each play_music_track(&"id")
##     under scripts/) has its generated file, and
##     it loads: a typo in an id would otherwise just play nothing;
##   - a music track loops once started.

const SCRIPTS_DIR := "res://scripts"

var _failures: Array[String] = []


func _ready() -> void:
	var sound_ids := {}
	var music_ids := {}
	_collect_ids(SCRIPTS_DIR, sound_ids, music_ids)
	print("sounds played in code: %s" % [sound_ids.keys()])
	print("music played in code: %s" % [music_ids.keys()])
	if sound_ids.is_empty():
		_failures.append("found no play_sound calls at all")

	for sound_id in sound_ids:
		_expect_loads(AudioManager.SFX_PATH % sound_id, "sound '%s' (played in %s)" % [sound_id, sound_ids[sound_id]])
	for track_id in music_ids:
		_expect_loads(AudioManager.MUSIC_PATH % track_id, "music '%s' (played in %s)" % [track_id, music_ids[track_id]])

	if not music_ids.is_empty():
		var track: StringName = music_ids.keys()[0]
		AudioManager.play_music_track(track)
		var stream := load(AudioManager.MUSIC_PATH % track) as AudioStreamWAV
		if stream == null or stream.loop_mode == AudioStreamWAV.LOOP_DISABLED:
			_failures.append("music '%s' does not loop" % track)
		AudioManager.stop_music()

	if _failures.is_empty():
		print("Audio: all checks passed")
		get_tree().quit(0)
		return
	for failure in _failures:
		print("  FAIL: %s" % failure)
	print("Audio: %d checks failed" % _failures.size())
	get_tree().quit(1)


func _expect_loads(path: String, what: String) -> void:
	if not ResourceLoader.exists(path) or not (load(path) is AudioStream):
		_failures.append("%s: no file at %s" % [what, path])


## Every &"id" passed to play_sound / play_music_track in the scripts, with
## the file it appears in.
func _collect_ids(directory: String, sound_ids: Dictionary, music_ids: Dictionary) -> void:
	# Also sounds chosen through a variable named *_sound (dig_sound).
	var sound_call := RegEx.create_from_string("(?:play_sound\\(|_sound = )&\"([a-z_0-9]+)\"")
	var music_call := RegEx.create_from_string("play_music_track\\(&\"([a-z_0-9]+)\"\\)")
	for file_name in DirAccess.get_files_at(directory):
		if not file_name.ends_with(".gd"):
			continue
		var path := directory.path_join(file_name)
		var text := FileAccess.get_file_as_string(path)
		for found in sound_call.search_all(text):
			sound_ids[found.get_string(1)] = file_name
		for found in music_call.search_all(text):
			music_ids[found.get_string(1)] = file_name
	for sub_directory in DirAccess.get_directories_at(directory):
		_collect_ids(directory.path_join(sub_directory), sound_ids, music_ids)
