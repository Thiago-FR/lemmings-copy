class_name RoguelikeRunController
extends Node
## The roguelike mode's entry point (roguelike_run.tscn): plays a run of
## RoguelikeRunState.stage_count() stages in one scene. A run opens on the
## character screen, then goes stage, reward cards, shop, next stage, and
## ends on the run-end screen; during a stage a RoguelikeStageSession runs
## the level. There is no stage intro screen any more: the user found its
## text unnecessary.
##
## The run stays in this scene from start to end (no scene changes), so the
## run state needs no autoload: it lives here and dies with the mode. What
## outlives a run (the coin vault, the unlocked characters) is the profile.
##
## Saved games (SaveSlots, mode SAVE_MODE): the mode opens on its saved
## games; each is a profile and, while a run is under way, the run, written
## at each point between stages (RUN_FILE: about to play a stage, or in the
## shop) and saved automatically there. Loading a game in the middle of a
## run goes back to that point: a stage being played starts over.

const SAVE_MODE := "roguelike"
## The run controller's group, for the stage HUD's menu button.
const GROUP := &"roguelike_run"
const PROFILE_FILE := "profile.cfg"
const RUN_FILE := "run.cfg"
const RUN_SECTION := "run"
## Where the run is, in the saved run: about to play a stage, or the shop.
const AT_STAGE := "stage"
const AT_SHOP := "shop"

## Where the profile is saved; tests point it elsewhere before _ready.
var profile_path := RoguelikeProfile.DEFAULT_PATH
## Opens on the saved games. Tests turn it off before _ready and go
## straight to a run with profile_path.
var use_save_slots := true
const MENU_NAME := "RunMenu"
var profile: RoguelikeProfile = null
var state: RoguelikeRunState = null
var relics := RoguelikeRelics.new()

var _rng := RandomNumberGenerator.new()
var _session: RoguelikeStageSession = null
var _screen: RoguelikeOverlayScreen = null


func _ready() -> void:
	add_to_group(GROUP)
	relics.save_templates()
	_rng.randomize()
	if use_save_slots:
		_show_saved_games()
		return
	profile = RoguelikeProfile.load_from(profile_path)
	start_run()


## The mode's menu (new game, load, settings, main menu). The profile kept
## before there were saved games becomes the first. A new game opens the
## character screen; a loaded one resumes its run.
func _show_saved_games() -> void:
	var legacy := RoguelikeProfile.load_from(RoguelikeProfile.DEFAULT_PATH)
	SaveSlots.adopt_legacy_file(SAVE_MODE, RoguelikeProfile.DEFAULT_PATH, PROFILE_FILE, _profile_summary(legacy))
	_add_menu(false)


## The mode's menu in the middle of the game (the stage HUD's Menu button
## and Esc), over the paused stage.
func open_game_menu() -> void:
	if get_node_or_null(MENU_NAME) != null:
		return
	_add_menu(true)


func _add_menu(in_game: bool) -> void:
	var menu := GameMenu.new(SAVE_MODE, "Roguelike", in_game)
	menu.name = MENU_NAME
	menu.new_game_chosen.connect(_switch_to_saved_game)
	menu.load_chosen.connect(_switch_to_saved_game)
	menu.main_menu_requested.connect(GameManager.go_to_main_menu)
	add_child(menu)


## Leaves whatever is on show (a stage, a screen) for the saved game.
func _switch_to_saved_game(slot: int) -> void:
	if _session != null:
		remove_child(_session)
		_session.queue_free()
		_session = null
	_close_screen()
	GameManager.resume_game()
	SkillManager.selected_skill_id = ""
	state = null
	_open_saved_game(slot)


func _open_saved_game(slot: int) -> void:
	SaveSlots.open(SAVE_MODE, slot, _summary)
	profile_path = SaveSlots.working_path(PROFILE_FILE)
	profile = RoguelikeProfile.load_from(profile_path)
	var run := ConfigFile.new()
	if run.load(SaveSlots.working_path(RUN_FILE)) != OK:
		start_run()
		return
	state = RoguelikeRunState.from_dictionary(run.get_value(RUN_SECTION, "state"))
	if run.get_value(RUN_SECTION, "at", AT_STAGE) == AT_SHOP:
		_show_shop()
	else:
		_start_stage()


