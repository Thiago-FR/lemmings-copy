"""Draws the art of the roguelike's character abilities: one 32x32 icon per
ability for its slot in the tool bar, the recharge item, the compendium
button, and the illustration of the relic that raises ability charges.

    python tools/build_ability_art.py [preview.png]
    godot --headless --path . --import

Outputs:

  assets/sprites/ui/icons/ability_<id>.png     32x32 per ability (ids from
                                               modes/roguelike/scripts/abilities/ability_catalog.gd)
  assets/sprites/ui/icons/ability_charge.png   32x32 recharge item (and the relic's bar icon)
  assets/sprites/ui/icons/compendium.png       32x32 book, the compendium button
  assets/sprites/ui/cards/relic_ability_charges.png  64x64 relic illustration

Its own script, apart from tools/build_ui_art.py, so the two can be rerun
independently: it only reuses that script's palette and drawing helpers
(same rules: pixel by pixel at 1x, flat fills, a one pixel near-black
outline added automatically, light effects drawn after the outline).
"""

import math
import os
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from build_ui_art import (  # noqa: E402
    ICON, CLEAR, OUTLINE, rgb, new, put, rect, hline, vline, polygon, line, disc, outline, plank,
    earth_fill, grass_top,
    CONCRETE_SEAM, CONCRETE_DARK, CONCRETE_BASE, CONCRETE_LIGHT, CONCRETE_HIGHLIGHT,
    ROBE, ROBE_LIGHT, YELLOW, YELLOW_LIGHT, ORANGE, LEATHER_DARK, LEATHER, CREAM, CREAM_DARK,
    BLUE_DARK, BLUE, BLUE_LIGHT, BLUE_SHINE, EXIT_GREEN_DARK, EXIT_GREEN, EXIT_GREEN_LIGHT,
)

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
ICON_DIR = os.path.join(ROOT, "assets", "sprites", "ui", "icons")
CARD_DIR = os.path.join(ROOT, "assets", "sprites", "ui", "cards")

WHITE = (255, 255, 255, 255)
VIOLET_DARK = rgb("#2a0f3d")
VIOLET_GLOW = rgb("#c9a2ff")
VIOLET_SHINE = rgb("#efe2ff")
CYAN = rgb("#43c6f0")
CYAN_LIGHT = rgb("#a8ecff")
CYAN_DARK = rgb("#1b6f94")


def sparkle(image, x, y, size=2, core=WHITE, arm=YELLOW_LIGHT, tip=YELLOW):
    """Four pointed glint, drawn after outlining so it reads as light."""
    put(image, x, y, core)
    for step in range(1, size + 1):
        colour = arm if step < size else tip
        for dx, dy in ((step, 0), (-step, 0), (0, step), (0, -step)):
            put(image, x + dx, y + dy, colour)


def ring(image, cx, cy, rx, ry, thickness, colour):
    for y in range(image.height):
        for x in range(image.width):
            dx, dy = (x + 0.5 - cx) / rx, (y + 0.5 - cy) / ry
            outer = dx * dx + dy * dy
            dx2, dy2 = (x + 0.5 - cx) / (rx - thickness), (y + 0.5 - cy) / (ry - thickness)
            if outer <= 1.0 and dx2 * dx2 + dy2 * dy2 > 1.0:
                put(image, x, y, colour)


def ellipse(image, cx, cy, rx, ry, colour):
    for y in range(image.height):
        for x in range(image.width):
            dx, dy = (x + 0.5 - cx) / rx, (y + 0.5 - cy) / ry
            if dx * dx + dy * dy <= 1.0:
                put(image, x, y, colour)


def arrow_head(image, tip, direction, size, colour):
    dx, dy = direction
    length = math.hypot(dx, dy)
    dx, dy = dx / length, dy / length
    back = (tip[0] - dx * size, tip[1] - dy * size)
    side = (-dy * size * 0.7, dx * size * 0.7)
    polygon(image, [tip, (back[0] + side[0], back[1] + side[1]), (back[0] - side[0], back[1] - side[1])], colour)


# ---------------------------------------------------------------------------
# Ability icons
# ---------------------------------------------------------------------------

