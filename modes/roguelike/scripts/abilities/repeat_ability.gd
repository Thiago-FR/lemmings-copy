class_name RoguelikeRepeatAbility
extends RoguelikeAbility
## Tinkerer ("Inventor"), Repeat: hands the lemming the last tool it was
## given again, without spending a charge of that tool (only the ability's
## own). Refused when it has not been given a tool yet, or cannot take that
## tool right now (the same rules as handing it over from the bar).

const SPARKLE_COLOUR := Color(0.45, 0.85, 1.0)


func _init() -> void:
	id = RoguelikeAbilities.REPEAT


## Not only while walking: any moment the tool itself accepts.
func _is_ready(lemming: LemmingController) -> bool:
	return is_instance_valid(lemming) and lemming.state_machine.is_alive() and not lemming.is_entering_exit


func _use(lemming: LemmingController) -> bool:
	var tinkerer := RoguelikeCharacters.get_trait(lemming) as RoguelikeTinkererTrait
	if tinkerer == null or tinkerer.last_tool_id == "":
		return false
	var skill := SkillManager.create_skill(tinkerer.last_tool_id)
	if skill == null or not lemming.assign_skill(skill):
		return false
	RoguelikeAbilityEffect.spawn(lemming.get_parent(), lemming.get_body_rect().get_center(), RoguelikeAbilityEffect.Style.SPARKLES, SPARKLE_COLOUR)
	AudioManager.play_sound(&"assign_tool")
	return true
