extends Node
## Holds the currently selected skill and each skill's remaining count for
## the active level, and applies the chosen skill to a clicked lemming.
## LemmingController calls try_assign_to() on click; SkillPanelController
## calls select_skill() on button presses and get_display_name() for labels.
##
## Skills are registered as configured templates (see SkillBase). The
## defaults below can be replaced per level or per test with
## register_skill(), e.g. a slower digger, without touching any skill code.

signal skill_selected(skill_id: String)
signal skill_count_changed(skill_id: String, remaining_count: int)
signal skill_assigned(lemming: LemmingController, skill_id: String)

var _default_skill_types: Array[GDScript] = [
	SkillBlocker,
	SkillDigger,
	SkillBuilder,
	SkillBasher,
	SkillMiner,
	SkillClimber,
	SkillFloater,
	SkillBomber,
	SkillLadderVertical,
	SkillBridge,
]

var selected_skill_id: String = ""

var _skill_templates: Dictionary = {}
var _remaining_counts: Dictionary = {}


func _init() -> void:
	for skill_type in _default_skill_types:
		register_skill(skill_type.new())


## Adds a skill, or replaces the one already registered under the same id.
func register_skill(template: SkillBase) -> void:
	assert(template.id != &"", "A skill needs an id before it can be registered")
	_skill_templates[String(template.id)] = template


func has_skill(skill_id: String) -> bool:
	return _skill_templates.has(skill_id)


## Player-facing name for a skill id, falling back to the id itself so an
## unnamed skill still shows something readable instead of an empty button.
func get_display_name(skill_id: String) -> String:
	var template: SkillBase = _skill_templates.get(skill_id)
	if template == null or template.display_name.is_empty():
		return skill_id
	return template.display_name


func initialize_for_level(level_data: LevelData) -> void:
	selected_skill_id = ""
	_remaining_counts.clear()
	for skill_id in level_data.available_skills:
		_remaining_counts[skill_id] = int(level_data.skill_counts.get(skill_id, 0))


func select_skill(skill_id: String) -> void:
	if not has_skill(skill_id):
		push_warning("SkillManager: unknown skill '%s'" % skill_id)
		return
	if get_remaining_count(skill_id) <= 0:
		return
	selected_skill_id = skill_id
	skill_selected.emit(skill_id)


func get_remaining_count(skill_id: String) -> int:
	return int(_remaining_counts.get(skill_id, 0))


func try_assign_to(lemming: LemmingController) -> bool:
	if selected_skill_id == "" or get_remaining_count(selected_skill_id) <= 0:
		return false

	var skill := create_skill(selected_skill_id)
	if skill == null or not lemming.assign_skill(skill):
		return false

	_remaining_counts[selected_skill_id] -= 1
	skill_count_changed.emit(selected_skill_id, _remaining_counts[selected_skill_id])
	skill_assigned.emit(lemming, selected_skill_id)
	return true


## A ready-to-apply copy of a registered skill, or null for an unknown id.
func create_skill(skill_id: String) -> SkillBase:
	var template: SkillBase = _skill_templates.get(skill_id)
	return template.create_instance() if template != null else null
