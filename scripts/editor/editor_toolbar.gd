class_name EditorToolbar
extends CanvasLayer
## The level editor's on-screen controls: paint tools and test controls on
## top (icon slots, names on hover), the test run's counts under them as
## icons and numbers, and the lemming/tool counters at the bottom, on the
## same wooden panels as the level's tool bar (UiStyle). No status
## sentences (the user wants as little text as possible): when something is
## missing, the control that fixes it flashes red and shakes (flash()). It only reports what the player pressed through signals and shows
## whatever state it is told; LevelEditorController decides what happens.

signal tool_selected(kind: EditorTool.Kind)
signal play_requested
signal pause_requested
signal restart_requested
signal menu_requested

const FONT_SIZE := 12
const COUNTER_COLUMNS := 6
const MIN_COUNT := 0
const MAX_COUNT := 50
const DEFAULT_LEMMING_COUNT := 10
const DEFAULT_TOOL_COUNT := 5
## Where the test run's counts sit, just under the top bar of icon slots.
const RUN_COUNTS_Y := 58.0
const RUN_COUNTS_X := 8.0
const FLASH_COLOUR := Color(1.0, 0.35, 0.3)
const FLASH_PULSES := 3
const FLASH_PULSE_SECONDS := 0.12
const SHAKE_PIXELS := 4.0

var lemming_counter: EditorCounter
## skill id -> EditorCounter
var skill_counters: Dictionary = {}

var _tool_buttons: Dictionary = {}
var _play_button: Button
var _pause_button: Button
var _restart_button: Button
var _counters_toggle: Button
var _counters_panel: PanelContainer
var _run_counts: PanelContainer
var _run_labels: Dictionary = {}
var _is_editing := true


func _ready() -> void:
	var theme := Theme.new()
	theme.default_font_size = FONT_SIZE
	_build_top_bar(theme)
	_build_run_counts(theme)
	_build_counters_panel(theme)
	update_for_state(true, false)


## Highlights the tool's button and reports the choice.
func select_tool(kind: EditorTool.Kind) -> void:
	_tool_buttons[kind].button_pressed = true
	tool_selected.emit(kind)


func get_lemming_count() -> int:
	return lemming_counter.value


## skill id -> how many of that tool the player will have.
func get_skill_counts() -> Dictionary:
	var counts := {}
	for skill_id in skill_counters:
		counts[skill_id] = skill_counters[skill_id].value
	return counts


## The test run's counts (shown while it runs or is paused).
func show_run_counts(out_count: int, saved_count: int, lost_count: int, total_count: int) -> void:
	_run_labels.out.text = str(out_count)
	_run_labels.saved.text = str(saved_count)
	_run_labels.lost.text = str(lost_count)
	_run_labels.total.text = str(total_count)


## Draws the eye to what has to be fixed before playing (the entrance tool,
## the lemming counter): it flashes red a few times and shakes.
func flash(target: StringName) -> void:
	var control: Control = _tool_buttons[EditorTool.Kind.ENTRANCE] if target == &"entrance" else lemming_counter
	if target == &"lemmings" and not _counters_toggle.button_pressed:
		_counters_toggle.button_pressed = true
	AudioManager.play_sound(&"select_tool")
	var rest := control.position
	var tween := control.create_tween()
	for _pulse in FLASH_PULSES:
		tween.tween_property(control, "modulate", FLASH_COLOUR, FLASH_PULSE_SECONDS)
		tween.parallel().tween_property(control, "position:x", rest.x + SHAKE_PIXELS, FLASH_PULSE_SECONDS / 2.0)
		tween.tween_property(control, "modulate", Color.WHITE, FLASH_PULSE_SECONDS)
		tween.parallel().tween_property(control, "position:x", rest.x, FLASH_PULSE_SECONDS / 2.0)


## Enables only the controls that make sense right now: painting and the
## counters while editing, Pause while running, Play and Restart while
## paused.
func update_for_state(is_editing: bool, is_paused: bool) -> void:
	_is_editing = is_editing
	for button: Button in _tool_buttons.values():
		button.disabled = not is_editing
	_play_button.disabled = not (is_editing or is_paused)
	_pause_button.disabled = is_editing or is_paused
	_restart_button.disabled = is_editing
	_counters_toggle.disabled = not is_editing
	_run_counts.visible = not is_editing
	_refresh_counters_visibility()


