class_name SkillBlock
extends SkillBase
## Block ("Bloco"): the lemming puts a block of earth right in front of
## itself, at its own height. The block is ordinary terrain, a wall one
## block tall, so the lemming turns around at it, and so does everyone who
## walks into it afterwards. Any digging tool or explosive can remove it.
##
## It replaced the original game's blocker (a lemming that stood still for
## good, turning others around). With two of them the user got every
## lemming trapped between them, with nothing to do but wait for the time to
## run out; a block leaves its builder free and can be dug away.

## Material of the block put down.
@export var material: TerrainDestructible.TerrainMaterial = TerrainDestructible.TerrainMaterial.EARTH


func _init() -> void:
	id = &"block"
	display_name = "Bloco"


## Refused (and the charge kept) when the spot in front is already taken:
## terrain, a ladder or a brick.
func can_apply_to(lemming: LemmingController) -> bool:
	if lemming.state_machine.current_state != LemmingStateMachine.State.WALKING:
		return false
	var spot := block_rect(lemming)
	var centre := spot.get_center()
	return not lemming.terrain.is_solid_in_rect(spot.grow(-1.0)) and not lemming.terrain.is_ladder_at(centre)


func occupies_skill_slot() -> bool:
	return false


func apply_to(lemming: LemmingController) -> void:
	lemming.terrain.build_cell_at(block_rect(lemming).get_center(), material)
	AudioManager.play_sound(&"place_block")


## The cell the block goes in: the first one in front of the body, in the
## row the body is in. If the body's leading edge already pokes into the
## next cell, the block goes one further on, so it never lands on the body.
func block_rect(lemming: LemmingController) -> Rect2:
	var body := lemming.get_body_rect()
	var leading_edge := body.end.x if lemming.direction > 0 else body.position.x
	var probe := Vector2(leading_edge + lemming.direction * 0.5, body.get_center().y)
	var cell := lemming.terrain.cell_rect_at(probe)
	if cell.intersects(body.grow(-0.5)):
		cell = lemming.terrain.cell_rect_at(probe + Vector2(cell.size.x * lemming.direction, 0.0))
	return cell
