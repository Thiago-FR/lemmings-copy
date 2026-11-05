class_name RoguelikeToolBar
extends ToolInventoryBar
## The roguelike's tool bar: the core ToolInventoryBar with the run's
## inventory, and, given the stage session, the character's ability in a
## slot of its own after the tools, set apart by a line in the character's
## colour: its icon, the charges left, and selected while armed
## (RoguelikeStageSession.set_ability_armed).

const ABILITY_LINE_SIZE := Vector2(3, 34)

var _session: RoguelikeStageSession = null
var _ability_button: Button = null
var _ability_count: Label = null
var _shown_charges := -1


## session: optional; without it the bar shows only the tools.
func _init(inventory: ToolInventory, session: RoguelikeStageSession = null) -> void:
	super(inventory)
	_session = session
	name = "RoguelikeToolBar"


func _add_extra_slots(bar: HBoxContainer) -> void:
	if _session == null or _session.ability_slot == null:
		return
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
