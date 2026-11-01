"""Builds the floater ("parachute") animation out of the existing wizard art.

    python tools/build_float_frames.py

The body is the side-on walk frame with its waist hand removed and two arms
drawn raised, hands holding the cords at shoulder height. Above it a canopy
is drawn on the art-pixel grid (see wizard_art.py) with cords running down
to the hands. Over four frames:
  * the canopy swings a cell to each side and tilts with the swing;
  * the body swings with it like a pendulum, rotating a few degrees about
    the centre of the collision box, so it hangs under the canopy instead of
    staying rigid while the cloth moves;
  * the feet dangle and kick slowly, one dropping while the other lifts;
  * the bottom of the robe trails the swing by one cell.

Frame size: the canopy has to sit above the hood, but the 250x250 frames have
almost no room there. The AnimatedSprite2D draws every frame centred on the
node, so the frames are made taller by the same amount at the top and the
bottom: the body stays at exactly the same offset from the centre as in the
walk frames and keeps lining up with the 26x30 collision box, and the extra
rows at the top hold the canopy. The bottom padding is simply left empty.
"""

from PIL import Image

from wizard_art import (
    ART_PIXEL, HEM_Y, OUTLINE, ArtCanvas, occupied_box, rotate_point, save, shifted, side_body_without_hand,
    split_feet,
)

OUTPUT_PREFIX = "float"

# Rows added above and below the 250px frame. A multiple of the art pixel so
# the body keeps its position on the coarse grid.
VERTICAL_PADDING = 11 * ART_PIXEL

# Canopy size in art pixels. One art pixel is about one screen pixel in game,
# so this is roughly a 30x9 dome over a 26px-wide body: wider than the body,
# as a parachute has to be to read as one.
CANOPY_WIDTH_CELLS = 30
CANOPY_HEIGHT_CELLS = 9
# Gap between the canopy rim and the top of the hood, where the cords show.
CORD_GAP_CELLS = 5

# Alternating panels. Each is several art pixels wide, otherwise the stripes
# blur into one colour at the in-game scale. Light and red were picked to
# stand out from both the purple robe and the dark level backgrounds.
PANEL_WIDTH_CELLS = 6
CANOPY_LIGHT = (236, 226, 204, 255)
CANOPY_RED = (196, 58, 58, 255)
CORD = (214, 204, 184, 255)

# Raised arms, in source pixels of the 250px walk frame: (shoulder, hand) for
# the back arm (behind the backpack side) and the front arm (face side). The
# hands sit just outside the hood at shoulder height, where the cords end.
BACK_ARM = ((98, 168), (63, 126))
FRONT_ARM = ((182, 168), (203, 126))

# The body swings about the centre of the collision box (the sprite node's
# centre plus the box's (1, 2) offset, in source pixels), so it never drifts
# out of the box, only tilts inside it.
SWING_PIVOT = (132, 138)

# Rows of robe just above the hem that trail the swing.
HEM_FLUTTER_ROWS = 2 * ART_PIXEL

# Per frame:
#   canopy swing and tilt in cells (positive tilt lifts the right edge, so
#     the canopy leans into the direction it swings);
#   body angle in degrees (positive is counter-clockwise, as PIL rotates);
#     the body leans so its top follows the canopy;
#   back foot and front foot offsets in cells (dx, dy): a slow kick, one foot
#     dropping while the other lifts.
FRAMES = [
    {"swing": 0, "tilt": 0, "angle": 0, "back_foot": (0, 2), "front_foot": (1, -1)},
    {"swing": 1, "tilt": 1, "angle": -5, "back_foot": (-1, 1), "front_foot": (-1, 1)},
    {"swing": 0, "tilt": 0, "angle": 0, "back_foot": (-1, -1), "front_foot": (0, 2)},
    {"swing": -1, "tilt": -1, "angle": 5, "back_foot": (1, 1), "front_foot": (1, 1)},
]


def canopy_row_top(column, tilt):
    """Top edge of the dome above a given column (in cells from its left
    edge): a half-ellipse, so the dome is flat in the middle and steep at
    the sides, shifted up on one side by the tilt."""
    half = (CANOPY_WIDTH_CELLS - 1) / 2
    x = (column - half) / (half + 0.5)
    dome = CANOPY_HEIGHT_CELLS * (1 - x * x) ** 0.5
    lean = tilt * (column - half) / half
    return round(CANOPY_HEIGHT_CELLS - dome - lean)


def canopy_rim_bottom(column, tilt):
    """Bottom edge: scalloped between panels, so the gores read as cloth
    pulled taut between cords, and tilted like the top."""
    half = (CANOPY_WIDTH_CELLS - 1) / 2
    lean = tilt * (column - half) / half
    at_seam = column % PANEL_WIDTH_CELLS in (0, PANEL_WIDTH_CELLS - 1)
    return round(CANOPY_HEIGHT_CELLS - lean) - (1 if at_seam else 0)


