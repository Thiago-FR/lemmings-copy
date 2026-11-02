class_name RoguelikeTinkererTrait
extends RoguelikeCharacterTrait
## Tinkerer ("Inventor"): once per stage, uses the last tool it was given
## again without spending a charge. The player triggers it by clicking the
## Inventor with no usable tool selected (RoguelikeStageSession asks
## can_use_own_ability()).

var _last_tool_id: String = ""
var _reuse_spent := false


func _on_skill_about_to_apply(skill: SkillBase) -> void:
	_last_tool_id = String(skill.id)


func can_use_own_ability() -> bool:
	return not _reuse_spent and _last_tool_id != ""


func use_own_ability() -> bool:
	if not can_use_own_ability():
		return false
	var skill := SkillManager.create_skill(_last_tool_id)
	if skill == null or not lemming.assign_skill(skill):
		return false
	_reuse_spent = true
	AudioManager.play_sound(&"assign_tool")
	return true
