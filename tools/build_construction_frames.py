"""Builds the wizard's construction animations: fitting a vertical ladder
segment ("ladder_fit"), laying a diagonal ladder step ("stair_lay") and
laying a bridge plank ("bridge_lay").

    python tools/build_construction_frames.py

Same recipe as the other wizard builders (see wizard_art.py): the body comes
from existing art and only the arms, the hammer and the dust are drawn, on
the same coarse art-pixel grid as the character. The ladder segment and the
plank are the terrain's own art (assets/sprites/terrain/ladder.png and
brick.png) scaled up to source resolution and drawn exactly where the real
one appears when the tool places it, so the drawn piece turns into the real
one without a jump.

Vertical ladder (back view, the same as the "ladder" frames): over four
frames the wizard pulls the segment up out of its backpack, lifts it
overhead, pushes it up into place on the cell above and knocks it in, with
dust puffing off the joint. The skill shows these four frames while it waits
to place a segment and the back-view climbing frames while it climbs onto
it (see SkillAnimation).

Diagonal ladder and bridge (side view, facing right like the walk frames):
the wizard bends over the spot in front of it, sets the plank down, raises a
small hammer, strikes the plank's near nail (dust) and lifts the hammer
again. The diagonal step lies in front of the feet, its bottom on the line
the wizard stands on; the bridge plank hangs below that line, its top flush
with it, so for the bridge the wizard kneels deeper. The skills show these
four frames while waiting to lay a piece and the walk frames while walking
onto it.

The pieces reach well outside the 250x250 frame (a ladder segment is a whole
32px cell above the head, a plank 32px in front), so these frames are padded
on both sides of the axis they need: AnimatedSprite2D centres every frame,
and padding both sides equally keeps the body exactly where the other
frames have it.

tools/build_character_variants.py imports the poses from here, so the other
characters hold the same pieces in the same places at the same times.
"""

import math
from pathlib import Path

import numpy as np
from PIL import Image

from wizard_art import (
    ART_PIXEL, DUST, HEM_Y, LEG_SPLIT_X, METAL, METAL_LIGHT, ROBE_SHADE, WOOD, WOOD_LIGHT, ArtCanvas, load,
    rotate_point, save, shifted, side_body_without_hand, split_feet,
)

TERRAIN_DIR = Path(__file__).resolve().parent.parent / "assets/sprites/terrain"

FRAME_SIZE = 250
# The AnimatedSprite2D in lemming.tscn: 0.15 scale, centred on the node.
GAME_SCALE = 0.15
# Terrain cell and the pieces the tools place, in screen pixels.
CELL_SCREEN = 32
PLANK_SCREEN = (32, 8)
# Collision box (lemming.tscn): 26x30 at (1, 2) from the node, so the feet
# are 17 screen pixels below it and the front edge 14 to its right.
FEET_SCREEN = 17
FRONT_EDGE_SCREEN = 14
# The drawn plank starts 1px inside the front edge rather than 0.5px past
# it: the sprite is mirrored about the node, the box sits 1px right of it,
# and this splits the difference between facing right and left.
PLANK_START_SCREEN = FRONT_EDGE_SCREEN - 0.5


def to_source(screen):
    """A screen offset from the node to a source pixel of the 250 frame."""
    return FRAME_SIZE / 2 + screen / GAME_SCALE


def cells(count):
    return count * ART_PIXEL


# --- Vertical ladder ---------------------------------------------------------

