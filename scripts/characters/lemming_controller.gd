class_name LemmingController
extends CharacterBody2D
## Core lemming physics: FALLING and WALKING, wall turn-around/step-up and
## fatal fall detection. Skill-specific states (BUILDING, DIGGING, ...) are
## delegated to the active SkillBase instance instead of branching here.
##
## The lemming knows nothing about the level, the HUD or SkillManager. It
## reports what happens to it through signals (clicked, died, exited) and
## receives what it needs from outside: the terrain it walks on (assigned
## before it enters the tree, or found in the "terrain" group as a fallback)
## and skills through assign_skill().

## Why a lemming died. Decides which death animation plays, and lets
## listeners tell a fall from an explosion without inspecting the lemming.
enum DeathCause { FALL, VOID, EXPLOSION, OTHER }

signal clicked(lemming: LemmingController)
signal died(cause: DeathCause)
signal exited

## Tint a dying lemming fades towards: red, so a death reads as a death and
## not as the lemming simply walking off-screen.
const DEATH_FADE_COLOUR := Color(1.0, 0.25, 0.2, 0.0)
## Body overlap checks shrink the body by this much, so merely touching a
## surface does not count as overlapping it.
const BODY_OVERLAP_INSET := 1.0

## Animation played for each state. States missing here fall back to "walk"
## until they get dedicated art.
const STATE_ANIMATIONS := {
	LemmingStateMachine.State.CLIMBING: &"climb",
	LemmingStateMachine.State.DIGGING: &"dig",
	LemmingStateMachine.State.FLOATING: &"float",
	LemmingStateMachine.State.MINING: &"pickaxe",
	LemmingStateMachine.State.BASHING: &"jackhammer",
	# Back view, which shows the backpack the ladder comes out of. Stands in
	# for a dedicated "pulling the ladder out" animation until that exists.
	LemmingStateMachine.State.LADDER_PLACING: &"ladder",
	LemmingStateMachine.State.LADDER_CLIMBING: &"ladder",
}
const DEFAULT_ANIMATION := &"walk"

## Animation played before the body fades, per cause of death. Causes
## missing here go straight to the fade.
const DEATH_ANIMATIONS := {
	DeathCause.FALL: &"death_fall",
}

@onready var state_machine: LemmingStateMachine = LemmingStateMachine.new()
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var _collision_shape: CollisionShape2D = $CollisionShape2D
@onready var _blocker_zone: Area2D = $BlockerZone

## Terrain this lemming walks on and that its skills carve. Set it before
## adding the lemming to the tree to use a specific terrain; left empty, the
## first node in the "terrain" group is used.
var terrain: TerrainDestructible = null

var direction: int = 1
var current_skill: SkillBase = null

## Pixels per second this lemming climbs a ladder. Read by the ladder tool
## while it builds too, so building and climbing move at the same pace.
var ladder_climb_speed: float = Constants.LADDER_CLIMB_SPEED

# Persistent traits (Climber/Floater): unlike other skills, these don't
# occupy current_skill or a single active state; they permanently change how
# WALKING/FALLING behave. See SkillClimber/SkillFloater.
var has_climber_skill: bool = false

## A tool the lemming carries until it walks into a wall (the vertical
## ladder). Handing it over on click and using it on arrival is what makes it
## usable at all: a lemming turns around the instant it touches a wall, so
## there is no moment for the player to click on it while it stands there.
var pending_wall_tool: SkillBase = null
var has_floater_skill: bool = false

var _fall_start_y: float = 0.0
## While stepping from the top of a ladder or a climbed wall onto the ground
## beside it: which way, and how many pixels of the step are left. Zero when
## not stepping.
var _ledge_step_side: int = 0
var _ledge_step_remaining: float = 0.0
var _sprite_rest_y: float = 0.0
var _sprite_lift_tween: Tween = null


func _ready() -> void:
	add_to_group("lemmings")
	collision_layer = Constants.LEMMING_COLLISION_LAYER
	collision_mask = Constants.TERRAIN_COLLISION_LAYER
	_blocker_zone.collision_mask = Constants.LEMMING_COLLISION_LAYER
	_fall_start_y = position.y
	_sprite_rest_y = animated_sprite.position.y
	if terrain == null:
		terrain = get_tree().get_first_node_in_group("terrain")
	assert(terrain != null, "LemmingController needs a TerrainDestructible: assign one or add it to the 'terrain' group")
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
		clicked.emit(self)


## Applies a skill if the lemming can take it right now. Returns whether it
## was applied, so the caller only spends a skill charge when it was.
func assign_skill(skill: SkillBase) -> bool:
	if not state_machine.is_alive() or not skill.can_apply_to(self):
		return false
	if skill.occupies_skill_slot():
		current_skill = skill
	skill.apply_to(self)
	return true


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


