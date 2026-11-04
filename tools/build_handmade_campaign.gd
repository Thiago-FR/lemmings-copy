extends Node
## Writes the hand-made campaign levels (tools/campaign/level_NN.gd) into the
## game: each level's scene and LevelData, with its landscape's looks. The
## levels written over are backed up first (CampaignLevelStore). Run:
##   godot --headless --path . res://tools/build_handmade_campaign.tscn -- <level numbers...>
## (a scene, not --script: the level scenes need the game's autoloads)
## Then check each one: the robot plays its solution
## (tests/test_campaign_level.tscn -- <number>) and a look at it
## (tools/capture_solution.tscn).

const LEVEL_SCRIPT := "res://tools/campaign/level_%02d.gd"


func _ready() -> void:
	var failed := 0
	for arg in OS.get_cmdline_user_args():
		var number := int(arg)
		var path := LEVEL_SCRIPT % number
		if not ResourceLoader.exists(path):
			push_error("No level %s" % path)
			failed += 1
			continue
		var level: HandmadeLevel = load(path).new()
		var maze := level.build()
		if CampaignLevelStore.create_level(number - 1, maze, level.lemmings, level.spawn_seconds, level.tools, level.goal):
			print("%02d %s: %dx%d, tools %s, %d%% of %d" % [number, level.level_name, maze.columns, maze.rows, level.tools, roundi(level.goal * 100.0), level.lemmings])
		else:
			failed += 1
	get_tree().quit(1 if failed > 0 else 0)
