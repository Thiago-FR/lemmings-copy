"""Builds the fall-death ("splat") animation out of the existing wizard art.

    python tools/build_death_frames.py

Same approach as tools/build_dig_frames.py: nothing drawn from scratch
except a few dust puffs on the art-pixel grid. The side-on walk frame is
flattened against the floor over four frames, widening as it squashes, so
the lemming visibly hits the ground and stays there for a moment before
LemmingController fades the body out.

The feet line is kept where the walk frame's feet are, so the squashed body
sits on the same floor the lemming actually landed on.
"""

from PIL import Image

from wizard_art import ART_PIXEL, DUST, ArtCanvas, load, occupied_box, save

SOURCE = "walk_aligned_0"
OUTPUT_PREFIX = "death_fall"

# (height kept, width gained) per frame. The first frame is the impact, the
# last one is what lingers on screen while the fade plays.
SQUASH_PER_FRAME = [(0.62, 1.06), (0.44, 1.14), (0.32, 1.20), (0.30, 1.20)]

# Each puff is a square this many art pixels across: a single art pixel
# shrinks to under one screen pixel at the in-game scale and disappears.
DUST_PUFF_CELLS = 2

# Dust thrown out sideways from the point of impact: for each frame, how far
# from the body's edge each puff sits (in art pixels) and how high above the
# floor. Empty for the impact frame, so the dust follows the hit. Kept close
# to the body because the frame is only 250px wide and the flattened body
# already fills most of it.
DUST_PER_FRAME = [
    [],
    [(0, 0)],
    [(0, 1)],
    [(1, 2)],
]


def squash(body, height_fraction, width_fraction, canvas_size, centre_x, feet_y):
    width = min(canvas_size, round(body.width * width_fraction))
    height = max(1, round(body.height * height_fraction))
    flattened = body.resize((width, height), Image.NEAREST)
    frame = Image.new("RGBA", (canvas_size, canvas_size), (0, 0, 0, 0))
    left = max(0, min(canvas_size - width, centre_x - width // 2))
    frame.alpha_composite(flattened, (left, feet_y - height))
    return frame, left, left + width


def dust(canvas_size, body_left, body_right, feet_y, puffs):
    canvas = ArtCanvas(canvas_size)
    for offset_cells, rise_cells in puffs:
        y = feet_y - (rise_cells + DUST_PUFF_CELLS) * ART_PIXEL
        reach = (offset_cells + DUST_PUFF_CELLS) * ART_PIXEL
        canvas.rect(body_left - reach, y, DUST_PUFF_CELLS, DUST_PUFF_CELLS, DUST)
        canvas.rect(body_right + offset_cells * ART_PIXEL, y, DUST_PUFF_CELLS, DUST_PUFF_CELLS, DUST)
    return canvas.to_image()


def main():
    source = load(SOURCE)
    left, top, right, bottom = occupied_box(source)
    body = source.crop((left, top, right, bottom))
    centre_x = (left + right) // 2

    for index, (height_fraction, width_fraction) in enumerate(SQUASH_PER_FRAME):
        frame, body_left, body_right = squash(body, height_fraction, width_fraction, source.width, centre_x, bottom)
        frame.alpha_composite(dust(source.width, body_left, body_right, bottom, DUST_PER_FRAME[index]))
        save(frame, f"{OUTPUT_PREFIX}_{index}")

    print(f"wrote {len(SQUASH_PER_FRAME)} {OUTPUT_PREFIX} frames")


if __name__ == "__main__":
    main()
