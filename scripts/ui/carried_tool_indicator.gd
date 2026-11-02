class_name CarriedToolIndicator
extends Node2D
## The icon of the tool a lemming carries but has not used yet (ladders,
## bridge, pickaxe, jackhammer wait for their spot), in a small bubble over
## its head. Without it the player cannot tell a lemming carrying a pickaxe
## towards a wall from one with nothing.
##
## Added to each lemming by the level; reads the lemming, which does not
## know about it.

## The 32 px slot icon drawn at this size, inside a bubble a bit larger: a
## dark disc with a light rim, so it reads over sky, earth and concrete.
const ICON_SIZE := 18.0
const BUBBLE_RADIUS := 12.0
const RIM_WIDTH := 1.5
const BUBBLE_COLOUR := Color(0.1, 0.07, 0.06, 0.85)
const RIM_COLOUR := Color(0.94, 0.9, 0.8)
## Gap between the top of the body and the bubble.
const HEAD_GAP := 2.0
const BOB_PIXELS := 1.5
const BOB_SPEED := 4.0

var _lemming: LemmingController
var _shown_tool_id: StringName = &""
var _texture: Texture2D = null
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
	var carried := _lemming.pending_wall_tool
	var tool_id: StringName = carried.id if carried != null else &""
	if tool_id != _shown_tool_id:
		_shown_tool_id = tool_id
		_texture = UiStyle.icon(String(tool_id)) if tool_id != &"" else null
		visible = _texture != null
		queue_redraw()
	if not visible:
		return
	_age += delta
	var body := _lemming.get_body_rect()
	var centre := Vector2(body.get_center().x, body.position.y - HEAD_GAP - BUBBLE_RADIUS + sin(_age * BOB_SPEED) * BOB_PIXELS)
	position = _lemming.to_local(centre)


func _draw() -> void:
	if _texture == null:
		return
	draw_circle(Vector2.ZERO, BUBBLE_RADIUS, RIM_COLOUR)
	draw_circle(Vector2.ZERO, BUBBLE_RADIUS - RIM_WIDTH, BUBBLE_COLOUR)
	draw_texture_rect(_texture, Rect2(-Vector2.ONE * ICON_SIZE / 2.0, Vector2.ONE * ICON_SIZE), false)