## Writes the run where it stands between stages and saves the game
## automatically (unless turned off). Nothing without a saved game.
func _keep_run(at: String) -> void:
	if not SaveSlots.is_active(SAVE_MODE):
		return
	var run := ConfigFile.new()
	run.set_value(RUN_SECTION, "state", state.to_dictionary())
	run.set_value(RUN_SECTION, "at", at)
	run.save(SaveSlots.working_path(RUN_FILE))
	SaveSlots.auto_save()


## The run is over: only the profile is left to keep.
func _end_kept_run() -> void:
	if not SaveSlots.is_active(SAVE_MODE):
		return
	DirAccess.remove_absolute(SaveSlots.working_path(RUN_FILE))
	SaveSlots.auto_save()


## The game's line in the saved games list: the run under way, or the vault.
func _summary() -> String:
	if state != null and not state.is_over() and not state.is_won() and FileAccess.file_exists(SaveSlots.working_path(RUN_FILE)):
		var character: Dictionary = RoguelikeCharacters.DEFINITIONS.get(state.character_id, {})
		return "%s: fase %d de %d" % [character.get("name", ""), state.stage_index + 1, RoguelikeRunState.stage_count()]
	# A new game is saved as it opens, before its profile is loaded.
	return _profile_summary(profile if profile != null else RoguelikeProfile.load_from(SaveSlots.working_path(PROFILE_FILE)))


static func _profile_summary(saved_profile: RoguelikeProfile) -> String:
	return "Sem run em andamento, cofre %d moedas" % saved_profile.vault_coins


func _exit_tree() -> void:
	# The tool templates are global: leave them as the run found them.
	relics.restore_templates()
	SkillManager.selected_skill_id = ""


## Opens the character screen; the run itself starts once one is chosen.
func start_run() -> void:
	state = null
	var screen := RoguelikeCharacterSelectScreen.new(profile)
	screen.character_chosen.connect(_on_character_chosen)
	screen.menu_requested.connect(func() -> void:
		if use_save_slots:
			_add_menu(false)
		else:
			GameManager.go_to_main_menu())
	screen.developer_requested.connect(func() -> void:
		state = RoguelikeRunState.new_run()
		_show_dev_screen(start_run))
	_show_screen(screen)


func _on_character_chosen(character: StringName) -> void:
	# Keeps a state the developer screen already set up (cards applied,
	# stage chosen) if it was made for this character.
	if state == null or state.character_id != character:
		state = RoguelikeRunState.new_run(character)
	_start_stage()


## Testing tools (developer mode): jump to a stage, apply any card, try the
## reward screen. back is where closing it returns.
func _show_dev_screen(back: Callable) -> void:
	var screen := RoguelikeDevScreen.new(state, profile)
	# Jumping to a stage offers the reward cards first, as arriving there in a
	# real run would; the user missed them when testing stage 2.
	screen.stage_chosen.connect(func(stage_index: int) -> void:
		state.stage_index = stage_index
		_offer_rewards(null))
	screen.reward_screen_requested.connect(func() -> void: _offer_rewards(null))
	screen.closed.connect(back)
	_show_screen(screen)


func _start_stage() -> void:
	_close_screen()
	_keep_run(AT_STAGE)
	_session = RoguelikeStageSession.new()
	_session.state = state
	_session.relics = relics
	_session.profile = profile
	_session.stage_finished.connect(_on_stage_finished)
	add_child(_session)


func _on_stage_finished(saved: Array[StringName], lost: Array[StringName]) -> void:
	# Out of the tree at once: the next stage's lemmings look the terrain up
	# by group, and must not find this one's.
	remove_child(_session)
	_session.queue_free()
	_session = null
	GameManager.resume_game()
	SkillManager.selected_skill_id = ""
	var summary := RoguelikeStageSummary.new()
	summary.saved = saved.size()
	summary.lost = lost.size()
	summary.coins = saved.size() * state.coins_per_saved()
	if not saved.is_empty():
		summary.time_bonus = state.time_bonus()
	summary.revived = state.finish_stage(saved, lost)
	if not summary.revived.is_empty():
		await _play_revive(summary.revived)
	if state.is_over():
		_show_run_over(summary)
	elif state.is_won():
		_show_victory(summary)
	else:
		_offer_rewards(summary)


