class_name RoguelikeAbilityEffect
extends Node2D
## The short flourish an ability leaves where it acts, drawn in code (no
## art): SPARKLES, little four-pointed stars that burst out and twinkle away
## (the teleport, the repeat); PUFF, soft round clouds that swell and fade
## (a jump's take-off and landing, a plank laid, concrete smashed). Frees
## itself when done.

enum Style { SPARKLES, PUFF }

const LIFETIME_SECONDS := 0.55
const SPARKLE_COUNT := 10
const PUFF_COUNT := 6
const SPARKLE_SPEED := Vector2(30.0, 75.0)
const PUFF_SPEED := Vector2(12.0, 30.0)
const SPARKLE_SIZE := 3.0
const PUFF_RADIUS := Vector2(3.0, 8.0)
## Sparkles drift up a little as they go, like the sacrifice's.
const SPARKLE_LIFT := -30.0
## A lemming lit up by its ability: brighter than white for an instant.
const FLASH_SECONDS := 0.3
const FLASH_BOOST := 1.8

var style: Style = Style.SPARKLES
var colour := Color.WHITE

var _offsets: Array[Vector2] = []
var _velocities: Array[Vector2] = []
var _phases: Array[float] = []
var _age := 0.0


static func spawn(parent: Node, world_position: Vector2, effect_style: Style, effect_colour: Color) -> RoguelikeAbilityEffect:
	var effect := RoguelikeAbilityEffect.new()
	effect.style = effect_style
	effect.colour = effect_colour
	var count := SPARKLE_COUNT if effect_style == Style.SPARKLES else PUFF_COUNT
	var speed := SPARKLE_SPEED if effect_style == Style.SPARKLES else PUFF_SPEED
	for index in count:
		var angle := TAU * (float(index) + randf() * 0.6) / count
		effect._offsets.append(Vector2.ZERO)
		effect._velocities.append(Vector2.RIGHT.rotated(angle) * randf_range(speed.x, speed.y))
		effect._phases.append(randf())
	effect.z_index = 5
	if parent != null:
		parent.add_child(effect)
	effect.global_position = world_position
	return effect


## Brightens a sprite in the ability's colour and lets it settle back.
static func flash(sprite: CanvasItem, flash_colour: Color) -> void:
	if sprite == null:
		return
	var bright := Color(flash_colour.r * FLASH_BOOST, flash_colour.g * FLASH_BOOST, flash_colour.b * FLASH_BOOST, 1.0)
	var resting := sprite.modulate
	sprite.modulate = bright
	sprite.create_tween().tween_property(sprite, "modulate", resting, FLASH_SECONDS)


func _process(delta: float) -> void:
	_age += delta
	if _age >= LIFETIME_SECONDS:
		queue_free()
		return
	for index in _offsets.size():
		_velocities[index] *= 1.0 - 2.5 * delta
		if style == Style.SPARKLES:
			_velocities[index].y += SPARKLE_LIFT * delta
		_offsets[index] += _velocities[index] * delta
	queue_redraw()


func _draw() -> void:
	var life := _age / LIFETIME_SECONDS
	for index in _offsets.size():
		var faded := colour
		if style == Style.SPARKLES:
			# Each star twinkles at its own pace as it fades.
			faded.a = (1.0 - life) * (0.6 + 0.4 * sin((life * 3.0 + _phases[index]) * TAU))
			_draw_star(_offsets[index], SPARKLE_SIZE * (1.0 - life * 0.5), faded)
		else:
			faded.a = 0.7 * (1.0 - life)
			draw_circle(_offsets[index], lerpf(PUFF_RADIUS.x, PUFF_RADIUS.y, life), faded)


func _draw_star(centre: Vector2, size: float, star_colour: Color) -> void:
	draw_colored_polygon(PackedVector2Array([
		centre + Vector2(0, -size * 1.6), centre + Vector2(size * 0.4, -size * 0.4),
		centre + Vector2(size * 1.6, 0), centre + Vector2(size * 0.4, size * 0.4),
		centre + Vector2(0, size * 1.6), centre + Vector2(-size * 0.4, size * 0.4),
		centre + Vector2(-size * 1.6, 0), centre + Vector2(-size * 0.4, -size * 0.4),
	]), star_colour)
	draw_circle(centre, size * 0.45, Color(1, 1, 1, star_colour.a))
