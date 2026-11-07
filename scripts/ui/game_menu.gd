class_name GameMenu
extends CanvasLayer
## A game mode's menu, in the main menu's look (sky and hills, big outlined
## title, wooden panel, wide buttons with an icon and a word).
##
## Two uses:
##   * entering a mode (in_game false), over the levels' background:
##     NOVO JOGO, CARREGAR, CONFIGURAÇÕES, MENU PRINCIPAL;
##   * in the middle of the game (Esc or the Menu button; in_game true),
##     over the paused game: CONTINUAR, SALVAR, CARREGAR, (the mode's own
##     buttons), CONFIGURAÇÕES, MENU PRINCIPAL.
## A mode without saved games (mode "": a tool level, the tutorial) gets the
## in-game menu without SALVAR and CARREGAR.
##
## NOVO JOGO and CARREGAR open the saved games (SaveSlots) in the same
## panel: NOVO JOGO picks where to start (a taken slot is replaced after a
## confirmation), CARREGAR picks a saved game (and can delete one). The
## caller does the rest through the signals: new_game_chosen(slot) (the slot
## is already emptied), load_chosen(slot), main_menu_requested. CONTINUAR
## closes the menu and resumes the game. With the automatic save off,
## leaving for the main menu asks first.

signal new_game_chosen(slot: int)
signal load_chosen(slot: int)
signal main_menu_requested

## Above the HUD; below the settings screen and the confirmation modal.
const LAYER := 15
const BACKDROP_COLOUR := Color(0.03, 0.03, 0.06, 0.6)
const SLOT_BUTTON_SIZE := Vector2(420, 58)
const SLOT_FONT_SIZE := 18
## How far the delete button sits from the slot button's right edge.
const DELETE_INSET := 10
const SAVED_POP_SCALE := 1.15
const SAVED_POP_SECONDS := 0.12

var _mode: String
var _title: String
var _in_game: bool
## [text, icon id, action] for the mode's own buttons, before CONFIGURAÇÕES.
var _extra_buttons: Array = []
var _panel: VBoxContainer
var _was_paused := false


## mode: the SaveSlots mode id ("" for none); title: shown on top.
func _init(mode: String, title: String, in_game: bool) -> void:
	_mode = mode
	_title = title
	_in_game = in_game
	layer = LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS


## A button of the mode's own (the campaign's ESCOLHER FASE). Before
## adding the menu to the tree.
func add_button(text: String, icon_id: String, action: Callable) -> void:
	_extra_buttons.append([text, icon_id, action])


func _ready() -> void:
	# Dims the game behind; entering a mode it is clear, over the sky. Either
	# way it takes the clicks the panel does not.
	var backdrop := ColorRect.new()
	backdrop.color = BACKDROP_COLOUR if _in_game else Color.TRANSPARENT
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)
	if _in_game:
		_was_paused = GameManager.is_paused
		GameManager.pause_game()
	else:
		# Its own sky, just under the menu: it covers the screen that
		# opened it (the main menu, the level select).
		var background := LevelBackground.new()
		add_child(background)
		background.layer = LAYER - 1
	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(centre)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 18)
	centre.add_child(column)
	column.add_child(UiStyle.make_menu_title(_title))
	_panel = UiStyle.add_menu_panel(column)
	_show_main_page()


## A button of the page on show, by its node name, for tests.
func get_button(button_name: String) -> Button:
	return _panel.find_child(button_name, true, false) as Button


func _has_saves() -> bool:
	return _mode != ""


func _show_main_page() -> void:
	_clear()
	if _in_game:
		_add(_menu_button("Continuar", "editor_play", true, "Continue", close))
		if _has_saves():
			var save := _menu_button("Salvar", "level_save", false, "Save", Callable())
			save.pressed.connect(_save.bind(save))
			save.disabled = not SaveSlots.is_active(_mode)
			_add(save)
	elif _has_saves():
		_add(_menu_button("Novo jogo", "level_new", true, "NewGame", _show_slots.bind(true)))
	if _has_saves():
		var load_button := _menu_button("Carregar", "campaign", false, "Load", _show_slots.bind(false))
		load_button.disabled = not _any_used()
		_add(load_button)
	for entry in _extra_buttons:
		_add(_menu_button(entry[0], entry[1], false, "", entry[2]))
	_add(_menu_button("Configurações", "settings", false, "Settings", _open_settings))
	_add(_menu_button("Menu principal", "editor_menu", false, "MainMenu", _leave_for_main_menu))


## The saved games, one wide button each. new_game: where to start a new
## game (every slot answers, a taken one after a confirmation); otherwise
## which game to load (only taken slots answer, each with a delete button).
func _show_slots(new_game: bool) -> void:
	_clear()
	var heading := Label.new()
	heading.text = "Novo jogo" if new_game else "Carregar"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", UiStyle.MENU_FONT_SIZE + 4)
	heading.add_theme_color_override("font_color", UiStyle.MENU_TITLE_COLOUR)
	_add(heading)
	for slot in SaveSlots.SLOT_COUNT:
		_add(_make_slot_row(slot, new_game))
	_add(_menu_button("Voltar", "back", false, "Back", _show_main_page))


