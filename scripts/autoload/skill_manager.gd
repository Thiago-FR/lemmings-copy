extends Node
## Holds the currently selected skill and each skill's remaining count for
## the active level, and applies the Strategy skill (see skills/skill_base.gd)
## to a clicked lemming. LemmingController calls try_assign_to() on click;
## SkillPanelController calls select_skill() on skill button presses.

signal skill_selected(skill_id: String)
signal skill_count_changed(skill_id: String, remaining_count: int)
signal skill_assigned(lemming: LemmingController, skill_id: String)

var selected_skill_id: String = ""

# Skill scripts, not instances: each assignment gets its own SkillBase so
# per-lemming state (e.g. a builder's step count) is never shared.
var _skill_scripts: Dictionary = {
	"blocker": SkillBlocker,
	"digger": SkillDigger,
	"builder": SkillBuilder,
	"basher": SkillBasher,
	"miner": SkillMiner,
	"climber": SkillClimber,
	"floater": SkillFloater,
	"bomber": SkillBomber,
}

var _remaining_counts: Dictionary = {}


func initialize_for_level(level_data: LevelData) -> void:
	selected_skill_id = ""
	_remaining_counts.clear()
	for skill_id in level_data.available_skills:
		_remaining_counts[skill_id] = int(level_data.skill_counts.get(skill_id, 0))


func select_skill(skill_id: String) -> void:
	if not _skill_scripts.has(skill_id):
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

	var skill_script: GDScript = _skill_scripts.get(selected_skill_id)
	if skill_script == null:
		return false

	var skill: SkillBase = skill_script.new()
	skill.skill_id = selected_skill_id
	if not skill.can_apply_to(lemming):
		return false

	if skill.occupies_skill_slot():
		lemming.current_skill = skill
	skill.apply_to(lemming)

	_remaining_counts[selected_skill_id] -= 1
	skill_count_changed.emit(selected_skill_id, _remaining_counts[selected_skill_id])
	skill_assigned.emit(lemming, selected_skill_id)
	return true
