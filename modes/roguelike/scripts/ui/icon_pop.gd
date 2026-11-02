class_name RoguelikeIconPop
extends Node2D
## An icon that pops up where something happened, rises and fades: the
## user wants animation, not text messages ("aviso não, animação"). Used
## for a recharge picked up (the crystal) and for a new compendium
## discovery (the book). Frees itself when done.

const LIFETIME_SECONDS := 0.9
const RISE_PIXELS := 26.0
const ICON_SIZE := Vector2(24, 24)
## Grows past full size and settles, a quick "pop".
const POP_SCALE := 1.35
const POP_SECONDS := 0.15


static func spawn(parent: Node, world_position: Vector2, icon_id: String) -> RoguelikeIconPop:
	var texture := UiStyle.icon(icon_id)
	if parent == null or texture == null:
		return null
	var pop := RoguelikeIconPop.new()
	pop.z_index = 6
	pop.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	pop.set_meta("texture", texture)
	parent.add_child(pop)
	pop.global_position = world_position
	pop.scale = Vector2.ONE * 0.3
	var tween := pop.create_tween()
	tween.tween_property(pop, "scale", Vector2.ONE * POP_SCALE, POP_SECONDS).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(pop, "scale", Vector2.ONE, POP_SECONDS)
	tween.parallel().tween_property(pop, "position:y", pop.position.y - RISE_PIXELS, LIFETIME_SECONDS - POP_SECONDS).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(pop, "modulate:a", 0.0, LIFETIME_SECONDS - POP_SECONDS).set_ease(Tween.EASE_IN)
	tween.tween_callback(pop.queue_free)
	return pop


func _draw() -> void:
	draw_texture_rect(get_meta("texture"), Rect2(-ICON_SIZE / 2.0, ICON_SIZE), false)
