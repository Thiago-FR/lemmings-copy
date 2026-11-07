extends Node
## Close-ups of every character using the construction tools (vertical
## ladder, diagonal ladder, bridge), to check their animations in the game:
## feet on the ground, no jitter, the drawn piece turning into the real one.
## For each character and tool it saves a sheet of consecutive moments at 4x
## zoom, read left to right, top to bottom. Needs a real renderer (a window
## opens). Run via:
##   godot --path . --windowed --resolution 1280x720 res://tools/capture_construction.tscn -- <output dir> [character ids...]

const TILE := 32
const FLOOR_ROW := 12
const ZOOM := 4.0
const SETTLE_SECONDS := 0.3
## Shots start when the tool begins work on its second piece (so the steady
## rhythm shows) and are this far apart: 16 of them cover a whole cycle.
const SHOT_INTERVAL := 0.09
const SHOT_COUNT := 16
const SHOTS_PER_ROW := 8
## World pixels around the lemming kept in each shot: room for the segment
## above it and the plank ahead of it.
const SHOT_SIZE := Vector2(100, 120)
const SHOT_CENTRE_OFFSET := Vector2(12, -28)
const TIMEOUT_SECONDS := 8.0

const CHARACTERS := ["wizard", "miner", "engineer", "scout", "tinkerer"]
const SPRITE_FRAMES_PATH := "res://resources/sprite_frames/%s.tres"
const TILE_SET_PATH := "res://resources/tilesets/terrain_tileset.tres"
const LEMMING_SCENE_PATH := "res://scenes/characters/lemming.tscn"

## tool: file name; state: the tool's state; spawn_column: where the lemming
## starts walking right.
const TOOLS := [
	{"tool": "ladder_vertical", "state": LemmingStateMachine.State.LADDER_PLACING, "spawn_column": 8},
	{"tool": "ladder_diagonal", "state": LemmingStateMachine.State.BUILDING, "spawn_column": 6},
	{"tool": "bridge", "state": LemmingStateMachine.State.BRIDGING, "spawn_column": 7},
]

var _world: Node2D = null
var _terrain: TerrainDestructible = null
var _camera: Camera2D = null


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var output_dir: String = args[0] if not args.is_empty() else OS.get_user_data_dir()
	DirAccess.make_dir_recursive_absolute(output_dir)
	var characters: Array = args.slice(1) if args.size() > 1 else CHARACTERS
	for character in characters:
		for setup in TOOLS:
			await _capture(character, setup, output_dir)
	get_tree().quit()


func _capture(character: String, setup: Dictionary, output_dir: String) -> void:
	_build_world(setup.tool)
	var lemming: LemmingController = load(LEMMING_SCENE_PATH).instantiate()
	var body_height: float = (lemming.get_node("CollisionShape2D").shape as RectangleShape2D).size.y
	lemming.terrain = _terrain
	lemming.position = Vector2(setup.spawn_column * TILE + TILE / 2.0, FLOOR_ROW * TILE - body_height / 2.0)
	_world.add_child(lemming)
	lemming.animated_sprite.sprite_frames = load(SPRITE_FRAMES_PATH % character)
	_follow(lemming)

	await get_tree().create_timer(SETTLE_SECONDS).timeout
	lemming.assign_skill(_make_tool(setup.tool))
	var waited := 0.0
	while lemming.state_machine.current_state != setup.state and waited < TIMEOUT_SECONDS:
		await get_tree().physics_frame
		_follow(lemming)
		waited += get_physics_process_delta_time()
	if lemming.state_machine.current_state != setup.state:
		print("%s %s: the tool never started" % [character, setup.tool])
		_world.queue_free()
		return
	await _wait_for_next_piece(lemming)

	var shots: Array[Image] = []
	for _shot in SHOT_COUNT:
		_follow(lemming)
		await RenderingServer.frame_post_draw
		shots.append(_crop(get_viewport().get_texture().get_image()))
		await _wait_following(lemming, SHOT_INTERVAL)
	var path := output_dir.path_join("%s_%s.png" % [setup.tool, character])
	_sheet(shots).save_png(path)
	print("saved ", path)
	_world.queue_free()
	await get_tree().process_frame


## Until the tool moves onto a piece and starts working on the next one, so
## every sheet starts at the beginning of a work phase (see SkillAnimation).
func _wait_for_next_piece(lemming: LemmingController) -> void:
	var sprite := lemming.animated_sprite
	var moved := false
	var waited := 0.0
	while waited < TIMEOUT_SECONDS:
		await get_tree().process_frame
		waited += get_process_delta_time()
		_follow(lemming)
		if sprite.frame >= SkillAnimation.WORK_FRAMES:
			moved = true
		elif moved:
			return


func _wait_following(lemming: LemmingController, seconds: float) -> void:
	var waited := 0.0
	while waited < seconds:
		await get_tree().process_frame
		waited += get_process_delta_time()
		if is_instance_valid(lemming):
			_follow(lemming)


func _follow(lemming: LemmingController) -> void:
	_camera.global_position = lemming.global_position + SHOT_CENTRE_OFFSET


func _crop(image: Image) -> Image:
	var size := Vector2i(SHOT_SIZE * ZOOM)
	var centre := Vector2i(image.get_size() / 2)
	return image.get_region(Rect2i(centre - size / 2, size))


func _sheet(shots: Array[Image]) -> Image:
	var size := shots[0].get_size()
	var rows := ceili(float(shots.size()) / SHOTS_PER_ROW)
	var gap := 4
	var sheet := Image.create(SHOTS_PER_ROW * (size.x + gap), rows * (size.y + gap), false, shots[0].get_format())
	sheet.fill(Color(0.1, 0.1, 0.12))
	for index in shots.size():
		var at := Vector2i((index % SHOTS_PER_ROW) * (size.x + gap), (index / SHOTS_PER_ROW) * (size.y + gap))
		sheet.blit_rect(shots[index], Rect2i(Vector2i.ZERO, size), at)
	return sheet


func _make_tool(tool: String) -> SkillBase:
	match tool:
		"ladder_vertical":
			return SkillLadderVertical.new()
		"ladder_diagonal":
			return SkillBuilder.new()
	return SkillBridge.new()


## A floor across, with what each tool needs: a tall wall for the vertical
## ladder, a wide gap for the bridge, open ground for the diagonal ladder.
func _build_world(tool: String) -> void:
	_world = Node2D.new()
	add_child(_world)
	_terrain = TerrainDestructible.new()
	_terrain.tile_set = load(TILE_SET_PATH)
	_world.add_child(_terrain)
	_camera = Camera2D.new()
	_camera.zoom = Vector2.ONE * ZOOM
	_world.add_child(_camera)
	_camera.make_current()
	match tool:
		"ladder_vertical":
			_paint(0, 30, FLOOR_ROW, FLOOR_ROW + 1)
			_paint(10, 14, FLOOR_ROW - 6, FLOOR_ROW - 1)
		"bridge":
			_paint(0, 9, FLOOR_ROW, FLOOR_ROW + 1)
			_paint(22, 30, FLOOR_ROW, FLOOR_ROW + 1)
		_:
			_paint(0, 40, FLOOR_ROW, FLOOR_ROW + 1)


func _paint(from_column: int, to_column: int, from_row: int, to_row: int) -> void:
	for column in range(from_column, to_column + 1):
		for row in range(from_row, to_row + 1):
			_terrain.set_cell(Vector2i(column, row), TerrainDestructible.TERRAIN_SOURCE_ID, Vector2i.ZERO)
