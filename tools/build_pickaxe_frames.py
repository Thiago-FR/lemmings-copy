"""Builds the horizontal digging animation ("pickaxe", the Picareta tool).

    python tools/build_pickaxe_frames.py

The sideways counterpart of tools/build_dig_frames.py: there the wizard
faces the player and drives a shovel down; here it faces the wall on its
right and swings a pickaxe into it. Same recipe otherwise: the body comes
from existing art (the side-on walk frame with its waist hand removed, see
wizard_art.py) and only the tool, the arm and the chips of rock are drawn,
on the same coarse art-pixel grid as the character.

Over four frames the pickaxe is raised behind the hood, brought overhead,
struck into the wall at chest height and pulled back. The body rocks with
the swing (leaning back on the wind-up, forward into the blow) about its
feet, so the feet stay planted on the floor line. Chips fly off the wall
on the strike and the recoil.

The art faces right like the walk frames; LemmingController mirrors the
sprite with flip_h when the lemming faces left. The pick's point lands just
past the right edge of the 26x30 collision box, which is where the wall
face is while tunnelling.
"""

import math

from PIL import Image

from wizard_art import (
    ART_PIXEL, DUST, METAL, METAL_LIGHT, WOOD, WOOD_LIGHT, ArtCanvas, occupied_box, rotate_point, save,
    side_body_without_hand,
)

OUTPUT_PREFIX = "pickaxe"

HANDLE_CELLS = 9
# The head is drawn across the end of the handle: a short blunt end behind
# and a longer point in front, on the side the swing moves towards, so the
# point leads into the wall.
HEAD_BACK_CELLS = 2
HEAD_POINT_CELLS = 3
# Where the shoulder of the drawn arm is, in source pixels of the walk frame.
SHOULDER = (150, 168)

# Chips of rock: squares this many art pixels across (one art pixel shrinks
# below a screen pixel and disappears).
CHIP_CELLS = 2
# The wall face, in source pixels: the right edge of the collision box.
WALL_X = 218

# Per frame:
#   lean: body rotation in degrees about the feet (positive leans back);
#   grip: where the lower hand holds the handle, source pixels, before lean;
#   angle: handle direction in degrees, 0 pointing right, 90 straight up;
#   chips: (cells out from the wall, cells above the strike) per chip.
FRAMES = [
    {"lean": 4, "grip": (126, 158), "angle": 135, "chips": []},
    {"lean": 1, "grip": (140, 146), "angle": 80, "chips": []},
    {"lean": -6, "grip": (160, 172), "angle": 20, "chips": [(0, 2)]},
    {"lean": -2, "grip": (152, 168), "angle": 45, "chips": [(2, 4), (1, -1)]},
]
STRIKE_HEIGHT = 166


def along(origin, angle_degrees, cells):
    """The point `cells` art pixels from origin in a screen direction given
    in degrees (0 right, 90 up)."""
    angle = math.radians(angle_degrees)
    return (origin[0] + math.cos(angle) * cells * ART_PIXEL, origin[1] - math.sin(angle) * cells * ART_PIXEL)


def draw_pickaxe(canvas, grip, angle):
    """Handle from the grip outwards, head across its end. The swing turns
    clockwise on screen, so the point is on the clockwise side of the end."""
    end = along(grip, angle, HANDLE_CELLS)
    # Light wood: the darker tone disappears against the shaded robe.
    canvas.line(grip, end, WOOD_LIGHT)
    canvas.fill_cell(*along(grip, angle, -1), WOOD)

    point = along(end, angle - 90, HEAD_POINT_CELLS)
    back = along(end, angle + 90, HEAD_BACK_CELLS)
    canvas.line(back, point, METAL)
    canvas.line(end, along(end, angle - 90, 1), METAL_LIGHT)
    canvas.fill_cell(*point, METAL_LIGHT)


def draw_tool_and_arm(size, grip, angle, shoulder):
    canvas = ArtCanvas(size)
    draw_pickaxe(canvas, grip, angle)
    # One hand only, at the grip: a second two-by-two hand further up the
    # handle merged with the first into a skin-coloured stick at game scale.
    canvas.arm(shoulder, (grip[0] - ART_PIXEL // 2, grip[1] - ART_PIXEL // 2))
    canvas.outline()
    return canvas.to_image()


def draw_chips(size, chips):
    canvas = ArtCanvas(size)
    for out_cells, up_cells in chips:
        x = WALL_X - (out_cells + CHIP_CELLS) * ART_PIXEL
        y = STRIKE_HEIGHT - up_cells * ART_PIXEL
        canvas.rect(x, y, CHIP_CELLS, CHIP_CELLS, DUST)
    return canvas.to_image()


def main():
    body = side_body_without_hand()
    left, _, right, bottom = occupied_box(body)
    # Rocking about the middle of the feet keeps them on the floor line.
    feet_pivot = ((left + right) // 2, bottom)

    for index, pose in enumerate(FRAMES):
        frame = Image.new("RGBA", body.size, (0, 0, 0, 0))
        frame.alpha_composite(body.rotate(pose["lean"], resample=Image.NEAREST, center=feet_pivot))
        grip = rotate_point(pose["grip"], pose["lean"], feet_pivot)
        shoulder = rotate_point(SHOULDER, pose["lean"], feet_pivot)
        frame.alpha_composite(draw_tool_and_arm(body.width, grip, pose["angle"], shoulder))
        frame.alpha_composite(draw_chips(body.width, pose["chips"]))
        save(frame, f"{OUTPUT_PREFIX}_{index}")

    print(f"wrote {len(FRAMES)} {OUTPUT_PREFIX} frames")


if __name__ == "__main__":
    main()
