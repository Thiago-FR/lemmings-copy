extends SceneTree
## Bakes 4 vertically-aligned frames per spritesheet (walk/climb) so the
## character's silhouette sits at a consistent baseline across frames
## instead of bobbing up and down when the animation cycles. The source
## art has real leg/arm movement between frames (worth keeping animated)
## but was cropped/drawn with an inconsistent vertical anchor per frame.

const FRAME_SIZE := 250
const OUT_DIR := "res://assets/sprites/characters/wizard/"


func _initialize() -> void:
	_process_sheet("sprite_wizard_1.png", "walk")
	_process_sheet("sprite_wizard_0.png", "climb")
	quit()


func _process_sheet(filename: String, label: String) -> void:
	var img: Image = Image.load_from_file(OUT_DIR + filename)
	var coords = [Vector2i(0, 0), Vector2i(250, 0), Vector2i(0, 250), Vector2i(250, 250)]

	var bottoms := []
	var crops := []
	for origin in coords:
		var crop := Image.create(FRAME_SIZE, FRAME_SIZE, false, Image.FORMAT_RGBA8)
		crop.blit_rect(img, Rect2i(origin, Vector2i(FRAME_SIZE, FRAME_SIZE)), Vector2i.ZERO)
		crops.append(crop)
		bottoms.append(_find_bottom(crop))

	var baseline: int = bottoms.max()
	for i in range(crops.size()):
		var shift: int = baseline - bottoms[i]
		var aligned := Image.create(FRAME_SIZE, FRAME_SIZE, false, Image.FORMAT_RGBA8)
		if shift > 0:
			aligned.blit_rect(crops[i], Rect2i(0, 0, FRAME_SIZE, FRAME_SIZE - shift), Vector2i(0, shift))
		else:
			aligned.blit_rect(crops[i], Rect2i(0, 0, FRAME_SIZE, FRAME_SIZE), Vector2i.ZERO)
		var out_path := "%s%s_aligned_%d.png" % [OUT_DIR, label, i]
		aligned.save_png(out_path)
		print("%s frame %d: bottom=%d shift=%d -> %s" % [label, i, bottoms[i], shift, out_path])


func _find_bottom(img: Image) -> int:
	for y in range(FRAME_SIZE - 1, -1, -1):
		for x in range(FRAME_SIZE):
			if img.get_pixel(x, y).a > 0.05:
				return y
	return 0
