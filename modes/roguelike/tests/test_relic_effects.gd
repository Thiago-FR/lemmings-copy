extends Node
## The relics that act during a stage, on a real stage. Run via:
##   godot --headless res://modes/roguelike/tests/test_relic_effects.tscn
## Exits 0 when every check passes, 1 otherwise.
##
## Checked, with Quick step II, Hourglass I, Spare parachute II, Collector I
## and Greed II:
##   - the stage clock has the Hourglass's extra seconds;
##   - every lemming walks 30% faster;
##   - the first two lemmings come out with a parachute, the third without;
##   - a tool item gives its charge plus the Collector's;
##   - a coin item gives its coins plus the Greed's;
##   - the relic bar shows a slot per relic, with its level.

const TROOP_SIZE := 3
## Long enough for three lemmings (one every 1.5 s).
const WAIT_FOR_THREE_SECONDS := 3.6

var _failures: Array[String] = []


func _ready() -> void:
	var state := RoguelikeRunState.new_run()
	for _recruit in TROOP_SIZE - 1:
		state.recruit(RoguelikeCharacters.WIZARD)
	state.add_relic(RoguelikeRelics.QUICK_STEP)
	state.add_relic(RoguelikeRelics.QUICK_STEP)
	state.add_relic(RoguelikeRelics.HOURGLASS)
	state.add_relic(RoguelikeRelics.SPARE_PARACHUTE)
	state.add_relic(RoguelikeRelics.SPARE_PARACHUTE)
	state.add_relic(RoguelikeRelics.COLLECTOR)
	state.add_relic(RoguelikeRelics.GREED)
	state.add_relic(RoguelikeRelics.GREED)
	var session := RoguelikeStageSession.new()
	session.state = state
	add_child(session)

	var expected_time := state.get_stage_definition().time_limit_seconds + RoguelikeRelics.SECONDS_PER_LEVEL
	_expect(session.level_manager.level_data.time_limit_seconds == expected_time, "the stage has %d s, expected %d with the Hourglass" % [session.level_manager.level_data.time_limit_seconds, expected_time])

	await get_tree().create_timer(WAIT_FOR_THREE_SECONDS).timeout
	var lemmings := get_tree().root.find_children("*", "CharacterBody2D", true, false)
	_expect(lemmings.size() == TROOP_SIZE, "%d lemmings out, expected %d" % [lemmings.size(), TROOP_SIZE])
	if lemmings.size() == TROOP_SIZE:
		var expected_speed := Constants.WALK_SPEED * (1.0 + 2 * RoguelikeRelics.WALK_SPEED_PER_LEVEL)
		for lemming: LemmingController in lemmings:
			_expect(is_equal_approx(lemming.walk_speed, expected_speed), "a lemming walks at %.1f, expected %.1f" % [lemming.walk_speed, expected_speed])
		var with_parachute := lemmings.filter(func(lemming: LemmingController) -> bool: return lemming.has_floater_skill).size()
		_expect(with_parachute == 2, "%d lemmings have a parachute, expected the first 2" % with_parachute)

		var lemming := lemmings[0] as LemmingController
		var tool_item := _pickup(RoguelikePickupSpec.Kind.TOOL, 1, "bridge")
		session._on_pickup_collected(tool_item, lemming)
		_expect(state.inventory.get_charges("bridge") == 2, "a bridge item gave %d charges, expected 1 + 1 (Collector I)" % state.inventory.get_charges("bridge"))
		var coins_before := state.coins
		session._on_pickup_collected(_pickup(RoguelikePickupSpec.Kind.COINS, 2), lemming)
		_expect(state.coins == coins_before + 4, "a coin item gave %d coins, expected 2 + 2 (Greed II)" % (state.coins - coins_before))

	var bar := get_tree().root.find_child("RoguelikeRelicBar", true, false)
	_expect(bar != null and bar.find_children("Relic_*", "", true, false).size() == state.relics.size(), "the relic bar does not show one slot per relic")
	var quick := bar.find_child("Relic_quick_step", true, false) if bar != null else null
	_expect(quick != null and (quick.get_node("Count") as Label).text == "II", "the relic bar does not show Quick step at level II")

	if _failures.is_empty():
		print("Relic effects: PASS")
		get_tree().quit(0)
		return
	for failure in _failures:
		print("  FAIL: %s" % failure)
	print("Relic effects: FAIL")
	get_tree().quit(1)


func _pickup(kind: RoguelikePickupSpec.Kind, amount: int, tool_id: String = "") -> RoguelikePickup:
	var spec := RoguelikePickupSpec.new()
	spec.kind = kind
	spec.amount = amount
	spec.tool_id = tool_id
	var pickup := RoguelikePickup.new()
	pickup.spec = spec
	return pickup


func _expect(condition: bool, failure: String) -> void:
	if not condition:
		_failures.append(failure)