LADDER_PREFIX = "ladder_fit"
# Room above the body for a whole segment, added at the top and the bottom.
LADDER_PAD_Y = cells(28)
LADDER_FRAME = (FRAME_SIZE, FRAME_SIZE + 2 * LADDER_PAD_Y)
# The segment goes in the cell above the one the lemming stands in, centred
# on its column (the node, give or take the box's 1px).
LADDER_LEFT = round(to_source(-CELL_SCREEN / 2))
LADDER_SIZE = round(CELL_SCREEN / GAME_SCALE)
LADDER_FINAL_BOTTOM = round(to_source(FEET_SCREEN - CELL_SCREEN))
# Top-left of each hand (source pixels): on the two rails of ladder.png
# (columns 6-9 and 22-25 of 32).
LADDER_HAND_X = (cells(9), cells(24))
# Hands grip the rails this far above the segment's bottom end.
LADDER_GRIP_ABOVE_BOTTOM = cells(3)
# Per frame: the segment's bottom (source pixels, unpadded) and dust puffs
# off the joint with the segment below. Pulled up out of the backpack (its
# bottom hidden behind the body), lifted overhead, pushed into place, and
# knocked in.
LADDER_FRAMES = [
    {"bottom": 137, "dust": False},
    {"bottom": 81, "dust": False},
    {"bottom": LADDER_FINAL_BOTTOM + cells(2), "dust": False},
    {"bottom": LADDER_FINAL_BOTTOM, "dust": True},
]
DUST_CELLS = 2

# Wizard back view (climb_aligned_0): shoulders, at the sides of the hood
# above the backpack, and the box with the hands hanging at its sides.
WIZARD_BACK_SOURCE = "climb_aligned_0"
WIZARD_BACK_SHOULDERS = ((91, 112), (182, 112))
WIZARD_BACK_HANDS_TOP = 170


def ladder_segment(bottom, size=LADDER_FRAME):
    """The terrain's ladder tile at source scale, its bottom at `bottom`
    (unpadded source pixels), on a padded frame."""
    tile = Image.open(TERRAIN_DIR / "ladder.png").convert("RGBA")
    big = tile.resize((LADDER_SIZE, LADDER_SIZE), Image.NEAREST)
    layer = Image.new("RGBA", size, (0, 0, 0, 0))
    layer.paste(big, (LADDER_LEFT, LADDER_PAD_Y + bottom - LADDER_SIZE), big)
    return layer


def ladder_hands(bottom):
    """Top-left of each hand on the rails (unpadded source pixels)."""
    y = bottom - LADDER_GRIP_ABOVE_BOTTOM
    return [(x, y) for x in LADDER_HAND_X]


def ladder_dust(canvas, pad_y):
    """Puffs off the outside of both rails at the joint."""
    y = LADDER_FINAL_BOTTOM - cells(1) + pad_y
    canvas.rect(LADDER_HAND_X[0] - cells(3), y, DUST_CELLS, DUST_CELLS, DUST)
    canvas.rect(LADDER_HAND_X[1] + cells(3), y, DUST_CELLS, DUST_CELLS, DUST)


def wizard_back_body():
    """The back view with the hands at its sides painted over, since the
    arms are drawn raised."""
    pixels = np.array(load(WIZARD_BACK_SOURCE)).astype(int)
    region = pixels[WIZARD_BACK_HANDS_TOP:]
    red, green, blue = region[:, :, 0], region[:, :, 1], region[:, :, 2]
    skin = (region[:, :, 3] > 128) & (red > 120) & (red - blue > 40) & (green > 50)
    region[skin, :3] = ROBE_SHADE[:3]
    return Image.fromarray(pixels.astype(np.uint8))


def build_ladder_frames():
    body = wizard_back_body()
    for index, pose in enumerate(LADDER_FRAMES):
        frame = ladder_segment(pose["bottom"])
        frame.alpha_composite(body, (0, LADDER_PAD_Y))
        canvas = PaddedCanvas(LADDER_FRAME)
        for shoulder, hand in zip(WIZARD_BACK_SHOULDERS, ladder_hands(pose["bottom"])):
            canvas.arm((shoulder[0], shoulder[1] + LADDER_PAD_Y), (hand[0], hand[1] + LADDER_PAD_Y))
        canvas.outline()
        if pose["dust"]:
            ladder_dust(canvas, LADDER_PAD_Y)
        frame.alpha_composite(canvas.to_image())
        save(frame, f"{LADDER_PREFIX}_{index}")


# --- Diagonal ladder and bridge ---------------------------------------------------

