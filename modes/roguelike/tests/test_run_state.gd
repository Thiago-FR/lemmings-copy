extends Node
## Rules of a run without playing it: the tool bar's slots and limit, the
## troop carried from stage to stage, rescues, recruits, every kind of reward
## card, the card offer, and relics retuning the tool templates and putting
## them back. Run via:
##   godot --headless res://modes/roguelike/tests/test_run_state.tscn
## Exits 0 when every check passes, 1 otherwise.

var _failures: Array[String] = []


func _ready() -> void:
	_test_inventory_slots()
	_test_inventory_eviction()
	_test_inventory_empty_slots()
	_test_troop_carry_over()
	_test_revive_tokens()
	_test_recruits()
	_test_cards()
	_test_card_offer()
	_test_relic_templates()
	_test_stage_definitions_build()
	if _failures.is_empty():
		print("Run state: PASS")
	else:
		print("Run state: FAIL\n  " + "\n  ".join(_failures))
	get_tree().quit(0 if _failures.is_empty() else 1)


func _check(condition: bool, description: String) -> void:
	print("  [%s] %s" % ["ok" if condition else "FAIL", description])
	if not condition:
		_failures.append(description)


func _test_inventory_slots() -> void:
	var inventory := RoguelikeToolInventory.new()
	_check(inventory.get_tool_ids().is_empty(), "the bar starts empty")
	inventory.add_charges("digger", 2)
	inventory.add_charges("bridge", 1)
	inventory.add_charges("digger", 1)
	_check(inventory.get_tool_ids() == (["digger", "bridge"] as Array[String]), "a slot per new tool, in pick-up order")
	_check(inventory.get_charges("digger") == 3, "charges of a tool already carried add up")
	_check(inventory.spend("bridge") and inventory.get_charges("bridge") == 0, "spending takes one charge")
	_check(not inventory.spend("bridge"), "a tool with no charges cannot be spent")
	_check(not inventory.spend("tnt"), "a tool not carried cannot be spent")


func _test_inventory_eviction() -> void:
	var inventory := RoguelikeToolInventory.new()
	for tool_id in ["floater", "climber", "block", "tnt"]:
		inventory.add_charges(tool_id, 2)
	_check(inventory.is_full(), "four tools fill the bar")
	inventory.spend("floater")
	var evicted := inventory.add_charges("digger", 1)
	_check(evicted == "climber", "a full bar drops the tool touched longest ago (got '%s')" % evicted)
	_check(inventory.get_tool_ids().size() == 4 and inventory.has_tool("digger"), "the new tool takes its slot")
	inventory.spend("tnt")
	inventory.spend("tnt")
	evicted = inventory.add_charges("bridge", 1)
	_check(evicted == "tnt", "a slot with no charges goes first (got '%s')" % evicted)
	evicted = inventory.add_charges("miner", 1)
	_check(evicted == "block" and inventory.has_tool("digger") and inventory.has_tool("bridge"), "tools picked up in this stage are kept over older ones")
	inventory.add_slot()
	_check(inventory.max_slots == 5 and not inventory.is_full(), "an extra pocket adds a slot")


func _test_inventory_empty_slots() -> void:
	var inventory := RoguelikeToolInventory.new()
	inventory.add_charges("digger", 1)
	inventory.add_charges("bridge", 1)
	inventory.spend("digger")
	inventory.remove_empty_slots()
	_check(inventory.get_tool_ids() == (["bridge"] as Array[String]), "empty slots are freed between stages")
	_check(inventory.to_counts() == {"bridge": 1}, "the bar converts to LevelData skill counts")


func _test_troop_carry_over() -> void:
	var state := RoguelikeRunState.new_run()
	_check(state.troop == ([RoguelikeCharacters.WIZARD] as Array[StringName]), "a run starts with one Wizard")
	state.troop.assign([&"wizard", &"miner", &"engineer"])
	state.inventory.add_charges("digger", 1)
	state.inventory.spend("digger")
	state.finish_stage([&"wizard", &"engineer"] as Array[StringName], [&"miner"] as Array[StringName])
	_check(state.troop == ([&"wizard", &"engineer"] as Array[StringName]), "only the lemmings saved go on")
	_check(state.fallen == ([&"miner"] as Array[StringName]), "the lost ones are remembered")
	_check(state.stage_index == 1, "the next stage comes up")
	_check(not state.inventory.has_tool("digger"), "a used-up tool leaves the bar after the stage")
	state.finish_stage([] as Array[StringName], [&"wizard", &"engineer"] as Array[StringName])
	_check(state.is_over() and state.stage_index == 1, "losing everyone ends the run on that stage")


func _test_revive_tokens() -> void:
	var state := RoguelikeRunState.new_run()
	state.revive_tokens = 1
	var revived := state.finish_stage([] as Array[StringName], [&"wizard"] as Array[StringName])
	_check(revived == ([&"wizard"] as Array[StringName]) and not state.is_over(), "a rescue in hand brings back the last one lost and saves the run")
	_check(state.revive_tokens == 0, "the rescue is used up")
	state.revive_tokens = 2
	revived = state.finish_stage([&"wizard"] as Array[StringName], [] as Array[StringName])
	_check(revived.is_empty() and state.revive_tokens == 2, "rescues are kept when nobody was lost")


