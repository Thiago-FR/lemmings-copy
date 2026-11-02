class_name RoguelikeMinerTrait
extends RoguelikeCharacterTrait
## Miner ("Mineiro"): digs twice as fast with the shovel, the pickaxe and
## the jackhammer.

const DIG_SPEED_FACTOR := 2.0


func _on_skill_about_to_apply(skill: SkillBase) -> void:
	if skill is SkillDigger:
		(skill as SkillDigger).dig_speed *= DIG_SPEED_FACTOR
	elif skill is SkillSideDigger:
		(skill as SkillSideDigger).dig_speed *= DIG_SPEED_FACTOR