def ability_teleport():
    """A violet portal seen at an angle, with a star at its heart: the
    Wizard steps through a block."""
    image = new()
    ellipse(image, 16, 17, 11, 13, ROBE)
    ellipse(image, 16, 17, 8, 10, VIOLET_DARK)
    ring(image, 16, 17, 11, 13, 2, ROBE_LIGHT)
    # Swirl: two arcs of light inside the portal.
    for t in range(0, 26):
        angle = math.radians(t * 11)
        radius = 2 + t * 0.24
        put(image, int(16 + radius * math.cos(angle)), int(17 + radius * 1.2 * math.sin(angle)), VIOLET_GLOW)
        put(image, int(16 - radius * math.cos(angle)), int(17 - radius * 1.2 * math.sin(angle)), ROBE_LIGHT)
    outline(image)
    sparkle(image, 16, 17, 2, WHITE, VIOLET_SHINE, VIOLET_GLOW)
    sparkle(image, 26, 5, 2)
    sparkle(image, 5, 27, 1)
    return image


def ability_break_concrete():
    """A concrete block split by a crack, chips flying off where the
    Miner's blow lands."""
    image = new()
    rect(image, 3, 8, 24, 28, CONCRETE_BASE)
    hline(image, 3, 24, 8, CONCRETE_HIGHLIGHT)
    vline(image, 3, 8, 28, CONCRETE_LIGHT)
    hline(image, 3, 24, 28, CONCRETE_DARK)
    vline(image, 24, 8, 28, CONCRETE_DARK)
    hline(image, 4, 23, 18, CONCRETE_SEAM)
    # The crack, from the top right corner down through the block.
    crack = [(20, 8), (17, 12), (19, 15), (14, 19), (16, 22), (11, 28)]
    for start, end in zip(crack, crack[1:]):
        line(image, start, end, OUTLINE, 2)
    # Chips thrown up and to the right.
    for x, y in ((26, 6), (28, 11), (24, 2), (29, 3)):
        rect(image, x, y, x + 1, y + 1, CONCRETE_LIGHT)
    outline(image)
    sparkle(image, 21, 7, 2, WHITE, YELLOW_LIGHT, ORANGE)
    return image


def ability_platform():
    """Three planks laid out over a gap from a grassy ledge: the Engineer's
    plank, laid at once."""
    image = new()
    earth_fill(image, 0, 18, 6, 31, 7)
    grass_top(image, 0, 6, 17)
    for index in range(3):
        x0 = 7 + index * 8
        plank(image, x0, 17, x0 + 7, 21)
    outline(image)
    sparkle(image, 11, 11, 2)
    sparkle(image, 23, 8, 1)
    sparkle(image, 29, 13, 1)
    return image


def ability_leap():
    """A dotted arc over a gap between two ledges, ending in an arrow: the
    Scout's jump."""
    image = new()
    for x0, x1 in ((0, 8), (23, 31)):
        earth_fill(image, x0, 23, x1, 31, x0 + 3)
        grass_top(image, x0, x1, 22)
    outline(image)
    points = []
    for step in range(0, 21):
        t = step / 20
        points.append((5 + 21 * t, 19 - 15 * 4 * t * (1 - t)))
    for index, (x, y) in enumerate(points[:-2]):
        if index % 3 != 2:
            rect(image, int(x), int(y), int(x) + 1, int(y) + 1, EXIT_GREEN_LIGHT)
    arrow_head(image, (27, 20), (points[-1][0] - points[-4][0], points[-1][1] - points[-4][1]), 5, EXIT_GREEN_LIGHT)
    outline(image)
    sparkle(image, 15, 3, 1, WHITE, EXIT_GREEN_LIGHT, EXIT_GREEN)
    return image


def ability_repeat():
    """Two curved arrows chasing each other round a small wrench: the
    Tinkerer hands the same tool again."""
    image = new()
    for start, end in ((200, 340), (20, 160)):
        for degrees in range(start, end, 2):
            angle = math.radians(degrees)
            for radius in (10, 11, 12):
                put(image, int(16 + radius * math.cos(angle)), int(16 + radius * math.sin(angle)), CYAN)
        angle = math.radians(end)
        tip = (16 + 11 * math.cos(angle), 16 + 11 * math.sin(angle))
        arrow_head(image, (tip[0] - 2 * math.sin(angle), tip[1] + 2 * math.cos(angle)), (-math.sin(angle), math.cos(angle)), 5, CYAN)
    # Wrench: a handle and an open jaw.
    line(image, (11, 21), (19, 13), CREAM_DARK, 3)
    disc(image, 20, 12, 3.2, CREAM)
    rect(image, 20, 10, 21, 11, CLEAR)
    put(image, 22, 10, CLEAR)
    outline(image)
    for degrees in range(200, 340, 6):
        angle = math.radians(degrees)
        put(image, int(16 + 10 * math.cos(angle)), int(16 + 10 * math.sin(angle)), CYAN_LIGHT)
    sparkle(image, 27, 5, 1, WHITE, CYAN_LIGHT, CYAN)
    return image


