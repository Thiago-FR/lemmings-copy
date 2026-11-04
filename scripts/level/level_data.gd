class_name LevelData
extends Resource

@export var level_name: String
@export_multiline var instructions: String  # shown in the HUD, explains the level's goal/skills
@export var spawn_rate: float          # seconds between spawns
@export var total_lemmings: int        # total that will spawn in the level
@export var required_percentage: float # minimum % to win (0.0 to 1.0)
@export var time_limit_seconds: int
@export var available_skills: Array[String]  # which skills the player has available
@export var skill_counts: Dictionary    # amount of each skill (e.g. {"digger": 5})
@export var scene_path: String          # path to the level's terrain scene
## The setting the level takes place in (what is drawn behind and around it).
@export var environment_kind: LevelEnvironment.Kind = LevelEnvironment.Kind.SURFACE
## A generated level's looks, border and ramps (StageDressing), laid on its
## terrain when the level starts. Empty for a level drawn by hand.
@export var dressing: Dictionary = {}
## A generated level's recorded solution (MazeStageData.solution), which
## the tests play; empty when there is none.
@export var solution: Array[Dictionary] = []
## Where the solution comes from (a run's seed and stage, say), shown with
## it in the developer's solution view (SolutionOverlay).
@export var solution_note: String = ""
