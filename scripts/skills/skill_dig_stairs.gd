class_name SkillDigStairs
extends SkillBase
## Digging stairs ("Escada que cava"): the way up through rock, for the
## whole group. Given to a walking lemming, it is carried until the lemming
## walks into an earth wall. There it digs a staircase going up into the
## wall, one column at a time: each column is cleared tall enough for a body
## and its floor is half a block above the last one (a step any lemming
## walks up), until the staircase comes out into the open above. The
## lemmings behind walk up the same steps.
##
## Half a block a column, not a whole one: a whole block (32px) is taller
## than a lemming can step up, so a staircase of whole blocks would be a
## wall. Where a column's floor falls in the middle of a block, that block
## is dug from the top only down to the floor, leaving its lower half as the
## step (if it went anyway, a soil step is put back in its place).
##
## Like the pickaxe and the jackhammer, a column goes a slice (a dig stage)
## at a time, the lemming walking a slice further in and up after each one,
## rather than the whole column vanishing at once.
##
## Concrete and the stage's border stop it; so does max_steps.

## Seconds between two slices dug (each column is dug in as many slices as
## a block has dig stages, like the pickaxe's tunnel).
@export var dig_seconds_per_slice: float = 0.2
## How fast the lemming walks up into a dug slice, in pixels per second.
@export var climb_speed: float = 24.0
## Most columns dug with one staircase.
@export var max_steps: int = 24
## How much higher each column's floor is, as a fraction of a block.
@export var rise_fraction_of_tile: float = 0.5

const PROBE_INSET := 0.5
## Room cleared above each column's floor: a body (30) plus the step it
## lifts by walking onto the next column, so a lemming stepping up is not
## stopped by the ceiling of the column it is leaving.
const HEADROOM_FRACTION_OF_TILE := 1.5
## Debris flies up and back towards the digger, like the pickaxe's.
const DEBRIS_THROW := Vector2(-0.6, -0.8)
## Half the size of the probe used to dig one cell from the top.
const CELL_PROBE_HALF := Vector2(2.0, 2.0)

var _floor_y: float = 0.0
var _face_x: float = 0.0
var _steps_dug: int = 0
var _move_remaining: Vector2 = Vector2.ZERO

## The column being dug: where its floor will be, and what is left of it.
var _column_x: float = 0.0
var _next_floor_y: float = 0.0
var _slices_left: int = 0
var _slices_dug: int = 0
var _slice_wait: float = 0.0
## Cells of the column wholly above its floor, dug from the side (centres).
var _side_cells: Array[Vector2] = []
## The cell the floor falls in the middle of, dug from the top only down to
## the floor (centre, and how many stages that takes).
var _top_cells: Array[Vector2] = []
var _top_stages: Array[int] = []


func _init() -> void:
	id = &"dig_stairs"
	display_name = "Escada que cava"


func can_apply_to(lemming: LemmingController) -> bool:
	return lemming.state_machine.current_state == LemmingStateMachine.State.WALKING 		and lemming.pending_wall_tool == null


## Carried, not used yet: the digging starts at the next earth wall.
func apply_to(lemming: LemmingController) -> void:
	lemming.pending_wall_tool = self


func occupies_skill_slot() -> bool:
	return false


## Probed where walking sees the wall (see SkillSideDigger.can_start_at_wall).
## Concrete is turned away from like any other wall.
func can_start_at_wall(lemming: LemmingController) -> bool:
	var ahead := lemming.get_forward_position()
	var terrain := lemming.terrain
	return terrain.is_solid_at(ahead) and not terrain.is_concrete_at(ahead) and not terrain.is_unbreakable_at(ahead)


## Lines the leading edge up with the wall's face, so every column dug is a
## whole column of the grid.
func start_at_wall(lemming: LemmingController) -> void:
	lemming.velocity = Vector2.ZERO
	var face := lemming.terrain.cell_rect_at(lemming.get_forward_position())
	_face_x = face.position.x if lemming.direction > 0 else face.end.x
	lemming.global_position.x += _face_x - _leading_edge(lemming)
	_floor_y = lemming.get_body_rect().end.y
	lemming.state_machine.change_state(LemmingStateMachine.State.STAIR_DIGGING)


## Each column goes a slice at a time: a slice dug, a short walk up into it,
## the next slice. When the last slice is through, the column is finished
## and the next one started, until the staircase comes out above.
func physics_process(lemming: LemmingController, delta: float) -> bool:
	lemming.velocity = Vector2.ZERO
	if _move_remaining != Vector2.ZERO:
		_climb(lemming, delta)
		return true
	if _slices_left <= 0:
		if _slices_dug > 0:
			_finish_column(lemming)
		if _steps_dug >= max_steps or not _begin_column(lemming):
			return false
	_slice_wait -= delta
	if _slice_wait > 0.0:
		return true
	_dig_slice(lemming)
	return true


