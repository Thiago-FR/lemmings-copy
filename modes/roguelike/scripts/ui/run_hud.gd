class_name RoguelikeRunHud
extends CanvasLayer
## The bar at the top of a roguelike stage: which stage of the run this is,
## then each count as an icon and a number (troop, still in the stage,
## saved, lost, the clock, rescues in hand, coins), each with a tooltip
## saying what it is. At the right, the same icon buttons as the editor:
## Pause (P), Sacrifice, End stage, Settings and Menu (Esc). Sacrifice is
## here, not in the tool bar, so it is not taken for a tool or for a
## character's ability.
##
## No hint on how to solve the stage: the user wants the game (a tutorial,
## later), not text, to teach the tools. Restarting a stage is left out on
## purpose: in a run a stage is played once. Ending it is not: a player
## whose remaining lemmings are stuck should not have to sit out the clock.
##
## Reads everything from the LevelManager it is added to, through signals.

const MARGIN := 8
const SEPARATION := 14
## Between an icon and its number.
const ICON_GAP := 2
const BUTTON_SEPARATION := 4
const SACRIFICE_TOOLTIP := "Sacrificar (sem limite): ligue e clique num boneco preso. Cada sacrificado deixa 1 moeda."

var _state: RoguelikeRunState
var _definition: RoguelikeStageDefinition
var _session: RoguelikeStageSession
var _level_manager: LevelManager
var _troop_label: Label
var _out_label: Label
var _saved_label: Label
var _lost_label: Label
var _time_label: Label
var _rescues_label: Label
var _coins_label: Label
var _pause_button: Button
var _end_stage_button: Button
var _sacrifice_button: Button
var _paused_by_dialog := false


func _init(state: RoguelikeRunState, definition: RoguelikeStageDefinition, session: RoguelikeStageSession) -> void:
	_state = state
	_definition = definition
	_session = session
	name = "RoguelikeHud"


func _ready() -> void:
	_level_manager = get_parent() as LevelManager
	assert(_level_manager != null, "RoguelikeRunHud must be a child of the stage's LevelManager")
	_build_info_bar()
	_build_controls()
	_level_manager.counts_changed.connect(_on_counts_changed)
	_level_manager.time_remaining_changed.connect(_on_time_changed)
	_level_manager.level_completed.connect(_on_level_ended)
	_level_manager.level_failed.connect(_on_level_ended)
	_on_counts_changed(0, 0, 0, _level_manager.level_data.total_lemmings)
	_on_time_changed(_level_manager.time_remaining)


func _process(_delta: float) -> void:
	_rescues_label.text = str(_state.revive_tokens)
	_coins_label.text = str(_state.coins)


