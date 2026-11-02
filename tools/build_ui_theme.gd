extends SceneTree
## Saves the game's theme (UiStyle.build_theme) as the project theme file,
## which project.godot names in gui/theme/custom so every control uses it,
## including the ones in a CanvasLayer (a theme set on the window does not
## reach those). Run after changing UiStyle or the art in
## assets/sprites/ui/:
##   godot --headless --path . --script res://tools/build_ui_theme.gd

const THEME_PATH := "res://resources/ui/game_theme.tres"


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(THEME_PATH.get_base_dir()))
	var error := ResourceSaver.save(UiStyle.build_theme(), THEME_PATH)
	print("theme saved to %s (%s)" % [THEME_PATH, error_string(error)])
	quit(0 if error == OK else 1)