def draw_parachute(canvas, centre_x, rim_y, swing, tilt, left_hand, right_hand):
    """Draws the canopy with its rim at rim_y and the cords down to the two
    hands, all in padded-frame source pixels."""
    left = centre_x - (CANOPY_WIDTH_CELLS * ART_PIXEL) // 2 + swing * ART_PIXEL
    top = rim_y - CANOPY_HEIGHT_CELLS * ART_PIXEL

    rim_bottoms = {}
    for column in range(CANOPY_WIDTH_CELLS):
        x = left + column * ART_PIXEL
        first = canopy_row_top(column, tilt)
        last = canopy_rim_bottom(column, tilt)
        colour = CANOPY_LIGHT if (column // PANEL_WIDTH_CELLS) % 2 == 0 else CANOPY_RED
        for row in range(first, last):
            canvas.fill_cell(x, top + row * ART_PIXEL, colour)
        rim_bottoms[column] = (x, top + last * ART_PIXEL)

    canvas.outline(OUTLINE)

    # Cords drawn after the outline so they stay one art pixel thin. Only
    # four: from each outer corner and from the seam either side of the
    # centre panel down to the nearer hand. More than that turns into a
    # grey smear at the in-game scale.
    last_column = CANOPY_WIDTH_CELLS - 1
    centre_panel_left = (CANOPY_WIDTH_CELLS - PANEL_WIDTH_CELLS) // 2
    cords = (
        (0, left_hand),
        (centre_panel_left, left_hand),
        (centre_panel_left + PANEL_WIDTH_CELLS - 1, right_hand),
        (last_column, right_hand),
    )
    for column, hand in cords:
        x, y = rim_bottoms[column]
        canvas.line((x, y + ART_PIXEL), hand, CORD)


def flutter_hem(upper, swing):
    """Moves the last rows of robe one cell against the swing, so the cloth
    trails the movement."""
    if swing == 0:
        return upper
    width = upper.width
    band = upper.crop((0, HEM_Y - HEM_FLUTTER_ROWS, width, HEM_Y))
    result = upper.copy()
    result.paste((0, 0, 0, 0), (0, HEM_Y - HEM_FLUTTER_ROWS, width, HEM_Y))
    result.alpha_composite(shifted(band, -swing * ART_PIXEL, 0), (0, HEM_Y - HEM_FLUTTER_ROWS))
    return result


def build_body(upper, back_foot, front_foot, pose):
    """The hanging body for one frame in the 250px frame, before the swing."""
    body = Image.new("RGBA", upper.size, (0, 0, 0, 0))
    # Feet behind the robe, so a lifted foot tucks under the hem instead of
    # drawing over it.
    # A dropped foot is stamped at every cell on the way down, which
    # stretches the leg rather than leaving a gap under the hem.
    for foot, (dx, dy) in ((back_foot, pose["back_foot"]), (front_foot, pose["front_foot"])):
        for step in range(min(dy, 0), max(dy, 0) + 1) if dy > 0 else (dy,):
            body.alpha_composite(shifted(foot, dx * ART_PIXEL, step * ART_PIXEL))
    body.alpha_composite(flutter_hem(upper, pose["swing"]))

    arms = ArtCanvas(upper.width)
    for shoulder, hand in (BACK_ARM, FRONT_ARM):
        arms.arm(shoulder, hand)
    arms.outline()
    body.alpha_composite(arms.to_image())
    return body


def main():
    upper, back_foot, front_foot = split_feet(side_body_without_hand())
    left, top, right, bottom = occupied_box(upper)
    centre_x = (left + right) // 2
    width, height = upper.width, upper.height + 2 * VERTICAL_PADDING
    rim_y = VERTICAL_PADDING + top - CORD_GAP_CELLS * ART_PIXEL

    for index, pose in enumerate(FRAMES):
        body = build_body(upper, back_foot, front_foot, pose)
        body = body.rotate(pose["angle"], resample=Image.NEAREST, center=SWING_PIVOT)
        # The cords end where the hands are after the swing; the hand cell's
        # centre, not its corner, so the cord meets the middle of the hand.
        hands = []
        for _, hand in (BACK_ARM, FRONT_ARM):
            x, y = rotate_point((hand[0] + ART_PIXEL // 2, hand[1] + ART_PIXEL // 2), pose["angle"], SWING_PIVOT)
            hands.append((x, y + VERTICAL_PADDING))

        canvas = ArtCanvas(height)
        draw_parachute(canvas, centre_x, rim_y, pose["swing"], pose["tilt"], *hands)
        frame = Image.new("RGBA", (width, height), (0, 0, 0, 0))
        frame.alpha_composite(canvas.to_image().crop((0, 0, width, height)))
        # Body on top, so the cords disappear behind the hands rather than
        # crossing over them.
        frame.alpha_composite(body, (0, VERTICAL_PADDING))
        save(frame, f"{OUTPUT_PREFIX}_{index}")

    print(f"wrote {len(FRAMES)} {OUTPUT_PREFIX} frames ({width}x{height})")


if __name__ == "__main__":
    main()