## One wide button per slot, as wide as every other button of the panel.
## Loading, a taken slot's delete button sits inside it, at its right end:
## a column of its own beside the buttons left the empty slots and Back
## out of line with the taken ones (prints/bug24.png).
func _make_slot_row(slot: int, new_game: bool) -> Control:
	var used := SaveSlots.is_used(_mode, slot)
	var row := MarginContainer.new()
	row.name = "Slot%d" % (slot + 1)
	var button := UiStyle.make_text_button(_slot_text(slot, used))
	button.name = "Pick"
	button.custom_minimum_size = SLOT_BUTTON_SIZE
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.add_theme_font_size_override("font_size", SLOT_FONT_SIZE)
	button.icon = UiStyle.icon("level_save" if used else "level_new")
	row.add_child(button)
	if new_game:
		button.pressed.connect(_start_new_game.bind(slot))
		return row
	button.disabled = not used
	button.pressed.connect(_load.bind(slot))
	if used:
		var delete := UiStyle.make_icon_button("editor_eraser", "Apagar")
		delete.name = "Delete"
		delete.pressed.connect(_confirm_delete.bind(slot))
		# A child of the slot button, anchored to its right end: on top of
		# it, so a click there deletes instead of loading.
		button.add_child(delete)
		delete.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT, Control.PRESET_MODE_MINSIZE, DELETE_INSET)
	return row


func _slot_text(slot: int, used: bool) -> String:
	if not used:
		return "%d   Vazio" % (slot + 1)
	var info := SaveSlots.get_info(_mode, slot)
	var summary: String = info.summary if info.summary != "" else "Jogo salvo"
	return "%d   %s\n     %s" % [slot + 1, summary, SaveSlots.date_label(info.saved_at)]


func _start_new_game(slot: int) -> void:
	if not SaveSlots.is_used(_mode, slot):
		_emit_new_game(slot)
		return
	var modal := ConfirmModal.new("level_new", "Substituir o jogo %d?" % (slot + 1), "Substituir")
	modal.confirmed.connect(_emit_new_game.bind(slot))
	add_child(modal)


func _emit_new_game(slot: int) -> void:
	SaveSlots.delete(_mode, slot)
	AudioManager.play_sound(&"select_tool")
	_finish()
	new_game_chosen.emit(slot)


## In the middle of a game, loading drops what was not saved: asked first.
func _load(slot: int) -> void:
	if not _in_game:
		_emit_load(slot)
		return
	var modal := ConfirmModal.new("campaign", "Carregar o jogo %d?" % (slot + 1), "Carregar")
	modal.confirmed.connect(_emit_load.bind(slot))
	add_child(modal)


func _emit_load(slot: int) -> void:
	AudioManager.play_sound(&"select_tool")
	_finish()
	load_chosen.emit(slot)


func _confirm_delete(slot: int) -> void:
	var modal := ConfirmModal.new("editor_eraser", "Apagar o jogo %d?" % (slot + 1), "Apagar")
	modal.confirmed.connect(func() -> void:
		SaveSlots.delete(_mode, slot)
		if _any_used():
			_show_slots(false)
		else:
			_show_main_page())
	add_child(modal)


## Saves, and the button pops with a sound: the only feedback (no text).
func _save(button: Button) -> void:
	if not SaveSlots.save():
		return
	AudioManager.play_sound(&"select_tool")
	button.pivot_offset = button.size / 2.0
	var tween := button.create_tween()
	tween.tween_property(button, "scale", Vector2.ONE * SAVED_POP_SCALE, SAVED_POP_SECONDS)
	tween.tween_property(button, "scale", Vector2.ONE, SAVED_POP_SECONDS)


func _open_settings() -> void:
	var settings := SettingsMenu.new()
	settings.save_mode = _mode
	add_child(settings)


## With the automatic save off, whatever was not saved is lost: asked first.
func _leave_for_main_menu() -> void:
	if not _in_game or not SaveSlots.is_active(_mode) or SaveSlots.is_auto_save_on(_mode):
		_finish()
		main_menu_requested.emit()
		return
	var modal := ConfirmModal.new("level_save", "Sair sem salvar?", "Sair")
	modal.confirmed.connect(func() -> void:
		_finish()
		main_menu_requested.emit())
	add_child(modal)


## Back to the game (CONTINUAR, Esc on the main page in a game).
func close() -> void:
	if _in_game and not _was_paused:
		GameManager.resume_game()
	queue_free()


## The menu is done with: the caller takes over (and unpauses if it needs).
func _finish() -> void:
	queue_free()


func _any_used() -> bool:
	for slot in SaveSlots.SLOT_COUNT:
		if SaveSlots.is_used(_mode, slot):
			return true
	return false


func _menu_button(text: String, icon_id: String, primary: bool, button_name: String, action: Callable) -> Button:
	var button := UiStyle.make_menu_button(text, icon_id, primary)
	if button_name != "":
		button.name = button_name
	if action.is_valid():
		button.pressed.connect(action)
	return button


func _add(control: Control) -> void:
	_panel.add_child(control)


func _clear() -> void:
	for child in _panel.get_children():
		_panel.remove_child(child)
		child.queue_free()


## Esc: back from the saved games, back to the game, or (entering a mode)
## to the main menu. Not while a settings screen or a question is open over
## the menu: those close themselves.
func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo or key.keycode != KEY_ESCAPE:
		return
	get_viewport().set_input_as_handled()
	if _panel.find_child("Back", true, false) != null:
		_show_main_page()
	elif _in_game:
		close()
	else:
		main_menu_requested.emit()


## The Save button the screens of a game being played show besides the
## menu (the roguelike's HUD and shop): saves the game, the button pops and
## a sound plays. Hidden when no saved game is being played.
static func make_save_button() -> Button:
	var button := UiStyle.make_icon_button("level_save", "Salvar jogo")
	button.name = "SaveButton"
	button.visible = SaveSlots.is_active()
	button.pressed.connect(func() -> void:
		if not SaveSlots.save():
			return
		AudioManager.play_sound(&"select_tool")
		button.pivot_offset = button.size / 2.0
		var tween := button.create_tween()
		tween.tween_property(button, "scale", Vector2.ONE * SAVED_POP_SCALE, SAVED_POP_SECONDS)
		tween.tween_property(button, "scale", Vector2.ONE, SAVED_POP_SECONDS))
	return button
