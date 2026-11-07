class_name SkillRope
extends SkillBase
## Rope ("Corda"): gets the whole group down a drop that would kill them.
## Given to a walking lemming, it is carried until the lemming reaches a
## ledge with a deadly drop below (deeper than its safe fall height). There
## it ties the rope to the ledge's edge and lets it down to the ground, then
## walks off and slides down it. Every lemming that drops off that ledge
## after it takes hold of the rope too (LemmingController._try_grab_rope).
##
## It only goes down: nothing climbs up a rope. A drop deeper than the rope
## is long still gets it, and whoever reaches its end lets go and falls the
## rest of the way.

## Seconds spent tying the rope to the ledge before letting it down.
@export var tie_seconds: float = 0.6
## How fast the rope is let down, in pixels per second.
@export var lower_speed: float = 240.0
## Longest rope, in terrain cells.
@export var max_length_tiles: int = 16

const PROBE_INSET := 0.5
## Gap left between the hanging body and the ledge's face.
const FACE_CLEARANCE := 1.0

var _rope: Rope = null
var _target_length: float = 0.0
var _tie_remaining: float = 0.0


func _init() -> void:
	id = &"rope"
	display_name = "Corda"


func can_apply_to(lemming: LemmingController) -> bool:
	return lemming.state_machine.current_state == LemmingStateMachine.State.WALKING \
		and lemming.pending_wall_tool == null


## Carried, not used yet: the rope goes down at the next deadly ledge.
func apply_to(lemming: LemmingController) -> void:
	lemming.pending_wall_tool = self


func occupies_skill_slot() -> bool:
	return false


## A ledge right ahead with a drop deeper than this lemming survives.
func can_start_while_walking(lemming: LemmingController) -> bool:
	var edge_x := _ledge_edge_x(lemming)
	if is_nan(edge_x):
		return false
	return _drop_below(lemming, _rope_x(lemming, edge_x)) > lemming.max_safe_fall_height


func start_while_walking(lemming: LemmingController) -> void:
	lemming.velocity = Vector2.ZERO
	var edge_x := _ledge_edge_x(lemming)
	var body := lemming.get_body_rect()
	# Back up to the edge, in case the probe found it a pixel late.
	lemming.global_position.x += edge_x - _front_edge(body, lemming.direction)
	var rope_x := _rope_x(lemming, edge_x)
	_target_length = minf(_drop_below(lemming, rope_x), _max_length(lemming))
	_rope = lemming.terrain.place_rope(Vector2(rope_x, body.end.y))
	_rope.anchor_offset = edge_x - rope_x
	_tie_remaining = tie_seconds
	AudioManager.play_sound(&"place_ladder")
	lemming.state_machine.change_state(LemmingStateMachine.State.ROPE_TYING)


## Ties, then lets the rope down. When it is all the way down the lemming
## walks on, off the ledge, and takes hold of it like everyone else.
func physics_process(lemming: LemmingController, delta: float) -> bool:
	lemming.velocity = Vector2.ZERO
	if _rope == null or not is_instance_valid(_rope):
		return false
	if _tie_remaining > 0.0:
		_tie_remaining -= delta
		return true
	_rope.length = minf(_rope.length + lower_speed * delta, _target_length)
	return _rope.length < _target_length


## Where the floor under the lemming ends just ahead of its front, or NAN if
## there is ground (or a wall) right ahead. Only the ground right in front
## counts, so the rope is tied where the lemming stands, not a step away.
func _ledge_edge_x(lemming: LemmingController) -> float:
	var body := lemming.get_body_rect()
	var direction := lemming.direction
	var feet_y := body.end.y
	var front := _front_edge(body, direction)
	var ahead := Vector2(front + direction * PROBE_INSET, feet_y + PROBE_INSET)
	if lemming.terrain.is_solid_at(ahead) or lemming.terrain.is_solid_at(Vector2(ahead.x, feet_y - PROBE_INSET)):
		return NAN
	# Back from the front edge to where the ground under the body ends.
	for back in range(int(body.size.x)):
		var x := front - direction * (back + PROBE_INSET)
		if lemming.terrain.is_solid_at(Vector2(x, feet_y + PROBE_INSET)):
			return x + direction * PROBE_INSET
	return NAN


## The rope hangs just past the edge, where a body centred on it is clear of
## the ledge's face.
func _rope_x(lemming: LemmingController, edge_x: float) -> float:
	return edge_x + lemming.direction * (lemming.get_half_extents().x + FACE_CLEARANCE)


## How far a body hanging on a rope at rope_x drops before its feet reach
## ground; INF when nothing is below within reach (the void).
func _drop_below(lemming: LemmingController, rope_x: float) -> float:
	var feet_y := lemming.get_body_rect().end.y
	var half_width := lemming.get_half_extents().x - PROBE_INSET
	var reach := int(_max_length(lemming) + lemming.max_safe_fall_height) + 1
	for drop in range(1, reach):
		var y := feet_y + drop
		for x in [rope_x - half_width, rope_x, rope_x + half_width]:
			if lemming.terrain.is_solid_at(Vector2(x, y)):
				return float(drop) - PROBE_INSET
		if lemming.terrain.is_below_stage(Vector2(rope_x, y)):
			return INF
	return INF


func _max_length(lemming: LemmingController) -> float:
	return lemming.terrain.get_cell_size().y * max_length_tiles


func _front_edge(body: Rect2, direction: int) -> float:
	return body.end.x if direction > 0 else body.position.x
