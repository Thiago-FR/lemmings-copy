class_name LemmingController
extends CharacterBody2D
## Core lemming physics: FALLING and WALKING, wall turn-around/step-up and
## fatal fall detection. Skill-specific states (BUILDING, DIGGING, ...) are
## delegated to the active SkillBase instance instead of branching here.

signal died
signal exited

@onready var state_machine: LemmingStateMachine = LemmingStateMachine.new()
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var _collision_shape: CollisionShape2D = $CollisionShape2D
@onready var _blocker_zone: Area2D = $BlockerZone

var direction: int = 1
var current_skill: SkillBase = null

# Persistent traits (Climber/Floater): unlike other skills, these don't
# occupy current_skill or a single active state; they permanently change how
# WALKING/FALLING behave. See SkillClimber/SkillFloater.
var has_climber_skill: bool = false
var has_floater_skill: bool = false

# Bomber ticks independently of current_skill/state so the lemming keeps
# doing whatever it was doing until the fuse actually goes off.
var armed_bomber: SkillBomber = null

var _fall_start_y: float = 0.0


func _ready() -> void:
	collision_layer = Constants.LEMMING_COLLISION_LAYER
	collision_mask = Constants.TERRAIN_COLLISION_LAYER
	_blocker_zone.collision_mask = Constants.LEMMING_COLLISION_LAYER
	_fall_start_y = position.y
	input_event.connect(_on_input_event)
	_blocker_zone.body_entered.connect(_on_blocker_zone_body_entered)
	_assert_body_fits_carved_openings()


## Guards the invariant documented on Constants.MAX_BODY_WIDTH. Checked at
## spawn rather than left to surface later as a skill that carves an opening
## the lemming cannot pass through, which is how the bug originally
## presented and why it was so hard to trace back to the body size.
func _assert_body_fits_carved_openings() -> void:
	var body_size := get_half_extents() * 2.0
	assert(
		body_size.x <= Constants.MAX_BODY_WIDTH and body_size.y <= Constants.MAX_BODY_HEIGHT,
		"Lemming collision box is %s but must be at most %sx%s to pass through the tile-aligned openings the digging skills carve." % [
			body_size, Constants.MAX_BODY_WIDTH, Constants.MAX_BODY_HEIGHT
		]
	)


func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		SkillManager.try_assign_to(self)


func set_blocker_zone_active(active: bool) -> void:
	_blocker_zone.monitoring = active


## Half-width/half-height of the actual collision shape, read live instead
## of duplicated into constants, so resizing CollisionShape2D in the editor
## doesn't silently desync the skill/terrain math below.
func get_half_extents() -> Vector2:
	var rect_shape: RectangleShape2D = _collision_shape.shape
	return rect_shape.size / 2.0


## World-space rectangle of the body that actually collides. Digging and
## building skills size their carves from this instead of from constants, so
## the opening they make always matches the body that has to pass through it
## even if the collision shape is resized in the editor.
func get_body_rect() -> Rect2:
	var half := get_half_extents()
	return Rect2(_collision_shape.global_position - half, half * 2.0)


## World position at the lemming's feet, used by digging skills to find
## which terrain cell to remove next. Nudged past the collision boundary
## (see Constants.GROUND_PROBE_EPSILON) so it reliably lands inside the
## solid tile instead of the empty one just above it.
func get_feet_position() -> Vector2:
	return _collision_shape.global_position + Vector2(0, get_half_extents().y + Constants.GROUND_PROBE_EPSILON)


## World position just past the lemming's leading edge (in its facing
## direction), used by Basher/Miner to find the wall cell ahead. Same
## boundary nudge as get_feet_position().
func get_forward_position(extra_offset: float = 0.0) -> Vector2:
	var half := get_half_extents()
	return _collision_shape.global_position + Vector2((half.x + Constants.GROUND_PROBE_EPSILON + extra_offset) * direction, 0)


func _on_blocker_zone_body_entered(body: Node2D) -> void:
	if body == self or not (body is LemmingController):
		return
	if body.state_machine.current_state == LemmingStateMachine.State.WALKING:
		body.turn_around()


