class_name EditorDigDropsPanel
extends CanvasLayer
## What the drawing's broken blocks can give (LevelDrawing.dig_drops): the
## chance per material (earth, concrete) and how the finds split between a
## tool charge, an hourglass and a bag. Icons and numbers only, names in the
## tooltips (the user wants almost no text). The "nothing" switch turns the
## table off: the rest fades, but still answers, and touching any number
## switches the table back on. A level that drops nothing (the tutorials,
## the tool levels) opens switched off, and the settings that would not
## answer read as locked to the player. Every change is reported
## at once through table_changed (null: nothing comes out); the shares that
## move to keep the total at 100% light up, so the player sees where the
## difference went. Closes on the close button, a click outside or Esc.

signal table_changed(table: DigDropTable)

const LAYER := 30
const BACKDROP_COLOUR := Color(0.03, 0.03, 0.06, 0.65)
const HEADER_ICON_SIZE := Vector2(64, 64)
const MARGIN := 18
const ROW_SEPARATION := 22
const COLUMN_SEPARATION := 12
const ITEM_STEP := 5
const MAX_CHANCE := 100
## Faded rows while the table is off.
const OFF_ALPHA := 0.35
const GLOW_COLOUR := Color(1.0, 0.85, 0.35)
const GLOW_SECONDS := 0.18
const ITEM_ICONS := {
	ItemSpec.Kind.TOOL: ["item_tool_charge", "Carga de uma ferramenta da barra"],
	ItemSpec.Kind.TIME: ["hud_clock", "Ampulheta (+%d s)" % DigDropTable.DROPPED_HOURGLASS_SECONDS],
	ItemSpec.Kind.CHARGE_BAG: ["item_bag", "Bolsa (+1 em cada ferramenta)"],
}

var _shares: DigDropShares
var _none_button: Button
var _settings: VBoxContainer
var _earth_counter: EditorCounter
var _concrete_counter: EditorCounter
## ItemSpec.Kind -> EditorCounter
var _item_counters: Dictionary = {}
## While the counters are being set from the shares, their value_changed
## is not a player's change.
var _syncing := false


func _init(table: DigDropTable) -> void:
	layer = LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS
	_shares = DigDropShares.from_table(table)


func _ready() -> void:
	var backdrop := ColorRect.new()
	backdrop.name = "Backdrop"
	backdrop.color = BACKDROP_COLOUR
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.gui_input.connect(_on_backdrop_input)
	add_child(backdrop)
	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(centre)
	var panel := PanelContainer.new()
	panel.name = "Panel"
	panel.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	centre.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, MARGIN)
	panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", ROW_SEPARATION)
	margin.add_child(column)

	column.add_child(_make_header())
	_settings = VBoxContainer.new()
	_settings.name = "Settings"
	_settings.add_theme_constant_override("separation", ROW_SEPARATION)
	column.add_child(_settings)
	_settings.add_child(_make_chance_row())
	_settings.add_child(_make_item_row())
	column.add_child(_make_close_row())
	_show_shares()


## The table as it stands now (null: nothing comes out).
func get_table() -> DigDropTable:
	return _shares.to_table()


func _make_header() -> Control:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", COLUMN_SEPARATION)
	var icon := TextureRect.new()
	icon.texture = UiStyle.icon("dig_drops")
	icon.custom_minimum_size = HEADER_ICON_SIZE
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.tooltip_text = "Itens que saem dos blocos quebrados"
	row.add_child(icon)
	_none_button = UiStyle.make_icon_button("drops_none", "Nenhum item sai dos blocos")
	_none_button.name = "NoneButton"
	_none_button.toggle_mode = true
	_none_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_none_button.toggled.connect(_on_none_toggled)
	row.add_child(_none_button)
	var reset := UiStyle.make_icon_button("editor_restart", "Voltar ao padrão (o da campanha)")
	reset.name = "ResetButton"
	reset.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	reset.pressed.connect(_reset)
	row.add_child(reset)
	return row


