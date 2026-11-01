class_name SkillBuilder
extends SkillBase
## Diagonal ladder tool. The lemming builds a staircase of small bricks in
## the direction it is facing, starting the moment it is given the tool: it
## lays a brick just ahead of its feet, walks up onto it, lays the next one,
## and so on, up to max_pieces. It stops early if the next brick would go into
## terrain or if there is no headroom to step up, and then carries on walking.
##
## Each step is a thin brick: a quarter of a tile tall and a full tile wide
## by default (step_height_fraction_of_tile, step_width_fraction_of_tile),
## so the staircase is a gentle ramp. The previous version used a full 32px
## block per step and teleported the lemming a whole tile up and forward
## each time, which looked nothing like climbing.
##
## Bricks are not on the tile grid (see TerrainDestructible.place_brick), so
## the staircase starts exactly at the lemming's feet wherever it stands.
## Other lemmings walk up it like any low step.

## Steps laid before the builder stops.
@export var max_pieces: int = 12
## Height of each step as a fraction of a terrain tile: 0.25 is 8px on the
## 32px grid, 0.125 would be 4px.
@export var step_height_fraction_of_tile: float = 0.25
## Width of each step as a fraction of a terrain tile: 1.0 is a full block.
@export var step_width_fraction_of_tile: float = 1.0
## Seconds spent laying each brick before stepping onto it.
@export var place_interval_seconds: float = 0.3
## How fast the lemming moves up onto each new step, in pixels per second.
## Walking pace, so building reads as walking up the stairs it lays.
@export var step_up_speed: float = 50.0

## A hair of space kept between the body and the next brick's spot, so the
## body never overlaps the brick it is about to lay.
const BRICK_CLEARANCE := 0.5

var _step_width: float = 0.0
var _step_height: float = 0.0
## Where the staircase starts: the first brick's near edge, and the surface
## the lemming was standing on.
var _origin_x: float = 0.0
var _floor_y: float = 0.0
var _steps_built: int = 0
var _time_since_last_brick: float = 0.0
var _move_remaining: Vector2 = Vector2.ZERO


func _init() -> void:
	id = &"builder"
	display_name = "Escada diagonal"


func can_apply_to(lemming: LemmingController) -> bool:
	return lemming.state_machine.current_state == LemmingStateMachine.State.WALKING


func apply_to(lemming: LemmingController) -> void:
	lemming.velocity = Vector2.ZERO
	var tile := lemming.terrain.get_cell_size()
	_step_width = tile.x * step_width_fraction_of_tile
	_step_height = tile.y * step_height_fraction_of_tile
	var body := lemming.get_body_rect()
	_floor_y = roundf(body.end.y)
	# The first brick starts right at the leading edge, so the lemming steps
	# onto it straight away wherever it was standing.
	_origin_x = roundf(_front_edge(body, lemming.direction))
	lemming.state_machine.change_state(LemmingStateMachine.State.BUILDING)


func physics_process(lemming: LemmingController, delta: float) -> bool:
	lemming.velocity = Vector2.ZERO

	if _move_remaining != Vector2.ZERO:
		_step_up(lemming, delta)
		return true
	if _steps_built >= max_pieces:
		return false

	_time_since_last_brick += delta
	if _time_since_last_brick < place_interval_seconds:
		return true
	_time_since_last_brick = 0.0

	return _lay_next_brick(lemming)


## Lays brick number _steps_built and sets up the walk onto it. Returns false
## when the staircase has to end here: the brick's spot is taken (a wall), or
## the lemming would not fit standing on it (a ceiling).
func _lay_next_brick(lemming: LemmingController) -> bool:
	var offset := _offset_onto_brick(lemming, _steps_built)
	if lemming.is_body_blocked_at(offset):
		return false
	if not lemming.terrain.place_brick(_brick_rect(lemming.direction, _steps_built)):
		return false
	_steps_built += 1
	_move_remaining = offset
	return true


func _step_up(lemming: LemmingController, delta: float) -> void:
	var step := _move_remaining.limit_length(step_up_speed * delta)
	lemming.global_position += step
	_move_remaining -= step
	if _move_remaining.length() < 0.001:
		_move_remaining = Vector2.ZERO


func _brick_rect(direction: int, index: int) -> Rect2:
	var top := _floor_y - _step_height * (index + 1)
	var size := Vector2(_step_width, _step_height)
	if direction > 0:
		return Rect2(Vector2(_origin_x + _step_width * index, top), size)
	return Rect2(Vector2(_origin_x - _step_width * (index + 1), top), size)


## How far the lemming moves to stand on brick index: feet on its top, and
## the leading edge stopped just short of where the next brick goes.
func _offset_onto_brick(lemming: LemmingController, index: int) -> Vector2:
	var body := lemming.get_body_rect()
	var target_bottom := _floor_y - _step_height * (index + 1)
	var target_front := _origin_x + lemming.direction * (_step_width * (index + 1) - BRICK_CLEARANCE)
	return Vector2(target_front - _front_edge(body, lemming.direction), target_bottom - body.end.y)


func _front_edge(body: Rect2, direction: int) -> float:
	return body.end.x if direction > 0 else body.position.x
