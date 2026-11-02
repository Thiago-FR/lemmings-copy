extends "res://tests/tool_scenario_test.gd"
## Every character's ability on a small built terrain: that it works, and
## that each refusal holds without spending a charge. Run via:
##   godot --headless --path . res://modes/roguelike/tests/test_abilities.tscn
## Exits 0 when every scenario passes, 1 otherwise.
##
## Each scenario: a floor on row 10 (unless said otherwise) closed by walls
## at columns 0 and 19, one lemming starting at column 6 facing right, its
## ability used USE_AT_SECONDS in (its leading edge then in column 7), from
## a slot with STARTING_CHARGES charges.

const USE_AT_SECONDS := 0.2
const STARTING_CHARGES := 2
const START_COLUMN := 6
const FLOOR_ROW := 10
## The Tinkerer's scenario: when it is given a block, and when it repeats it
## (walking back from the first block).
const GIVE_BLOCK_AT_SECONDS := 0.25
const REPEAT_AT_SECONDS := 1.5

var _lemming: LemmingController = null
var _slot: RoguelikeAbilitySlot = null
var _results: Array[bool] = []
var _gave_block := false


func _get_test_name() -> String:
	return "abilities"


func _get_scenarios() -> Array:
	return [
		{"name": "Teleport through a wall 1 block thick", "run_seconds": 1.5, "ability": RoguelikeAbilities.TELEPORT, "works": true},
		{"name": "Teleport refused: wall 2 blocks thick", "run_seconds": 0.5, "ability": RoguelikeAbilities.TELEPORT, "works": false},
		{"name": "Teleport refused: outer wall of the stage", "run_seconds": 0.5, "ability": RoguelikeAbilities.TELEPORT, "works": false},
		{"name": "Teleport down through a floor 1 block thick", "run_seconds": 1.5, "ability": RoguelikeAbilities.TELEPORT, "works": true},
		{"name": "Teleport refused: floor 2 blocks thick", "run_seconds": 0.5, "ability": RoguelikeAbilities.TELEPORT, "works": false},
		{"name": "Concrete breaker opens a concrete wall", "run_seconds": 3.0, "ability": RoguelikeAbilities.BREAK_CONCRETE, "works": true},
		{"name": "Concrete breaker refused: earth wall", "run_seconds": 0.5, "ability": RoguelikeAbilities.BREAK_CONCRETE, "works": false},
		{"name": "Concrete breaker refused: no wall in reach", "run_seconds": 0.5, "ability": RoguelikeAbilities.BREAK_CONCRETE, "works": false},
		{"name": "Platform lays 3 planks over a gap of 3", "run_seconds": 4.0, "ability": RoguelikeAbilities.PLATFORM, "works": true},
		{"name": "Platform refused: no edge in reach", "run_seconds": 0.5, "ability": RoguelikeAbilities.PLATFORM, "works": false},
		{"name": "Leap over a gap of 3", "run_seconds": 2.0, "ability": RoguelikeAbilities.LEAP, "works": true},
		{"name": "Leap refused: gap of 4", "run_seconds": 0.5, "ability": RoguelikeAbilities.LEAP, "works": false},
		{"name": "Leap up a step of 2", "run_seconds": 2.0, "ability": RoguelikeAbilities.LEAP, "works": true},
		{"name": "Leap refused: step of 3", "run_seconds": 0.5, "ability": RoguelikeAbilities.LEAP, "works": false},
		{"name": "Repeat: refused before any tool, then repeats the block", "run_seconds": 2.0, "ability": RoguelikeAbilities.REPEAT, "works": true},
	]


func _build_scenario() -> void:
	_results = []
	_gave_block = false
	_slot = RoguelikeAbilitySlot.make(scenario.ability, STARTING_CHARGES)
	var floor_row := FLOOR_ROW
	match scenario.name:
		"Teleport through a wall 1 block thick":
			_room()
			paint(8, 8, 5, 9)
		"Teleport refused: wall 2 blocks thick":
			_room()
			paint(8, 9, 5, 9)
		"Teleport refused: outer wall of the stage":
			# The wall in front is the stage's last column: nothing beyond it.
			paint(0, 8, FLOOR_ROW, FLOOR_ROW)
			paint(0, 0, 5, 9)
			paint(8, 8, 5, 9)
		"Teleport down through a floor 1 block thick":
			floor_row = 6
			paint(0, 19, 6, 6)
			paint(0, 19, 8, 8)
			paint(0, 0, 1, 7)
			paint(19, 19, 1, 7)
		"Teleport refused: floor 2 blocks thick":
			floor_row = 6
			paint(0, 19, 6, 7)
			paint(0, 19, 9, 9)
			paint(0, 0, 1, 8)
			paint(19, 19, 1, 8)
		"Concrete breaker opens a concrete wall":
			_room()
			_paint_concrete(8, 5, 9)
		"Concrete breaker refused: earth wall":
			_room()
			paint(8, 8, 5, 9)
		"Concrete breaker refused: no wall in reach", "Platform refused: no edge in reach":
			_room()
		"Platform lays 3 planks over a gap of 3", "Leap over a gap of 3":
			_room_with_gap(8, 10)
		"Leap refused: gap of 4":
			_room_with_gap(8, 11)
		"Leap up a step of 2":
			_room()
			paint(8, 12, 8, 9)
		"Leap refused: step of 3":
			_room()
			paint(8, 12, 7, 9)
		"Repeat: refused before any tool, then repeats the block":
			_room()
	_lemming = spawn_lemming(START_COLUMN * TILE + TILE / 2.0, floor_row, 1, "lemming")
	if scenario.ability == RoguelikeAbilities.REPEAT:
		RoguelikeCharacters.apply_to(_lemming, RoguelikeCharacters.TINKERER)


