class_name RoguelikeBreakConcreteAbility
extends RoguelikeAbility
## Miner ("Mineiro"), Concrete breaker: smashes one block of concrete in
## front of the lemming (up to a block ahead, or the one it has just turned
## at), at body height, so it can walk through. Only concrete: the shovel
## and the pickaxe stop at it, and earth is theirs. Refused when the wall
## there is earth, or there is no wall.

const DUST_COLOUR := Color(0.78, 0.79, 0.8)
const DEBRIS_BURSTS := 3


func _init() -> void:
	id = RoguelikeAbilities.BREAK_CONCRETE


func _use(lemming: LemmingController) -> bool:
	for side in [lemming.direction, -lemming.direction]:
		var target := _concrete_block(lemming, side)
		if target != Vector2.INF:
			_smash(lemming, target, side)
			return true
	return false


## The centre of the concrete cell to break on that side, or Vector2.INF.
func _concrete_block(lemming: LemmingController, side: int) -> Vector2:
	var wall_x := find_wall_column(lemming, side)
	if is_nan(wall_x):
		return Vector2.INF
	var tile_width := lemming.terrain.get_cell_size().x
	if side != lemming.direction and absf(wall_x - edge_column_centre(lemming, side)) > tile_width * 1.5:
		return Vector2.INF
	var spot := Vector2(wall_x, lemming.get_body_rect().get_center().y)
	if not lemming.terrain.is_concrete_at(spot) or not lemming.terrain.is_solid_at(spot):
		return Vector2.INF
	return lemming.terrain.cell_rect_at(spot).get_center()


func _smash(lemming: LemmingController, cell_centre: Vector2, side: int) -> void:
	lemming.terrain.destroy_cell_at(cell_centre)
	var parent := lemming.get_parent()
	for burst in DEBRIS_BURSTS:
		DebrisBurst.spawn(parent, cell_centre, Vector2(-side, -1.0).normalized(), TerrainDestructible.TerrainMaterial.CONCRETE)
	RoguelikeAbilityEffect.spawn(parent, cell_centre, RoguelikeAbilityEffect.Style.PUFF, DUST_COLOUR)
	AudioManager.play_sound(&"jackhammer_hit")
