class_name RoguelikeRunController
extends Node
## The roguelike mode's entry point (roguelike_run.tscn): plays a run of
## RoguelikeRunState.STAGE_COUNT stages in one scene. A run opens on the
## character screen, then goes stage, reward cards, shop, next stage, and
## ends on the run-end screen; during a stage a RoguelikeStageSession runs
## the level. There is no stage intro screen any more: the user found its
## text unnecessary.
##
## The run stays in this scene from start to end (no scene changes), so the
## run state needs no autoload: it lives here and dies with the mode. What
## outlives a run (the coin vault, the unlocked characters) is the profile.

## Where the profile is saved; tests point it elsewhere before _ready.
var profile_path := RoguelikeProfile.DEFAULT_PATH
var profile: RoguelikeProfile = null
var state: RoguelikeRunState = null
var relics := RoguelikeRelics.new()

var _rng := RandomNumberGenerator.new()
var _session: RoguelikeStageSession = null
var _screen: RoguelikeOverlayScreen = null


func _ready() -> void:
	relics.save_templates()
	_rng.randomize()
	profile = RoguelikeProfile.load_from(profile_path)
	start_run()


func _exit_tree() -> void:
	# The tool templates are global: leave them as the run found them.
	relics.restore_templates()
	SkillManager.selected_skill_id = ""


## Opens the character screen; the run itself starts once one is chosen.
func start_run() -> void:
	state = null
	var screen := RoguelikeCharacterSelectScreen.new(profile)
	screen.character_chosen.connect(_on_character_chosen)
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
		_offer_rewards("(modo desenvolvedor) Indo para a fase %d" % (stage_index + 1)))
	screen.reward_screen_requested.connect(func() -> void: _offer_rewards("(modo desenvolvedor)"))
	screen.closed.connect(back)
	_show_screen(screen)


func _start_stage() -> void:
	_close_screen()
	_session = RoguelikeStageSession.new()
	_session.state = state
	_session.relics = relics
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
	var revived := state.finish_stage(saved, lost)
	var summary := "Salvos: %d   Perdidos: %d   +%d moedas" % [saved.size(), lost.size(), saved.size() * state.coins_per_saved()]
	for character in revived:
		summary += "\nA pena da fênix trouxe de volta: %s" % RoguelikeCharacters.get_display_name(character)
	if state.is_over():
		_show_run_over(summary)
	elif state.is_won():
		_show_victory(summary)
	else:
		_offer_rewards(summary)


func _offer_rewards(summary: String) -> void:
	var recruit := state.recruit_for_cleared_stage()
	if recruit != &"":
		summary += "\n%s entrou na tropa!" % RoguelikeCharacters.get_display_name(recruit)
	var size := RoguelikeCardPool.OFFER_SIZE
	if state.last_stage_perfect:
		size = RoguelikeCardPool.PERFECT_OFFER_SIZE
		summary += "\nNinguém perdido: escolha entre %d cartas!" % size
	var screen := RoguelikeCardScreen.new(RoguelikeCardPool.draw_offer(state, _rng, size), summary)
	screen.card_chosen.connect(_on_card_chosen)
	_show_screen(screen)


func _on_card_chosen(card: RoguelikeCard) -> void:
	card.apply(state)
	_show_shop()


## Spends the coins earned before the next stage, which starts on leaving.
func _show_shop() -> void:
	var screen := RoguelikeShopScreen.new(state, RoguelikeCardPool.draw_offer(state, _rng, RoguelikeShopScreen.OFFER_SIZE))
	screen.closed.connect(_start_stage)
	if GameManager.developer_mode:
		screen.add_icon_buttons([["dev", "Modo desenvolvedor", _show_dev_screen.bind(_show_shop), "Dev"]])
	_show_screen(screen)


func _show_run_over(summary: String) -> void:
	_show_run_end(false, summary)


func _show_victory(summary: String) -> void:
	# Survivors multiply the score: finishing with more lemmings is worth more.
	state.score *= maxi(state.troop.size(), 1)
	_show_run_end(true, summary)


## The coins left go into the vault, for unlocking characters.
func _show_run_end(won: bool, summary: String) -> void:
	var deposited := state.coins
	profile.deposit(deposited)
	state.coins = 0
	var screen := RoguelikeRunEndScreen.new(state, won, summary, deposited, profile.vault_coins)
	screen.play_again_requested.connect(start_run)
	_show_screen(screen)


func _show_screen(screen: RoguelikeOverlayScreen) -> void:
	_close_screen()
	_screen = screen
	add_child(screen)


func _close_screen() -> void:
	if _screen != null:
		_screen.queue_free()
		_screen = null
