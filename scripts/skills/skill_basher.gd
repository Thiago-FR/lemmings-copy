class_name SkillBasher
extends SkillSideDigger
## Jackhammer ("Britadeira"): digs a tunnel straight ahead, through concrete
## as well as earth. See SkillSideDigger for how the digging works.
##
## It used to clear a whole block every 0.15s and move the lemming a block
## at a time, which read as teleporting; it now digs a slice at a time like
## the pickaxe, a little faster.


func _init() -> void:
	id = &"basher"
	display_name = "Britadeira"
	dig_speed = 24.0
	breaks_concrete = true
	dig_state = LemmingStateMachine.State.BASHING
