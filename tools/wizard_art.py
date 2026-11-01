"""Shared helpers for the scripts that build wizard frames from existing art.

Imported by the tools/build_*_frames.py scripts. Kept separate so they all
read the source frames, draw new pixels and save the results the same way.
"""

import math
from pathlib import Path

import numpy as np
from PIL import Image

SPRITE_DIR = Path(__file__).resolve().parent.parent / "assets/sprites/characters/wizard"

# The wizard is drawn as pixel art scaled up: one art pixel is about 7 source
# pixels (measured from the run lengths of flat colour in walk_aligned_0).
# Anything added on top is drawn on this same coarse grid, otherwise its
# edges come out visibly finer than the character it is attached to.
ART_PIXEL = 7

# Sampled from the existing frames so new props share the character's palette.
OUTLINE = (25, 14, 32, 255)
SKIN = (203, 121, 99, 255)
WOOD = (125, 51, 40, 255)
WOOD_LIGHT = (160, 78, 52, 255)
METAL = (150, 152, 168, 255)
METAL_LIGHT = (205, 207, 218, 255)
DUST = (196, 186, 170, 255)
ROBE = (97, 35, 121, 255)
ROBE_SHADE = (52, 23, 87, 255)
# Sleeves of drawn arms: a step lighter than the robe, so an arm crossing
# the body still reads as a separate shape.
SLEEVE = (126, 54, 158, 255)

# Side-on walk frame landmarks, in source pixels of walk_aligned_0. The robe
# hem ends on HEM_Y; everything below is the two feet, split at LEG_SPLIT_X
# (back foot on the left, front foot on the right). HAND_BOX holds the one
# hand drawn at the waist, which poses with raised arms have to remove.
SIDE_SOURCE = "walk_aligned_0"
HEM_Y = 214
LEG_SPLIT_X = 132
HAND_BOX = (90, 188, 124, 212)


def load(name):
    return Image.open(SPRITE_DIR / f"{name}.png").convert("RGBA")


def save(image, name):
    image.save(SPRITE_DIR / f"{name}.png")


def side_body_without_hand():
    """The side-on walk frame with the waist hand painted over in robe
    shade, so new arms can be drawn wherever a pose needs them without a
    third hand left behind."""
    pixels = np.array(load(SIDE_SOURCE)).astype(int)
    left, top, right, bottom = HAND_BOX
    region = pixels[top:bottom, left:right]
    red, green, blue = region[:, :, 0], region[:, :, 1], region[:, :, 2]
    skin = (region[:, :, 3] > 128) & (red > 120) & (red - blue > 40) & (green > 50)
    region[skin, :3] = ROBE_SHADE[:3]
    return Image.fromarray(pixels.astype(np.uint8))


def split_feet(image):
    """(upper body, back foot, front foot) as full-frame layers, so the feet
    can be moved independently of the robe they hang from."""
    width, height = image.size
    upper = image.copy()
    upper.paste((0, 0, 0, 0), (0, HEM_Y, width, height))
    back = Image.new("RGBA", image.size, (0, 0, 0, 0))
    back.paste(image.crop((0, HEM_Y, LEG_SPLIT_X, height)), (0, HEM_Y))
    front = Image.new("RGBA", image.size, (0, 0, 0, 0))
    front.paste(image.crop((LEG_SPLIT_X, HEM_Y, width, height)), (LEG_SPLIT_X, HEM_Y))
    return upper, back, front


def shifted(layer, dx, dy):
    """The layer moved by (dx, dy) source pixels on a canvas of the same size."""
    moved = Image.new("RGBA", layer.size, (0, 0, 0, 0))
    moved.paste(layer, (dx, dy), layer)
    return moved


def rotate_point(point, angle_degrees, pivot):
    """Where a point lands when its image is rotated with PIL's rotate()
    about pivot (counter-clockwise on screen for a positive angle), so props
    drawn afterwards can be attached to a body that was rotated."""
    angle = math.radians(angle_degrees)
    dx, dy = point[0] - pivot[0], point[1] - pivot[1]
    return (
        round(pivot[0] + dx * math.cos(angle) + dy * math.sin(angle)),
        round(pivot[1] - dx * math.sin(angle) + dy * math.cos(angle)),
    )


def occupied_box(image):
    """(left, top, right, bottom) of the opaque pixels."""
    alpha = np.array(image)[:, :, 3] > 128
    rows, columns = np.where(alpha)
    return columns.min(), rows.min(), columns.max() + 1, rows.max() + 1


class ArtCanvas:
    """A transparent layer drawn on the coarse art-pixel grid, then scaled
    up to source resolution. Coordinates passed in are in source pixels and
    are snapped to the grid, so callers can place things against the
    character without converting units themselves."""

    def __init__(self, size):
        self.size = size
        cells = -(-size // ART_PIXEL)
        self.cells = np.zeros((cells, cells, 4), dtype=np.uint8)

    def _cell(self, x, y):
        return int(round(y / ART_PIXEL)), int(round(x / ART_PIXEL))

    def fill_cell(self, x, y, colour):
        row, column = self._cell(x, y)
        if 0 <= row < self.cells.shape[0] and 0 <= column < self.cells.shape[1]:
            self.cells[row, column] = colour

    def line(self, start, end, colour):
        """One art pixel thick, stepping on the grid."""
        (row_a, col_a), (row_b, col_b) = self._cell(*start), self._cell(*end)
        steps = max(abs(row_b - row_a), abs(col_b - col_a), 1)
        for i in range(steps + 1):
            row = round(row_a + (row_b - row_a) * i / steps)
            column = round(col_a + (col_b - col_a) * i / steps)
            self.cells[row, column] = colour

    def arm(self, shoulder, hand, sleeve=SLEEVE, claws=False):
        """A sleeve two art pixels thick from shoulder to hand, ending in a
        two-by-two hand. One art pixel thick vanishes at the in-game scale.
        With claws, a two-cell strip of metal sticks out ahead of the hand (to the
        right, the way the art faces), into the wall being gripped."""
        self.line(shoulder, hand, sleeve)
        self.line((shoulder[0], shoulder[1] + ART_PIXEL), (hand[0], hand[1] + ART_PIXEL), sleeve)
        self.rect(hand[0], hand[1], 2, 2, SKIN)
        if claws:
            for row in (0, 1):
                self.fill_cell(hand[0] + 2 * ART_PIXEL, hand[1] + row * ART_PIXEL, METAL_LIGHT)

    def rect(self, left, top, width_cells, height_cells, colour):
        row, column = self._cell(left, top)
        self.cells[row:row + height_cells, column:column + width_cells] = colour

    def outline(self, colour=OUTLINE):
        """Rings everything drawn so far with a one-art-pixel outline, which
        is what makes a prop read against the dark robe behind it."""
        solid = self.cells[:, :, 3] > 0
        grown = solid.copy()
        grown[1:, :] |= solid[:-1, :]
        grown[:-1, :] |= solid[1:, :]
        grown[:, 1:] |= solid[:, :-1]
        grown[:, :-1] |= solid[:, 1:]
        self.cells[grown & ~solid] = colour

    def to_image(self):
        image = Image.fromarray(self.cells, "RGBA")
        upscaled = image.resize((self.cells.shape[1] * ART_PIXEL, self.cells.shape[0] * ART_PIXEL), Image.NEAREST)
        return upscaled.crop((0, 0, self.size, self.size))