func _physics_process(delta: float) -> void:
	if not state_machine.is_alive():
		return

	# Action skills (Digger, Builder, Basher, Miner, Blocker, ...) move the
	# lemming by writing global_position directly rather than through
	# velocity. move_and_slide() — even called with zero velocity — still
	# depenetrates the body from whatever it's newly overlapping, which
	# undoes the skill's own positioning right after it just dug into
	# still-solid terrain one tile below/ahead (the body is taller/wider
	# than a single tile). So these states skip the physics step below
	# entirely and own position fully; is_on_floor()/is_on_wall() go stale
	# while they're active, so skill scripts must not rely on those and
	# should query the terrain directly instead (see SkillBasher).
	var uses_physics_movement := true

	match state_machine.current_state:
		LemmingStateMachine.State.FALLING:
			_process_falling()
		LemmingStateMachine.State.WALKING:
			_process_walking()
		LemmingStateMachine.State.CLIMBING:
			_process_climbing()
		LemmingStateMachine.State.FLOATING:
			_process_floating()
		_:
			_process_skill(delta)
			uses_physics_movement = false

	# Bomber ticks down independently of the state above: a bombed lemming
	# keeps walking/building/whatever until the fuse actually goes off.
	if armed_bomber != null:
		var still_armed := armed_bomber.physics_process(self, delta)
		if not still_armed:
			armed_bomber = null

	if not state_machine.is_alive():
		return

	if uses_physics_movement:
		# Climbing sets its own velocity.y every frame (see _process_climbing)
		# and shouldn't fight gravity on top of that — it was cutting the
		# effective climb speed from 18px/s to ~3px/s.
		if state_machine.current_state != LemmingStateMachine.State.CLIMBING:
			var is_floating := state_machine.current_state == LemmingStateMachine.State.FLOATING
			var terminal_speed := Constants.FLOAT_FALL_SPEED if is_floating else Constants.TERMINAL_FALL_SPEED
			velocity.y = min(velocity.y + Constants.GRAVITY * delta, terminal_speed)
		move_and_slide()

	_update_animation()


## Only the walk/climb cycles exist so far (see lemming.tscn); every other
## state just falls back to "walk" until dedicated art is added.
func _update_animation() -> void:
	var animation_name := "climb" if state_machine.current_state == LemmingStateMachine.State.CLIMBING else "walk"
	if animated_sprite.animation != animation_name:
		animated_sprite.play(animation_name)


func _process_falling() -> void:
	velocity.x = 0.0
	if is_on_floor():
		_land()
	elif _fell_into_void():
		die()


func _process_floating() -> void:
	velocity.x = 0.0
	if is_on_floor():
		state_machine.change_state(LemmingStateMachine.State.WALKING)
	elif _fell_into_void():
		# Floater survives fall damage, not an actually bottomless level —
		# without this, floating into a gap with no floor anywhere below
		# would leave the lemming falling forever, never saved or lost, so
		# the level could never finish resolving on its own.
		die()


func _fell_into_void() -> bool:
	return position.y - _fall_start_y > Constants.VOID_FALL_DISTANCE


func _process_climbing() -> void:
	velocity = Vector2(0.0, -Constants.CLIMB_SPEED)

	var terrain: TerrainDestructible = get_tree().get_first_node_in_group("terrain")
	if terrain == null:
		return

	# Terrain-grid checks instead of is_on_ceiling()/is_on_wall(): a wall
	# tall enough to need Climber is built from many stacked tiles, and the
	# physics flags can flicker false for a single frame right at a seam
	# between two of them (the same ghost-collision issue walking had at a
	# ledge's edge) — which made a lemming think it reached the top mid-wall
	# and step sideways into still-solid rock, getting stuck oscillating.
	var half := get_half_extents()
	var head_point := _collision_shape.global_position + Vector2(0, -half.y - Constants.GROUND_PROBE_EPSILON)
	if terrain.is_solid_at(head_point):
		turn_around()
		state_machine.change_state(LemmingStateMachine.State.WALKING)
		return

	if not terrain.is_solid_at(get_forward_position()):
		# Reached the top of the wall: step a full tile onto the ledge so
		# the lemming clears the wall's edge instead of hovering right at
		# it (and doesn't immediately re-detect the same wall next frame).
		global_position.x += Constants.TERRAIN_TILE_SIZE * direction
		state_machine.change_state(LemmingStateMachine.State.WALKING)


