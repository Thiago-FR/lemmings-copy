extends Node
## Makes the campaign's levels with the stage generator, the same stages
## the roguelike has (every stage of every biome, in order) drawn from a
## seed of the campaign's own, each checked winnable, saved with its
## solution and then played by the robot in the real game
## (tests/test_campaign_level.tscn): drawn again until the robot wins.
## The levels written over are backed up first (CampaignLevelStore). Run
## (CAMPAIGN_SPEED_UP=8 plays the robot's games faster):
##   godot --headless --path . res://tools/build_generated_campaign.tscn -- [first] [last]
## (a scene, not --script: the level scenes need the game's autoloads)

const CAMPAIGN_SEED := 2026
## Levels drawn again when the robot loses one.
const MAX_TRIES := 10


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var first := int(args[0]) if args.size() > 0 else 1
	var last := int(args[1]) if args.size() > 1 else Campaign.LEVEL_COUNT
	var failed := 0
	for number in range(first, last + 1):
		if not _make_level(number):
			failed += 1
	print("%d levels not won by the robot" % failed)
	get_tree().quit(1 if failed > 0 else 0)


## Draws the level until the robot wins it in the real game with the
## solution recorded (the solver's model of the game is not exact), at most
## MAX_TRIES times. The last one drawn stays if none is won.
func _make_level(number: int) -> bool:
	for attempt in MAX_TRIES:
		var maze := BiomeStageGenerator.generate(CAMPAIGN_SEED + attempt * 7919, number - 1)
		if maze.solution.is_empty() or not CampaignLevelStore.create_generated(number - 1, maze):
			print("%02d try %d: no solution" % [number, attempt + 1])
			continue
		var output := []
		var code := OS.execute(OS.get_executable_path(), ["--headless", "--path", ProjectSettings.globalize_path("res://"),
			"res://tests/test_campaign_level.tscn", "--", str(number)], output, true)
		var won := code == 0
		print("%02d try %d %s: %s, %d tools" % [number, attempt + 1, maze.stage_name, "won by the robot" if won else "robot lost", maze.solution.size()])
		if won:
			return true
	return false
