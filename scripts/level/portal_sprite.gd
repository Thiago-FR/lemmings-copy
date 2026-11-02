class_name PortalSprite
extends RefCounted
## Builds the animated sprites of the entrance and the exit from their
## frames (tools/build_portal_art.py, assets/sprites/level/). Built in code
## so the frame lists live next to the anchors that place them, instead of
## being hand-written into the scenes.

const LEVEL_ART_DIR := "res://assets/sprites/level/"


## An AnimatedSprite2D with one animation per entry of animations:
## {name: [frame file prefix, frame count, fps, loops]}. offset puts the
## art's anchor pixel on the node's origin.
static func make(animations: Dictionary, offset: Vector2) -> AnimatedSprite2D:
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	for animation_name: StringName in animations:
		var spec: Array = animations[animation_name]
		frames.add_animation(animation_name)
		frames.set_animation_speed(animation_name, spec[2])
		frames.set_animation_loop(animation_name, spec[3])
		for index in int(spec[1]):
			var path := LEVEL_ART_DIR + "%s_%d.png" % [spec[0], index]
			if ResourceLoader.exists(path):
				frames.add_frame(animation_name, load(path))
	var sprite := AnimatedSprite2D.new()
	sprite.name = "Art"
	sprite.sprite_frames = frames
	sprite.centered = false
	sprite.offset = offset
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return sprite
