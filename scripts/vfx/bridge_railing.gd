class_name BridgeRailing
extends Node2D
## What makes a row of bridge planks read as a bridge, like the tool's icon:
## a wooden post at each end and a rope handrail sagging between them, with
## a hanger down to every plank. Grows with the bridge as SkillBridge lays
## each piece, and follows whatever is left of it: planks blown up or dug
## away drop out, and a bridge with no planks left takes its railing away.
##
## Drawn in code over the terrain; it has no collision.

## Post: width, how far it rises above the walking surface and how far it
## hangs below it (posts go down into the gap, as a bridge's do).
const POST_WIDTH := 4.0
const POST_HEIGHT := 18.0
const POST_DEPTH := 8.0
## The rope's height above the walking surface at the posts, and how far it
## sags at the middle of a span, per pixel of span, never more than
## MAX_ROPE_SAG (it stays at about a lemming's waist).
const ROPE_HEIGHT := 16.0
const ROPE_SAG_PER_PIXEL := 0.03
const MAX_ROPE_SAG := 6.0
const ROPE_SEGMENTS := 16
const ROPE_WIDTH := 1.5
const HANGER_WIDTH := 1.0
## How often the planks are checked for still being there.
const CHECK_SECONDS := 0.25

const POST_COLOUR := Color(0.42, 0.26, 0.14)
const POST_LIGHT := Color(0.62, 0.40, 0.22)
const POST_CAP := Color(0.78, 0.68, 0.45)
const ROPE_COLOUR := Color(0.86, 0.78, 0.58)
const OUTLINE_COLOUR := Color(0.1, 0.06, 0.08)

var _terrain: TerrainDestructible
## The walking surface (the planks' top), in the terrain's coordinates.
var _surface_y := 0.0
var _pieces: Array[Rect2] = []
var _since_check := 0.0


## A railing for a bridge whose planks' tops are at surface_y (global).
static func attach(terrain: TerrainDestructible, surface_y: float) -> BridgeRailing:
	var railing := BridgeRailing.new()
	railing._terrain = terrain
	terrain.add_child(railing)
	railing._surface_y = terrain.to_local(Vector2(0.0, surface_y)).y
	return railing


## A plank just laid (global rect).
func add_piece(piece: Rect2) -> void:
	_pieces.append(piece)
	queue_redraw()


func _process(delta: float) -> void:
	_since_check += delta
	if _since_check < CHECK_SECONDS:
		return
	_since_check = 0.0
	var before := _pieces.size()
	_pieces = _pieces.filter(func(piece: Rect2) -> bool: return _terrain.has_brick(piece))
	if _pieces.size() != before:
		if _pieces.is_empty():
			queue_free()
			return
		queue_redraw()


func _draw() -> void:
	for span in _spans():
		_draw_span(span.x, span.y)


## Runs of touching planks, as [left x, right x] in local coordinates: a
## plank destroyed in the middle splits the bridge into two, each with its
## own posts.
func _spans() -> Array[Vector2]:
	var edges: Array[Vector2] = []
	for piece in _pieces:
		var local := Rect2(to_local(piece.position), piece.size)
		edges.append(Vector2(local.position.x, local.end.x))
	edges.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
	var spans: Array[Vector2] = []
	for edge in edges:
		if not spans.is_empty() and edge.x <= spans[-1].y + 0.5:
			spans[-1].y = maxf(spans[-1].y, edge.y)
		else:
			spans.append(edge)
	return spans


func _draw_span(left: float, right: float) -> void:
	var rope_y := _surface_y - ROPE_HEIGHT
	var sag := minf((right - left) * ROPE_SAG_PER_PIXEL, MAX_ROPE_SAG)
	var rope := PackedVector2Array()
	for index in ROPE_SEGMENTS + 1:
		var t := float(index) / ROPE_SEGMENTS
		rope.append(Vector2(lerpf(left, right, t), rope_y + sag * 4.0 * t * (1.0 - t)))
	# Hangers from the rope down to each plank's middle.
	for piece in _pieces:
		var x := to_local(piece.get_center()).x
		if x <= left or x >= right:
			continue
		var t := (x - left) / (right - left)
		var y := rope_y + sag * 4.0 * t * (1.0 - t)
		draw_line(Vector2(x, y), Vector2(x, _surface_y), ROPE_COLOUR.darkened(0.2), HANGER_WIDTH)
	draw_polyline(rope, OUTLINE_COLOUR, ROPE_WIDTH + 1.5)
	draw_polyline(rope, ROPE_COLOUR, ROPE_WIDTH)
	for x in [left, right]:
		_draw_post(x)


func _draw_post(x: float) -> void:
	var post := Rect2(x - POST_WIDTH / 2.0, _surface_y - POST_HEIGHT, POST_WIDTH, POST_HEIGHT + POST_DEPTH)
	draw_rect(post.grow(1.0), OUTLINE_COLOUR)
	draw_rect(post, POST_COLOUR)
	draw_rect(Rect2(post.position, Vector2(1.0, post.size.y)), POST_LIGHT)
	draw_rect(Rect2(post.position - Vector2(0.5, 1.0), Vector2(POST_WIDTH + 1.0, 2.0)), POST_CAP)
