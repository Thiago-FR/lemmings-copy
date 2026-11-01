extends SceneTree
## Generates the placeholder lemming frames at exactly the collision box
## size, so what is drawn on screen IS the body that collides. Run via:
##   godot --headless --script res://tools/build_lemming_placeholder.gd
##
## Deliberately not hand-drawn art: every frame is built from rectangles
## here, so a colour or proportion can be changed in one place and the whole
## set regenerated. Real art replaces the PNGs later without touching code —
## lemming.tscn references them through a SpriteFrames resource.
##
## The magenta corner ticks mark the exact collision bounds. They exist to
## make misalignment between body and terrain grid visible at a glance (the
## bug that stalled this project) and should be dropped once real art lands.
##
## Size is driven by Constants.MAX_BODY_WIDTH/MAX_BODY_HEIGHT so the art and
## the collision shape can never drift apart.

const BODY_WIDTH := 12
const BODY_HEIGHT := 28
const OUTPUT_DIRECTORY := "res://assets/sprites/characters/lemming"

const TRANSPARENT := Color(0, 0, 0, 0)
const HAIR := Color("2ECC40")
const SKIN := Color("FFD1A4")
const EYE := Color("1A1A1A")
const TUNIC := Color("2B5FD9")
const TUNIC_SHADE := Color("1E44A0")
const CORNER_TICK := Color("FF00FF")

## Horizontal leg offsets per walk frame: contact, passing, contact, passing.
## Mirrored between the two legs to read as a stride rather than a shuffle.
const WALK_LEG_OFFSETS := [1, 0, -1, 0]


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIRECTORY))

	for frame_index in WALK_LEG_OFFSETS.size():
		_save(_build_walk_frame(frame_index), "walk_%d.png" % frame_index)

	for frame_index in 4:
		_save(_build_climb_frame(frame_index), "climb_%d.png" % frame_index)

	print("Lemming placeholder frames written to %s (%dx%d each)" % [OUTPUT_DIRECTORY, BODY_WIDTH, BODY_HEIGHT])
	quit()


func _new_canvas() -> Image:
	var image := Image.create(BODY_WIDTH, BODY_HEIGHT, false, Image.FORMAT_RGBA8)
	image.fill(TRANSPARENT)
	return image


func _fill_rect(image: Image, from_x: int, from_y: int, to_x: int, to_y: int, colour: Color) -> void:
	for y in range(from_y, to_y + 1):
		for x in range(from_x, to_x + 1):
			if x >= 0 and x < BODY_WIDTH and y >= 0 and y < BODY_HEIGHT:
				image.set_pixel(x, y, colour)


## Two-pixel L marks at each corner of the sprite, which is also each corner
## of the collision box. If the lemming ever looks like it is sunk into the
## floor or clipping a wall, these show it immediately.
func _draw_corner_ticks(image: Image) -> void:
	var right := BODY_WIDTH - 1
	var bottom := BODY_HEIGHT - 1
	for offset in 2:
		image.set_pixel(offset, 0, CORNER_TICK)
		image.set_pixel(0, offset, CORNER_TICK)
		image.set_pixel(right - offset, 0, CORNER_TICK)
		image.set_pixel(right, offset, CORNER_TICK)
		image.set_pixel(offset, bottom, CORNER_TICK)
		image.set_pixel(0, bottom - offset, CORNER_TICK)
		image.set_pixel(right - offset, bottom, CORNER_TICK)
		image.set_pixel(right, bottom - offset, CORNER_TICK)


## Head and tunic are identical across the walk cycle; only the limbs move,
## which is what makes the stride readable at this size.
func _draw_torso_and_head(image: Image) -> void:
	_fill_rect(image, 2, 1, 9, 4, HAIR)
	_fill_rect(image, 2, 5, 9, 10, SKIN)
	# Facing right by default; LemmingController flips the sprite when the
	# direction reverses, so only one eye position is needed here.
	_fill_rect(image, 7, 7, 8, 8, EYE)
	_fill_rect(image, 1, 11, 10, 21, TUNIC)
	_fill_rect(image, 1, 20, 10, 21, TUNIC_SHADE)


func _build_walk_frame(frame_index: int) -> Image:
	var image := _new_canvas()
	_draw_torso_and_head(image)

	var leg_offset: int = WALK_LEG_OFFSETS[frame_index]
	# Front leg swings with the stride, back leg opposes it.
	_fill_rect(image, 2 + leg_offset, 22, 4 + leg_offset, 27, TUNIC_SHADE)
	_fill_rect(image, 7 - leg_offset, 22, 9 - leg_offset, 27, TUNIC_SHADE)

	# Arms swing opposite to the legs, same as a real stride.
	_fill_rect(image, 0, 12 + leg_offset, 0, 17 + leg_offset, TUNIC)
	_fill_rect(image, 11, 12 - leg_offset, 11, 17 - leg_offset, TUNIC)

	_draw_corner_ticks(image)
	return image


## Climbing: body hugs the wall on the facing side, both arms reach up, legs
## stay tucked. The alternation reads as hand-over-hand.
func _build_climb_frame(frame_index: int) -> Image:
	var image := _new_canvas()
	var reach: int = 0 if frame_index % 2 == 0 else 2

	_fill_rect(image, 2, 3, 9, 6, HAIR)
	_fill_rect(image, 2, 7, 9, 12, SKIN)
	_fill_rect(image, 7, 9, 8, 10, EYE)
	_fill_rect(image, 1, 13, 9, 21, TUNIC)
	_fill_rect(image, 1, 20, 9, 21, TUNIC_SHADE)

	# Arms up against the wall, alternating which one is higher.
	_fill_rect(image, 10, 1 + reach, 11, 8 + reach, TUNIC)
	_fill_rect(image, 10, 5 - reach, 11, 12 - reach, TUNIC)

	# Tucked legs, slight alternation so the cycle is not static.
	_fill_rect(image, 2, 22, 4, 27, TUNIC_SHADE)
	_fill_rect(image, 6, 22 + reach, 8, 27, TUNIC_SHADE)

	_draw_corner_ticks(image)
	return image


func _save(image: Image, file_name: String) -> void:
	var path := "%s/%s" % [OUTPUT_DIRECTORY, file_name]
	var err := image.save_png(path)
	if err != OK:
		push_error("Failed to write %s: %d" % [path, err])