func _build_info_bar() -> void:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiStyle.panel_style())
	panel.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	panel.position = Vector2(MARGIN, MARGIN)
	add_child(panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", SEPARATION)
	panel.add_child(row)

	var stage_label := Label.new()
	stage_label.text = _definition.stage_name
	stage_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(stage_label)
	row.add_child(VSeparator.new())
	_troop_label = _add_counter(row, "hud_troop", "Tropa: bonecos que entraram nesta fase")
	_out_label = _add_counter(row, "hud_out", "Na fase: bonecos andando agora")
	_saved_label = _add_counter(row, "hud_saved", "Salvos: chegaram à saída e seguem na run")
	_lost_label = _add_counter(row, "hud_lost", "Perdidos")
	row.add_child(VSeparator.new())
	_time_label = _add_counter(row, "hud_clock", "Tempo restante")
	_rescues_label = _add_counter(row, "hud_rescue", "Penas da fênix: no fim da fase, cada uma traz de volta um boneco perdido")
	_coins_label = _add_counter(row, "hud_coin", "Moedas: gaste na loja entre as fases")


## An icon followed by its number; the tooltip covers both.
func _add_counter(row: HBoxContainer, icon_id: String, tooltip: String) -> Label:
	var counter := HBoxContainer.new()
	counter.add_theme_constant_override("separation", ICON_GAP)
	counter.tooltip_text = tooltip
	counter.mouse_filter = Control.MOUSE_FILTER_STOP
	row.add_child(counter)
	var icon := TextureRect.new()
	icon.texture = UiStyle.icon(icon_id)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	counter.add_child(icon)
	var label := Label.new()
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	counter.add_child(label)
	return label


func _build_controls() -> void:
	var panel := PanelContainer.new()
	panel.process_mode = Node.PROCESS_MODE_ALWAYS
	panel.add_theme_stylebox_override("panel", UiStyle.panel_style())
	panel.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	panel.offset_top = MARGIN
	panel.offset_right = -MARGIN
	add_child(panel)
	var controls := HBoxContainer.new()
	controls.add_theme_constant_override("separation", BUTTON_SEPARATION)
	panel.add_child(controls)
	_pause_button = _add_button(controls, "editor_pause", "Pausar (P)", GameManager.toggle_pause)
	var fast := UiStyle.make_icon_button("fast_forward", "Acelerar (F)")
	fast.name = "FastButton"
	fast.toggle_mode = true
	fast.toggled.connect(GameManager.set_fast_forward)
	GameManager.fast_forward_changed.connect(fast.set_pressed_no_signal)
	controls.add_child(fast)
	controls.add_child(VSeparator.new())
	_sacrifice_button = UiStyle.make_icon_button("sacrifice", SACRIFICE_TOOLTIP)
	_sacrifice_button.name = "SacrificeButton"
	_sacrifice_button.toggle_mode = true
	_sacrifice_button.toggled.connect(_session.set_sacrifice_armed)
	controls.add_child(_sacrifice_button)
	_session.sacrifice_armed_changed.connect(_sacrifice_button.set_pressed_no_signal)
	_end_stage_button = _add_button(controls, "give_up", "Encerrar fase: para quando os bonecos que faltam ficaram presos", _ask_end_stage)
	controls.add_child(VSeparator.new())
	_add_button(controls, "settings", "Configurações", _open_settings)
	_add_button(controls, "editor_menu", "Menu (Esc)", _open_menu)
	GameManager.game_paused.connect(_refresh_pause_button)
	GameManager.game_resumed.connect(_refresh_pause_button)


func _add_button(row: HBoxContainer, icon_id: String, tooltip: String, action: Callable) -> Button:
	var button := UiStyle.make_icon_button(icon_id, tooltip)
	button.pressed.connect(action)
	row.add_child(button)
	return button


## Asks first, in the game's own modal: a misclick would otherwise throw
## away every lemming still in the stage. What will happen is shown as icons
## and numbers (who already got out goes on, who is in the stage is
## sacrificed and leaves a coin, who has not come out is lost). The stage
## waits, paused, while the question is open.
func _ask_end_stage() -> void:
	if _level_manager.is_ending() or get_node_or_null("EndStageModal") != null:
		return
	_paused_by_dialog = not GameManager.is_paused
	if _paused_by_dialog:
		GameManager.pause_game()
	var data := _level_manager.level_data
	var out_count := _level_manager.lemmings_spawned_count - _level_manager.lemmings_saved_count - _level_manager.lemmings_lost_count
	var modal := ConfirmModal.new("give_up", "Encerrar fase?", "Encerrar")
	modal.name = "EndStageModal"
	modal.add_fact("hud_saved", _level_manager.lemmings_saved_count, "Já salvos: seguem na run")
	modal.add_fact("sacrifice", out_count, "Na fase: são sacrificados (1 moeda cada)")
	modal.add_fact("hud_lost", data.total_lemmings - _level_manager.lemmings_spawned_count, "Ainda na entrada: perdidos")
	modal.confirmed.connect(_on_end_stage_confirmed)
	modal.cancelled.connect(_close_confirm_dialog)
	add_child(modal)


func _close_confirm_dialog() -> void:
	if _paused_by_dialog:
		_paused_by_dialog = false
		GameManager.resume_game()


func _on_end_stage_confirmed() -> void:
	# The sacrifices have to be seen, so the game runs again even if the
	# player had paused it before asking.
	_paused_by_dialog = false
	if GameManager.is_paused:
		GameManager.resume_game()
	_end_stage_button.disabled = true
	_session.end_stage_now()


func _open_settings() -> void:
	get_tree().root.add_child(SettingsMenu.new())


## The run's menu over the paused stage (RoguelikeRunController), or the
## main menu when the stage is played on its own (tests).
func _open_menu() -> void:
	var run := get_tree().get_first_node_in_group(RoguelikeRunController.GROUP) as RoguelikeRunController
	if run == null:
		GameManager.go_to_main_menu()
		return
	run.open_game_menu()


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_P:
			GameManager.toggle_pause()
		KEY_F:
			GameManager.toggle_fast_forward()
		KEY_ESCAPE:
			_open_menu()
		_:
			return
	get_viewport().set_input_as_handled()


func _exit_tree() -> void:
	# The cards and the shop between stages run at normal speed.
	GameManager.set_fast_forward(false)
	if GameManager.game_paused.is_connected(_refresh_pause_button):
		GameManager.game_paused.disconnect(_refresh_pause_button)
		GameManager.game_resumed.disconnect(_refresh_pause_button)


func _refresh_pause_button() -> void:
	var paused := GameManager.is_paused
	_pause_button.icon = UiStyle.icon("editor_play" if paused else "editor_pause")
	_pause_button.tooltip_text = "Continuar (P)" if paused else "Pausar (P)"


func _on_level_ended(_percentage_saved: float) -> void:
	GameManager.set_fast_forward(false)
	_end_stage_button.disabled = true
	_sacrifice_button.disabled = true


func _on_counts_changed(saved_count: int, lost_count: int, spawned_count: int, total_count: int) -> void:
	_troop_label.text = str(total_count)
	_out_label.text = str(spawned_count - saved_count - lost_count)
	_saved_label.text = str(saved_count)
	_lost_label.text = str(lost_count)


func _on_time_changed(seconds_remaining: float) -> void:
	var total_seconds := int(ceil(seconds_remaining))
	_time_label.text = "%02d:%02d" % [total_seconds / 60, total_seconds % 60]
