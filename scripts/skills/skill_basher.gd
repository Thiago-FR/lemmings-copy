class_name SkillBasher
extends SkillBase
## Digs horizontally through terrain in the lemming's facing direction, one
## tile at a time, until it breaks into open space, loses its footing, or
## max_duration_seconds runs out (real terrain is always finite, but this
## guards against pathological cases).
##
## Given to a walking lemming, it is carried until the lemming walks into a
## wall and used there (see LemmingController.pending_wall_tool), like the
## vertical ladder. It used to start on the spot, which made it unusable: a
## lemming turns around the instant it touches a wall, so it is never
## standing against one for the player to click, and started anywhere else
## it found nothing ahead to dig and stopped at once.

## Seconds between two consecutive tiles being cleared.
@export var dig_interval_seconds: float = 0.15
## Safety cap on how long a single bash can run.
@export var max_duration_seconds: float = 6.0
## How many tiles tall the tunnel is. One is enough headroom: the body is
## 30px tall and a block 32px. Two broke the block above the lemming too,
## which looked wrong.
@export var tunnel_height_tiles: int = 1

var _time_since_last_bash: float = 0.0
var _elapsed_seconds: float = 0.0


func _init() -> void:
	id = &"basher"
	display_name = "Britadeira"


func can_apply_to(lemming: LemmingController) -> bool:
	return lemming.state_machine.current_state == LemmingStateMachine.State.WALKING \
		and lemming.pending_wall_tool == null


## Carried, not used yet: the bashing starts at the next wall.
func apply_to(lemming: LemmingController) -> void:
	lemming.pending_wall_tool = self


func occupies_skill_slot() -> bool:
	return false


## Any wall will do: there is always something ahead to dig.
func can_start_at_wall(_lemming: LemmingController) -> bool:
	return true


func start_at_wall(lemming: LemmingController) -> void:
	lemming.velocity.x = 0.0
	lemming.state_machine.change_state(LemmingStateMachine.State.BASHING)


func physics_process(lemming: LemmingController, delta: float) -> bool:
	lemming.velocity.x = 0.0

	_elapsed_seconds += delta
	if _elapsed_seconds >= max_duration_seconds:
		return false

	# is_on_floor() would work in theory, but LemmingController skips
	# move_and_slide() while a skill drives the lemming, so the flag stays
	# frozen at whatever it was before bashing started.
	var terrain := lemming.terrain
	if not terrain.is_solid_at(lemming.get_feet_position()):
		return false

	_time_since_last_bash += delta
	if _time_since_last_bash < dig_interval_seconds:
		return true
	_time_since_last_bash = 0.0

	var tile := terrain.get_cell_size()
	var forward := lemming.get_forward_position()
	var destroyed_center := terrain.destroy_cell_at(forward)
	for row in range(1, tunnel_height_tiles):
		terrain.destroy_cell_at(forward + Vector2(0, -tile.y * row))
	if not destroyed_center:
		return false

	lemming.global_position.x += tile.x * lemming.direction
	return true
