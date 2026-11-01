class_name EditorToolbar
extends CanvasLayer
## The level editor's on-screen controls: paint tools and test controls on
## top, a status line under them, and the lemming/tool counters at the
## bottom. It only reports what the player pressed through signals and shows
## whatever state it is told; LevelEditorController decides what happens.

signal tool_selected(kind: EditorTool.Kind)
signal play_requested
signal pause_requested
signal restart_requested
signal menu_requested

const FONT_SIZE := 12
const COUNTER_COLUMNS := 4
const MIN_COUNT := 0
const MAX_COUNT := 50
const DEFAULT_LEMMING_COUNT := 10
const DEFAULT_TOOL_COUNT := 5

var lemming_counter: EditorCounter
## skill id -> EditorCounter
var skill_counters: Dictionary = {}

var _tool_buttons: Dictionary = {}
var _play_button: Button
var _pause_button: Button
var _restart_button: Button
var _counters_toggle: Button
var _counters_panel: PanelContainer
var _status_label: Label
var _is_editing := true


func _ready() -> void:
	var theme := Theme.new()
	theme.default_font_size = FONT_SIZE
	_build_top_bar(theme)
	_build_status_label(theme)
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


func set_status(text: String) -> void:
	_status_label.text = text


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
	_refresh_counters_visibility()


func _build_top_bar(theme: Theme) -> void:
	var panel := PanelContainer.new()
	panel.name = "TopBar"
	panel.theme = theme
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	add_child(panel)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	panel.add_child(row)

	var tool_group := ButtonGroup.new()
	for kind: EditorTool.Kind in EditorTool.Kind.values():
		var button := _make_button(row, EditorTool.get_display_name(kind))
		button.toggle_mode = true
		button.button_group = tool_group
		button.pressed.connect(func() -> void: tool_selected.emit(kind))
		_tool_buttons[kind] = button

	row.add_child(VSeparator.new())
	_play_button = _make_button(row, "Jogar")
	_play_button.pressed.connect(play_requested.emit)
	_pause_button = _make_button(row, "Pausar")
	_pause_button.pressed.connect(pause_requested.emit)
	_restart_button = _make_button(row, "Reiniciar")
	_restart_button.pressed.connect(restart_requested.emit)

	row.add_child(VSeparator.new())
	_counters_toggle = _make_button(row, "Quantidades")
	_counters_toggle.toggle_mode = true
	_counters_toggle.button_pressed = true
	_counters_toggle.toggled.connect(func(_on: bool) -> void: _refresh_counters_visibility())
	var menu_button := _make_button(row, "Menu")
	menu_button.pressed.connect(menu_requested.emit)


func _build_status_label(theme: Theme) -> void:
	_status_label = Label.new()
	_status_label.name = "StatusLabel"
	_status_label.theme = theme
	_status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_status_label.position = Vector2(8, 34)
	_status_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.85))
	_status_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_status_label.add_theme_constant_override("outline_size", 3)
	add_child(_status_label)


func _build_counters_panel(theme: Theme) -> void:
	_counters_panel = PanelContainer.new()
	_counters_panel.name = "CountersPanel"
	_counters_panel.theme = theme
	_counters_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_counters_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(_counters_panel)

	var grid := GridContainer.new()
	grid.columns = COUNTER_COLUMNS
	grid.add_theme_constant_override("h_separation", 16)
	_counters_panel.add_child(grid)

	lemming_counter = EditorCounter.new("Bonecos", DEFAULT_LEMMING_COUNT, MIN_COUNT, MAX_COUNT)
	grid.add_child(lemming_counter)
	for skill_id in SkillManager.get_skill_ids():
		var counter := EditorCounter.new(SkillManager.get_display_name(skill_id), DEFAULT_TOOL_COUNT, MIN_COUNT, MAX_COUNT)
		grid.add_child(counter)
		skill_counters[skill_id] = counter


func _refresh_counters_visibility() -> void:
	_counters_panel.visible = _is_editing and _counters_toggle.button_pressed


func _make_button(parent: Node, text: String) -> Button:
	var button := Button.new()
	button.text = text
	# Without this, Space/Enter would re-press the last clicked button.
	button.focus_mode = Control.FOCUS_NONE
	parent.add_child(button)
	return button
