class_name RoguelikePlatformAbility
extends RoguelikeAbility
## Engineer ("Engenheiro"), Platform: lays a plank PLANK_TILES blocks long
## at once where the ground in front ends (up to a block ahead), made of the
## bridge's bricks and laid the same way: hanging just below the walking
## surface, so the lemming and everyone after it walk across flat. A gap
## wider than the plank is still a gap. Refused when there is no edge that
## close, or a wall comes first.

const PLANK_TILES := 3
## A brick is a quarter of a block thick, like the bridge's.
const PIECE_HEIGHT_FRACTION := 0.25
## Narrowest last piece cut to fit against the far side (SkillBridge's).
const MIN_PIECE_WIDTH := 2.0
const DUST_COLOUR := Color(0.95, 0.8, 0.45)


func _init() -> void:
	id = RoguelikeAbilities.PLATFORM


func _use(lemming: LemmingController) -> bool:
	var floor_y := roundf(lemming.get_body_rect().end.y)
	var edge_x := find_floor_edge(lemming, floor_y)
	if is_nan(edge_x):
		return false
	var tile := lemming.terrain.get_cell_size()
	var side := lemming.direction
	var laid: Array[Rect2] = []
	for index in PLANK_TILES:
		var near_x := edge_x + side * tile.x * index
		var piece := Rect2(Vector2(near_x if side > 0 else near_x - tile.x, floor_y), Vector2(tile.x, tile.y * PIECE_HEIGHT_FRACTION))
		piece = lemming.terrain.fit_brick(piece, side, MIN_PIECE_WIDTH)
		if not piece.has_area() or lemming.terrain.is_ladder_at(piece.get_center()):
			break
		if not lemming.terrain.place_brick(piece):
			break
		laid.append(piece)
		if piece.size.x < tile.x:
			break
	if laid.is_empty():
		return false
	for piece in laid:
		RoguelikeAbilityEffect.spawn(lemming.get_parent(), piece.get_center(), RoguelikeAbilityEffect.Style.PUFF, DUST_COLOUR)
	AudioManager.play_sound(&"place_brick")
	return true


## The first x ahead where nothing is under the walking surface at floor_y,
## searched from the body's trailing edge (which is over ground while it
## walks) to a block past its leading edge. NAN if something at body height
## comes first or there is no edge that close.
static func find_floor_edge(lemming: LemmingController, floor_y: float) -> float:
	var body := lemming.get_body_rect()
	var side := lemming.direction
	var trailing := front_edge(body, -side)
	var x := floorf(trailing) if side > 0 else ceilf(trailing)
	var limit := absf(front_edge(body, side) - x) + lemming.terrain.get_cell_size().x * REACH_TILES
	for _pixel in int(limit):
		var column_x := x + side * PROBE_INSET
		if lemming.terrain.is_terrain_solid_in_rect(Rect2(column_x - 0.25, floor_y - body.size.y + BODY_INSET, 0.5, body.size.y - BODY_INSET * 2.0)):
			return NAN
		if not lemming.terrain.is_solid_at(Vector2(column_x, floor_y + PROBE_INSET)):
			return x
		x += side
	return NAN
