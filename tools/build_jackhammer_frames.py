"""Builds the horizontal drilling animation ("jackhammer", the Britadeira tool).

    python tools/build_jackhammer_frames.py

Same recipe as tools/build_pickaxe_frames.py: the body is the side-on walk
frame with its waist hand removed (see wizard_art.py), and only the tool,
the arm and the dust are drawn, on the same coarse art-pixel grid as the
character.

The wizard holds a pneumatic drill level at waist height, pointing at the
wall on its right: a grey housing with a handle bar across its back end
(where the one hand grips), a nose and a bright bit whose tip reaches just
past the right edge of the 26x30 collision box, which is where the wall
face is while tunnelling. There is no swing: the body and the drill shake
by one art pixel between frames, the bit hammers in and out by one cell and
dust puffs off the wall.

The body steps back two cells so the drill fits between it and the wall;
the upper body bobs down (never up) so the robe never lifts off the feet,
which stay on the floor line.

The art faces right like the walk frames; LemmingController mirrors the
sprite with flip_h when the lemming faces left.
"""

from PIL import Image

from wizard_art import (
    ART_PIXEL, DUST, METAL, METAL_LIGHT, ArtCanvas, save, shifted, side_body_without_hand, split_feet,
)

OUTPUT_PREFIX = "jackhammer"

# Darker steel for the fins, nose and handle posts, and a safety-yellow grip:
# a black grip vanished against the dark face of the hood behind it.
METAL_DARK = (96, 98, 116, 255)
GRIP = (226, 170, 52, 255)

# How far the whole body steps back from the walk pose, so the drill fits in
# front of it without its tip going further than just past the wall.
BODY_BACK_CELLS = 2
# Where the shoulder of the drawn arm is, in source pixels of the walk frame.
SHOULDER = (150, 168)

# Drill layout in source pixels, before the per-frame shake. The housing's
# top-left corner, its size in cells, and the bit's resting length.
HOUSING_TOP_LEFT = (140, 161)
HOUSING_CELLS = (6, 4)
NOSE_CELLS = 1
BIT_CELLS = 3
HANDLE_RISE_CELLS = 2
HANDLE_WIDTH_CELLS = 4

# The wall face, in source pixels: the right edge of the collision box.
WALL_X = 218
DUST_CELLS = 2

# Per frame:
#   shake: (cells right, cells down) for body and drill together;
#   bit: extra cells the bit is pushed out (the hammer stroke);
#   dust: (cells out from the wall, cells from the bit line, up positive).
# The bit's tip ends up 0, 1, -1 and 0 cells from the wall face: shake and
# stroke add up so it visibly hammers in and out.
FRAMES = [
    {"shake": (0, 0), "bit": 1, "dust": [(0, 2)]},
    {"shake": (1, 1), "bit": 1, "dust": [(1, -2), (3, 3)]},
    {"shake": (0, 1), "bit": 0, "dust": [(2, 3)]},
    {"shake": (1, 0), "bit": 0, "dust": [(0, -2)]},
]


def cells(count):
    return count * ART_PIXEL


def draw_drill(canvas, offset):
    """Housing, handle on top of its back end, nose and bit, shifted by
    offset (source pixels). Returns (hand position, bit start x, bit y)."""
    left = HOUSING_TOP_LEFT[0] + offset[0]
    top = HOUSING_TOP_LEFT[1] + offset[1]
    width, height = HOUSING_CELLS
    canvas.rect(left, top, width, height, METAL)
    canvas.rect(left, top, width, 1, METAL_LIGHT)
    # Dark ribs across the housing: the cooling fins are what tell a
    # jackhammer apart from a gun or a torch at this size.
    for column in range(1, width - 1, 2):
        canvas.rect(left + cells(column), top + cells(1), 1, height - 1, METAL_DARK)

    # A D-shaped handle rising from the back end, the grip on top of it.
    handle_top = top - cells(HANDLE_RISE_CELLS)
    canvas.rect(left, handle_top, 1, HANDLE_RISE_CELLS, METAL_DARK)
    canvas.rect(left + cells(HANDLE_WIDTH_CELLS - 1), handle_top, 1, HANDLE_RISE_CELLS, METAL_DARK)
    canvas.rect(left, handle_top, HANDLE_WIDTH_CELLS, 1, GRIP)

    nose_x = left + cells(width)
    middle_y = top + cells(height // 2 - 1)
    canvas.rect(nose_x, middle_y, NOSE_CELLS, 2, METAL_DARK)
    bit_y = middle_y + cells(1) if height % 2 == 0 else middle_y
    # Over the back of the grip, leaving its front half in sight.
    hand = (left, handle_top - cells(1))
    return hand, nose_x + cells(NOSE_CELLS), bit_y


def draw_bit(canvas, start_x, y, extra_cells):
    length = BIT_CELLS + extra_cells
    canvas.rect(start_x, y, length, 1, METAL_LIGHT)


def draw_tool_and_arm(size, offset, bit_extra, shoulder):
    canvas = ArtCanvas(size)
    hand, bit_x, bit_y = draw_drill(canvas, offset)
    draw_bit(canvas, bit_x, bit_y, bit_extra)
    # The hand closes over the grip: a short arm straight from the shoulder,
    # never stretched out towards the wall.
    canvas.arm(shoulder, hand)
    canvas.outline()
    return canvas.to_image(), bit_y


def draw_dust(size, dust, bit_y):
    canvas = ArtCanvas(size)
    for out_cells, up_cells in dust:
        x = WALL_X - cells(out_cells + DUST_CELLS - 1)
        y = bit_y - cells(up_cells)
        canvas.rect(x, y, DUST_CELLS, DUST_CELLS, DUST)
    return canvas.to_image()


def main():
    upper, back_foot, front_foot = split_feet(side_body_without_hand())
    back = -cells(BODY_BACK_CELLS)

    for index, pose in enumerate(FRAMES):
        dx, dy = cells(pose["shake"][0]), cells(pose["shake"][1])
        frame = Image.new("RGBA", upper.size, (0, 0, 0, 0))
        # Feet shake sideways only, so they stay on the floor line.
        frame.alpha_composite(shifted(back_foot, back + dx, 0))
        frame.alpha_composite(shifted(front_foot, back + dx, 0))
        frame.alpha_composite(shifted(upper, back + dx, dy))

        shoulder = (SHOULDER[0] + back + dx, SHOULDER[1] + dy)
        tool, bit_y = draw_tool_and_arm(upper.width, (dx, dy), pose["bit"], shoulder)
        frame.alpha_composite(tool)
        frame.alpha_composite(draw_dust(upper.width, pose["dust"], bit_y))
        save(frame, f"{OUTPUT_PREFIX}_{index}")

    print(f"wrote {len(FRAMES)} {OUTPUT_PREFIX} frames")


if __name__ == "__main__":
    main()