## Moves the lemming sideways so its collision box is centred on the terrain
## column it is standing in. Tools that work in a single column (shovel,
## vertical ladder) call this first: the body is narrower than a tile, so
## once centred it only ever overlaps that one column.
func snap_to_column_centre() -> void:
	# Centre the collision box, not the node: the shape sits at a small
	# offset from the node origin, and snapping the origin would leave the
	# body itself off-centre in the column.
	var body_centre := get_body_rect().get_center()
	global_position.x += terrain.column_centre_x(body_centre) - body_centre.x


## World position at the lemming's feet, used by digging skills to find
## which terrain cell to remove next. Nudged past the collision boundary
## (see Constants.GROUND_PROBE_EPSILON) so it reliably lands inside the
## solid tile instead of the empty one just above it.
func get_feet_position() -> Vector2:
	return _collision_shape.global_position + Vector2(0, get_half_extents().y + Constants.GROUND_PROBE_EPSILON)


## The terrain cell just ahead of the feet: where Builder lays its next step
## and where Miner digs its next diagonal.
func get_forward_feet_position() -> Vector2:
	return get_forward_position() + Vector2(0, get_half_extents().y + Constants.GROUND_PROBE_EPSILON)


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
	# should query the terrain directly instead (see SkillSideDigger).
	var uses_physics_movement := true

	match state_machine.current_state:
		LemmingStateMachine.State.FALLING:
			_process_falling()
		LemmingStateMachine.State.WALKING:
			_process_walking()
		LemmingStateMachine.State.CLIMBING:
			_process_climbing(delta)
		LemmingStateMachine.State.FLOATING:
			_process_floating()
		LemmingStateMachine.State.LADDER_CLIMBING:
			_process_ladder_climbing(delta)
			uses_physics_movement = false
		_:
			_process_skill(delta)
			uses_physics_movement = false

	# Whatever ran above may have killed the lemming (a fatal landing).
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


func _update_animation() -> void:
	var animation_name: StringName = STATE_ANIMATIONS.get(state_machine.current_state, DEFAULT_ANIMATION)
	if animated_sprite.animation != animation_name:
		animated_sprite.play(animation_name)


func _process_falling() -> void:
	velocity.x = 0.0
	if _try_grab_ladder():
		return
	if is_on_floor():
		_land()
	elif _fell_into_void():
		die(DeathCause.VOID)


func _process_floating() -> void:
	velocity.x = 0.0
	if is_on_floor():
		state_machine.change_state(LemmingStateMachine.State.WALKING)
	elif _fell_into_void():
		# Floater survives fall damage, not an actually bottomless level —
		# without this, floating into a gap with no floor anywhere below
		# would leave the lemming falling forever, never saved or lost, so
		# the level could never finish resolving on its own.
		die(DeathCause.VOID)


func _fell_into_void() -> bool:
	return position.y - _fall_start_y > Constants.VOID_FALL_DISTANCE


func _process_climbing(delta: float) -> void:
	if _ledge_step_remaining > 0.0:
		velocity = Vector2.ZERO
		_continue_ledge_step(delta)
		return
	velocity = Vector2(0.0, -Constants.CLIMB_SPEED)

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

	# Climbs until the feet are level with the top of the wall, then walks a
	# short step onto it. It used to stop as soon as the middle of the body
	# cleared the top and jump a whole tile sideways in one frame, landing
	# with its legs inside the ledge: it looked like a teleport.
	# Half a pixel, not GROUND_PROBE_EPSILON: with the larger margin the feet
	# were still below the top when the step began, so the body pushed into
	# the wall's edge, slid off it and fell.
	const PROBE_INSET := 0.5
	var just_above_feet_ahead := Vector2(get_forward_position().x, get_body_rect().end.y - PROBE_INSET)
	if not terrain.is_solid_at(just_above_feet_ahead):
		# The feet are now less than a frame's climb below the top; lift them
		# clear of it so the step slides over the edge instead of into it.
		global_position.y -= PROBE_INSET + Constants.CLIMB_SPEED * delta
		velocity = Vector2.ZERO
		_start_ledge_step(direction, Constants.LEDGE_STEP_FOOTING)


