class_name RoguelikeStageDefinition
extends RefCounted
## A roguelike stage ready to build: the maze (terrain, entrance, exit and
## its recorded solution, from the core's procedural code), the items the
## roguelike put on the maze's spots, the name and the time limit. Built
## into a playable level by RoguelikeStageBuilder; made by
## RoguelikeStageFactory, from the run's seed or from a hand-made layout.

var stage_name: String = ""
var time_limit_seconds: int = 300
var maze: MazeStageData = null
## ItemSpec, each with its column and floor row.
var pickups: Array[ItemSpec] = []
## Whether it came from the generator (false: one of the hand-made stages).
var is_procedural := true


## Clicks that win the stage (see MazeStageData.solution).
func get_solution() -> Array[Dictionary]:
	return maze.solution


func get_environment_kind() -> LevelEnvironment.Kind:
	return maze.environment_kind
