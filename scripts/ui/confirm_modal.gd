class_name ConfirmModal
extends CanvasLayer
## The game's own "are you sure?": over a dimmed screen, a wooden panel that
## pops in with a big icon, a short question, what will happen as icons and
## numbers (no paragraph: the user wants as little text as possible), and
## two buttons, Back and the action. Works while the game is paused.
## Emits confirmed or cancelled, then frees itself.
##
##   var modal := ConfirmModal.new("give_up", "Encerrar fase?", "Encerrar")
##   modal.add_fact("hud_saved", 3, "Já salvos: seguem na run")
##   modal.confirmed.connect(...)
##   add_child(modal)

signal confirmed
signal cancelled

const LAYER := 30
const BACKDROP_COLOUR := Color(0.03, 0.03, 0.06, 0.65)
const ICON_SCALE := 2.0
const TITLE_FONT_SIZE := 24
const FACT_FONT_SIZE := 20
const POP_SECONDS := 0.18
const POP_START_SCALE := 0.85

var _icon_id: String
var _question: String
var _action_text: String
var _facts: Array = []
var _panel: PanelContainer


## icon_id: UiStyle icon shown big; action_text: the confirm button.
func _init(icon_id: String, question: String, action_text: String) -> void:
	_icon_id = icon_id
	_question = question
	_action_text = action_text
	layer = LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS


## One consequence: an icon and a number, the tooltip saying what it means.
func add_fact(icon_id: String, value: Variant, tooltip: String) -> void:
	_facts.append([icon_id, str(value), tooltip])


func _ready() -> void:
	var backdrop := ColorRect.new()
	backdrop.color = BACKDROP_COLOUR
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)
	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(centre)
	_panel = PanelContainer.new()
	_panel.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	centre.add_child(_panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	_panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	margin.add_child(column)

	var icon := TextureRect.new()
	icon.texture = UiStyle.icon(_icon_id)
	icon.custom_minimum_size = Vector2(32, 32) * ICON_SCALE
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(icon)
	var title := Label.new()
	title.text = _question
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", TITLE_FONT_SIZE)
	column.add_child(title)
	if not _facts.is_empty():
		column.add_child(_make_facts())

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 12)
	column.add_child(buttons)
	var back := UiStyle.make_text_button("Voltar")
	back.name = "Back"
	back.icon = UiStyle.icon("editor_play")
	back.pressed.connect(_close.bind(false))
	buttons.add_child(back)
	var action := UiStyle.make_text_button(_action_text, true)
	action.name = "Confirm"
	action.icon = UiStyle.icon(_icon_id)
	action.pressed.connect(_close.bind(true))
	buttons.add_child(action)
	_pop_in.call_deferred()


func _make_facts() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 22)
	for fact in _facts:
		var item := HBoxContainer.new()
		item.tooltip_text = fact[2]
		item.mouse_filter = Control.MOUSE_FILTER_STOP
		item.add_theme_constant_override("separation", 4)
		row.add_child(item)
		var icon := TextureRect.new()
		icon.texture = UiStyle.icon(fact[0])
		icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		item.add_child(icon)
		var label := Label.new()
		label.text = fact[1]
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", FACT_FONT_SIZE)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		item.add_child(label)
	return row


## Grows from slightly small to full size, from its centre.
func _pop_in() -> void:
	_panel.pivot_offset = _panel.size / 2.0
	_panel.scale = Vector2.ONE * POP_START_SCALE
	_panel.modulate.a = 0.0
	var tween := create_tween().set_parallel()
	tween.tween_property(_panel, "scale", Vector2.ONE, POP_SECONDS).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(_panel, "modulate:a", 1.0, POP_SECONDS)


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo and key.keycode == KEY_ESCAPE:
		_close(false)
		get_viewport().set_input_as_handled()


func _close(accepted: bool) -> void:
	if accepted:
		confirmed.emit()
	else:
		cancelled.emit()
	queue_free()
