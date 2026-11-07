class_name SkillBuilder
extends SkillBase
## Diagonal ladder tool. The lemming builds a staircase of small bricks in
## the direction it is facing, starting the moment it is given the tool: it
## lays a brick just ahead of its feet, walks up onto it, lays the next one,
## and so on, up to max_pieces. It stops early if there is no headroom to
## step up, or at a wall, and then carries on walking.
##
## At a wall the last step is cut to the room left, so the staircase always
## ends touching the wall. It used to stop when the next full step did not
## fit, leaving a gap of up to a step's width at its foot: lemmings crossed
## it or turned at it, and a second ladder could not fill it
## (prints/bug5.png, bug7.png).
##
## Each step is a thin brick: a quarter of a tile tall and a full tile wide
## by default (step_height_fraction_of_tile, step_width_fraction_of_tile),
## so the staircase is a gentle ramp. The previous version used a full 32px
## block per step and teleported the lemming a whole tile up and forward
## each time, which looked nothing like climbing.
##
## Bricks are not tiles (see TerrainDestructible.place_brick), but on open
## ground the staircase starts on the next column line (see _set_origin), so
## its steps lie on the columns. Other lemmings walk up it like any low step.
##
## When the first brick has no room (the lemming is part-way up a staircase,
## the next step already there, or faces a wall), the lemming keeps the tool
## (LemmingController.pending_wall_tool) and starts as soon as there is room:
## given to a lemming walking up a finished staircase, it carries on from the
## top step and extends it. It used to start on the spot anyway, find the
## spot taken and stop at once, spending the charge for nothing.

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

## Animation of the BUILDING state (LemmingController.STATE_ANIMATIONS):
## kneel and hammer a step, then walk up onto it (see SkillAnimation).
const ANIMATION := &"build"
## A hair of space kept between the body and the next brick's spot, so the
## body never overlaps the brick it is about to lay.
const BRICK_CLEARANCE := 0.5
## Narrowest step cut to fit against a wall. Below this the staircase is
## already touching the wall for every purpose.
const MIN_STEP_WIDTH := 2.0

var _step_width: float = 0.0
var _step_height: float = 0.0
## Where the staircase starts: the first brick's near edge, and the surface
## the lemming was standing on.
var _origin_x: float = 0.0
var _floor_y: float = 0.0
var _steps_built: int = 0
## Set once a step had to be cut to fit against a wall: the staircase ends
## with it.
var _reached_wall := false
var _time_since_last_brick: float = 0.0
var _move_remaining: Vector2 = Vector2.ZERO


func _init() -> void:
	id = &"builder"
	display_name = "Escada diagonal"


## Refused only by a lemming already carrying a tool, like the other
## carried tools.
func can_apply_to(lemming: LemmingController) -> bool:
	return lemming.state_machine.current_state == LemmingStateMachine.State.WALKING 		and lemming.pending_wall_tool == null


## Takes control itself when it starts (now or later), so the lemming walks
## normally while carrying it.
func occupies_skill_slot() -> bool:
	return false


func apply_to(lemming: LemmingController) -> void:
	if can_start_while_walking(lemming):
		lemming.current_skill = self
		start_while_walking(lemming)
	else:
		lemming.pending_wall_tool = self


## Whether the first brick would fit right now and the lemming could step
## onto it.
func can_start_while_walking(lemming: LemmingController) -> bool:
	_measure(lemming)
	_set_origin(lemming)
	var first := _fitted_brick(lemming, _brick_rect(lemming.direction, 0))
	if not first.has_area():
		return false
	return not lemming.is_body_blocked_at(_offset_onto_brick(lemming, first))


func start_while_walking(lemming: LemmingController) -> void:
	lemming.velocity = Vector2.ZERO
	_measure(lemming)
	_set_origin(lemming)
	lemming.state_machine.change_state(LemmingStateMachine.State.BUILDING)


