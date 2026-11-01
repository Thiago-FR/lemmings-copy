extends Node
## Standalone launcher used only for headless smoke-testing a single level
## through the real LevelLoader.load_level() path (so GameManager.current_level_data
## is set correctly, matching how the main menu starts a level). Usage:
##   godot --headless res://tools/level_smoke_launcher.tscn --quit-after N -- <level_data_path>


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	assert(not args.is_empty(), "Pass the LevelData resource path after '--'")

	var level_data: LevelData = load(args[0])
	print("Smoke-launching %s (%s)..." % [level_data.level_name, level_data.scene_path])
	LevelLoader.load_level(level_data)