## summary: what the stage brought (null from the developer screen).
func _offer_rewards(summary: RoguelikeStageSummary) -> void:
	var recruit := state.recruit_for_cleared_stage()
	var size := RoguelikeCardPool.OFFER_SIZE
	if state.last_stage_perfect:
		size = RoguelikeCardPool.PERFECT_OFFER_SIZE
	if summary != null:
		summary.joined = recruit
		summary.perfect = state.last_stage_perfect
	var offer := RoguelikeCardPool.draw_offer(state, _rng, size)
	_discover_cards(offer)
	var screen := RoguelikeCardScreen.new(offer, summary)
	screen.card_chosen.connect(_on_card_chosen)
	_show_screen(screen)


func _on_card_chosen(card: RoguelikeCard) -> void:
	var troop_before := state.troop.size()
	card.apply(state)
	# A phoenix feather card brings the last one lost back at once: shown.
	if card.kind == RoguelikeCard.Kind.REVIVE and state.troop.size() > troop_before:
		await _play_revive(state.troop.slice(troop_before))
	_show_shop()


## The phoenix animation for each lemming brought back; waits for it.
func _play_revive(characters: Array[StringName]) -> void:
	var animation := RoguelikeReviveAnimation.new(characters)
	add_child(animation)
	await animation.finished


## Spends the coins earned before the next stage, which starts on leaving.
func _show_shop() -> void:
	var offer := RoguelikeCardPool.draw_offer(state, _rng, RoguelikeShopScreen.OFFER_SIZE)
	_discover_cards(offer)
	var screen := RoguelikeShopScreen.new(state, offer)
	screen.closed.connect(_start_stage)
	_keep_run(AT_SHOP)
	if SaveSlots.is_active(SAVE_MODE):
		screen.add_icon_buttons([]).add_child(GameMenu.make_save_button())
	if GameManager.developer_mode:
		screen.add_icon_buttons([["dev", "Modo desenvolvedor", _show_dev_screen.bind(_show_shop), "Dev"]])
	_show_screen(screen)


## A card offered has been read: its kind, relic or tool go into the
## compendium.
func _discover_cards(cards: Array[RoguelikeCard]) -> void:
	var entry_ids: Array[String] = []
	for card in cards:
		entry_ids.append_array(RoguelikeDiscovery.for_card(card))
	profile.discover_all(entry_ids)


func _show_run_over(summary: RoguelikeStageSummary) -> void:
	_show_run_end(false, summary)


func _show_victory(summary: RoguelikeStageSummary) -> void:
	# Survivors multiply the score: finishing with more lemmings is worth more.
	state.score *= maxi(state.troop.size(), 1)
	_show_run_end(true, summary)


## The coins left go into the vault, for unlocking characters.
func _show_run_end(won: bool, summary: RoguelikeStageSummary) -> void:
	var deposited := state.coins
	profile.deposit(deposited)
	state.coins = 0
	var rank := profile.record_run(state.score, state.character_id, mini(state.stage_index + 1, RoguelikeRunState.stage_count()), won)
	_end_kept_run()
	var screen := RoguelikeRunEndScreen.new(state, won, summary, deposited, profile.vault_coins, rank)
	screen.play_again_requested.connect(start_run)
	screen.ranking_requested.connect(_show_ranking.bind(rank, screen))
	_show_screen(screen)


## The best runs; highlight is the row just made (-1 for none). Closing it
## goes back to the screen that opened it.
func _show_ranking(highlight: int, back: RoguelikeOverlayScreen) -> void:
	var ranking := RoguelikeRankingScreen.new(profile, highlight)
	ranking.closed.connect(ranking.queue_free)
	back.add_child(ranking)


func _show_screen(screen: RoguelikeOverlayScreen) -> void:
	_close_screen()
	_screen = screen
	add_child(screen)


func _close_screen() -> void:
	if _screen != null:
		_screen.queue_free()
		_screen = null
