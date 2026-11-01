"""Builds the front-facing digging animation out of the existing wizard art.

    python tools/build_dig_frames.py

Nothing here is drawn from scratch. The frames are composited from pixels
that are already in the project, which is the only way to stay exactly on
style at this size: the sprite is ~30x34 on screen, so anything hand-authored
next to it reads as a different character immediately.

Recipe:
  * start from the back-facing climb frame, which already has the symmetric
    front/back silhouette, the arms at the sides and two legs;
  * erase the backpack and the blur halo around it, refilling with the robe
    colour sampled from the same row so the vertical shading survives;
  * paste the hood opening and glowing eyes from a walk frame, centred;
  * squash the body vertically over four frames with the feet pinned;
  * draw a shovel on the coarse art-pixel grid (see wizard_art.py) that is
    raised, driven into the ground and levered back over the same four
    frames, held by two hands in the character's skin tone.

The shovel is the one thing that is drawn rather than composited, because
nothing in the existing art has a tool to borrow. It is drawn on the same
~7px grid as the character so its edges match.

Python rather than GDScript (unlike tools/build_terrain_tileset.gd) because
this is per-pixel mask work, which numpy does in a few lines and the Godot
Image API does not.
"""

import numpy as np
from PIL import Image, ImageFilter

from wizard_art import (
    ART_PIXEL, METAL, METAL_LIGHT, SKIN, SPRITE_DIR, WOOD, WOOD_LIGHT, ArtCanvas,
)
SOURCE_BACK = "climb_aligned_0"
SOURCE_FACE = "walk_aligned_0"
OUTPUT_PREFIX = "dig_aligned"

# How much of the body's height each frame keeps. Feet stay planted, so the
# shrink reads as the lemming bearing down on the floor.
SQUASH_PER_FRAME = [1.00, 0.96, 0.87, 0.93]

# Shovel pose per frame as (grip, blade_join) in source pixels: where the top
# of the handle is and where the handle meets the blade. The cycle is lift,
# swing down, bite into the floor (blade below the feet line), lever back.
SHOVEL_POSES = [
    ((175, 63), (175, 154)),
    ((175, 91), (175, 182)),
    ((175, 126), (175, 210)),
    ((196, 98), (168, 196)),
]
# Fractions along the handle where the two hands hold it.
HAND_POSITIONS = (0.42, 0.72)
BLADE_WIDTH_CELLS = 3
BLADE_HEIGHT_CELLS = 3

# A pixel counts as "warm" — backpack, straps, or the blurred halo between
# them and the robe — when it is not clearly more blue than red. The robe
# sits around +25 on this measure and the backpack around -96, so the
# threshold has plenty of room on both sides.
WARM_THRESHOLD = 12
ROBE_THRESHOLD = 18
DARK_SUM_THRESHOLD = 90

# Width of the outer rim left untouched, so the silhouette keeps its outline.
OUTLINE_RIM = 5


def load(name):
    return np.array(Image.open(SPRITE_DIR / f"{name}.png").convert("RGBA")).astype(int)


def channels(image):
    rgb = image[:, :, :3]
    solid = image[:, :, 3] > 128
    return rgb, solid, rgb[:, :, 0], rgb[:, :, 1], rgb[:, :, 2]


def outer_rim(solid):
    eroded = Image.fromarray((solid * 255).astype(np.uint8)).filter(ImageFilter.MinFilter(OUTLINE_RIM))
    return (np.array(eroded) <= 128) & solid


