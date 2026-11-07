class_name EditorPlaySession
extends RefCounted
## Builds a playable level out of the editor's drawing: a LevelManager root
## with a copy of the painted terrain, a fresh entrance and exit, and the
## normal skill panel. The game runs entirely on these copies, so whatever
## the lemmings dig or build never reaches the drawing, and Restart only has
## to throw the session away.

const SPAWN_POINT_SCENE := preload("res://scenes/level/spawn_point.tscn")
const EXIT_POINT_SCENE := preload("res://scenes/level/exit_point.tscn")
const SKILL_PANEL_SCENE := preload("res://scenes/ui/skill_panel.tscn")

const LEVEL_NAME := "Modo livre"
## Seconds between lemmings leaving the entrance.
const SPAWN_INTERVAL_SECONDS := 1.0
## The editor is for trying things out, so the clock should never be what
## ends a test run. LevelManager still needs some limit.
const TIME_LIMIT_SECONDS := 99 * 60


## The LevelData a test run uses: every registered tool is offered, with the
## counts chosen in the editor, and broken blocks give what the drawing's
## table says (null: nothing), handed out by the core on the fixed bar.
static func make_level_data(lemming_count: int, skill_counts: Dictionary, scene_path: String, dig_drops: DigDropTable = null) -> LevelData:
	assert(lemming_count > 0, "A test run needs at least one lemming")
	var level_data := LevelData.new()
	level_data.level_name = LEVEL_NAME
	level_data.spawn_rate = SPAWN_INTERVAL_SECONDS
	level_data.total_lemmings = lemming_count
	level_data.required_percentage = 0.0
	level_data.time_limit_seconds = TIME_LIMIT_SECONDS
	level_data.available_skills = SkillManager.get_skill_ids()
	level_data.skill_counts = skill_counts.duplicate()
	level_data.scene_path = scene_path
	level_data.dig_drops = dig_drops.copy() if dig_drops != null else null
	level_data.drops_on_fixed_bar = true
	return level_data


## A level root ready to be added to the tree. LevelManager reads its data
## from GameManager.current_level_data on entering the tree, so the caller
## sets that first.
## entrances: [{"position", "faces_left"}]; several share the troop.
static func build(source_terrain: TerrainDestructible, entrances: Array[Dictionary], exit_positions: Array[Vector2], lemming_count: int, dressing: Dictionary = {}) -> LevelManager:
	assert(not entrances.is_empty(), "A test run needs an entrance")
	var level := LevelManager.new()
	level.name = "PlaySession"
	var terrain := _copy_terrain(source_terrain)
	# A generated stage plays with its looks, border and ramps.
	StageDressing.apply(terrain, dressing)
	level.add_child(terrain)

	for index in entrances.size():
		var spawn_point: SpawnPoint = SPAWN_POINT_SCENE.instantiate()
		spawn_point.position = entrances[index].position
		spawn_point.faces_left = entrances[index].faces_left
		if entrances.size() > 1:
			spawn_point.lemming_count = lemming_count / entrances.size() + (1 if index < lemming_count % entrances.size() else 0)
		level.add_child(spawn_point)

	for exit_position in exit_positions:
		var exit_point: ExitPoint = EXIT_POINT_SCENE.instantiate()
		exit_point.position = exit_position
		level.add_child(exit_point)

	level.add_child(SKILL_PANEL_SCENE.instantiate())
	return level


static func _copy_terrain(source: TerrainDestructible) -> TerrainDestructible:
	var copy := TerrainDestructible.new()
	copy.name = "Terrain"
	copy.tile_set = source.tile_set
	copy.position = source.position
	copy.tile_map_data = source.tile_map_data
	# Bricks are not part of the tile data. They can only be laid once the
	# copy has made its brick body in _ready, and its ready signal fires
	# before LevelManager's _ready releases the first lemming.
	var bricks := source.get_bricks()
	copy.ready.connect(func() -> void:
		for brick in bricks:
			copy.place_brick(brick)
	, CONNECT_ONE_SHOT)
	return copy
