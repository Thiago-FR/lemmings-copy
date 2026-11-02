class_name CarriedToolIndicator
extends Node2D
## What a lemming has, in small bubbles over its head: the tool it holds,
## carried until its spot or being used (the bridge and the diagonal ladder
## start almost at once, and the user wants every tool shown), then its
## permanent traits (claws, parachute). Without it the player cannot tell a
## lemming carrying a pickaxe towards a wall from one with nothing.
##
## Added to each lemming by the level; reads the lemming, which does not
## know about it.

## The 32 px slot icon drawn at this size, inside a bubble a bit larger: a
## dark disc with a light rim, so it reads over sky, earth and concrete.
const ICON_SIZE := 18.0
const BUBBLE_RADIUS := 12.0
## Traits are smaller than the held tool: they are always there.
const TRAIT_SCALE := 0.7
const BUBBLE_GAP := 1.0
const RIM_WIDTH := 1.5
const BUBBLE_COLOUR := Color(0.1, 0.07, 0.06, 0.85)
const RIM_COLOUR := Color(0.94, 0.9, 0.8)
## The held tool's rim, gold while it is being used.
const ACTIVE_RIM_COLOUR := Color(1.0, 0.82, 0.3)
## Gap between the top of the body and the bubbles.
const HEAD_GAP := 2.0
const BOB_PIXELS := 1.5
const BOB_SPEED := 4.0

var _lemming: LemmingController
## [icon id, scale, rim colour] of each bubble, left to right.
var _shown: Array = []
var _textures: Dictionary = {}
var _age := 0.0


static func attach_to(lemming: LemmingController) -> CarriedToolIndicator:
	var indicator := CarriedToolIndicator.new()
	indicator._lemming = lemming
	lemming.add_child(indicator)
	return indicator


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	z_index = 1
	visible = false


func _process(delta: float) -> void:
	var bubbles := _current_bubbles()
	if bubbles != _shown:
		_shown = bubbles
		visible = not bubbles.is_empty()
		queue_redraw()
	if not visible:
		return
	_age += delta
	var body := _lemming.get_body_rect()
	var centre := Vector2(body.get_center().x, body.position.y - HEAD_GAP - BUBBLE_RADIUS + sin(_age * BOB_SPEED) * BOB_PIXELS)
	position = _lemming.to_local(centre)


func _current_bubbles() -> Array:
	var bubbles: Array = []
	if not _lemming.state_machine.is_alive() or _lemming.is_entering_exit:
		return bubbles
	var held: SkillBase = _lemming.current_skill if _lemming.current_skill != null else _lemming.pending_wall_tool
	if held != null and held.is_held_tool():
		var rim := ACTIVE_RIM_COLOUR if held == _lemming.current_skill else RIM_COLOUR
		bubbles.append([String(held.id), 1.0, rim])
	if _lemming.has_climber_skill:
		bubbles.append(["climber", TRAIT_SCALE, RIM_COLOUR])
	if _lemming.has_floater_skill:
		bubbles.append(["floater", TRAIT_SCALE, RIM_COLOUR])
	return bubbles


func _texture(icon_id: String) -> Texture2D:
	if not _textures.has(icon_id):
		_textures[icon_id] = UiStyle.icon(icon_id)
	return _textures[icon_id]


func _draw() -> void:
	var widths: Array[float] = []
	var total := 0.0
	for bubble in _shown:
		var width: float = BUBBLE_RADIUS * 2.0 * bubble[1]
		widths.append(width)
		total += width
	total += BUBBLE_GAP * maxf(_shown.size() - 1, 0)
	var x := -total / 2.0
	for index in _shown.size():
		var bubble: Array = _shown[index]
		var radius: float = BUBBLE_RADIUS * bubble[1]
		var centre := Vector2(x + radius, BUBBLE_RADIUS - radius)
		draw_circle(centre, radius, bubble[2])
		draw_circle(centre, radius - RIM_WIDTH, BUBBLE_COLOUR)
		var texture := _texture(bubble[0])
		if texture != null:
			var size: float = ICON_SIZE * bubble[1]
			draw_texture_rect(texture, Rect2(centre - Vector2.ONE * size / 2.0, Vector2.ONE * size), false)
		x += widths[index] + BUBBLE_GAP