## Where the first brick goes. On open ground, on the line between the
## column the lemming stands in and the next one, so every step lies on a
## column and the last one meets a wall whole: started at the leading edge,
## wherever that happened to be, the last step came out cut against the wall
## and 8px higher than the stage generator's solver expects, enough to walk
## up a one-block wall it counted on stopping the lemming (campaign level 3).
## The first brick lies on the ground, so a body overlapping it a little or
## a short stretch of ground before it changes nothing. Standing on a brick
## (the top step of a staircase), at that brick's far end, one step up: the
## new staircase carries straight on from the old one. Starting at the
## leading edge there stacked the first brick on top of the last step,
## half-way along it (prints/bug6.png).
func _set_origin(lemming: LemmingController) -> void:
	var body := lemming.get_body_rect()
	_floor_y = roundf(body.end.y)
	var column := lemming.terrain.cell_rect_at(body.get_center())
	_origin_x = column.end.x if lemming.direction > 0 else column.position.x
	var front := roundf(_front_edge(body, lemming.direction))
	var under_front := Vector2(front - lemming.direction * BRICK_CLEARANCE * 2.0, body.end.y + BRICK_CLEARANCE)
	var brick := lemming.terrain.brick_at(under_front)
	if brick.has_area():
		_floor_y = brick.position.y
		_origin_x = brick.end.x if lemming.direction > 0 else brick.position.x


func _measure(lemming: LemmingController) -> void:
	var tile := lemming.terrain.get_cell_size()
	_step_width = tile.x * step_width_fraction_of_tile
	_step_height = tile.y * step_height_fraction_of_tile


func physics_process(lemming: LemmingController, delta: float) -> bool:
	lemming.velocity = Vector2.ZERO
	SkillAnimation.hold(lemming.animated_sprite, ANIMATION, _move_remaining == Vector2.ZERO)

	if _move_remaining != Vector2.ZERO:
		_step_up(lemming, delta)
		return true
	if _steps_built >= max_pieces or _reached_wall:
		return false

	_time_since_last_brick += delta
	if _time_since_last_brick < place_interval_seconds:
		return true
	_time_since_last_brick = 0.0

	return _lay_next_brick(lemming)


## Lays brick number _steps_built (cut short against a wall if need be) and
## sets up the walk onto it. Returns false when the staircase has to end
## here: no room for even a cut step (a wall right there), or the lemming
## would not fit standing on it (a ceiling).
func _lay_next_brick(lemming: LemmingController) -> bool:
	var brick := _fitted_brick(lemming, _brick_rect(lemming.direction, _steps_built))
	if not brick.has_area():
		return false
	var offset := _offset_onto_brick(lemming, brick)
	if lemming.is_body_blocked_at(offset):
		return false
	if not lemming.terrain.place_brick(brick):
		return false
	AudioManager.play_sound(&"place_brick")
	_steps_built += 1
	_reached_wall = brick.size.x < _step_width
	_move_remaining = offset
	return true


## The brick as it fits (see TerrainDestructible.fit_brick): cut against the
## wall the staircase has reached.
func _fitted_brick(lemming: LemmingController, brick: Rect2) -> Rect2:
	return lemming.terrain.fit_brick(brick, lemming.direction, MIN_STEP_WIDTH)


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


## How far the lemming moves to stand on a brick: feet on its top, and the
## leading edge stopped just short of its far end (where the next brick
## goes, or the wall a cut step reaches).
func _offset_onto_brick(lemming: LemmingController, brick: Rect2) -> Vector2:
	var body := lemming.get_body_rect()
	var far_end := brick.end.x if lemming.direction > 0 else brick.position.x
	var target_front := far_end - lemming.direction * BRICK_CLEARANCE
	return Vector2(target_front - _front_edge(body, lemming.direction), brick.position.y - body.end.y)


func _front_edge(body: Rect2, direction: int) -> float:
	return body.end.x if direction > 0 else body.position.x