STAIR_PREFIX = "stair_lay"
BRIDGE_PREFIX = "bridge_lay"
# Room for a plank in front (and, for the bridge, below the feet).
PLANK_PAD_X = cells(28)
PLANK_PAD_Y = cells(7)
PLANK_FRAME = (FRAME_SIZE + 2 * PLANK_PAD_X, FRAME_SIZE + 2 * PLANK_PAD_Y)
PLANK_LEFT = round(to_source(PLANK_START_SCREEN))
PLANK_SIZE = (round(PLANK_SCREEN[0] / GAME_SCALE), round(PLANK_SCREEN[1] / GAME_SCALE))
# Top of the plank (source pixels, unpadded): the diagonal step stands on
# the feet line, the bridge plank hangs from it.
STAIR_SURFACE = round(to_source(FEET_SCREEN - PLANK_SCREEN[1]))
BRIDGE_SURFACE = round(to_source(FEET_SCREEN))

HAMMER_HANDLE_CELLS = 5
# Head cells behind and ahead of the handle (the face, which strikes, is
# the side ahead), and how thick it is along the handle.
HAMMER_BACK_CELLS = 1
HAMMER_FACE_CELLS = 2
# Where the hammer lands: on the plank's near nail.
STRIKE_X = PLANK_LEFT + cells(4)

# How low the body gets over the plank: cells down (the robe drops over the
# feet) and lean forward in degrees (negative is clockwise, as PIL rotates).
# The bridge plank is lower, so the wizard kneels deeper over it. The other
# characters have legs: they bend them by a share of their length
# (leg_share) and lean the upper body about the hips (body_lean), further
# than the wizard's robe turns about its hem, since a shear about the hips
# moves the head less.
STAIR_STANCE = {"crouch": 1, "lean": -8, "leg_share": 0.3, "body_lean": -14}
BRIDGE_STANCE = {"crouch": 3, "lean": -14, "leg_share": 0.5, "body_lean": -22}

# Per frame, relative to the plank's top:
#   lift: cells the plank is held above its place (0 is in place);
#   hand: top-left of the hand setting the plank down (x, cells above);
#   grip: where the hand holds the hammer (x, cells above), and angle of
#         the handle in degrees (0 right, 90 up), the head across its end;
#   dust: (cells right of the strike, cells above the plank) per puff.
# Set the plank down, raise the hammer, strike, lift it again.
LAY_FRAMES = [
    {"lift": 2, "hand": (PLANK_LEFT + cells(1), 2), "grip": None, "dust": []},
    {"lift": 0, "hand": None, "grip": ((STRIKE_X - cells(2), 8), 80), "dust": []},
    {"lift": 0, "hand": None, "grip": ((STRIKE_X - cells(HAMMER_HANDLE_CELLS), HAMMER_FACE_CELLS + 1), 0),
     "dust": [(-3, 1), (2, 1)]},
    {"lift": 0, "hand": None, "grip": ((STRIKE_X - cells(HAMMER_HANDLE_CELLS), 6), 50), "dust": [(3, 3)]},
]

# The wizard's swinging arm, in source pixels of the walk frame.
WIZARD_SHOULDER = (150, 168)


class PaddedCanvas(ArtCanvas):
    """An ArtCanvas for a frame that is not square."""

    def __init__(self, size):
        super().__init__(max(size))
        self.frame_size = size

    def to_image(self):
        return super().to_image().crop((0, 0, *self.frame_size))


def plank(surface, lift_cells):
    """The terrain's brick at source scale, its top lift_cells above
    `surface` (unpadded source pixels), on a padded frame."""
    brick = Image.open(TERRAIN_DIR / "brick.png").convert("RGBA")
    big = brick.resize(PLANK_SIZE, Image.NEAREST)
    layer = Image.new("RGBA", PLANK_FRAME, (0, 0, 0, 0))
    layer.paste(big, (PLANK_PAD_X + PLANK_LEFT, PLANK_PAD_Y + surface - cells(lift_cells)), big)
    return layer


def along(origin, angle_degrees, length_cells):
    angle = math.radians(angle_degrees)
    return (origin[0] + math.cos(angle) * cells(length_cells), origin[1] - math.sin(angle) * cells(length_cells))


