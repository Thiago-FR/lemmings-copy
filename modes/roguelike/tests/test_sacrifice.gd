extends Node
## Sacrificing a lemming and ending a stage early, on a real stage with its
## HUD and tool bar. Run via:
##   godot --headless res://modes/roguelike/tests/test_sacrifice.tscn
## Exits 0 when every check passes, 1 otherwise.
##
## Checked:
##   - the Sacrifice button arms the session and lets go of the selected tool;
##     selecting a tool disarms it;
##   - clicking a lemming while armed sacrifices it (dies with SACRIFICE),
##     leaves COINS_PER_SACRIFICED coins and counts it as lost;
##   - ending the stage sacrifices whoever is still in it, loses the ones
##     not released yet, and finishes the stage with nobody saved.

const TROOP_SIZE := 4
## Long enough for two lemmings to come out (one every 1.5 s), not all four.
const WAIT_FOR_TWO_SECONDS := 2.0
const STAGE_END_TIMEOUT_SECONDS := 5.0

var _failures: Array[String] = []
var _finished := false
var _saved: Array[StringName] = []
var _lost: Array[StringName] = []


func _ready() -> void:
	var state := RoguelikeRunState.new_run()
	for _recruit in TROOP_SIZE - 1:
		state.recruit(RoguelikeCharacters.WIZARD)
	state.inventory.add_charges("digger", 2)
	var session := RoguelikeStageSession.new()
	session.state = state
	session.stage_finished.connect(_on_stage_finished)
	add_child(session)
	await get_tree().create_timer(WAIT_FOR_TWO_SECONDS).timeout

	var lemmings := _lemmings()
	_expect(lemmings.size() == 2, "%d lemmings out after %.1fs, expected 2" % [lemmings.size(), WAIT_FOR_TWO_SECONDS])
	if lemmings.size() < 2:
		_report()
		return

	var slot := get_tree().root.find_child("SacrificeButton", true, false) as Button
	_expect(slot != null, "the HUD has no Sacrifice button")
	SkillManager.select_skill("digger")
	slot.button_pressed = true
	_expect(session.sacrifice_armed, "pressing the Sacrifice button did not arm the session")
	_expect(SkillManager.selected_skill_id == "", "arming the sacrifice kept the tool selected")
	SkillManager.select_skill("digger")
	_expect(not session.sacrifice_armed and not slot.button_pressed, "selecting a tool did not disarm the sacrifice")
	slot.button_pressed = true

	var victim := lemmings[0]
	# Compared around the click: a lemming may pick up a shovel item on its way.
	var charges_before := SkillManager.get_remaining_count("digger")
	victim.clicked.emit(victim)
	_expect(not victim.state_machine.is_alive(), "clicking a lemming while armed did not sacrifice it")
	_expect(state.coins == RoguelikeRunState.COINS_PER_SACRIFICED, "a sacrifice left %d coins, expected %d" % [state.coins, RoguelikeRunState.COINS_PER_SACRIFICED])
	_expect(session.level_manager.lemmings_lost_count == 1, "the sacrificed lemming does not count as lost")
	_expect(SkillManager.get_remaining_count("digger") == charges_before, "the sacrifice spent a tool charge")

	session.end_stage_now()
	var waited := 0.0
	while not _finished and waited < STAGE_END_TIMEOUT_SECONDS:
		await get_tree().process_frame
		waited += get_process_delta_time()
	_expect(_finished, "ending the stage did not finish it")
	_expect(_saved.is_empty(), "%d saved, expected none" % _saved.size())
	_expect(_lost.size() == TROOP_SIZE, "%d lost, expected the whole troop of %d" % [_lost.size(), TROOP_SIZE])
	_expect(state.coins == 2 * RoguelikeRunState.COINS_PER_SACRIFICED, "two sacrifices left %d coins" % state.coins)
	_report()


func _lemmings() -> Array[LemmingController]:
	var found: Array[LemmingController] = []
	for node in get_tree().root.find_children("*", "CharacterBody2D", true, false):
		if node is LemmingController and (node as LemmingController).state_machine.is_alive():
			found.append(node)
	return found


func _on_stage_finished(saved: Array[StringName], lost: Array[StringName]) -> void:
	_finished = true
	_saved = saved
	_lost = lost


func _expect(condition: bool, failure: String) -> void:
	if not condition:
		_failures.append(failure)


func _report() -> void:
	if _failures.is_empty():
		print("Sacrifice: PASS")
		get_tree().quit(0)
		return
	for failure in _failures:
		print("  FAIL: %s" % failure)
	print("Sacrifice: FAIL")
	get_tree().quit(1)
