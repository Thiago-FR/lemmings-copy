extends Node
## A live stage, checked piece by piece: items picked up by walking into
## them reach the bar and SkillManager (one charge each), a tool
## handed out spends a charge from the bar, and each character's ability
## works on its own lemming (Miner digs faster, Engineer builds longer,
## Scout survives higher falls, Inventor reuses its last tool for free).
## Plays a small hand-drawn maze: the entrance room holds a shovel and a
## patch to dig (over a staircase) by its left wall; two more items lie
## beyond a wall and down the stairs.
## Run via:
##   godot --headless res://modes/roguelike/tests/test_stage_session.tscn
## Exits 0 when every check passes, 1 otherwise.

const SPEEDUP := 4
const PHYSICS_TICKS := 60
## Seconds to wait for something to happen before calling it a failure.
const WAIT_LIMIT_SECONDS := 20.0

var _failures: Array[String] = []
var _session: RoguelikeStageSession = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Engine.physics_ticks_per_second = PHYSICS_TICKS * SPEEDUP
	Engine.time_scale = SPEEDUP
	Engine.max_physics_steps_per_frame = 8 * SPEEDUP
	await _test_wizard_pickup_and_spending()
	await _test_miner_digs_faster()
	await _test_tinkerer_reuses_tool()
	_test_engineer_and_scout_hooks()
	Engine.time_scale = 1.0
	if _failures.is_empty():
		print("Stage session: PASS")
	else:
		print("Stage session: FAIL\n  " + "\n  ".join(_failures))
	get_tree().quit(0 if _failures.is_empty() else 1)


func _check(condition: bool, description: String) -> void:
	print("  [%s] %s" % ["ok" if condition else "FAIL", description])
	if not condition:
		_failures.append(description)


func _start_session(troop: Array[StringName]) -> RoguelikeRunState:
	if _session != null:
		remove_child(_session)
		_session.queue_free()
	var state := RoguelikeRunState.new()
	state.troop = troop
	state.stage_definitions[0] = _small_maze()
	_session = RoguelikeStageSession.new()
	_session.state = state
	add_child(_session)
	return state


func _small_maze() -> RoguelikeStageDefinition:
	var layout := MazeLayout.new()
	layout.floor_materials.fill(MazeLayout.CONCRETE)
	layout.add_stairs(0, 0, -1)
	layout.add_wall(0, 0, MazeLayout.EARTH)
	layout.spawn_room = MazeLayout.room_id(0, 0)
	layout.exit_room = MazeLayout.room_id(0, 1)
	layout.add_tool_spot(MazeLayout.room_id(0, 0), "digger", 1)
	layout.add_tool_spot(MazeLayout.room_id(1, 0), "miner", 1, false)
	layout.add_bonus_spot(MazeLayout.room_id(0, 1))
	return RoguelikeStageFactory.from_layout(layout, "Teste", 0)


## Column of the patch to dig: the entrance room's first column.
func _patch_column() -> int:
	return MazeLayout.first_column(MazeLayout.room_id(0, 0))


func _column_of(lemming: LemmingController) -> int:
	return int(lemming.get_body_rect().get_center().x / Constants.TERRAIN_TILE_SIZE)


## Waits physics frames until `condition` holds; false on timeout.
func _wait_for(condition: Callable) -> bool:
	var waited := 0.0
	while not condition.call():
		await get_tree().physics_frame
		waited += get_physics_process_delta_time()
		if waited > WAIT_LIMIT_SECONDS:
			return false
	return true


func _first_lemming() -> LemmingController:
	for node in get_tree().get_nodes_in_group("lemmings"):
		var lemming := node as LemmingController
		if lemming.state_machine.is_alive():
			return lemming
	return null


func _give(tool_id: String, lemming: LemmingController) -> bool:
	SkillManager.select_skill(tool_id)
	return SkillManager.try_assign_to(lemming)


