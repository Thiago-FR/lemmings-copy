class_name RoguelikeScoutTrait
extends RoguelikeCharacterTrait
## Scout ("Batedor"): sturdy legs, survives falls twice as high as anyone
## else (five blocks instead of two and a half).

const SAFE_FALL_FACTOR := 2.0


func _on_attached() -> void:
	lemming.max_safe_fall_height = Constants.MAX_SAFE_FALL_HEIGHT * SAFE_FALL_FACTOR
