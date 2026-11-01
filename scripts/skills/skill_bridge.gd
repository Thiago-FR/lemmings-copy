class_name SkillBridge
extends SkillBase
## Bridge tool. The lemming lays a flat bridge of thin bricks in the
## direction it is facing, starting the moment it is given the tool: it lays
## a piece, walks to the end of it, lays the next one, and so on, up to
## max_pieces. Unlike the diagonal ladder the pieces do not climb: each one
## hangs just below the surface the lemming walks on, its top flush with
## that surface, so the lemming and everyone after it walk across flat.
##
## The bridge stops at the first piece whose spot is not empty (the far side
## of a gap, a wall, a brick or a ladder), and then the lemming carries on
## walking. A bridge that runs out of pieces over a gap leaves the lemming at
## its unfinished end, and it walks off.
##
## The bridge always starts where the ground under the lemming ends. A
## lemming given the tool on solid floor first walks to the floor's edge
## (still under the tool's control) and starts there; one already leaning
## over the edge starts the bridge at that edge, behind its leading edge.
## Starting at the leading edge instead would make the first piece run into
## the floor the lemming stands on, and a bridge started a few pixels past
## the edge would end a few pixels short of the far side: a gap wider than
## the body, which it falls into.

## Pieces laid before the bridge stops.
@export var max_pieces: int = 12
## Width of each piece as a fraction of a terrain tile: 1.0 is a full block.
@export var step_width_fraction_of_tile: float = 1.0
## Height of each piece as a fraction of a terrain tile: 0.25 is 8px on the
## 32px grid, the same thickness as a diagonal ladder step.
@export var piece_height_fraction_of_tile: float = 0.25
## Seconds spent laying each piece before walking onto it.
@export var place_interval_seconds: float = 0.3
## How fast the lemming walks to the floor's edge and along each new piece,
## in pixels per second. Walking pace, so bridging reads as walking.
@export var walk_speed: float = 50.0

## A hair of space kept between the body and the next piece's spot, so the
## body never touches whatever ends the bridge there.
const PIECE_CLEARANCE := 0.5
## Half a pixel above or below the walking surface, so a probe lands inside
## whatever is there instead of on its edge.
const PROBE_INSET := 0.5
## How far ahead, in tiles, the floor's edge is looked for. Any real floor
## ends well before this; it only keeps the search finite.
const MAX_EDGE_SEARCH_TILES := 100

var _piece_width: float = 0.0
var _piece_height: float = 0.0
## Where the bridge starts (the near edge of the first piece), and the
## surface the lemming walks on, which every piece's top is flush with.
var _origin_x: float = 0.0
var _floor_y: float = 0.0
var _pieces_laid: int = 0
var _time_since_last_piece: float = 0.0
var _move_remaining: Vector2 = Vector2.ZERO


func _init() -> void:
	id = &"bridge"
	display_name = "Ponte"


## Refused when a wall comes before the floor's edge: there is nothing to
## bridge, so the charge is not spent.
func can_apply_to(lemming: LemmingController) -> bool:
	if lemming.state_machine.current_state != LemmingStateMachine.State.WALKING:
		return false
	var floor_y := roundf(lemming.get_body_rect().end.y)
	return not is_nan(_find_floor_edge(lemming, floor_y))


func apply_to(lemming: LemmingController) -> void:
	lemming.velocity = Vector2.ZERO
	var tile := lemming.terrain.get_cell_size()
	_piece_width = tile.x * step_width_fraction_of_tile
	_piece_height = tile.y * piece_height_fraction_of_tile
	var body := lemming.get_body_rect()
	_floor_y = roundf(body.end.y)
	_origin_x = _find_floor_edge(lemming, _floor_y)
	# Walk up to the edge first, unless the lemming is already leaning past it.
	var to_edge := _origin_x - _front_edge(body, lemming.direction)
	if to_edge * lemming.direction > 0.0:
		_move_remaining = Vector2(to_edge, _floor_y - body.end.y)
	lemming.state_machine.change_state(LemmingStateMachine.State.BRIDGING)


