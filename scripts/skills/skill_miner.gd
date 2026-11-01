class_name SkillMiner
extends SkillSideDigger
## Pickaxe ("Picareta"): digs a tunnel straight ahead through earth, at the
## shovel's pace. Stops at concrete, which only the jackhammer breaks. See
## SkillSideDigger for how the digging works.


func _init() -> void:
	id = &"miner"
	display_name = "Picareta"
	dig_speed = 20.0
	breaks_concrete = false
	dig_state = LemmingStateMachine.State.MINING
