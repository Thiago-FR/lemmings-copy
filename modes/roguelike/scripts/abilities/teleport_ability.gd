class_name RoguelikeTeleportAbility
extends RoguelikeAbility
## Wizard ("Mago"), Teleport: the lemming vanishes and appears on the other
## side of a wall or a floor exactly one block thick. Wizard-like without
## breaking the stages: only one block, never into rock, never out of the
## stage, and few charges.
##
## Which way: a wall in front (up to a block ahead), else a wall right
## behind it (a lemming that has just turned at one, so the player does not
## have to wait for it to come back), else the floor under it. Refused when
## the wall or floor is thicker, when the body would not fit on the other
## side, or when the other side is outside the stage.

const SPARKLE_COLOUR := Color(0.78, 0.6, 1.0)


func _init() -> void:
	id = RoguelikeAbilities.TELEPORT


func _use(lemming: LemmingController) -> bool:
	for side in [lemming.direction, -lemming.direction]:
		var target := _through_wall(lemming, side)
		if not is_nan(target.x):
			_teleport(lemming, target, side)
			return true
	var below := _through_floor(lemming)
	if is_nan(below.x):
		return false
	_teleport(lemming, below, lemming.direction)
	return true


## Where the body's centre goes through the wall on that side, or NAN.
## Behind, only a wall the body touches counts: one a block behind is one it
## is walking away from.
func _through_wall(lemming: LemmingController, side: int) -> Vector2:
	var wall_x := find_wall_column(lemming, side)
	if is_nan(wall_x):
		return Vector2(NAN, NAN)
	var tile_width := lemming.terrain.get_cell_size().x
	if side != lemming.direction and absf(wall_x - edge_column_centre(lemming, side)) > tile_width * 1.5:
		return Vector2(NAN, NAN)
	var target := Vector2(wall_x + side * tile_width, lemming.get_body_rect().get_center().y)
	if not _can_land(lemming, target):
		return Vector2(NAN, NAN)
	return target


## Where the body's centre goes through the floor under it, or NAN: centred
## in its column, standing at the bottom of the cell under the floor.
func _through_floor(lemming: LemmingController) -> Vector2:
	var body := lemming.get_body_rect()
	var tile := lemming.terrain.get_cell_size()
	var floor_cell := lemming.terrain.cell_rect_at(Vector2(body.get_center().x, body.end.y + PROBE_INSET))
	if not lemming.terrain.is_terrain_solid_in_rect(floor_cell.grow(-BODY_INSET)):
		return Vector2(NAN, NAN)
	var feet_y := floor_cell.end.y + tile.y
	var target := Vector2(floor_cell.get_center().x, feet_y - body.size.y / 2.0)
	if not _can_land(lemming, target):
		return Vector2(NAN, NAN)
	return target


func _can_land(lemming: LemmingController, body_centre: Vector2) -> bool:
	return is_inside_stage(lemming.terrain, body_centre) and body_fits_at(lemming, body_centre)


func _teleport(lemming: LemmingController, body_centre: Vector2, facing: int) -> void:
	var parent := lemming.get_parent()
	var body := lemming.get_body_rect()
	RoguelikeAbilityEffect.spawn(parent, body.get_center(), RoguelikeAbilityEffect.Style.SPARKLES, SPARKLE_COLOUR)
	lemming.global_position += body_centre - body.get_center()
	lemming.velocity = Vector2.ZERO
	if facing != lemming.direction:
		lemming.turn_around()
	RoguelikeAbilityEffect.spawn(parent, body_centre, RoguelikeAbilityEffect.Style.SPARKLES, SPARKLE_COLOUR)
	RoguelikeAbilityEffect.flash(lemming.animated_sprite, SPARKLE_COLOUR)
	AudioManager.play_sound(&"spawn")
