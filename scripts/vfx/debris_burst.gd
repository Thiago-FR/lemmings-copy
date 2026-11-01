class_name DebrisBurst
extends Node2D
## A handful of small chips thrown out where a tool bites into terrain:
## clods of earth from the shovel and the pickaxe, grey chips from the
## jackhammer. Drawn as plain squares so it needs no art, and frees itself
## once the chips have faded.

const CHIP_COUNT := 5
const CHIP_SIZE := 2.0
const LIFETIME_SECONDS := 0.45
const GRAVITY := 400.0
## Launch speed range, in pixels per second.
const MIN_SPEED := 40.0
const MAX_SPEED := 90.0
## How far the chips spread around the throw direction, in radians.
const SPREAD := 1.1

const EARTH_COLOUR := Color(0.52, 0.37, 0.21)
const CONCRETE_COLOUR := Color(0.70, 0.71, 0.73)

var _positions: Array[Vector2] = []
var _velocities: Array[Vector2] = []
var _age := 0.0
var _colour := EARTH_COLOUR


## Throws chips from world_position, mostly in throw_direction (a unit
## vector, e.g. up and back towards the digger), coloured for the material
## at that spot.
static func spawn(parent: Node, world_position: Vector2, throw_direction: Vector2, material: TerrainDestructible.TerrainMaterial) -> DebrisBurst:
	var burst := DebrisBurst.new()
	burst._colour = CONCRETE_COLOUR if material == TerrainDestructible.TerrainMaterial.CONCRETE else EARTH_COLOUR
	for _chip in CHIP_COUNT:
		var angle := randf_range(-SPREAD, SPREAD)
		burst._positions.append(Vector2.ZERO)
		burst._velocities.append(throw_direction.rotated(angle) * randf_range(MIN_SPEED, MAX_SPEED))
	parent.add_child(burst)
	burst.global_position = world_position
	return burst


func _process(delta: float) -> void:
	_age += delta
	if _age >= LIFETIME_SECONDS:
		queue_free()
		return
	for index in _positions.size():
		_velocities[index].y += GRAVITY * delta
		_positions[index] += _velocities[index] * delta
	queue_redraw()


func _draw() -> void:
	var faded := _colour
	faded.a = 1.0 - _age / LIFETIME_SECONDS
	for chip in _positions:
		draw_rect(Rect2(chip - Vector2.ONE * CHIP_SIZE / 2.0, Vector2.ONE * CHIP_SIZE), faded)