func _process_walking() -> void:
	# Losing the floor is resolved before anything ahead. A lemming standing
	# in a shaft exactly as wide as its own body has solid wall on both
	# sides, so when the wall check came first it turned around every frame
	# and never reached the floor check — hovering in mid-air at the bottom
	# of the shaft it had just dug instead of falling down it.
	# Before the floor check, so a lemming walking past a ladder that starts
	# at its own feet takes it instead of just walking by.
	if _try_grab_ladder():
		return

	if not is_on_floor():
		_start_falling()
		return

	# Resolve direction (wall turn/climb/step-up) BEFORE computing
	# velocity.x, so this same frame's move_and_slide() already pushes the
	# right way instead of one frame later (which let a lemming re-detect
	# the same wall next frame and immediately flip back, oscillating in
	# place forever).
	var step_height := _forward_step_height()
	if step_height >= 0.0 and _is_head_blocked_ahead(step_height):
		step_height = -1.0

	if step_height < 0.0:
		if _try_start_wall_tool():
			return
		if has_climber_skill:
			state_machine.change_state(LemmingStateMachine.State.CLIMBING)
			return
		turn_around()
	elif step_height > 0.0:
		# Lifted flush onto the step AND moved onto it. The step is seen a
		# couple of pixels before the body reaches it; lifted in place, the
		# body hung beside the step for a frame, which read as falling, and a
		# falling lemming loses its forward motion, so it dropped back and
		# stuck on the step's corner. Lifting extra height to clear the gap
		# had the same problem.
		global_position += Vector2(direction * Constants.STEP_UP_FORWARD_NUDGE, -step_height)
		_smooth_sprite_after_lift(step_height)

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
## Whether terrain ahead blocks the body above its feet, even though the
## ground at foot level is clear or only a low step (an overhang at head
## height). Bricks are left out: they only collide from above, so a lemming
## walking underneath a diagonal ladder passes through them. Counting them
## turned it around under the staircase as if it had hit a wall.
func _is_head_blocked_ahead(step_height: float) -> bool:
	var moved_body := get_body_rect()
	moved_body.position += Vector2(direction * Constants.STEP_UP_FORWARD_NUDGE, -step_height)
	return terrain.is_terrain_solid_in_rect(moved_body.grow(-BODY_OVERLAP_INSET))


func _forward_step_height() -> float:
	var feet_y := get_body_rect().end.y
	var forward_x := get_forward_position().x
	# Half a pixel above each candidate height, so the probe sits just inside
	# an obstacle of that height rather than on its top edge.
	const PROBE_INSET := 0.5

	if not terrain.is_solid_at(Vector2(forward_x, feet_y - PROBE_INSET)):
		return 0.0

	# Measured a pixel at a time: the diagonal ladder's steps are a quarter
	# of a tile, and the old quarter-tile probe rounded every obstacle up to
	# the next probe, lifting the lemming 16px onto an 8px step and dropping
	# it back. Anything from 30px up is a wall, same threshold as
	# before, so which ledges are walkable did not change.
	var wall_height := int(Constants.STEP_MAX_HEIGHT - Constants.GROUND_PROBE_EPSILON)
	for rise in range(1, wall_height):
		if not terrain.is_solid_at(Vector2(forward_x, feet_y - rise - PROBE_INSET)):
			return float(rise)
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


## Any walking or falling lemming whose body centre reaches a ladder takes
## it, so a ladder placed by one lemming is used by every lemming that comes
## along afterwards. A lemming that walks off the top edge into the ladder's
## shaft grabs it on the way down and climbs back out instead of dropping.
func _try_grab_ladder() -> bool:
	var centre := get_body_rect().get_center()
	if not terrain.is_ladder_at(centre):
		return false
	if absf(terrain.column_centre_x(centre) - centre.x) > Constants.LADDER_GRAB_DISTANCE:
		return false
	snap_to_column_centre()
	velocity = Vector2.ZERO
	state_machine.change_state(LemmingStateMachine.State.LADDER_CLIMBING)
	return true


## Climbs straight up until the feet clear the top rung, then steps off to
## the side. Position is driven directly, like the action skills, because a
## ladder cell has no collision for physics to rest the body on.
func _process_ladder_climbing(delta: float) -> void:
	velocity = Vector2.ZERO
	if _ledge_step_remaining > 0.0:
		_continue_ledge_step(delta)
		return
	global_position.y -= ladder_climb_speed * delta

	var body := get_body_rect()
	var just_above_feet := Vector2(body.get_center().x, body.end.y - Constants.GROUND_PROBE_EPSILON)
	if not terrain.is_ladder_at(just_above_feet):
		# Feet exactly level with the top rung, so stepping sideways lands
		# the body on the surrounding ground rather than slightly inside it.
		var top_rung_y := terrain.cell_rect_at(just_above_feet).end.y
		global_position.y += top_rung_y - body.end.y
		_step_off_ladder_top()


## The top rung has nothing to stand on itself, so the lemming steps sideways
## onto ground: ahead if there is ground there, otherwise behind. With ground
## on neither side (a ladder still being built, or one leading nowhere) it
## holds on at the top rung instead of stepping into a fall, and carries on as
## soon as the ladder grows.
##
## The step is walked at walking pace, only as far as it takes to have firm
## footing. It used to be a whole tile in a single frame, which looked like
## the lemming vanishing from the ladder and reappearing on the next block.
func _step_off_ladder_top() -> void:
	var tile_width := terrain.get_cell_size().x
	for side in [direction, -direction]:
		if _can_stand_at(Vector2(tile_width * side, 0.0)):
			if side != direction:
				turn_around()
			_start_ledge_step(side, _ladder_step_off_distance())
			return