func _build_top_bar(theme: Theme) -> void:
	var panel := PanelContainer.new()
	panel.name = "TopBar"
	panel.theme = theme
	panel.add_theme_stylebox_override("panel", UiStyle.panel_style())
	panel.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	add_child(panel)

	# Scrolls sideways: with every tool and control the row is wider than
	# the window, and the last buttons were cut off.
	var scroll := ScrollContainer.new()
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	scroll.add_child(row)

	var tool_group := ButtonGroup.new()
	for kind: EditorTool.Kind in EditorTool.Kind.values():
		var button := _make_icon_button(row, EditorTool.get_icon_id(kind), EditorTool.get_display_name(kind))
		button.toggle_mode = true
		button.button_group = tool_group
		button.pressed.connect(func() -> void: tool_selected.emit(kind))
		_tool_buttons[kind] = button

	row.add_child(VSeparator.new())
	_play_button = _make_icon_button(row, "editor_play", "Jogar")
	_play_button.pressed.connect(play_requested.emit)
	_pause_button = _make_icon_button(row, "editor_pause", "Pausar")
	_pause_button.pressed.connect(pause_requested.emit)
	_restart_button = _make_icon_button(row, "editor_restart", "Reiniciar (volta ao desenho)")
	_restart_button.pressed.connect(restart_requested.emit)

	row.add_child(VSeparator.new())
	_counters_toggle = _make_icon_button(row, "editor_counts", "Quantidades")
	_counters_toggle.toggle_mode = true
	_counters_toggle.button_pressed = true
	_counters_toggle.toggled.connect(func(_on: bool) -> void: _refresh_counters_visibility())
	var menu_button := _make_icon_button(row, "editor_menu", "Menu")
	menu_button.pressed.connect(menu_requested.emit)


func _build_run_counts(theme: Theme) -> void:
	_run_counts = PanelContainer.new()
	_run_counts.name = "RunCounts"
	_run_counts.theme = theme
	_run_counts.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_run_counts.position = Vector2(RUN_COUNTS_X, RUN_COUNTS_Y)
	add_child(_run_counts)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	_run_counts.add_child(row)
	for entry in [[&"out", "hud_out", "Na fase"], [&"saved", "hud_saved", "Salvos"], [&"lost", "hud_lost", "Perdidos"], [&"total", "hud_troop", "Total"]]:
		var item := HBoxContainer.new()
		item.tooltip_text = entry[2]
		item.mouse_filter = Control.MOUSE_FILTER_STOP
		row.add_child(item)
		var icon := TextureRect.new()
		icon.texture = UiStyle.icon(entry[1])
		icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		item.add_child(icon)
		var label := Label.new()
		label.text = "0"
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 16)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		item.add_child(label)
		_run_labels[entry[0]] = label


func _build_counters_panel(theme: Theme) -> void:
	_counters_panel = PanelContainer.new()
	_counters_panel.name = "CountersPanel"
	_counters_panel.theme = theme
	_counters_panel.add_theme_stylebox_override("panel", UiStyle.panel_style())
	_counters_panel.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_counters_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_counters_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(_counters_panel)

	var grid := GridContainer.new()
	grid.columns = COUNTER_COLUMNS
	grid.add_theme_constant_override("h_separation", 16)
	_counters_panel.add_child(grid)

	lemming_counter = EditorCounter.new("Bonecos", DEFAULT_LEMMING_COUNT, MIN_COUNT, MAX_COUNT, UiStyle.icon("editor_entrance"))
	grid.add_child(lemming_counter)
	for skill_id in SkillManager.get_skill_ids():
		var counter := EditorCounter.new(SkillManager.get_display_name(skill_id), DEFAULT_TOOL_COUNT, MIN_COUNT, MAX_COUNT, UiStyle.icon(skill_id))
		grid.add_child(counter)
		skill_counters[skill_id] = counter


func _refresh_counters_visibility() -> void:
	_counters_panel.visible = _is_editing and _counters_toggle.button_pressed


func _make_icon_button(parent: Node, icon_id: String, tooltip: String) -> Button:
	var button := UiStyle.make_icon_button(icon_id, tooltip)
	parent.add_child(button)
	return button
