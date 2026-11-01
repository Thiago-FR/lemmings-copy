class_name SkillDynamite
extends SkillExplosive
## Dynamite ("Dinamite"): the small explosive. Blows up the blocks right
## around the charge, a 3x3 square, floor included. See SkillExplosive.


func _init() -> void:
	id = &"dynamite"
	display_name = "Dinamite"
	blast_radius_tiles = 1
	charge_look = ExplosiveCharge.Look.DYNAMITE
