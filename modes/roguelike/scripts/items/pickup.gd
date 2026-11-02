class_name RoguelikePickup
extends Area2D
## An item lying in a stage. The first living lemming to walk into it
## collects it: the pickup emits `collected` and disappears. What the item
## does is up to whoever listens (RoguelikeStageSession); the pickup only
## knows how to look and when it was taken.
##
## Drawn in code: tools show their bar icon on a glowing disc, the other
## items a simple shape of their own.

signal collected(pickup: RoguelikePickup, lemming: LemmingController)

const COLLISION_SIZE := Vector2(20, 28)
const DISC_RADIUS := 15.0
const BOB_HEIGHT := 3.0
const BOB_SPEED := 3.0
const GLOW_COLOUR := Color(1.0, 0.9, 0.45, 0.35)
const RIM_COLOUR := Color(1.0, 0.85, 0.3)
const REVIVE_COLOUR := Color(0.95, 0.3, 0.35)
const TIME_COLOUR := Color(0.95, 0.85, 0.55)
const BAG_COLOUR := Color(0.6, 0.4, 0.2)

var spec: RoguelikePickupSpec = null

var _icon: Texture2D = null
var _time := 0.0
var _taken := false


func _ready() -> void:
	assert(spec != null, "A pickup needs a spec before entering the tree")
	collision_layer = 0
	collision_mask = Constants.LEMMING_COLLISION_LAYER
	monitorable = false
	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = COLLISION_SIZE
	shape.shape = rectangle
	add_child(shape)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if spec.kind == RoguelikePickupSpec.Kind.TOOL:
		_icon = UiStyle.icon(spec.tool_id)
	add_to_group("roguelike_pickups")
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _on_body_entered(body: Node2D) -> void:
	var lemming := body as LemmingController
	if _taken or lemming == null or not lemming.state_machine.is_alive():
		return
	_taken = true
	collected.emit(self, lemming)
	queue_free()


func _draw() -> void:
	var centre := Vector2(0, sin(_time * BOB_SPEED) * BOB_HEIGHT)
	draw_circle(centre, DISC_RADIUS, GLOW_COLOUR)
	draw_arc(centre, DISC_RADIUS, 0.0, TAU, 24, RIM_COLOUR, 1.5)
	match spec.kind:
		RoguelikePickupSpec.Kind.TOOL:
			if _icon != null:
				draw_texture_rect(_icon, Rect2(centre - Vector2(12, 12), Vector2(24, 24)), false)
		RoguelikePickupSpec.Kind.REVIVE:
			_draw_heart(centre)
		RoguelikePickupSpec.Kind.TIME:
			_draw_hourglass(centre)
		RoguelikePickupSpec.Kind.CHARGE_BAG:
			_draw_bag(centre)


func _draw_heart(centre: Vector2) -> void:
	draw_circle(centre + Vector2(-4, -2), 5.0, REVIVE_COLOUR)
	draw_circle(centre + Vector2(4, -2), 5.0, REVIVE_COLOUR)
	draw_colored_polygon(PackedVector2Array([
		centre + Vector2(-9, 0), centre + Vector2(9, 0), centre + Vector2(0, 10)
	]), REVIVE_COLOUR)


func _draw_hourglass(centre: Vector2) -> void:
	draw_colored_polygon(PackedVector2Array([
		centre + Vector2(-7, -9), centre + Vector2(7, -9), centre + Vector2(0, 0)
	]), TIME_COLOUR)
	draw_colored_polygon(PackedVector2Array([
		centre + Vector2(0, 0), centre + Vector2(7, 9), centre + Vector2(-7, 9)
	]), TIME_COLOUR)
	draw_line(centre + Vector2(-8, -10), centre + Vector2(8, -10), BAG_COLOUR, 2.0)
	draw_line(centre + Vector2(-8, 10), centre + Vector2(8, 10), BAG_COLOUR, 2.0)


func _draw_bag(centre: Vector2) -> void:
	draw_circle(centre + Vector2(0, 3), 8.0, BAG_COLOUR)
	draw_colored_polygon(PackedVector2Array([
		centre + Vector2(-4, -5), centre + Vector2(4, -5), centre + Vector2(2, -1), centre + Vector2(-2, -1)
	]), BAG_COLOUR)
	draw_line(centre + Vector2(-5, -6), centre + Vector2(5, -6), RIM_COLOUR, 2.0)
