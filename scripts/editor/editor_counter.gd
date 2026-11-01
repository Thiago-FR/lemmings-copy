class_name EditorCounter
extends HBoxContainer
## A named number with - and + buttons, clamped to [min_value, max_value].
## Used by the editor for the lemming count and each tool's count.

signal value_changed(new_value: int)

const NAME_WIDTH := 104.0
const BUTTON_WIDTH := 24.0
const VALUE_WIDTH := 26.0

var min_value: int = 0
var max_value: int = 50
var value: int = 0:
	set = set_value

var _value_label: Label
var _decrease_button: Button
var _increase_button: Button


func _init(display_name: String, initial_value: int, minimum: int, maximum: int) -> void:
	assert(minimum <= maximum, "EditorCounter needs minimum <= maximum")
	min_value = minimum
	max_value = maximum
	add_theme_constant_override("separation", 2)

	var name_label := Label.new()
	name_label.text = display_name
	name_label.custom_minimum_size.x = NAME_WIDTH
	name_label.clip_text = true
	add_child(name_label)

	_decrease_button = _make_step_button("-", -1)
	_value_label = Label.new()
	_value_label.custom_minimum_size.x = VALUE_WIDTH
	_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_value_label)
	_increase_button = _make_step_button("+", 1)

	value = initial_value


func set_value(new_value: int) -> void:
	var clamped := clampi(new_value, min_value, max_value)
	var changed := clamped != value
	value = clamped
	if _value_label == null:
		return
	_value_label.text = str(value)
	_decrease_button.disabled = value <= min_value
	_increase_button.disabled = value >= max_value
	if changed:
		value_changed.emit(value)


func _make_step_button(text: String, step: int) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.x = BUTTON_WIDTH
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(func() -> void: value += step)
	add_child(button)
	return button
