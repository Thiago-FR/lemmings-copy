class_name RoguelikeWizardTrait
extends RoguelikeCharacterTrait
## Wizard ("Mago"), the character every run starts with: lucky, every tool
## item it collects gives one more charge.

const PICKUP_BONUS := 1


func get_pickup_bonus() -> int:
	return PICKUP_BONUS