## Sizes up the next column: false when the staircase ends here (out in the
## open above, or rock it cannot break), otherwise ready to dig it.
func _begin_column(lemming: LemmingController) -> bool:
	var terrain := lemming.terrain
	var tile := terrain.get_cell_size()
	_next_floor_y = _floor_y - tile.y * rise_fraction_of_tile
	var headroom := tile.y * HEADROOM_FRACTION_OF_TILE
	_column_x = _face_x if lemming.direction > 0 else _face_x - tile.x
	var room := Rect2(_column_x, _next_floor_y - headroom, tile.x, headroom)
	var cells := terrain.get_solid_cells_in_rect(room.grow(-PROBE_INSET))
	if cells.is_empty() or terrain.is_above_stage(room.position):
		return false
	_side_cells.clear()
	_top_cells.clear()
	_top_stages.clear()
	for cell in cells:
		var centre := terrain.to_global(terrain.map_to_local(cell))
		if terrain.is_concrete_at(centre) or terrain.is_unbreakable_at(centre):
			return false
		if terrain.cell_rect_at(centre).end.y <= _next_floor_y + PROBE_INSET:
			_side_cells.append(centre)
			continue
		var stages := roundi((_next_floor_y - terrain.solid_top_y_at(centre)) / terrain.get_dig_stage_height())
		if stages > 0:
			_top_cells.append(centre)
			_top_stages.append(stages)
	_slices_left = terrain.get_dig_stage_count()
	_slices_dug = 0
	_slice_wait = dig_seconds_per_slice
	return true


## One slice off every cell of the column: the cells above the floor lose a
## stage from the side facing the digger, the cell under the floor a stage
## from its top while it is still above the floor. Then the lemming walks a
## slice further in and up.
func _dig_slice(lemming: LemmingController) -> void:
	var terrain := lemming.terrain
	var debris_at := Vector2.INF
	var material := TerrainDestructible.TerrainMaterial.EARTH
	for centre in _side_cells:
		material = terrain.material_at(centre)
		if terrain.dig_side_stage_at(centre, lemming.direction, false, id):
			debris_at = centre
	for index in _top_cells.size():
		if _slices_dug < _top_stages[index]:
			var centre := _top_cells[index]
			material = terrain.material_at(centre)
			if terrain.dig_stage_in_rect(Rect2(centre - CELL_PROBE_HALF, CELL_PROBE_HALF * 2.0), false, id) > 0:
				debris_at = centre
	if debris_at != Vector2.INF:
		var face := Vector2(_column_x + (0.0 if lemming.direction > 0 else terrain.get_cell_size().x), debris_at.y)
		DebrisBurst.spawn(lemming.get_parent(), face, Vector2(DEBRIS_THROW.x * lemming.direction, DEBRIS_THROW.y), material)
		AudioManager.play_sound(&"pickaxe_hit")
	var slice_count := terrain.get_dig_stage_count()
	_move_remaining = Vector2(terrain.get_cell_size().x * lemming.direction, _next_floor_y - _floor_y) / slice_count
	_slices_dug += 1
	_slices_left -= 1
	_slice_wait = dig_seconds_per_slice


## The column is through: its floor is the new floor, its far side the new
## face.
func _finish_column(lemming: LemmingController) -> void:
	var tile_width := lemming.terrain.get_cell_size().x
	_put_back_floor(lemming.terrain, Rect2(_column_x, _next_floor_y, tile_width, _floor_y - _next_floor_y))
	_floor_y = _next_floor_y
	_face_x += tile_width * lemming.direction
	_steps_dug += 1
	_slices_dug = 0


## A column's floor in the middle of a block: the block went with the
## column, so the half under the floor comes back as a soil step.
func _put_back_floor(terrain: TerrainDestructible, step: Rect2) -> void:
	var under := Vector2(step.get_center().x, step.position.y + PROBE_INSET)
	if terrain.is_solid_at(under):
		return
	terrain.place_brick(step, true)


## Walks up into the column just dug, rising as it goes.
func _climb(lemming: LemmingController, delta: float) -> void:
	var distance := minf(climb_speed * delta, _move_remaining.length())
	var step := _move_remaining.normalized() * distance
	lemming.global_position += step
	_move_remaining -= step
	if _move_remaining.length() < 0.01:
		lemming.global_position += _move_remaining
		_move_remaining = Vector2.ZERO


func _leading_edge(lemming: LemmingController) -> float:
	var body := lemming.get_body_rect()
	return body.end.x if lemming.direction > 0 else body.position.x