func _process_walking() -> void:
	# Losing the floor is resolved before anything ahead. A lemming standing
	# in a shaft exactly as wide as its own body has solid wall on both
	# sides, so when the wall check came first it turned around every frame
	# and never reached the floor check — hovering in mid-air at the bottom
	# of the shaft it had just dug instead of falling down it.
	if not is_on_floor():
		_start_falling()
		return

	# Resolve direction (wall turn/climb/step-up) BEFORE computing
	# velocity.x, so this same frame's move_and_slide() already pushes the
	# right way instead of one frame later (which let a lemming re-detect
	# the same wall next frame and immediately flip back, oscillating in
	# place forever).
	var terrain: TerrainDestructible = get_tree().get_first_node_in_group("terrain")
	var step_height := _forward_step_height(terrain) if terrain != null else 0.0

	if step_height < 0.0:
		if has_climber_skill:
			state_machine.change_state(LemmingStateMachine.State.CLIMBING)
			return
		turn_around()
	elif step_height > 0.0:
		global_position.y -= step_height

	velocity.x = Constants.WALK_SPEED * direction


## Classifies what's directly ahead at foot level by walking the terrain
## grid upward from the lemming's current foot height, rather than trusting
## CharacterBody2D.is_on_wall() (which can misfire for a single frame right
## where a floor tile ends — a corner between the top and side collision
## faces briefly reads as "wall", turning a lemming around at a ledge
## instead of letting it walk off — and can't tell a Builder step from a
## genuine multi-tile wall in the first place).
##
## Returns 0.0 for flat/open ground (nothing to do), a positive height to
## step up onto a short ledge (a Builder step, the lip left by Digger/
## Miner), or -1.0 if solid terrain extends all the way up to
## Constants.STEP_MAX_HEIGHT (too tall to just walk onto — a real wall).
## Deliberately a single combined check: having "is this a wall" and "is
## this a step" as two separate probes let them disagree — an obstruction
## exactly Constants.STEP_MAX_HEIGHT tall wasn't short enough for the step
## probe to find clearance, but also didn't hit the (differently placed)
## wall probe, so the lemming neither turned around nor stepped up and just
## froze walking into solid terrain.
func _forward_step_height(terrain: TerrainDestructible) -> float:
	var half := get_half_extents()
	var forward_x := get_forward_position().x
	var foot_y := _collision_shape.global_position.y + half.y + Constants.GROUND_PROBE_EPSILON
	var probe_increment := Constants.STEP_MAX_HEIGHT / 4.0

	if not terrain.is_solid_at(Vector2(forward_x, foot_y - probe_increment)):
		return 0.0

	var climbed := probe_increment
	while climbed < Constants.STEP_MAX_HEIGHT:
		climbed += probe_increment
		if not terrain.is_solid_at(Vector2(forward_x, foot_y - climbed)):
			return climbed
	return -1.0


func _process_skill(delta: float) -> void:
	if current_skill == null:
		state_machine.change_state(LemmingStateMachine.State.WALKING)
		return

	var still_active := current_skill.physics_process(self, delta)
	if not still_active:
		current_skill = null
		if state_machine.is_alive():
			state_machine.change_state(LemmingStateMachine.State.WALKING)


func turn_around() -> void:
	direction *= -1
	animated_sprite.flip_h = direction < 0


func die() -> void:
	if not state_machine.is_alive():
		return
	state_machine.change_state(LemmingStateMachine.State.DEAD)
	died.emit()
	queue_free()


func exit() -> void:
	if not state_machine.is_alive():
		return
	state_machine.change_state(LemmingStateMachine.State.EXITED)
	exited.emit()
	queue_free()


func _land() -> void:
	var fall_distance := position.y - _fall_start_y
	if fall_distance > Constants.MAX_SAFE_FALL_HEIGHT:
		die()
		return
	state_machine.change_state(LemmingStateMachine.State.WALKING)


func _start_falling() -> void:
	_fall_start_y = position.y
	if has_floater_skill:
		state_machine.change_state(LemmingStateMachine.State.FLOATING)
	else:
		state_machine.change_state(LemmingStateMachine.State.FALLING)