def ability_charge():
    """A glowing crystal: one more use of the character's ability."""
    image = new()
    ellipse(image, 16, 16, 13, 13, rgb("#3b1f5c"))
    ring(image, 16, 16, 13, 13, 1, ROBE_LIGHT)
    gem = [(16, 4), (24, 13), (16, 28), (8, 13)]
    polygon(image, gem, CYAN)
    polygon(image, [(16, 4), (24, 13), (16, 13)], CYAN_LIGHT)
    polygon(image, [(8, 13), (16, 13), (16, 28)], CYAN_DARK)
    hline(image, 9, 23, 13, BLUE_SHINE)
    outline(image)
    sparkle(image, 13, 9, 1, WHITE, BLUE_SHINE, CYAN_LIGHT)
    sparkle(image, 25, 6, 2)
    sparkle(image, 6, 24, 1)
    return image


def compendium():
    """A leather-bound book with a gold clasp and a star on the cover."""
    image = new()
    rect(image, 7, 4, 26, 28, CREAM)
    for y in range(6, 28, 2):
        hline(image, 24, 26, y, CREAM_DARK)
    rect(image, 5, 3, 23, 27, LEATHER)
    vline(image, 5, 3, 27, LEATHER_DARK)
    vline(image, 6, 3, 27, LEATHER_DARK)
    hline(image, 7, 23, 3, rgb("#8a5232"))
    rect(image, 9, 6, 20, 24, rgb("#7a4a2c"))
    rect(image, 10, 7, 19, 23, LEATHER)
    star = []
    for index in range(10):
        radius = 4.5 if index % 2 == 0 else 2
        angle = math.radians(-90 + index * 36)
        star.append((14.5 + radius * math.cos(angle), 14.5 + radius * math.sin(angle)))
    polygon(image, star, YELLOW)
    rect(image, 22, 13, 25, 17, YELLOW)
    put(image, 23, 15, ORANGE)
    outline(image)
    sparkle(image, 13, 13, 1, WHITE, YELLOW_LIGHT, YELLOW)
    return image


ICONS = {
    "ability_teleport": ability_teleport,
    "ability_break_concrete": ability_break_concrete,
    "ability_platform": ability_platform,
    "ability_leap": ability_leap,
    "ability_repeat": ability_repeat,
    "ability_charge": ability_charge,
    "compendium": compendium,
}


def relic_ability_charges():
    """The relic: the recharge crystal at twice the size on a ring of
    light, with more sparkles."""
    image = Image.new("RGBA", (64, 64), CLEAR)
    halo = Image.new("RGBA", (64, 64), CLEAR)
    ring(halo, 32, 32, 30, 30, 2, VIOLET_GLOW)
    image.alpha_composite(halo)
    crystal = ability_charge().resize((ICON * 2 - 8, ICON * 2 - 8), Image.NEAREST)
    image.alpha_composite(crystal, (4, 4))
    for x, y, size in ((52, 10, 3), (10, 50, 2), (55, 46, 2), (9, 12, 2)):
        sparkle(image, x, y, size)
    return image


def preview(images, path):
    scale = 3
    pad = 6
    cell = 64 * scale + pad * 2
    sheet = Image.new("RGBA", (cell * len(images), cell * 2), rgb("#808080"))
    for row, background in enumerate((rgb("#15131a"), rgb("#d9d6cc"))):
        for index, image in enumerate(images):
            x, y = index * cell, row * cell
            sheet.paste(background, (x, y, x + cell, y + cell))
            big = image.resize((image.width * scale, image.height * scale), Image.NEAREST)
            sheet.alpha_composite(big, (x + pad, y + pad))
    sheet.save(path)


def main():
    os.makedirs(ICON_DIR, exist_ok=True)
    images = []
    for name, build in ICONS.items():
        image = build()
        assert image.size == (ICON, ICON), name
        image.save(os.path.join(ICON_DIR, name + ".png"))
        images.append(image)
    relic = relic_ability_charges()
    relic.save(os.path.join(CARD_DIR, "relic_ability_charges.png"))
    images.append(relic)
    print("ability art written to", os.path.normpath(ICON_DIR), "and", os.path.normpath(CARD_DIR))
    if len(sys.argv) > 1:
        preview(images, sys.argv[1])
        print("preview written to", sys.argv[1])


if __name__ == "__main__":
    main()
