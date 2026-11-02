class_name SkillPanelController
extends CanvasLayer
## The tool bar at the bottom of a level: one slot per tool available, its
## icon with the charges left as a small number, and the tool's name on
## hover. Selecting a slot forwards to SkillManager; slots follow
## SkillManager's remaining counts, which LevelManager already initialised.
##
## The bar is a wooden panel centred at the bottom, as wide as its slots,
## and scrolls sideways if there are more tools than fit (the editor offers
## all of them).

@onready var _panel: PanelContainer = $MarginContainer/Panel
@onready var _scroll: ScrollContainer = $MarginContainer/Panel/ScrollContainer
@onready var _button_container: HBoxContainer = $MarginContainer/Panel/ScrollContainer/HBoxContainer

var _buttons: Dictionary = {}
var _counts: Dictionary = {}
var _level_manager: LevelManager


func _ready() -> void:
	_level_manager = get_tree().get_first_node_in_group("level_manager")
	assert(_level_manager != null, "SkillPanelController requires a LevelManager in the 'level_manager' group")

	_panel.add_theme_stylebox_override("panel", UiStyle.panel_style())
	_panel.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	SkillManager.skill_count_changed.connect(_on_skill_count_changed)
	SkillManager.skill_selected.connect(_on_skill_selected)

	_build_buttons()
	get_viewport().size_changed.connect(_fit_width)
	_fit_width.call_deferred()


func _build_buttons() -> void:
	for skill_id in _level_manager.level_data.available_skills:
		var button := UiStyle.make_icon_button(skill_id, SkillManager.get_display_name(skill_id))
		button.name = skill_id.capitalize()
		button.toggle_mode = true
		button.pressed.connect(_on_skill_button_pressed.bind(skill_id))
		_button_container.add_child(button)
		_buttons[skill_id] = button
		_counts[skill_id] = UiStyle.add_count_label(button)
		_refresh(skill_id)


## A scroll container does not take its content's width by itself, which
## would collapse the centred panel; it is given the slots' width, or the
## screen's if that is narrower (then it scrolls).
func _fit_width() -> void:
	const SCREEN_GUTTER := 48.0
	var available := get_viewport().get_visible_rect().size.x - SCREEN_GUTTER
	_scroll.custom_minimum_size.x = minf(_button_container.get_combined_minimum_size().x, available)


func _on_skill_button_pressed(skill_id: String) -> void:
	SkillManager.select_skill(skill_id)


func _on_skill_selected(skill_id: String) -> void:
	for id in _buttons:
		_buttons[id].button_pressed = (id == skill_id)


func _on_skill_count_changed(skill_id: String, _remaining_count: int) -> void:
	if _buttons.has(skill_id):
		_refresh(skill_id)


func _refresh(skill_id: String) -> void:
	var remaining := SkillManager.get_remaining_count(skill_id)
	_counts[skill_id].text = str(remaining)
	_buttons[skill_id].disabled = remaining <= 0
	_buttons[skill_id].tooltip_text = "%s (%d)" % [SkillManager.get_display_name(skill_id), remaining]
