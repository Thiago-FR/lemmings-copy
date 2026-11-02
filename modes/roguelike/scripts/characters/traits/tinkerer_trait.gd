class_name RoguelikeTinkererTrait
extends RoguelikeCharacterTrait
## Tinkerer ("Inventor"): remembers the last tool it was given, which its
## ability, Repeat (RoguelikeRepeatAbility), hands it again for free. The
## ability used to be "click it with no tool selected, once per stage"; it
## now has its own slot in the tool bar, like every character's.

var last_tool_id: String = ""


func _on_skill_about_to_apply(skill: SkillBase) -> void:
	last_tool_id = String(skill.id)
