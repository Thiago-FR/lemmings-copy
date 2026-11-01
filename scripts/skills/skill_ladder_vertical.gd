class_name SkillLadderVertical
extends SkillBase
## Vertical ladder tool. Given to a walking lemming, it is carried until the
## lemming walks into a wall. There the lemming pulls ladder segments out of
## its backpack and builds straight up against the wall, one cell at a time,
## climbing onto each segment before placing the next (the same rhythm as the
## shovel going down), until the top segment is level with the top of the
## wall. Then it steps onto the wall.
##
## The ladder never destroys terrain: it only goes into empty cells. A wall
## that is too tall (more than max_segments), or a column blocked above, is
## not used; the lemming turns around and keeps the ladder for the next wall.
##
## After the last segment the lemming finishes climbing with the ordinary
## ladder behaviour every lemming has (LemmingController._try_grab_ladder),
## which is also what lets any lemming that comes along later climb it.

## Seconds spent pulling out and fixing each segment before climbing onto it.
@export var segment_interval_seconds: float = 0.35
## Tallest ladder, in cells. Walls taller than this are not used.
@export var max_segments: int = 12

## Centre of the cell the ladder starts from. Segments are placed relative
## to this, not to the lemming, because the lemming moves up as it builds.
var _base_centre: Vector2 = Vector2.ZERO
var _segments_needed: int = 0
var _segments_placed: int = 0
var _time_since_last_segment: float = 0.0
var _climb_remaining: float = 0.0


func _init() -> void:
	id = &"ladder_vertical"
	display_name = "Escada vertical"


func can_apply_to(lemming: LemmingController) -> bool:
	return lemming.state_machine.current_state == LemmingStateMachine.State.WALKING \
		and lemming.pending_wall_tool == null


## Carried, not used yet: the ladder goes up at the next suitable wall.
func apply_to(lemming: LemmingController) -> void:
	lemming.pending_wall_tool = self


func occupies_skill_slot() -> bool:
	return false


func can_start_at_wall(lemming: LemmingController) -> bool:
	return _count_segments_to_wall_top(lemming, _column_centre(lemming)) > 0


func start_at_wall(lemming: LemmingController) -> void:
	lemming.velocity = Vector2.ZERO
	lemming.snap_to_column_centre()
	_base_centre = lemming.get_body_rect().get_center()
	_segments_needed = _count_segments_to_wall_top(lemming, _base_centre)
	lemming.state_machine.change_state(LemmingStateMachine.State.LADDER_PLACING)


func physics_process(lemming: LemmingController, delta: float) -> bool:
	lemming.velocity = Vector2.ZERO

	if _climb_remaining > 0.0:
		_climb(lemming, delta)
		return true
	if _segments_placed >= _segments_needed:
		return false

	_time_since_last_segment += delta
	if _time_since_last_segment < segment_interval_seconds:
		return true
	_time_since_last_segment = 0.0

	_place_next_segment(lemming)
	return true


## The first segment goes in the cell the lemming is standing in, so the
## ladder starts at floor level where others can grab it. Every later one
## goes in the cell above, and the lemming climbs up into it.
func _place_next_segment(lemming: LemmingController) -> void:
	lemming.terrain.place_ladder_at(_cell_centre(lemming, _base_centre, 0, _segments_placed))
	if _segments_placed > 0:
		_climb_remaining = lemming.terrain.get_cell_size().y
	_segments_placed += 1


func _climb(lemming: LemmingController, delta: float) -> void:
	var step := minf(lemming.ladder_climb_speed * delta, _climb_remaining)
	lemming.global_position.y -= step
	_climb_remaining -= step


## How many segments reach the top of the wall directly ahead, or 0 if this
## wall cannot be climbed this way: no wall right in front, a cell in the
## ladder's own column already solid (the ladder does not dig), or the wall
## taller than max_segments. The top segment is the one level with the
## wall's last solid cell, so its top rung is level with the wall's top.
func _count_segments_to_wall_top(lemming: LemmingController, base: Vector2) -> int:
	var terrain := lemming.terrain
	for segment_index in max_segments:
		if terrain.is_solid_at(_cell_centre(lemming, base, 0, segment_index)):
			return 0
		if not terrain.is_solid_at(_cell_centre(lemming, base, lemming.direction, segment_index)):
			return 0
		if not terrain.is_solid_at(_cell_centre(lemming, base, lemming.direction, segment_index + 1)):
			return segment_index + 1
	return 0


## Centre of the cell columns_ahead columns along the facing direction and
## rows_up rows above base.
func _cell_centre(lemming: LemmingController, base: Vector2, columns_ahead: int, rows_up: int) -> Vector2:
	var tile := lemming.terrain.get_cell_size()
	return base + Vector2(tile.x * columns_ahead, -tile.y * rows_up)


## Where the ladder would start if built right now: the body's own column,
## centred, before start_at_wall() actually moves the body there.
func _column_centre(lemming: LemmingController) -> Vector2:
	var centre := lemming.get_body_rect().get_center()
	return Vector2(lemming.terrain.column_centre_x(centre), centre.y)
