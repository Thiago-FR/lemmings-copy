class_name SkillTnt
extends SkillExplosive
## TNT: the big explosive. Blows up blocks up to two away from the charge (a
## 5x5 square without its corners), floor included, so it goes through a
## floor two blocks thick where dynamite only takes the top one. See
## SkillExplosive.


func _init() -> void:
	id = &"tnt"
	display_name = "TNT"
	blast_radius_tiles = 2
	charge_look = ExplosiveCharge.Look.TNT
