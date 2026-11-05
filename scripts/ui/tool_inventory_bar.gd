class_name ToolInventoryBar
extends CanvasLayer
## The tool bar of a level whose tools come from items (ToolInventory): the
## same wooden panel and icon slots as SkillPanel (UiStyle), one slot per
## tool carried, then empty slots up to the bar's limit, so the player sees
## how much room is left. Clicking a slot selects its tool in SkillManager;
## clicking the selected slot again lets go of it.
##
## A mode adds slots of its own after the tools by overriding
## _add_extra_slots (the roguelike's character ability).

const MARGIN := 8
const SLOT_SEPARATION := 4
## The gap between the tools and a mode's extra slots.
const EXTRA_GAP := 6
## A charge gained makes the slot bounce instead of a message: the user
## wants animation, not text.
const PULSE_SCALE := 1.3
const PULSE_SECONDS := 0.12

var _inventory: ToolInventory
var _row: HBoxContainer


func _init(inventory: ToolInventory) -> void:
	assert(inventory != null, "A tool bar needs an inventory")
	_inventory = inventory
	name = "ToolInventoryBar"


func _ready() -> void:
	var anchor := MarginContainer.new()
	anchor.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	anchor.grow_vertical = Control.GROW_DIRECTION_BEGIN
	anchor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	anchor.add_theme_constant_override("margin_bottom", MARGIN)
	add_child(anchor)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiStyle.panel_style())
	panel.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	anchor.add_child(panel)
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", EXTRA_GAP)
	panel.add_child(bar)
	_row = HBoxContainer.new()
	_row.add_theme_constant_override("separation", SLOT_SEPARATION)
	bar.add_child(_row)
	_add_extra_slots(bar)

	_inventory.changed.connect(_rebuild)
	SkillManager.skill_selected.connect(_on_skill_selected)
	_rebuild()


func _exit_tree() -> void:
	if _inventory.changed.is_connected(_rebuild):
		_inventory.changed.disconnect(_rebuild)
	if SkillManager.skill_selected.is_connected(_on_skill_selected):
		SkillManager.skill_selected.disconnect(_on_skill_selected)


## Slots a mode puts after the tools, in the bar beside the tools' row.
func _add_extra_slots(_bar: HBoxContainer) -> void:
	pass


func _on_skill_selected(_skill_id: String) -> void:
	_refresh_pressed()


func _rebuild() -> void:
	for child in _row.get_children():
		child.queue_free()
	var tool_ids := _inventory.get_tool_ids()
	for tool_id in tool_ids:
		_row.add_child(_make_tool_slot(tool_id))
	for _empty in _inventory.max_slots - tool_ids.size():
		var empty := UiStyle.make_icon_button("", "Espaço vazio: pegue um item de ferramenta")
		empty.text = ""
		empty.disabled = true
		_row.add_child(empty)
	_refresh_pressed()


func _make_tool_slot(tool_id: String) -> Button:
	var charges := _inventory.get_charges(tool_id)
	var button := UiStyle.make_icon_button(tool_id, "%s (%d)" % [SkillManager.get_display_name(tool_id), charges])
	button.name = tool_id
	button.toggle_mode = true
	button.disabled = charges <= 0
	button.set_meta("tool_id", tool_id)
	button.pressed.connect(_on_slot_pressed.bind(tool_id))
	UiStyle.add_count_label(button).text = str(charges)
	return button


func _on_slot_pressed(tool_id: String) -> void:
	if SkillManager.selected_skill_id == tool_id:
		SkillManager.selected_skill_id = ""
		_refresh_pressed()
		return
	SkillManager.select_skill(tool_id)
	_refresh_pressed()


func _refresh_pressed() -> void:
	for button in _row.get_children():
		if button.has_meta("tool_id"):
			(button as Button).set_pressed_no_signal(button.get_meta("tool_id") == SkillManager.selected_skill_id)


func _pulse(control: Control) -> void:
	control.pivot_offset = control.size / 2.0
	var tween := control.create_tween()
	tween.tween_property(control, "scale", Vector2.ONE * PULSE_SCALE, PULSE_SECONDS).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(control, "scale", Vector2.ONE, PULSE_SECONDS * 2.0)