func _test_recruits() -> void:
	var state := RoguelikeRunState.new_run(RoguelikeCharacters.MINER)
	_check(state.troop == ([RoguelikeCharacters.MINER] as Array[StringName]), "a run starts with one lemming of the chosen character")
	state.finish_stage(state.troop.duplicate(), [] as Array[StringName])
	var recruit := state.recruit_for_cleared_stage()
	_check(recruit == RoguelikeCharacters.MINER and state.troop.size() == 2, "clearing stage 1 recruits one more of the run's character")
	_check(state.unlocked_characters == ([RoguelikeCharacters.MINER] as Array[StringName]), "recruit cards offer only the run's character")
	_test_profile()
	for character in RoguelikeCharacters.DEFINITIONS:
		_check(RoguelikeCharacters.get_display_name(character) != "" and RoguelikeCharacters.get_ability(character) != "", "character '%s' has a name and an ability" % character)


## The coin vault and unlocks, saved to a test file (never the player's).
func _test_profile() -> void:
	var path := "user://test_roguelike_profile.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	var profile := RoguelikeProfile.load_from(path)
	_check(profile.unlocked == ([RoguelikeCharacters.STARTER] as Array[StringName]) and profile.vault_coins == 0, "a new profile has only the starter and an empty vault")
	var price := RoguelikeCharacters.get_price(RoguelikeCharacters.MINER)
	profile.deposit(price - 1)
	_check(not profile.buy(RoguelikeCharacters.MINER) and profile.vault_coins == price - 1, "a character the vault cannot pay for is not sold")
	profile.deposit(1)
	_check(profile.buy(RoguelikeCharacters.MINER) and profile.vault_coins == 0, "buying a character spends its price")
	_check(not profile.buy(RoguelikeCharacters.MINER), "a character cannot be bought twice")
	var reloaded := RoguelikeProfile.load_from(path)
	_check(reloaded.is_unlocked(RoguelikeCharacters.MINER) and reloaded.vault_coins == 0, "the vault and unlocks are saved")
	_check(profile.record_run(100, &"wizard", 2, false) == 0, "the first run is first in the ranking")
	_check(profile.record_run(300, &"miner", 5, true) == 0, "a better run goes on top")
	_check(profile.record_run(200, &"wizard", 3, false) == 1, "a middle run goes in the middle")
	for filler in RoguelikeProfile.RANKING_SIZE:
		profile.record_run(150, &"wizard", 2, false)
	_check(profile.ranking.size() == RoguelikeProfile.RANKING_SIZE, "the ranking keeps %d runs (%d)" % [RoguelikeProfile.RANKING_SIZE, profile.ranking.size()])
	_check(profile.record_run(50, &"wizard", 1, false) == -1, "a run worse than all ten does not make it")
	var saved_ranking := RoguelikeProfile.load_from(path)
	_check(saved_ranking.ranking.size() == RoguelikeProfile.RANKING_SIZE and int(saved_ranking.ranking[0].score) == 300 and bool(saved_ranking.ranking[0].won), "the ranking is saved, best first")
	var timed := RoguelikeRunState.new_run()
	timed.stage_index = 2
	timed.last_time_left = 40.7
	var score_before := timed.score
	timed.finish_stage([&"wizard"] as Array[StringName], [] as Array[StringName])
	_check(timed.score - score_before == RoguelikeRunState.SCORE_PER_SAVED * 3 + 40 * 3, "40 s left in stage 3 add 120 points to the 30 of the saved lemming (%d)" % (timed.score - score_before))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _test_cards() -> void:
	var state := RoguelikeRunState.new_run()
	RoguelikeCard.make(RoguelikeCard.Kind.NEW_TOOL, "bridge", 2).apply(state)
	_check(state.inventory.get_charges("bridge") == 2, "a new-tool card adds the tool with its charges")
	RoguelikeCard.make(RoguelikeCard.Kind.CHARGES, "bridge", 3).apply(state)
	_check(state.inventory.get_charges("bridge") == 5, "a charges card adds charges")
	RoguelikeCard.make(RoguelikeCard.Kind.RECRUIT, "scout").apply(state)
	_check(state.troop.has(&"scout"), "a recruit card adds a lemming")
	RoguelikeCard.make(RoguelikeCard.Kind.RELIC, "extra_pocket").apply(state)
	_check(state.relics.has(&"extra_pocket") and state.inventory.max_slots == 5, "the extra pocket relic adds a slot")
	_test_relic_levels()
	RoguelikeCard.make(RoguelikeCard.Kind.REVIVE).apply(state)
	_check(state.revive_tokens == 1, "a rescue card with nobody lost keeps a rescue for later")
	state.fallen.append(&"miner")
	RoguelikeCard.make(RoguelikeCard.Kind.REVIVE).apply(state)
	_check(state.troop.has(&"miner") and state.fallen.is_empty(), "a rescue card brings back the last one lost")
	for kind in RoguelikeCard.Kind.values():
		var card := RoguelikeCard.make(kind, "digger" if kind <= RoguelikeCard.Kind.NEW_TOOL else ("miner" if kind == RoguelikeCard.Kind.RECRUIT else "short_fuse"), 2)
		_check(card.get_title() != "" and card.get_description() != "", "card kind %s has a title and a description" % RoguelikeCard.Kind.keys()[kind])


