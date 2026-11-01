class_name ExplosionEffect
extends Node2D
## The blast of an explosive: a bright flash that swells to the size of the
## blast and fades, a ring of smoke spreading past it, and chips of earth
## and concrete thrown out. Drawn in code, so it needs no art, and frees
## itself when done.

const DURATION_SECONDS := 0.55
const FLASH_COLOURS: Array[Color] = [Color(1, 0.95, 0.6), Color(1, 0.6, 0.15), Color(0.75, 0.2, 0.08)]
const SMOKE_COLOUR := Color(0.25, 0.22, 0.2)
## Bursts of chips thrown out, and how many of them are concrete grey.
const DEBRIS_BURST_COUNT := 8
const CONCRETE_BURST_EVERY := 3

var _radius := 32.0
var _age := 0.0


static func spawn(parent: Node, world_position: Vector2, blast_radius: float) -> ExplosionEffect:
	var effect := ExplosionEffect.new()
	effect._radius = blast_radius
	parent.add_child(effect)
	effect.global_position = world_position
	for burst in DEBRIS_BURST_COUNT:
		var direction := Vector2.UP.rotated(TAU * burst / DEBRIS_BURST_COUNT)
		var material := TerrainDestructible.TerrainMaterial.CONCRETE if burst % CONCRETE_BURST_EVERY == 0 else TerrainDestructible.TerrainMaterial.EARTH
		DebrisBurst.spawn(parent, world_position + direction * blast_radius * 0.4, direction, material)
	return effect


func _process(delta: float) -> void:
	_age += delta
	if _age >= DURATION_SECONDS:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var progress := _age / DURATION_SECONDS
	# Flash: swells fast, then shrinks back as it fades, hot centre first.
	var flash_radius := _radius * sin(minf(progress * 1.6, 1.0) * PI * 0.5) * (1.0 - progress * 0.5)
	for index in FLASH_COLOURS.size():
		var colour := FLASH_COLOURS[FLASH_COLOURS.size() - 1 - index]
		colour.a = 1.0 - progress
		draw_circle(Vector2.ZERO, flash_radius * (1.0 - index * 0.28), colour)
	var smoke := SMOKE_COLOUR
	smoke.a = 0.7 * (1.0 - progress)
	draw_arc(Vector2.ZERO, _radius * (0.6 + progress * 0.7), 0.0, TAU, 32, smoke, 4.0 * (1.0 - progress) + 1.0)