func _make_chance_row() -> Control:
	var row := _make_row("Chances")
	_earth_counter = EditorCounter.new("Chance de sair um item ao quebrar terra", 0, 0, MAX_CHANCE,
		UiStyle.icon("editor_earth"), "%")
	_earth_counter.name = "EarthChance"
	_earth_counter.value_changed.connect(func(percent: int) -> void: _on_chance_changed(percent, true))
	row.add_child(_earth_counter)
	_concrete_counter = EditorCounter.new("Chance de sair um item ao quebrar concreto", 0, 0, MAX_CHANCE,
		UiStyle.icon("editor_concrete"), "%")
	_concrete_counter.name = "ConcreteChance"
	_concrete_counter.value_changed.connect(func(percent: int) -> void: _on_chance_changed(percent, false))
	row.add_child(_concrete_counter)
	return row


func _make_item_row() -> Control:
	var row := _make_row("Items")
	for kind in DigDropShares.KINDS:
		var counter := EditorCounter.new(ITEM_ICONS[kind][1], 0, 0, DigDropShares.FULL,
			UiStyle.icon(ITEM_ICONS[kind][0]), "%", ITEM_STEP)
		counter.name = "Share_%s" % ITEM_ICONS[kind][0]
		counter.value_changed.connect(func(percent: int) -> void: _on_share_changed(kind, percent))
		row.add_child(counter)
		_item_counters[kind] = counter
	return row


func _make_row(row_name: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.name = row_name
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", COLUMN_SEPARATION * 2)
	return row


func _make_close_row() -> Control:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var close := UiStyle.make_icon_button("next", "Fechar")
	close.name = "CloseButton"
	close.pressed.connect(queue_free)
	row.add_child(close)
	return row


func _show_shares() -> void:
	_syncing = true
	_none_button.set_pressed_no_signal(not _shares.enabled)
	_earth_counter.value = _shares.earth_percent
	_concrete_counter.value = _shares.concrete_percent
	for kind in DigDropShares.KINDS:
		_item_counters[kind].value = int(_shares.shares[kind])
	_syncing = false
	_show_enabled()


## Off: the settings fade, keeping their numbers for when the table is
## switched back on.
func _show_enabled() -> void:
	_settings.modulate.a = 1.0 if _shares.enabled else OFF_ALPHA


## A number changed while the table is off: the player wants items, so the
## "nothing" switch goes off.
func _switch_on() -> void:
	if _shares.enabled:
		return
	_shares.enabled = true
	_none_button.set_pressed_no_signal(false)
	_show_enabled()


func _on_none_toggled(is_none: bool) -> void:
	_shares.enabled = not is_none
	_show_enabled()
	_report()


func _on_chance_changed(percent: int, is_earth: bool) -> void:
	if _syncing:
		return
	_switch_on()
	if is_earth:
		_shares.earth_percent = percent
	else:
		_shares.concrete_percent = percent
	_report()


func _on_share_changed(kind: ItemSpec.Kind, percent: int) -> void:
	if _syncing:
		return
	_switch_on()
	var moved := _shares.set_share(kind, percent)
	_show_shares()
	for other in moved:
		_glow(_item_counters[other])
	_report()


func _reset() -> void:
	_shares = DigDropShares.from_table(DigDropTable.for_campaign())
	_show_shares()
	for counter in _item_counters.values():
		_glow(counter)
	_glow(_earth_counter)
	_glow(_concrete_counter)
	AudioManager.play_sound(&"select_tool")
	_report()


## A counter the player did not touch changed: it lights up for a moment.
func _glow(control: Control) -> void:
	var tween := control.create_tween()
	tween.tween_property(control, "modulate", GLOW_COLOUR, GLOW_SECONDS)
	tween.tween_property(control, "modulate", Color.WHITE, GLOW_SECONDS)


func _report() -> void:
	table_changed.emit(_shares.to_table())


func _on_backdrop_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click != null and click.pressed:
		queue_free()


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo and key.keycode == KEY_ESCAPE:
		queue_free()
		get_viewport().set_input_as_handled()