func _test_wizard_pickup_and_spending() -> void:
	var state := _start_session([RoguelikeCharacters.WIZARD] as Array[StringName])
	var picked := await _wait_for(func() -> bool: return state.inventory.has_tool("digger"))
	_check(picked, "walking into the shovel item puts the shovel in the bar")
	_check(state.inventory.get_charges("digger") == 1, "an item gives one charge (got %d)" % state.inventory.get_charges("digger"))
	_check(SkillManager.get_remaining_count("digger") == 1, "SkillManager follows the bar")
	var pickups_left := get_tree().get_nodes_in_group("roguelike_pickups").filter(func(node: Node) -> bool: return not node.is_queued_for_deletion()).size()
	_check(pickups_left == 2, "the item is gone once collected (%d left)" % pickups_left)
	var lemming := _first_lemming()
	await _wait_for(func() -> bool: return lemming.state_machine.current_state == LemmingStateMachine.State.WALKING)
	_check(_give("digger", lemming), "the shovel can be handed out")
	_check(state.inventory.get_charges("digger") == 0 and SkillManager.get_remaining_count("digger") == 0, "handing it out spends a charge from the bar")


func _test_miner_digs_faster() -> void:
	var state := _start_session([RoguelikeCharacters.MINER] as Array[StringName])
	await _wait_for(func() -> bool: return state.inventory.has_tool("digger"))
	_check(state.inventory.get_charges("digger") == 1, "only the Wizard gets the pick-up bonus")
	var lemming := _first_lemming()
	await _wait_for(func() -> bool: return lemming.state_machine.current_state == LemmingStateMachine.State.WALKING)
	var template_speed := (SkillManager.create_skill("digger") as SkillDigger).dig_speed
	_give("digger", lemming)
	var copy := lemming.current_skill as SkillDigger
	_check(copy != null and is_equal_approx(copy.dig_speed, template_speed * RoguelikeMinerTrait.DIG_SPEED_FACTOR), "the Miner's shovel digs twice as fast")
	_check(is_equal_approx((SkillManager.create_skill("digger") as SkillDigger).dig_speed, template_speed), "the shared template is untouched")


func _test_tinkerer_reuses_tool() -> void:
	var state := _start_session([RoguelikeCharacters.TINKERER] as Array[StringName])
	await _wait_for(func() -> bool: return state.inventory.has_tool("digger"))
	var lemming := _first_lemming()
	await _wait_for(func() -> bool: return lemming.state_machine.current_state == LemmingStateMachine.State.WALKING and _column_of(lemming) == _patch_column())
	_give("digger", lemming)
	_check(state.inventory.get_charges("digger") == 0, "the only shovel charge is spent")
	var dug := await _wait_for(func() -> bool: return lemming.state_machine.current_state == LemmingStateMachine.State.WALKING)
	_check(dug, "the Inventor finishes digging")
	lemming.clicked.emit(lemming)
	_check(lemming.state_machine.current_state == LemmingStateMachine.State.DIGGING, "clicking the Inventor with no charges left digs again")
	_check(state.inventory.get_charges("digger") == 0, "the reuse spends nothing")
	await _wait_for(func() -> bool: return lemming.state_machine.current_state == LemmingStateMachine.State.WALKING)
	lemming.clicked.emit(lemming)
	_check(lemming.state_machine.current_state != LemmingStateMachine.State.DIGGING, "the reuse works once per stage")


## Hooks that need no walking: the Engineer's longer tools and the Scout's
## higher safe fall, checked on a lemming of the running stage.
func _test_engineer_and_scout_hooks() -> void:
	var lemming := _first_lemming()
	var engineer: RoguelikeCharacterTrait = preload("res://modes/roguelike/scripts/characters/traits/engineer_trait.gd").new()
	var bridge := SkillManager.create_skill("bridge") as SkillBridge
	var pieces := bridge.max_pieces
	engineer._on_skill_about_to_apply(bridge)
	_check(bridge.max_pieces == pieces + RoguelikeEngineerTrait.EXTRA_PIECES, "the Engineer's bridge has more pieces")
	engineer.free()
	var scout_lemming: LemmingController = preload("res://scenes/characters/lemming.tscn").instantiate()
	scout_lemming.global_position = lemming.global_position if lemming != null else Vector2(100, 100)
	_session.level_manager.add_child(scout_lemming)
	RoguelikeCharacters.apply_to(scout_lemming, RoguelikeCharacters.SCOUT)
	_check(is_equal_approx(scout_lemming.max_safe_fall_height, Constants.MAX_SAFE_FALL_HEIGHT * RoguelikeScoutTrait.SAFE_FALL_FACTOR), "the Scout survives higher falls")
	_check(scout_lemming.get_node_or_null("CharacterTrait") != null, "a character wears its trait (gem and tint)")