## Far enough that the body's leading edge rests on the ground beside the
## ladder's column and its centre is past the grab distance, so it neither
## falls back into the shaft nor grabs the same ladder again.
func _ladder_step_off_distance() -> float:
	var to_column_edge := terrain.get_cell_size().x / 2.0 - get_half_extents().x
	return maxf(to_column_edge, 0.0) + Constants.LEDGE_STEP_FOOTING


func _start_ledge_step(side: int, distance: float) -> void:
	_ledge_step_side = side
	_ledge_step_remaining = distance


## Walks the step at walking pace, then carries on walking from there.
func _continue_ledge_step(delta: float) -> void:
	var step := minf(Constants.WALK_SPEED * delta, _ledge_step_remaining)
	global_position.x += step * _ledge_step_side
	_ledge_step_remaining -= step
	if _ledge_step_remaining > 0.0:
		return
	_ledge_step_remaining = 0.0
	_fall_start_y = position.y
	state_machine.change_state(LemmingStateMachine.State.WALKING)


## Whether the body, moved by offset, would be clear of terrain and standing
## on solid ground.
func _can_stand_at(offset: Vector2) -> bool:
	if is_body_blocked_at(offset):
		return false
	return terrain.is_solid_at(get_feet_position() + offset)


func _try_start_wall_tool() -> bool:
	if pending_wall_tool == null or not pending_wall_tool.can_start_at_wall(self):
		return false
	var tool := pending_wall_tool
	pending_wall_tool = null
	current_skill = tool
	tool.start_at_wall(self)
	return true


## Whether the body would overlap solid terrain if moved by offset. Inset by
## a pixel so merely touching a surface does not count as overlapping it.
func is_body_blocked_at(offset: Vector2) -> bool:
	var moved_body := get_body_rect()
	moved_body.position += offset
	return terrain.is_solid_in_rect(moved_body.grow(-BODY_OVERLAP_INSET))


## The body is lifted onto a step in one frame, which on a staircase read as
## the lemming hopping up and down. The sprite is left where it was and
## slides up to the body over a few frames instead, so the climb looks like
## walking up the step while the physics stays exact.
func _smooth_sprite_after_lift(lift: float) -> void:
	if _sprite_lift_tween != null:
		_sprite_lift_tween.kill()
	animated_sprite.position.y += lift
	_sprite_lift_tween = create_tween()
	_sprite_lift_tween.tween_property(animated_sprite, "position:y", _sprite_rest_y, lift / Constants.WALK_SPEED)


func turn_around() -> void:
	direction *= -1
	animated_sprite.flip_h = direction < 0


func die(cause: DeathCause = DeathCause.OTHER) -> void:
	if not state_machine.is_alive():
		return
	state_machine.change_state(LemmingStateMachine.State.DEAD)
	# Emitted before the animation so the level's counts and its win/lose
	# check resolve on the frame the lemming actually died, not once the body
	# has finished disappearing.
	died.emit(cause)
	_play_death(cause)


## A dying lemming used to be freed on the same frame, so it vanished at the
## instant of impact with nothing to show why. Landing a fatal fall and
## falling straight through the floor looked identical, and the second is
## what it got reported as. The body now plays the death animation for its
## cause (a splat for a fall) and then fades out.
func _play_death(cause: DeathCause) -> void:
	set_physics_process(false)
	input_pickable = false
	_blocker_zone.monitoring = false
	_collision_shape.set_deferred("disabled", true)

	var animation_name: StringName = DEATH_ANIMATIONS.get(cause, &"")
	if animation_name != &"" and animated_sprite.sprite_frames.has_animation(animation_name):
		animated_sprite.play(animation_name)
		await animated_sprite.animation_finished

	var tween := create_tween()
	tween.tween_property(animated_sprite, "modulate", DEATH_FADE_COLOUR, Constants.DEATH_FADE_SECONDS)
	tween.tween_callback(queue_free)


func exit() -> void:
	if not state_machine.is_alive():
		return
	state_machine.change_state(LemmingStateMachine.State.EXITED)
	exited.emit()
	queue_free()


func _land() -> void:
	var fall_distance := position.y - _fall_start_y
	if fall_distance > Constants.MAX_SAFE_FALL_HEIGHT:
		die(DeathCause.FALL)
		return
	state_machine.change_state(LemmingStateMachine.State.WALKING)


func _start_falling() -> void:
	_fall_start_y = position.y
	if has_floater_skill:
		state_machine.change_state(LemmingStateMachine.State.FLOATING)
	else:
		state_machine.change_state(LemmingStateMachine.State.FALLING)
