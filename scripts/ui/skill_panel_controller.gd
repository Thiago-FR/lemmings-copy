class_name SkillPanelController
extends CanvasLayer
## Renders one toggle button per skill available in the current level and
## forwards selection to SkillManager. Button labels/availability follow
## SkillManager's remaining counts, which LevelManager already initialized.

@onready var _button_container: HBoxContainer = $MarginContainer/HBoxContainer

var _buttons: Dictionary = {}
var _level_manager: LevelManager


func _ready() -> void:
	_level_manager = get_tree().get_first_node_in_group("level_manager")
	assert(_level_manager != null, "SkillPanelController requires a LevelManager in the 'level_manager' group")

	SkillManager.skill_count_changed.connect(_on_skill_count_changed)
	SkillManager.skill_selected.connect(_on_skill_selected)

	_build_buttons()


func _build_buttons() -> void:
	for skill_id in _level_manager.level_data.available_skills:
		var button := Button.new()
		button.name = skill_id.capitalize()
		button.toggle_mode = true
		button.text = _skill_button_text(skill_id)
		button.disabled = SkillManager.get_remaining_count(skill_id) <= 0
		button.pressed.connect(_on_skill_button_pressed.bind(skill_id))
		_button_container.add_child(button)
		_buttons[skill_id] = button


func _on_skill_button_pressed(skill_id: String) -> void:
	SkillManager.select_skill(skill_id)


func _on_skill_selected(skill_id: String) -> void:
	for id in _buttons:
		_buttons[id].button_pressed = (id == skill_id)


func _on_skill_count_changed(skill_id: String, remaining_count: int) -> void:
	if not _buttons.has(skill_id):
		return
	var button: Button = _buttons[skill_id]
	button.text = _skill_button_text(skill_id)
	button.disabled = remaining_count <= 0


func _skill_button_text(skill_id: String) -> String:
	return "%s (%d)" % [skill_id.capitalize(), SkillManager.get_remaining_count(skill_id)]
