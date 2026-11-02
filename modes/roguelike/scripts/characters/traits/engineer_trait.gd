class_name RoguelikeEngineerTrait
extends RoguelikeCharacterTrait
## Engineer ("Engenheiro"): bridges and both ladders get extra pieces.

## Four, not more: a diagonal ladder that overshoots a 2-block platform
## drops the lemming from its top, and 16 steps is the most that stays a
## safe fall (see the stage chunks).
const EXTRA_PIECES := 4


func _on_skill_about_to_apply(skill: SkillBase) -> void:
	if skill is SkillBridge:
		(skill as SkillBridge).max_pieces += EXTRA_PIECES
	elif skill is SkillBuilder:
		(skill as SkillBuilder).max_pieces += EXTRA_PIECES
	elif skill is SkillLadderVertical:
		(skill as SkillLadderVertical).max_pieces += EXTRA_PIECES
