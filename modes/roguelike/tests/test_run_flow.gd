extends Node
## The run from screen to screen, without playing the stages: the
## character screen (locked characters as silhouettes with a price, buying
## one from the vault), starting a stage straight from it, the reward cards
## after a cleared stage (and the recruit that joins), the shop leading
## straight to the next stage, the victory after the last stage, the
## run-end screen when the troop is lost (coins into the vault), and the
## tool templates put back when the mode closes. Stage results are fed
## straight to the controller. Run via:
##   godot --headless res://modes/roguelike/tests/test_run_flow.tscn
## Exits 0 when every check passes, 1 otherwise.

const RUN_SCENE := preload("res://modes/roguelike/scenes/roguelike_run.tscn")
const PROFILE_PATH := "user://test_run_flow_profile.cfg"

var _failures: Array[String] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PROFILE_PATH))
	var dig_speed_before := (SkillManager.create_skill("digger") as SkillDigger).dig_speed
	var run: RoguelikeRunController = RUN_SCENE.instantiate()
	run.profile_path = PROFILE_PATH
	run.use_save_slots = false
	add_child(run)
	await get_tree().process_frame

	_check(_screen_title(run) == "Escolha seu personagem", "the run opens on the character screen (%s)" % _screen_title(run))
	var miner_card := _current_screen(run).find_child("Card_miner", true, false)
	var buy := miner_card.find_child("Buy", true, false) as Button if miner_card != null else null
	_check(buy != null, "a locked character shows a Buy button")
	var portrait := miner_card.find_children("*", "TextureRect", true, false)[0] as TextureRect
	_check(portrait.self_modulate == Color.BLACK, "and its portrait as a black silhouette")
	_check(buy != null and buy.disabled, "it cannot be bought with an empty vault")
	run.profile.deposit(RoguelikeCharacters.get_price(RoguelikeCharacters.MINER))
	run.start_run()
	await get_tree().process_frame
	(_current_screen(run).find_child("Card_miner", true, false).find_child("Buy", true, false) as Button).pressed.emit()
	await get_tree().process_frame
	_check(run.profile.is_unlocked(RoguelikeCharacters.MINER) and run.profile.vault_coins == 0, "buying the Miner spends the vault and unlocks it")
	var play := _current_screen(run).find_child("Card_miner", true, false).find_child("Play", true, false) as Button
	_check(play != null, "the bought character can be played")
	play.pressed.emit()
	await get_tree().process_frame
	_check(_has_session(run), "choosing a character starts stage 1 at once")
	_check(run.state.troop == ([RoguelikeCharacters.MINER] as Array[StringName]), "with a troop of the chosen character")

	for stage in RoguelikeRunState.stage_count() - 1:
		run._on_stage_finished(run.state.troop.duplicate(), [] as Array[StringName])
		await get_tree().process_frame
		# Cleared without losses: four cards instead of three.
		_check(_cards(run).size() == RoguelikeCardPool.PERFECT_OFFER_SIZE, "after a perfect stage %d four reward cards are offered (%d)" % [stage + 1, _cards(run).size()])
		# A recruit joins after each of the first stages only (one per
		# character there is to buy).
		var expected := mini(stage + 2, RoguelikeCharacters.UNLOCK_ORDER.size() + 1)
		_check(run.state.troop.size() >= expected and not run.state.troop.has(RoguelikeCharacters.WIZARD), "and the troop grew as it should (troop of %d, %d expected)" % [run.state.troop.size(), expected])
		if _cards(run).is_empty():
			break
		(_cards(run)[0] as BaseButton).pressed.emit()
		await get_tree().process_frame
		_check(_screen_title(run) == "Loja", "picking a card leads to the shop (%s)" % _screen_title(run))
		_press(run, "Seguir para a fase")
		await get_tree().process_frame
		_check(_has_session(run) and run.state.stage_index == stage + 1, "leaving the shop starts stage %d" % (stage + 2))

	run._on_stage_finished(run.state.troop.duplicate(), [] as Array[StringName])
	await get_tree().process_frame
	_check(_screen_title(run) == "Vitória!", "clearing stage 5 wins the run")

	_press(run, "Jogar de novo")
	await get_tree().process_frame
	_check(_screen_title(run) == "Escolha seu personagem", "Jogar de novo goes back to the character screen")
	run._on_character_chosen(RoguelikeCharacters.WIZARD)
	await get_tree().process_frame
	_check(run.state.stage_index == 0 and run.state.troop.size() == 1, "and a fresh run starts")
	run.state.coins = 7
	var vault_before := run.profile.vault_coins
	run._on_stage_finished([] as Array[StringName], run.state.troop.duplicate())
	await get_tree().process_frame
	_check(_screen_title(run) == "Fim da run", "losing the whole troop ends the run")
	_check(run.profile.vault_coins == vault_before + 7, "the coins left go into the vault (%d -> %d)" % [vault_before, run.profile.vault_coins])
	_check(_find_button(run, "Jogar de novo") != null and _find_button(run, "Menu") != null, "the run-end screen offers Jogar de novo and Menu")

	run.state.add_relic(RoguelikeRelics.SHARP_BLADES)
	run.relics.apply_templates(run.state.relic_levels)
	remove_child(run)
	run.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PROFILE_PATH))
	var dig_speed_after := (SkillManager.create_skill("digger") as SkillDigger).dig_speed
	_check(is_equal_approx(dig_speed_after, dig_speed_before), "closing the mode puts the tool templates back")

	if _failures.is_empty():
		print("Run flow: PASS")
	else:
		print("Run flow: FAIL\n  " + "\n  ".join(_failures))
	get_tree().quit(0 if _failures.is_empty() else 1)


func _check(condition: bool, description: String) -> void:
	print("  [%s] %s" % ["ok" if condition else "FAIL", description])
	if not condition:
		_failures.append(description)


func _has_session(run: Node) -> bool:
	for child in run.get_children():
		if child is RoguelikeStageSession:
			return true
	return false


func _current_screen(run: Node) -> RoguelikeOverlayScreen:
	for child in run.get_children():
		if child is RoguelikeOverlayScreen and not child.is_queued_for_deletion():
			return child
	return null


func _screen_title(run: Node) -> String:
	var screen := _current_screen(run)
	if screen == null:
		return "(no screen)"
	return (screen.content.get_child(0) as Label).text


func _find_button(run: Node, text: String) -> Button:
	var screen := _current_screen(run)
	if screen == null:
		return null
	for node in screen.find_children("*", "Button", true, false):
		if (node as Button).text == text:
			return node
	return null


func _press(run: Node, text: String) -> void:
	var button := _find_button(run, text)
	if button == null:
		_check(false, "button '%s' is on screen" % text)
		return
	button.pressed.emit()


func _cards(run: Node) -> Array:
	var screen := _current_screen(run)
	if screen == null:
		return []
	return screen.find_children("Card*", "BaseButton", true, false)