def draw_hammer(canvas, grip, angle):
    """Handle from the grip outwards, a head three cells across its end,
    with the striking face lit on the side it swings towards (clockwise)."""
    end = along(grip, angle, HAMMER_HANDLE_CELLS)
    canvas.line(grip, end, WOOD_LIGHT)
    canvas.fill_cell(*along(grip, angle, -1), WOOD)
    back = along(end, angle + 90, HAMMER_BACK_CELLS)
    face = along(end, angle - 90, HAMMER_FACE_CELLS)
    canvas.line(back, face, METAL)
    canvas.line(along(back, angle, -1), along(face, angle, -1), METAL)
    canvas.fill_cell(*face, METAL_LIGHT)
    canvas.fill_cell(*along(face, angle, -1), METAL_LIGHT)


def lay_tool(canvas, surface, pose, pad=(PLANK_PAD_X, PLANK_PAD_Y)):
    """Draws the hammer of one frame (if it shows) on canvas and returns
    where the hand goes (top-left, padded source pixels): on the hammer's
    grip, or on top of the plank being set down."""
    if pose["grip"] is None:
        x, above = pose["hand"]
        plank_top = surface - cells(pose["lift"])
        return x + pad[0], plank_top - cells(above) + pad[1]
    (x, above), angle = pose["grip"]
    grip = (x + pad[0], surface - cells(above) + pad[1])
    draw_hammer(canvas, grip, angle)
    return grip[0] - ART_PIXEL // 2, grip[1] - ART_PIXEL // 2


def lay_dust(surface, pose, pad=(PLANK_PAD_X, PLANK_PAD_Y)):
    canvas = PaddedCanvas(PLANK_FRAME)
    for right_cells, up_cells in pose["dust"]:
        x = STRIKE_X + cells(right_cells) + pad[0]
        y = surface - cells(up_cells + DUST_CELLS - 1) + pad[1]
        canvas.rect(x, y, DUST_CELLS, DUST_CELLS, DUST)
    return canvas.to_image()


def wizard_kneeling(stance):
    """(body on the 250 frame, shoulder) bent over the spot in front: the
    robe drops `crouch` cells over the feet and leans forward about the hem,
    the back foot steps back a cell."""
    upper, back_foot, front_foot = split_feet(side_body_without_hand())
    drop = cells(stance["crouch"])
    pivot = (LEG_SPLIT_X, HEM_Y + drop)
    body = Image.new("RGBA", upper.size, (0, 0, 0, 0))
    body.alpha_composite(shifted(back_foot, -cells(1), 0))
    body.alpha_composite(front_foot)
    robe = shifted(upper, 0, drop).rotate(stance["lean"], resample=Image.NEAREST, center=pivot)
    body.alpha_composite(robe)
    shoulder = rotate_point((WIZARD_SHOULDER[0], WIZARD_SHOULDER[1] + drop), stance["lean"], pivot)
    return body, shoulder


def build_lay_frames(prefix, surface, stance):
    body, shoulder = wizard_kneeling(stance)
    shoulder = (shoulder[0] + PLANK_PAD_X, shoulder[1] + PLANK_PAD_Y)
    for index, pose in enumerate(LAY_FRAMES):
        frame = Image.new("RGBA", PLANK_FRAME, (0, 0, 0, 0))
        frame.alpha_composite(body, (PLANK_PAD_X, PLANK_PAD_Y))
        frame.alpha_composite(plank(surface, pose["lift"]))
        canvas = PaddedCanvas(PLANK_FRAME)
        hand = lay_tool(canvas, surface, pose)
        canvas.arm(shoulder, hand)
        canvas.outline()
        frame.alpha_composite(canvas.to_image())
        frame.alpha_composite(lay_dust(surface, pose))
        save(frame, f"{prefix}_{index}")


def main():
    build_ladder_frames()
    build_lay_frames(STAIR_PREFIX, STAIR_SURFACE, STAIR_STANCE)
    build_lay_frames(BRIDGE_PREFIX, BRIDGE_SURFACE, BRIDGE_STANCE)
    print("wrote %s, %s and %s frames" % (LADDER_PREFIX, STAIR_PREFIX, BRIDGE_PREFIX))


if __name__ == "__main__":
    main()