def robe_colour_per_row(rgb, robe, rim):
    """Average robe colour for each row, with rows that have no robe left
    (the ones the backpack covers edge to edge) filled from the nearest row
    that does. Sampling per row is what preserves the original top-to-bottom
    shading instead of flattening the body into one tone."""
    height = rgb.shape[0]
    colours = np.full((height, 3), np.nan)
    for y in range(height):
        sample = robe[y] & ~rim[y]
        if sample.sum() < 4:
            continue
        # The brightest quarter of the row, not its average: a row's robe
        # pixels are mostly the shaded sides of the body, so averaging them
        # filled the chest with a tone darker than the lit area around it
        # and left a visible dark band where the backpack used to be.
        row = rgb[y][sample]
        lit = row[np.argsort(row.sum(axis=1))[-max(2, len(row) // 4):]]
        colours[y] = lit.mean(axis=0)

    known = np.where(~np.isnan(colours[:, 0]))[0]
    for y in range(height):
        if np.isnan(colours[y, 0]):
            colours[y] = colours[known[np.argmin(np.abs(known - y))]]
    return colours


def build_front_facing_body():
    back = load(SOURCE_BACK)
    rgb, solid, red, _, blue = channels(back)

    dark = solid & (rgb.sum(axis=2) < DARK_SUM_THRESHOLD)
    robe = solid & ((blue - red) >= ROBE_THRESHOLD) & ~dark
    rim = outer_rim(solid)

    # Dark pixels are left alone: they are the outline, the arm seams and the
    # gap between the legs. Removing them flattened the body into a blob.
    backpack = ~rim & solid & ((blue - red) < WARM_THRESHOLD) & ~dark

    colours = robe_colour_per_row(rgb, robe, rim)
    front = back.copy()
    for y in range(back.shape[0]):
        columns = np.where(backpack[y])[0]
        if len(columns):
            front[y, columns, :3] = colours[y]

    _paste_face(front, solid)
    return front


def _paste_face(front, back_solid):
    """Moves the hood opening and eyes from the side-on walk frame to the
    centre of the hood, which is what turns the back view into a front view."""
    walk = load(SOURCE_FACE)
    rgb, solid, red, green, blue = channels(walk)

    yellow = solid & (red > 180) & (green > 150) & (blue < 120)
    dark = solid & (rgb.sum(axis=2) < DARK_SUM_THRESHOLD)

    rows, columns = np.where(yellow)
    eye_centre_x = (columns.min() + columns.max()) // 2
    eye_centre_y = (rows.min() + rows.max()) // 2

    occupied = np.where(back_solid.any(axis=0))[0]
    shift = (occupied.min() + occupied.max()) // 2 - eye_centre_x

    face_region = np.zeros_like(solid)
    face_region[eye_centre_y - 34:eye_centre_y + 26, eye_centre_x - 32:eye_centre_x + 32] = True

    for y, x in zip(*np.where(face_region & (yellow | dark))):
        target_x = x + shift
        if 0 <= target_x < front.shape[1]:
            front[y, target_x] = walk[y, x]


def draw_shovel(size, grip, blade_join):
    canvas = ArtCanvas(size)
    canvas.line(grip, blade_join, WOOD)
    # Short crossbar at the top so it reads as a spade grip, not a stick.
    canvas.fill_cell(grip[0] - ART_PIXEL, grip[1], WOOD_LIGHT)
    canvas.fill_cell(grip[0] + ART_PIXEL, grip[1], WOOD_LIGHT)

    # Square blade with a one-cell point below it, lit down its left edge.
    blade_left = blade_join[0] - (BLADE_WIDTH_CELLS // 2) * ART_PIXEL
    blade_top = blade_join[1] + ART_PIXEL
    canvas.rect(blade_left, blade_top, BLADE_WIDTH_CELLS, BLADE_HEIGHT_CELLS, METAL)
    canvas.rect(blade_left, blade_top, 1, BLADE_HEIGHT_CELLS, METAL_LIGHT)
    canvas.fill_cell(blade_join[0], blade_top + BLADE_HEIGHT_CELLS * ART_PIXEL, METAL)

    # Each hand is two cells, reaching from the handle back towards the
    # body, so the shovel reads as held rather than floating beside it.
    for fraction in HAND_POSITIONS:
        x = grip[0] + (blade_join[0] - grip[0]) * fraction
        y = grip[1] + (blade_join[1] - grip[1]) * fraction
        canvas.fill_cell(x, y, SKIN)
        canvas.fill_cell(x - ART_PIXEL, y, SKIN)

    canvas.outline()
    return canvas.to_image()


def main():
    front = build_front_facing_body()
    image = Image.fromarray(front.astype(np.uint8))

    occupied = np.array(image)[:, :, 3] > 128
    rows, columns = np.where(occupied)
    left, right = columns.min(), columns.max() + 1
    top, bottom = rows.min(), rows.max() + 1
    body = image.crop((left, top, right, bottom))

    for index, squash in enumerate(SQUASH_PER_FRAME):
        height = max(1, round(body.height * squash))
        frame = Image.new("RGBA", image.size, (0, 0, 0, 0))
        # Pasted against the original bottom edge so the feet stay on the
        # floor and only the head dips.
        frame.alpha_composite(body.resize((body.width, height), Image.NEAREST), (left, bottom - height))
        grip, blade_join = SHOVEL_POSES[index]
        frame.alpha_composite(draw_shovel(image.width, grip, blade_join))
        frame.save(SPRITE_DIR / f"{OUTPUT_PREFIX}_{index}.png")

    print(f"wrote {len(SQUASH_PER_FRAME)} {OUTPUT_PREFIX} frames to {SPRITE_DIR}")


if __name__ == "__main__":
    main()