## Floor on row 10, walls at columns 0 and 19.
func _room() -> void:
	paint(0, 19, FLOOR_ROW, FLOOR_ROW)
	_walls()


## The same room with a bottomless gap from first to last column.
func _room_with_gap(first: int, last: int) -> void:
	paint(0, first - 1, FLOOR_ROW, FLOOR_ROW)
	paint(last + 1, 19, FLOOR_ROW, FLOOR_ROW)
	_walls()


func _walls() -> void:
	paint(0, 0, 5, FLOOR_ROW - 1)
	paint(19, 19, 5, FLOOR_ROW - 1)


func _paint_concrete(column: int, from_row: int, to_row: int) -> void:
	for row in range(from_row, to_row + 1):
		terrain.set_cell(Vector2i(column, row), TerrainDestructible.TERRAIN_SOURCE_ID, Vector2i(0, TerrainDestructible.TerrainMaterial.CONCRETE))


func _scenario_frame(_delta: float) -> void:
	if not is_instance_valid(_lemming):
		return
	if _results.is_empty() and elapsed >= USE_AT_SECONDS:
		_results.append(_slot.use_on(_lemming))
	if scenario.ability != RoguelikeAbilities.REPEAT:
		return
	if not _gave_block and elapsed >= GIVE_BLOCK_AT_SECONDS:
		_gave_block = true
		if not _lemming.assign_skill(SkillManager.create_skill("block")):
			fail("the block could not be given")
	if _results.size() == 1 and elapsed >= REPEAT_AT_SECONDS:
		_results.append(_slot.use_on(_lemming))


func _evaluate_scenario() -> void:
	if _results.is_empty():
		fail("the ability was never used")
		return
	match scenario.name:
		"Repeat: refused before any tool, then repeats the block":
			_evaluate_repeat()
			return
	var worked: bool = _results[0]
	if worked != bool(scenario.works):
		fail("the ability %s, expected it to %s" % ["worked" if worked else "was refused", "work" if scenario.works else "be refused"])
	var expected_charges := STARTING_CHARGES - (1 if worked else 0)
	if _slot.charges != expected_charges:
		fail("%d charges left, expected %d" % [_slot.charges, expected_charges])
	if not worked:
		_expect_unchanged()
		return
	match scenario.name:
		"Teleport through a wall 1 block thick":
			_expect_past_column(8)
			expect_walking_on_row(_lemming, FLOOR_ROW, "lemming")
			if not is_cell_solid(8, 9):
				fail("the wall was broken, not passed through")
		"Teleport down through a floor 1 block thick":
			expect_walking_on_row(_lemming, 8, "lemming")
			if not is_cell_solid(6, 6) or not is_cell_solid(7, 6):
				fail("the floor was broken, not passed through")
		"Concrete breaker opens a concrete wall":
			if is_cell_solid(8, 9):
				fail("the concrete block at body height is still there")
			for row in range(5, 9):
				if not is_cell_solid(8, row):
					fail("more than one block broken (row %d)" % row)
			_expect_past_column(8)
			expect_walking_on_row(_lemming, FLOOR_ROW, "lemming")
		"Platform lays 3 planks over a gap of 3":
			if terrain.get_bricks().size() != 3:
				fail("%d planks laid, expected 3" % terrain.get_bricks().size())
			_expect_past_column(10)
			expect_walking_on_row(_lemming, FLOOR_ROW, "lemming")
		"Leap over a gap of 3":
			_expect_past_column(10)
			expect_walking_on_row(_lemming, FLOOR_ROW, "lemming")
		"Leap up a step of 2":
			_expect_past_column(7)
			expect_walking_on_row(_lemming, 8, "lemming")


## A refused ability leaves nothing behind: no planks, no broken block, and
## the lemming alive on the ground it started on.
func _expect_unchanged() -> void:
	if not terrain.get_bricks().is_empty():
		fail("a refused ability laid planks")
	if scenario.name == "Concrete breaker refused: earth wall" and not is_cell_solid(8, 9):
		fail("a refused ability broke the earth block")
	var floor_row := 6 if scenario.name.contains("floor 2 blocks") else FLOOR_ROW
	expect_walking_on_row(_lemming, floor_row, "lemming")


func _expect_past_column(column: int) -> void:
	if not is_instance_valid(_lemming):
		return
	var centre_x := _lemming.get_body_rect().get_center().x
	if centre_x <= (column + 1) * TILE:
		fail("the lemming is at x=%.0f, expected past column %d (x > %d)" % [centre_x, column, (column + 1) * TILE])


func _evaluate_repeat() -> void:
	if _results.size() < 2:
		fail("the repeat was not tried a second time")
		return
	if _results[0]:
		fail("the repeat worked before the lemming had any tool")
	if not _results[1]:
		fail("the repeat was refused after the lemming was given a block")
	if _slot.charges != STARTING_CHARGES - 1:
		fail("%d charges left, expected %d (only the use that worked)" % [_slot.charges, STARTING_CHARGES - 1])
	var blocks := 0
	for column in range(1, 19):
		if is_cell_solid(column, 9):
			blocks += 1
	if blocks != 2:
		fail("%d blocks on the floor, expected 2 (the one given and the repeat)" % blocks)
	expect_walking_on_row(_lemming, FLOOR_ROW, "lemming")
