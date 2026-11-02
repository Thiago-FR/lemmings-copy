class_name RoguelikeFloatingText
extends Label
## A short message that rises from a spot in the world and fades: what an
## item gave, for example.

const RISE := 40.0
const SECONDS := 1.6
const FONT_SIZE := 13
const WIDTH := 220.0


static func spawn(parent: Node, world_position: Vector2, message: String) -> void:
	var label := RoguelikeFloatingText.new()
	label.text = message
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.size = Vector2(WIDTH, 20)
	label.position = world_position - Vector2(WIDTH / 2.0, 36)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.z_index = 10
	label.add_theme_font_size_override("font_size", FONT_SIZE)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 4)
	parent.add_child(label)
	var tween := label.create_tween().set_parallel()
	tween.tween_property(label, "position:y", label.position.y - RISE, SECONDS)
	tween.tween_property(label, "modulate:a", 0.0, SECONDS).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(label.queue_free)