func physics_process(lemming: LemmingController, delta: float) -> bool:
	lemming.velocity = Vector2.ZERO

	if _move_remaining != Vector2.ZERO:
		_walk(lemming, delta)
		return true
	if _pieces_laid >= max_pieces:
		return false

	_time_since_last_piece += delta
	if _time_since_last_piece < place_interval_seconds:
		return true
	_time_since_last_piece = 0.0

	return _lay_next_piece(lemming)


## Lays piece number _pieces_laid and sets up the walk along it. Returns
## false when the bridge has to end here: the piece's spot is not empty, or
## the body would run into something walking along it.
func _lay_next_piece(lemming: LemmingController) -> bool:
	var offset := _offset_to_piece_end(lemming, _pieces_laid)
	if lemming.is_body_blocked_at(offset):
		return false
	var piece := _piece_rect(lemming.direction, _pieces_laid)
	if _overlaps_ladder(lemming.terrain, piece):
		return false
	if not lemming.terrain.place_brick(piece):
		return false
	_pieces_laid += 1
	_move_remaining = offset
	return true


func _walk(lemming: LemmingController, delta: float) -> void:
	var step := _move_remaining.limit_length(walk_speed * delta)
	lemming.global_position += step
	_move_remaining -= step
	if _move_remaining.length() < 0.001:
		_move_remaining = Vector2.ZERO


## The first x ahead of the lemming where nothing is under its walking
## surface, searched pixel by pixel from its trailing edge (which is always
## over ground for a lemming that is walking). NAN if something at body
## height (a wall or a step up) comes first.
func _find_floor_edge(lemming: LemmingController, floor_y: float) -> float:
	var body := lemming.get_body_rect()
	var direction := lemming.direction
	var trailing_edge := body.position.x if direction > 0 else body.end.x
	var x := floorf(trailing_edge) if direction > 0 else ceilf(trailing_edge)
	var search_length := int(lemming.terrain.get_cell_size().x * MAX_EDGE_SEARCH_TILES)
	for _pixel in search_length:
		var column_x := x + direction * PROBE_INSET
		if lemming.terrain.is_solid_at(Vector2(column_x, floor_y - PROBE_INSET)):
			return NAN
		if not lemming.terrain.is_solid_at(Vector2(column_x, floor_y + PROBE_INSET)):
			return x
		x += direction
	return NAN


## Ladder cells have no collision, so place_brick() does not see them; a
## bridge stops at a ladder like at any other occupied spot. A piece is
## smaller than a cell, so its inset corners touch every cell it overlaps.
func _overlaps_ladder(terrain: TerrainDestructible, piece: Rect2) -> bool:
	var inner := piece.grow(-PROBE_INSET)
	for corner in [inner.position, Vector2(inner.end.x, inner.position.y), Vector2(inner.position.x, inner.end.y), inner.end]:
		if terrain.is_ladder_at(corner):
			return true
	return false


func _piece_rect(direction: int, index: int) -> Rect2:
	var size := Vector2(_piece_width, _piece_height)
	if direction > 0:
		return Rect2(Vector2(_origin_x + _piece_width * index, _floor_y), size)
	return Rect2(Vector2(_origin_x - _piece_width * (index + 1), _floor_y), size)


## How far the lemming moves to stand at the end of piece index: feet on the
## walking surface, and the leading edge stopped just short of where the
## next piece goes.
func _offset_to_piece_end(lemming: LemmingController, index: int) -> Vector2:
	var body := lemming.get_body_rect()
	var target_front := _origin_x + lemming.direction * (_piece_width * (index + 1) - PIECE_CLEARANCE)
	return Vector2(target_front - _front_edge(body, lemming.direction), _floor_y - body.end.y)


func _front_edge(body: Rect2, direction: int) -> float:
	return body.end.x if direction > 0 else body.position.x
