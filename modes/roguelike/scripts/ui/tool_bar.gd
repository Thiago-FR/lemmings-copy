class_name RoguelikeToolBar
extends CanvasLayer
## The roguelike's tool bar: the same wooden panel and icon slots as the
## core SkillPanel (UiStyle), but it shows the run's inventory: one slot per
## tool carried, then empty slots up to the bar's limit, so the player sees
## how much room is left. Clicking a slot selects its tool in SkillManager;
## clicking the selected slot again lets go of it.
##
## Given the stage session, the bar ends with the character's ability in a
## slot of its own, set apart from the tools by a gap and a line in the
## character's colour: its icon, the charges left, and selected while armed
## (RoguelikeStageSession.set_ability_armed).

const MARGIN := 8
const SLOT_SEPARATION := 4
## The gap between the tools and the ability, either side of its line.
const ABILITY_GAP := 6
const ABILITY_LINE_SIZE := Vector2(3, 34)
## A charge gained (a recharge item) makes the slot bounce instead of a
## message: the user wants animation, not text.
const PULSE_SCALE := 1.3
const PULSE_SECONDS := 0.12

var _inventory: RoguelikeToolInventory
var _session: RoguelikeStageSession = null
var _row: HBoxContainer
var _ability_button: Button = null
var _ability_count: Label = null
var _shown_charges := -1


## session: optional; without it the bar shows only the tools.
func _init(inventory: RoguelikeToolInventory, session: RoguelikeStageSession = null) -> void:
	_inventory = inventory
	_session = session
	name = "RoguelikeToolBar"


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
	bar.add_theme_constant_override("separation", ABILITY_GAP)
	panel.add_child(bar)
	_row = HBoxContainer.new()
	_row.add_theme_constant_override("separation", SLOT_SEPARATION)
	bar.add_child(_row)
	if _session != null and _session.ability_slot != null:
		_add_ability_slot(bar)

	_inventory.changed.connect(_rebuild)
	SkillManager.skill_selected.connect(_on_skill_selected)
	_rebuild()


func _exit_tree() -> void:
	if _inventory.changed.is_connected(_rebuild):
		_inventory.changed.disconnect(_rebuild)
	if SkillManager.skill_selected.is_connected(_on_skill_selected):
		SkillManager.skill_selected.disconnect(_on_skill_selected)


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


# --- The ability -------------------------------------------------------------

func _add_ability_slot(bar: HBoxContainer) -> void:
	var line := ColorRect.new()
	line.name = "AbilityDivider"
	line.custom_minimum_size = ABILITY_LINE_SIZE
	line.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.color = RoguelikeCharacters.get_colour(_session.state.character_id)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(line)
	var ability_id := _session.ability_slot.get_ability_id()
	_ability_button = UiStyle.make_icon_button(RoguelikeAbilities.get_icon_id(ability_id), RoguelikeAbilities.get_display_name(ability_id))
	_ability_button.name = "AbilitySlot"
	_ability_button.toggle_mode = true
	_ability_button.toggled.connect(func(pressed: bool) -> void:
		_session.set_ability_armed(pressed)
		_refresh_pressed())
	_ability_count = UiStyle.add_count_label(_ability_button)
	bar.add_child(_ability_button)
	_session.ability_slot.changed.connect(_refresh_ability)
	_refresh_ability()


func _refresh_ability() -> void:
	var slot := _session.ability_slot
	var ability_id := slot.get_ability_id()
	_ability_count.text = str(slot.charges)
	if _shown_charges >= 0 and slot.charges > _shown_charges:
		_pulse(_ability_button)
	_shown_charges = slot.charges
	_ability_button.disabled = slot.charges <= 0
	_ability_button.set_pressed_no_signal(slot.armed)
	_ability_button.tooltip_text = "%s (%d): %s" % [RoguelikeAbilities.get_display_name(ability_id), slot.charges, RoguelikeAbilities.get_description(ability_id)]


func _pulse(control: Control) -> void:
	control.pivot_offset = control.size / 2.0
	var tween := control.create_tween()
	tween.tween_property(control, "scale", Vector2.ONE * PULSE_SCALE, PULSE_SECONDS).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(control, "scale", Vector2.ONE, PULSE_SECONDS * 2.0)
