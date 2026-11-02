class_name PortalSprite
extends RefCounted
## Builds the animated sprites of the entrance and the exit from their
## frames (tools/build_portal_art.py, assets/sprites/level/). Built in code
## so the frame lists live next to the anchors that place them, instead of
## being hand-written into the scenes.

const LEVEL_ART_DIR := "res://assets/sprites/level/"
## Recoloured entrances and exits, one folder per art theme
## (tools/build_terrain_themes.py), with the same file names.
const THEMES_DIR := LEVEL_ART_DIR + "themes/"


## An AnimatedSprite2D with one animation per entry of animations:
## {name: [frame file prefix, frame count, fps, loops]}. offset puts the
## art's anchor pixel on the node's origin. theme picks a recoloured set;
## a frame the theme lacks comes from the default art.
static func make(animations: Dictionary, offset: Vector2, theme: StringName = &"") -> AnimatedSprite2D:
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	for animation_name: StringName in animations:
		var spec: Array = animations[animation_name]
		frames.add_animation(animation_name)
		frames.set_animation_speed(animation_name, spec[2])
		frames.set_animation_loop(animation_name, spec[3])
		for index in int(spec[1]):
			var file := "%s_%d.png" % [spec[0], index]
			var path := LEVEL_ART_DIR + file
			if theme != &"" and ResourceLoader.exists(THEMES_DIR + String(theme) + "/" + file):
				path = THEMES_DIR + String(theme) + "/" + file
			if ResourceLoader.exists(path):
				frames.add_frame(animation_name, load(path))
	var sprite := AnimatedSprite2D.new()
	sprite.name = "Art"
	sprite.sprite_frames = frames
	sprite.centered = false
	sprite.offset = offset
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return sprite