## Taking a relic again raises its level, up to the top one, where it is no
## longer offered; its card says the level it goes to, and costs more.
func _test_relic_levels() -> void:
	var state := RoguelikeRunState.new_run()
	for expected in [1, 2, 3, 3]:
		state.add_relic(RoguelikeRelics.GREED)
		_check(state.get_relic_level(RoguelikeRelics.GREED) == expected, "Greed taken again is at level %d (%d)" % [expected, state.get_relic_level(RoguelikeRelics.GREED)])
	_check(state.relics.count(RoguelikeRelics.GREED) == 1, "a relic is listed once, whatever its level")
	_check(state.coins_per_saved() == RoguelikeRunState.COINS_PER_SAVED + 3, "Greed III adds 3 coins per saved lemming")
	var rng := RandomNumberGenerator.new()
	for attempt in 50:
		for card in RoguelikeCardPool.draw_offer(state, rng, 5):
			if card.kind == RoguelikeCard.Kind.RELIC and card.subject == String(RoguelikeRelics.GREED):
				_check(false, "a relic at the top level is still offered")
				return
	state.add_relic(RoguelikeRelics.EXTRA_POCKET)
	state.add_relic(RoguelikeRelics.EXTRA_POCKET)
	_check(state.inventory.max_slots == RoguelikeToolInventory.DEFAULT_MAX_SLOTS + 2, "Extra pocket II adds two slots (%d)" % state.inventory.max_slots)
	var next := RoguelikeCard.make(RoguelikeCard.Kind.RELIC, RoguelikeRelics.EXTRA_POCKET, 3)
	_check(next.get_title().ends_with("III") and next.get_price() > RoguelikeCard.make(RoguelikeCard.Kind.RELIC, RoguelikeRelics.EXTRA_POCKET, 1).get_price(), "a level III card says so and costs more")


func _test_card_offer() -> void:
	var state := RoguelikeRunState.new_run()
	state.inventory.add_charges("digger", 1)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for attempt in 20:
		var offer := RoguelikeCardPool.draw_offer(state, rng)
		var kinds := {}
		for card in offer:
			kinds[card.kind] = true
		if offer.size() != 3 or kinds.size() != 3:
			_check(false, "an offer is three cards of three different kinds (got %d cards, %d kinds)" % [offer.size(), kinds.size()])
			return
	_check(true, "an offer is three cards of three different kinds")


func _test_relic_templates() -> void:
	var relics := RoguelikeRelics.new()
	relics.save_templates()
	var before_dig := (SkillManager.create_skill("digger") as SkillDigger).dig_speed
	var before_fuse := (SkillManager.create_skill("tnt") as SkillExplosive).fuse_seconds
	var levels := {RoguelikeRelics.SHARP_BLADES: 2, RoguelikeRelics.SHORT_FUSE: 3}
	relics.apply_templates(levels)
	relics.apply_templates(levels)
	var upgraded_dig := (SkillManager.create_skill("digger") as SkillDigger).dig_speed
	_check(is_equal_approx(upgraded_dig, before_dig * (1.0 + 2 * RoguelikeRelics.DIG_SPEED_PER_LEVEL)), "sharp blades II speed the shovel up by 50%, once however often applied")
	_check(is_equal_approx((SkillManager.create_skill("tnt") as SkillExplosive).fuse_seconds, before_fuse - 3 * RoguelikeRelics.FUSE_SECONDS_CUT_PER_LEVEL), "short fuse III cuts the TNT fuse by 1.5 s")
	relics.restore_templates()
	_check(is_equal_approx((SkillManager.create_skill("digger") as SkillDigger).dig_speed, before_dig), "restoring puts the shovel back")
	_check(is_equal_approx((SkillManager.create_skill("tnt") as SkillExplosive).fuse_seconds, before_fuse), "restoring puts the fuse back")


func _test_stage_definitions_build() -> void:
	# Generated stages are drawn and solved, which takes a while: the
	# hand-made ones and a generated stage from a few biomes.
	for handmade in [false, true]:
		for index in [0, 1, 2, 3, 4, 9, 27]:
			var state := RoguelikeRunState.new_run()
			state.use_handmade_stages = handmade
			state.stage_index = index
			var definition := state.get_stage_definition()
			var builder := RoguelikeStageBuilder.new()
			var level := builder.build(definition)
			var used := (level.get_node("Terrain") as TerrainDestructible).get_used_rect()
			var size := Vector2i(definition.maze.columns, definition.maze.rows)
			_check(used.end.x <= size.x and used.end.y <= size.y and used.size.x > 0, "%s stage %d is built at its maze's size, %dx%d blocks (%dx%d)" % ["hand-made" if handmade else "generated", index + 1, size.x, size.y, used.size.x, used.size.y])
			level.free()
