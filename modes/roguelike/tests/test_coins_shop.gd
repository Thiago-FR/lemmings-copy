extends Node
## Automated check of what saved lemmings earn: coins, score, the bigger
## card choice for a perfect stage, and the shop. Run via:
##   godot --headless res://modes/roguelike/tests/test_coins_shop.tscn
## Exits 0 when every check passes, 1 otherwise.
##
## Checked:
##   - every lemming saved earns COINS_PER_SAVED coins and score that grows
##     with the stage;
##   - a stage cleared without losses is marked perfect (four cards), one
##     with a loss is not;
##   - the shop sells an offer for its price, applies it and marks it
##     bought; offers the coins cannot pay for stay disabled and spend
##     nothing.

var _failures: Array[String] = []


func _ready() -> void:
	var state := RoguelikeRunState.new_run()
	state.recruit(RoguelikeCharacters.MINER)
	state.recruit(RoguelikeCharacters.SCOUT)
	var three: Array[StringName] = [RoguelikeCharacters.WIZARD, RoguelikeCharacters.MINER, RoguelikeCharacters.SCOUT]
	var none: Array[StringName] = []
	state.finish_stage(three, none)
	_expect(state.coins == 3 * RoguelikeRunState.COINS_PER_SAVED, "3 saved earned %d coins" % state.coins)
	_expect(state.score == 3 * RoguelikeRunState.SCORE_PER_SAVED, "3 saved in stage 1 scored %d" % state.score)
	_expect(state.last_stage_perfect, "a stage with no losses was not perfect")

	var two: Array[StringName] = [RoguelikeCharacters.WIZARD, RoguelikeCharacters.MINER]
	var one_lost: Array[StringName] = [RoguelikeCharacters.SCOUT]
	state.finish_stage(two, one_lost)
	_expect(not state.last_stage_perfect, "a stage with a loss was perfect")
	_expect(state.score == 3 * 10 + 2 * 10 * 2, "score after stage 2 is %d, expected %d" % [state.score, 3 * 10 + 2 * 10 * 2])

	# Enough for the tool (6) but not for the relic (12).
	state.coins = 8
	var coins_before := state.coins
	var cheap := RoguelikeCard.make(RoguelikeCard.Kind.NEW_TOOL, "miner", 2)
	var dear := RoguelikeCard.make(RoguelikeCard.Kind.RELIC, RoguelikeRelics.LONG_BRIDGE)
	var offers: Array[RoguelikeCard] = [cheap, dear]
	var shop := RoguelikeShopScreen.new(state, offers)
	add_child(shop)
	var buttons := shop.find_children("Buy", "Button", true, false)
	var cheap_button := buttons[0] as Button
	var dear_button := buttons[1] as Button
	_expect(dear_button.disabled, "an offer dearer than the coins (%d > %d) was not disabled" % [dear.get_price(), state.coins])
	cheap_button.pressed.emit()
	_expect(state.coins == coins_before - cheap.get_price(), "buying cost %d coins, expected %d" % [coins_before - state.coins, cheap.get_price()])
	_expect(state.inventory.has_tool("miner"), "the bought tool is not in the bar")
	_expect(cheap_button.disabled, "a bought offer can still be bought")
	var coins_after := state.coins
	dear_button.pressed.emit()
	_expect(state.coins == coins_after and not state.relics.has(RoguelikeRelics.LONG_BRIDGE), "an offer the coins cannot pay for was sold")

	if _failures.is_empty():
		print("Coins and shop: PASS")
		get_tree().quit(0)
		return
	for failure in _failures:
		print("  FAIL: %s" % failure)
	print("Coins and shop: FAIL")
	get_tree().quit(1)


func _expect(condition: bool, failure: String) -> void:
	if not condition:
		_failures.append(failure)
