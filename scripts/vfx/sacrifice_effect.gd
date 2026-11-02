class_name SacrificeEffect
extends Node2D
## What is left on screen when a lemming is sacrificed: a ring of light
## spreading on the ground under it and violet sparks drifting up out of the
## body, while the body itself glows and rises away (LemmingController).
## A voluntary departure, so it reads as magic going up, not as the splat
## of an accident. Drawn in code like DebrisBurst, and frees itself.

const LIFETIME_SECONDS := 0.8
const SPARK_COUNT := 12
const SPARK_SIZE := 2.0
## Sparks start anywhere inside the body's box and drift up at this speed
## (pixels per second), swaying sideways.
const MIN_RISE_SPEED := 25.0
const MAX_RISE_SPEED := 60.0
const SWAY_PIXELS := 3.0
const SWAY_FREQUENCY := 9.0
## The ring at the feet grows to this half-width while flattening out.
const RING_MAX_RADIUS := 18.0
const RING_HEIGHT_RATIO := 0.3
const RING_WIDTH := 1.5

const SPARK_COLOURS: Array[Color] = [Color(0.84, 0.75, 1.0), Color(0.56, 0.42, 0.85), Color(0.83, 0.93, 1.0)]
const RING_COLOUR := Color(0.84, 0.75, 1.0)

var _starts: Array[Vector2] = []
var _speeds: Array[float] = []
var _phases: Array[float] = []
var _colours: Array[Color] = []
var _feet_offset := Vector2.ZERO
var _age := 0.0


## Plays the effect over a body whose box is body_rect (global coordinates).
static func spawn(parent: Node, body_rect: Rect2) -> SacrificeEffect:
	var effect := SacrificeEffect.new()
	var centre := body_rect.get_center()
	for _spark in SPARK_COUNT:
		effect._starts.append(Vector2(randf_range(-0.5, 0.5) * body_rect.size.x, randf_range(-0.5, 0.5) * body_rect.size.y))
		effect._speeds.append(randf_range(MIN_RISE_SPEED, MAX_RISE_SPEED))
		effect._phases.append(randf() * TAU)
		effect._colours.append(SPARK_COLOURS.pick_random())
	effect._feet_offset = Vector2(0.0, body_rect.size.y / 2.0)
	parent.add_child(effect)
	effect.global_position = centre
	return effect


func _process(delta: float) -> void:
	_age += delta
	if _age >= LIFETIME_SECONDS:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var progress := _age / LIFETIME_SECONDS
	var fade := 1.0 - progress
	_draw_ring(progress, fade)
	for index in _starts.size():
		var rise := _speeds[index] * _age
		var sway := sin(_age * SWAY_FREQUENCY + _phases[index]) * SWAY_PIXELS
		var spark := _starts[index] + Vector2(sway, -rise)
		var colour := _colours[index]
		colour.a = fade
		draw_rect(Rect2(spark - Vector2.ONE * SPARK_SIZE / 2.0, Vector2.ONE * SPARK_SIZE), colour)


func _draw_ring(progress: float, fade: float) -> void:
	var radius := RING_MAX_RADIUS * sqrt(progress)
	if radius < 1.0:
		return
	var colour := RING_COLOUR
	colour.a = fade * 0.8
	# An ellipse lying on the ground: a circle squashed vertically.
	draw_set_transform(_feet_offset, 0.0, Vector2(1.0, RING_HEIGHT_RATIO))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 32, colour, RING_WIDTH / RING_HEIGHT_RATIO)
	draw_set_transform(Vector2.ZERO)
