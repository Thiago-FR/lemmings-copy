"""Shared helpers for the scripts that build wizard frames from existing art.

Imported by tools/build_dig_frames.py and tools/build_death_frames.py. Kept
separate so both scripts read the source frames, draw new pixels and save
the results the same way.
"""

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


def load(name):
    return Image.open(SPRITE_DIR / f"{name}.png").convert("RGBA")


def save(image, name):
    image.save(SPRITE_DIR / f"{name}.png")


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
