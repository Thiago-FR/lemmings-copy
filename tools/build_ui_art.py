"""Draws the interface art: tool icons, editor palette icons and the
toolbar frame pieces.

    python tools/build_ui_art.py [preview.png]
    godot --headless --path . --import

Outputs, all in assets/sprites/ui/:

  icons/<tool id>.png      32x32 tool icons (digger, builder, ...), the file
                           name is the tool id used by the game.
  icons/editor_<name>.png  32x32 level editor palette and control icons.
  icons/sound_on/off.png   32x32 sound toggle pair.
  panel.png                24x24 toolbar frame, 9-slice margins 8 on every
                           side (StyleBoxTexture texture_margin_* = 8).
  slot*.png                40x40 item slot in four states (normal, hover,
                           selected, disabled), 9-slice margins 4.
  button*.png              24x24 wooden button (normal, hover, pressed,
                           disabled) and a green "primary" one for the main
                           action of a screen, 9-slice margins 6.
  check_on/off.png         20x20 check box.
  slider_*.png             slider groove and fill (12x8, margins 4) and knob.

Same rules as tools/build_terrain_art.py: pixel by pixel at 1x, a fixed
random seed, and the terrain palette (earth, grass, concrete, wood) plus the
wizard's metal and purple, so the icons look like pieces of the level. Every
shape is drawn as flat fills first and then given a one pixel near-black
outline automatically, which is what keeps them readable at 32 px against
both dark and light backgrounds. The frame edges are uniform along their
length so a 9-slice stretch does not smear any detail; the only details
(rivets) sit in the corners, which are never stretched.

Passing a path writes a preview sheet of everything at 1x and 3x on a dark
and a light background, with the frame pieces stretched as a 9-slice.
"""

import math
import os
import random
import sys

from PIL import Image, ImageDraw

ICON = 32
PANEL_SIZE = 24
PANEL_MARGIN = 8
SLOT_SIZE = 40
SLOT_MARGIN = 4

OUT_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "sprites", "ui")
ICON_DIR = os.path.join(OUT_DIR, "icons")

CLEAR = (0, 0, 0, 0)


def rgb(hex_colour):
    hex_colour = hex_colour.lstrip("#")
    return tuple(int(hex_colour[i:i + 2], 16) for i in (0, 2, 4)) + (255,)


OUTLINE = rgb("#1a0f14")

# Terrain palette (kept identical to tools/build_terrain_art.py).
EARTH_OUTLINE = rgb("#24140c")
EARTH_DARK = rgb("#4a2d1b")
EARTH_BASE = rgb("#6a4327")
EARTH_MID = rgb("#7b5030")
EARTH_LIGHT = rgb("#94643b")
PEBBLE = rgb("#6f6056")
PEBBLE_LIGHT = rgb("#8f8072")
GRASS_DARK = rgb("#2c6a2e")
GRASS = rgb("#45943a")
GRASS_LIGHT = rgb("#79c24e")
CONCRETE_SEAM = rgb("#5a5e66")
CONCRETE_DARK = rgb("#6f737c")
CONCRETE_BASE = rgb("#868a93")
CONCRETE_LIGHT = rgb("#a2a6ae")
CONCRETE_HIGHLIGHT = rgb("#c4c8ce")
WOOD_DARK = rgb("#7a4a22")
WOOD = rgb("#a86c34")
WOOD_LIGHT = rgb("#d39a55")
NAIL = rgb("#3c3f46")

# Wizard palette (tools/wizard_art.py) and a few extras.
METAL_DARK = rgb("#5e606e")
METAL = rgb("#9698a8")
METAL_LIGHT = rgb("#cdcfda")
METAL_SHINE = rgb("#f2f3f8")
ROBE = rgb("#612379")
ROBE_LIGHT = rgb("#7e369e")
SKIN = rgb("#cb7963")
RED_DARK = rgb("#7c1c1c")
RED = rgb("#c4322a")
RED_LIGHT = rgb("#ec6a4c")
CREAM = rgb("#efe2c0")
CREAM_DARK = rgb("#c9b78e")
YELLOW = rgb("#f2c230")
YELLOW_LIGHT = rgb("#fff08a")
ORANGE = rgb("#e8782a")
LEATHER_DARK = rgb("#4a2a1a")
LEATHER = rgb("#6e3f26")
BLUE_DARK = rgb("#1c2f7a")
BLUE = rgb("#3a62d8")
BLUE_LIGHT = rgb("#7fb2ff")
BLUE_SHINE = rgb("#d4ecff")
EXIT_GREEN_DARK = rgb("#1f5a2a")
EXIT_GREEN = rgb("#3fa04a")
EXIT_GREEN_LIGHT = rgb("#8fe07a")
PINK = rgb("#ef8fa6")
PINK_LIGHT = rgb("#ffc2cf")
PINK_DARK = rgb("#b85a74")
UI_LIGHT = rgb("#f0e6cc")
UI_SHADE = rgb("#b9a988")


# ---------------------------------------------------------------------------
# Drawing helpers
# ---------------------------------------------------------------------------

def new(width=ICON, height=ICON):
    return Image.new("RGBA", (width, height), CLEAR)


def put(image, x, y, colour):
    if 0 <= x < image.width and 0 <= y < image.height:
        image.putpixel((x, y), colour)


def rect(image, x0, y0, x1, y1, colour):
    """Filled rectangle, both corners inclusive."""
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            put(image, x, y, colour)


def hline(image, x0, x1, y, colour):
    rect(image, x0, y, x1, y, colour)


def vline(image, x, y0, y1, colour):
    rect(image, x, y0, x, y1, colour)


def polygon(image, points, colour):
    ImageDraw.Draw(image).polygon(points, fill=colour)


def line(image, p0, p1, colour, width=1):
    ImageDraw.Draw(image).line([p0, p1], fill=colour, width=width)


def disc(image, cx, cy, radius, colour):
    for y in range(int(cy - radius) - 1, int(cy + radius) + 2):
        for x in range(int(cx - radius) - 1, int(cx + radius) + 2):
            if (x - cx) ** 2 + (y - cy) ** 2 <= radius * radius:
                put(image, x, y, colour)


def opaque(image, x, y):
    return 0 <= x < image.width and 0 <= y < image.height and image.getpixel((x, y))[3] > 0


def outline(image, colour=OUTLINE):
    """Rings every shape with a one pixel border on the transparent side.
    Four-neighbour, so diagonals stay one pixel thick."""
    border = [
        (x, y)
        for y in range(image.height)
        for x in range(image.width)
        if not opaque(image, x, y)
        and any(opaque(image, x + dx, y + dy) for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))
    ]
    for x, y in border:
        image.putpixel((x, y), colour)
    return image


def recolour_where(image, old, new_colour, predicate):
    for y in range(image.height):
        for x in range(image.width):
            if image.getpixel((x, y)) == old and predicate(x, y):
                image.putpixel((x, y), new_colour)


# ---------------------------------------------------------------------------
# Shared pieces
# ---------------------------------------------------------------------------

def plank(image, x0, y0, x1, y1, nails=True):
    """A wooden plank like brick.png: light top edge, dark bottom edge,
    nails at both ends. Inner outline so stacked planks stay separate."""
    rect(image, x0, y0, x1, y1, OUTLINE)
    rect(image, x0 + 1, y0 + 1, x1 - 1, y1 - 1, WOOD)
    hline(image, x0 + 1, x1 - 1, y0 + 1, WOOD_LIGHT)
    if y1 - y0 >= 4:
        hline(image, x0 + 1, x1 - 1, y1 - 1, WOOD_DARK)
    if nails and x1 - x0 >= 7 and y1 - y0 >= 4:
        mid = (y0 + y1) // 2
        put(image, x0 + 2, mid, NAIL)
        put(image, x1 - 2, mid, NAIL)


def earth_fill(image, x0, y0, x1, y1, seed):
    rng = random.Random(seed)
    rect(image, x0, y0, x1, y1, EARTH_BASE)
    for _ in range((x1 - x0) * (y1 - y0) // 12):
        x, y = rng.randint(x0, x1), rng.randint(y0, y1)
        colour = rng.choice([EARTH_DARK, EARTH_MID, EARTH_MID, EARTH_LIGHT])
        put(image, x, y, colour)
        if rng.random() < 0.5:
            put(image, min(x + 1, x1), y, colour)
    # A few short strata, the packed earth cue from the terrain tiles.
    for _ in range(3):
        x, y = rng.randint(x0, x1 - 5), rng.randint(y0 + 2, y1)
        hline(image, x, x + rng.randint(3, 5), y, EARTH_DARK)


def pebble(image, x, y):
    rect(image, x, y, x + 2, y + 1, PEBBLE)
    put(image, x, y, PEBBLE_LIGHT)
    put(image, x + 1, y, PEBBLE_LIGHT)
    put(image, x + 2, y + 1, EARTH_DARK)


def grass_top(image, x0, x1, y):
    """Grass band whose surface row is y, with tufts poking above it."""
    rect(image, x0, y, x1, y + 4, GRASS)
    hline(image, x0, x1, y, GRASS_LIGHT)
    hline(image, x0, x1, y + 4, GRASS_DARK)
    for x in range(x0, x1 + 1):
        if x % 4 == 1:
            put(image, x, y - 1, GRASS_LIGHT)
        if x % 7 == 3:
            put(image, x, y + 5, GRASS_DARK)
            put(image, x, y + 6, GRASS_DARK)


def ladder_shape(image, top, bottom, left=7, right=22, spacing=6):
    for rail in (left, right):
        rect(image, rail, top, rail + 2, bottom, WOOD)
        vline(image, rail, top, bottom, WOOD_LIGHT)
        vline(image, rail + 2, top, bottom, WOOD_DARK)
    for y in range(top + 3, bottom - 1, spacing):
        rect(image, left + 3, y, right - 1, y + 1, WOOD)
        hline(image, left + 3, right - 1, y, WOOD_LIGHT)
        # Dark gap line under each rung so rungs read at 1x.
        hline(image, left + 3, right - 1, y + 2, OUTLINE)
        put(image, left + 2, y, NAIL)
        put(image, right, y, NAIL)
    return image


def speaker(image):
    rect(image, 3, 12, 8, 19, UI_LIGHT)
    polygon(image, [(8, 12), (15, 5), (15, 26), (8, 19)], UI_LIGHT)
    vline(image, 8, 13, 18, UI_SHADE)
    hline(image, 3, 7, 19, UI_SHADE)


# ---------------------------------------------------------------------------
# Tool icons
# ---------------------------------------------------------------------------

def icon_digger():
    """Shovel: wooden handle with a T grip, broad metal spade pointing down
    and left. The broad blade is what separates it from the pickaxe."""
    image = new()
    line(image, (25, 6), (15, 16), WOOD, 3)
    line(image, (26, 5), (16, 15), WOOD_LIGHT, 1)
    line(image, (22, 3), (28, 9), WOOD_DARK, 3)
    line(image, (22, 2), (28, 8), WOOD, 1)
    # Socket.
    line(image, (16, 15), (13, 18), METAL_DARK, 4)
    blade = [(9, 13), (18, 22), (13, 27), (4, 28), (4, 18)]
    polygon(image, blade, METAL)
    line(image, (9, 14), (5, 18), METAL_LIGHT, 1)
    line(image, (5, 19), (5, 26), METAL_LIGHT, 1)
    line(image, (12, 19), (6, 25), METAL_DARK, 1)
    line(image, (17, 22), (13, 26), METAL_DARK, 1)
    put(image, 6, 16, METAL_SHINE)
    return outline(image)


def icon_builder():
    """Diagonal staircase: four planks stepping up to the right, each one
    resting on the one below, and an arrow showing the direction."""
    image = new()
    steps = [(1, 25), (8, 19), (15, 13), (22, 7)]
    # Wooden posts under each step so it reads as a staircase, not a
    # scatter of planks.
    for x, y in steps[1:]:
        rect(image, x + 2, y + 5, x + 3, 30, WOOD_DARK)
    for x, y in steps:
        plank(image, x, y, x + 9, y + 5)
    return outline(image)


def icon_ladder_vertical():
    image = new()
    ladder_shape(image, 1, 30)
    return outline(image)


def icon_bridge():
    """Flat bridge of planks laid end to end across a gap between two
    grassy earth banks."""
    image = new()
    grass_top(image, 0, 6, 15)
    grass_top(image, 25, 31, 15)
    earth_fill(image, 0, 20, 6, 30, 11)
    earth_fill(image, 25, 20, 31, 30, 12)
    for x0 in (2, 11, 20):
        plank(image, x0, 11, x0 + 9, 16)
    # Rope rail: posts at the banks and a sagging rope between them.
    for x in (3, 28):
        rect(image, x, 4, x + 1, 10, WOOD_DARK)
        put(image, x, 4, WOOD_LIGHT)
    for x in range(5, 28):
        sag = round(2.2 * math.sin(math.pi * (x - 4) / 24))
        put(image, x, 5 + sag, CREAM_DARK)
    return outline(image)


def icon_floater():
    """Parachute, striped cream and red like the float animation, with a
    tiny hooded wizard hanging from four cords."""
    image = new()
    cx = 15.5
    for y in range(2, 14):
        for x in range(1, 31):
            dx = (x + 0.5 - cx) / 14.5
            dy = (y + 0.5 - 14) / 12
            if dx * dx + dy * dy <= 1.0:
                stripe = int((x - 1) // 5) % 2
                put(image, x, y, RED if stripe else CREAM)
    # Scalloped bottom edge.
    for x in range(1, 31):
        if (x - 1) % 5 in (0, 4):
            put(image, x, 13, CLEAR)
    # Shade along the lower rim, light on the crown.
    for x in range(2, 30):
        top_y = next(y for y in range(2, 14) if image.getpixel((x, y))[3])
        colour = image.getpixel((x, top_y + 1))
        put(image, x, top_y, RED_LIGHT if colour == RED else rgb("#fffaf0"))
        if image.getpixel((x, 12))[3]:
            put(image, x, 12, RED_DARK if image.getpixel((x, 12)) == RED else CREAM_DARK)
    for start in ((3, 14), (11, 14), (20, 14), (28, 14)):
        line(image, start, (15 if start[0] < 16 else 16, 21), CREAM_DARK, 1)
    # Wizard: purple hood and robe, skin face.
    polygon(image, [(15, 19), (17, 19), (20, 30), (12, 30)], ROBE)
    rect(image, 14, 20, 18, 23, ROBE_LIGHT)
    rect(image, 15, 21, 17, 22, SKIN)
    put(image, 16, 18, ROBE_LIGHT)
    vline(image, 13, 26, 29, rgb("#3a1752"))
    return outline(image)


def icon_climber():
    """Climbing claws: a leather glove whose three long steel hooks bite
    into a stone wall on the right. Claws are drawn on their own layer
    and outlined separately so they stay distinct where they overlap the
    wall."""
    wall = new()
    rect(wall, 25, 0, 31, 31, CONCRETE_BASE)
    vline(wall, 25, 0, 31, CONCRETE_HIGHLIGHT)
    for y in (7, 17, 27):
        hline(wall, 26, 31, y, CONCRETE_SEAM)
    vline(wall, 28, 8, 16, CONCRETE_SEAM)
    vline(wall, 29, 18, 26, CONCRETE_SEAM)
    outline(wall)

    glove = new()
    # Cuff leaving the frame at the bottom.
    rect(glove, 5, 23, 15, 31, LEATHER_DARK)
    hline(glove, 5, 15, 23, rgb("#8a5634"))
    rect(glove, 5, 26, 15, 27, YELLOW)
    # Fist seen from the side, knuckles toward the wall.
    rect(glove, 3, 9, 16, 22, LEATHER)
    for corner in ((3, 9), (16, 9), (3, 22), (16, 22)):
        put(glove, corner[0], corner[1], CLEAR)
    hline(glove, 4, 15, 9, rgb("#8a5634"))
    vline(glove, 3, 10, 21, rgb("#8a5634"))
    hline(glove, 4, 15, 22, LEATHER_DARK)
    # Steel knuckle plate the claws are riveted to.
    rect(glove, 12, 10, 16, 21, METAL)
    vline(glove, 12, 10, 21, METAL_LIGHT)
    vline(glove, 16, 10, 21, METAL_DARK)
    for y in (12, 16, 20):
        put(glove, 14, y, NAIL)
    outline(glove)

    claws = new()
    for y in (11, 15, 19):
        # Straight shank, then the tip hooks down into the wall.
        rect(claws, 17, y, 24, y + 1, METAL)
        hline(claws, 17, 23, y, METAL_LIGHT)
        put(claws, 25, y + 1, METAL)
        put(claws, 25, y + 2, METAL_LIGHT)
        put(claws, 26, y + 2, METAL)
        put(claws, 26, y + 3, METAL_SHINE)
    outline(claws)

    image = wall
    image.alpha_composite(claws)
    image.alpha_composite(glove)
    # Chips knocked off where the tips bite.
    return image


def icon_block():
    """A block of earth with grass on top, like a floor tile."""
    image = new()
    earth_fill(image, 2, 7, 29, 29, 7)
    pebble(image, 7, 19)
    pebble(image, 20, 24)
    grass_top(image, 2, 29, 5)
    # Light left face, dark right face for volume.
    vline(image, 2, 10, 29, EARTH_LIGHT)
    vline(image, 29, 10, 29, EARTH_DARK)
    hline(image, 2, 29, 29, EARTH_DARK)
    return outline(image)


def icon_dynamite():
    """Three red sticks tied with a band, a lit fuse curling up."""
    image = new()
    for x0 in (5, 12, 19):
        rect(image, x0, 12, x0 + 6, 29, RED)
        vline(image, x0 + 1, 13, 28, RED_LIGHT)
        vline(image, x0 + 5, 12, 29, RED_DARK)
        hline(image, x0, x0 + 6, 12, CREAM_DARK)
        hline(image, x0, x0 + 6, 29, RED_DARK)
    # Gaps between sticks.
    vline(image, 11, 12, 29, OUTLINE)
    vline(image, 18, 12, 29, OUTLINE)
    rect(image, 4, 19, 26, 22, LEATHER_DARK)
    hline(image, 4, 26, 19, LEATHER)
    # Fuse from the middle stick.
    fuse = [(15, 11), (15, 9), (16, 7), (18, 6), (20, 6), (22, 5), (23, 4)]
    for p0, p1 in zip(fuse, fuse[1:]):
        line(image, p0, p1, CREAM_DARK, 1)
    image = outline(image)
    # Spark drawn after the outline so it glows.
    for x, y, colour in [(25, 2, YELLOW_LIGHT), (24, 2, YELLOW), (26, 2, YELLOW), (25, 1, YELLOW),
                         (25, 3, YELLOW), (23, 0, ORANGE), (27, 0, ORANGE), (27, 4, ORANGE),
                         (28, 2, ORANGE), (22, 2, ORANGE)]:
        put(image, x, y, colour)
    return image


LETTERS = {
    # 5 wide, 7 tall, strokes 2 px where it matters for 1x legibility.
    "T": ["#####", "#####", "..#..", "..#..", "..#..", "..#..", "..#.."],
    "N": ["#...#", "##..#", "###.#", "#.###", "#..##", "#...#", "#...#"],
}


def draw_text(image, text, x, y, colour, letters=LETTERS, spacing=1):
    for char in text:
        rows = letters[char]
        for row_index, row in enumerate(rows):
            for col_index, cell in enumerate(row):
                if cell == "#":
                    put(image, x + col_index, y + row_index, colour)
        x += len(rows[0]) + spacing


def icon_tnt():
    """Wooden crate with TNT stencilled in red, so it is not just another
    red thing next to the dynamite."""
    image = new()
    rect(image, 1, 5, 30, 29, WOOD)
    for y in (5, 13, 21):
        hline(image, 1, 30, y, WOOD_LIGHT)
    for y in (12, 20):
        hline(image, 1, 30, y, WOOD_DARK)
    hline(image, 1, 30, 29, WOOD_DARK)
    # Corner battens.
    for x in (1, 27):
        rect(image, x, 5, x + 3, 29, WOOD_DARK)
        vline(image, x + 1, 5, 29, WOOD)
        put(image, x + 1, 7, NAIL)
        put(image, x + 1, 27, NAIL)
    # Label.
    rect(image, 6, 10, 25, 24, CREAM)
    hline(image, 6, 25, 24, CREAM_DARK)
    vline(image, 25, 10, 24, CREAM_DARK)
    draw_text(image, "TNT", 7, 12, RED, spacing=1)
    # Thicken the letters vertically to 2px strokes on the diagonals.
    letters = new()
    draw_text(letters, "TNT", 7, 12, RED, spacing=1)
    for y in range(ICON):
        for x in range(ICON):
            if letters.getpixel((x, y))[3]:
                if y + 1 <= 19:
                    put(image, x, y + 1, RED)
    rect(image, 6, 10, 25, 10, CREAM)
    image = outline(image)
    return image


def icon_basher():
    """Jackhammer, upright: D handle with yellow grips, grey finned body,
    bright bit and a puff of dust where it bites."""
    image = new()
    # Handle bar and grips.
    rect(image, 5, 2, 26, 5, METAL_DARK)
    hline(image, 5, 26, 2, METAL)
    rect(image, 4, 2, 9, 6, YELLOW)
    rect(image, 22, 2, 27, 6, YELLOW)
    hline(image, 4, 9, 2, YELLOW_LIGHT)
    hline(image, 22, 27, 2, YELLOW_LIGHT)
    hline(image, 4, 9, 6, ORANGE)
    hline(image, 22, 27, 6, ORANGE)
    rect(image, 14, 6, 17, 8, METAL_DARK)
    # Body with cooling fins.
    rect(image, 10, 8, 21, 19, METAL)
    vline(image, 10, 8, 19, METAL_LIGHT)
    vline(image, 21, 8, 19, METAL_DARK)
    for y in (10, 13, 16):
        hline(image, 9, 22, y, OUTLINE)
        hline(image, 10, 21, y + 1, METAL_LIGHT)
    # Nozzle and bit.
    rect(image, 13, 20, 18, 22, METAL_DARK)
    hline(image, 13, 18, 20, METAL)
    rect(image, 15, 23, 16, 27, METAL_LIGHT)
    vline(image, 15, 23, 27, METAL_SHINE)
    put(image, 15, 28, METAL_LIGHT)
    put(image, 16, 28, METAL_LIGHT)
    image = outline(image)
    # Dust and chips, after the outline: they are loose bits, not solid.
    for x, y, colour in [(10, 29, CREAM_DARK), (11, 30, CREAM_DARK), (8, 28, PEBBLE_LIGHT),
                         (21, 29, CREAM_DARK), (20, 30, CREAM_DARK), (23, 28, PEBBLE_LIGHT),
                         (12, 28, CREAM), (19, 28, CREAM), (14, 31, PEBBLE), (17, 31, PEBBLE)]:
        put(image, x, y, colour)
    return image


def icon_miner():
    """Pickaxe: long handle from bottom left, curved double pointed iron
    head across the top right. Thin crescent head versus the shovel's
    broad blade."""
    image = new()
    line(image, (4, 28), (20, 12), WOOD, 3)
    line(image, (4, 27), (19, 12), WOOD_LIGHT, 1)
    line(image, (6, 29), (21, 14), WOOD_DARK, 1)
    # Head: a crescent along the (1,1) axis bowed away from the handle.
    cx, cy = 21.0, 11.0
    for step in range(-60, 61):
        t = step / 60.0
        bow = 4.5 * (1 - t * t)
        # u = (1,1)/sqrt2 along the head, n = (1,-1)/sqrt2 away from handle.
        px = cx + (t * 12.0) * 0.7071 + bow * 0.7071 - 4.5 * 0.7071 * 0.5
        py = cy + (t * 12.0) * 0.7071 - bow * 0.7071 + 4.5 * 0.7071 * 0.5
        radius = 1.9 * (1 - abs(t)) + 0.4
        disc(image, px, py, radius, METAL)
    # Light along the outer curve.
    for step in range(-50, 51):
        t = step / 60.0
        bow = 4.5 * (1 - t * t) + 1.0
        px = cx + (t * 12.0) * 0.7071 + bow * 0.7071 - 1.6
        py = cy + (t * 12.0) * 0.7071 - bow * 0.7071 + 1.6
        if opaque(image, round(px), round(py)):
            put(image, round(px), round(py), METAL_LIGHT)
    # Collar where the head meets the handle.
    rect(image, 19, 11, 22, 14, METAL_DARK)
    put(image, 20, 12, METAL)
    return outline(image)


# ---------------------------------------------------------------------------
# Editor icons
# ---------------------------------------------------------------------------

def editor_earth():
    image = new()
    earth_fill(image, 2, 2, 29, 29, 21)
    pebble(image, 6, 8)
    pebble(image, 19, 17)
    pebble(image, 9, 23)
    hline(image, 2, 29, 2, EARTH_LIGHT)
    vline(image, 2, 2, 29, EARTH_LIGHT)
    hline(image, 2, 29, 29, EARTH_DARK)
    vline(image, 29, 2, 29, EARTH_DARK)
    return outline(image)


def editor_concrete():
    image = new()
    rect(image, 2, 2, 29, 29, CONCRETE_BASE)
    rng = random.Random(33)
    for _ in range(40):
        put(image, rng.randint(3, 28), rng.randint(3, 28), rng.choice([CONCRETE_DARK, CONCRETE_LIGHT]))
    # Slab seams: one horizontal, offset verticals, like the tile.
    hline(image, 2, 29, 15, CONCRETE_SEAM)
    hline(image, 2, 29, 16, CONCRETE_HIGHLIGHT)
    vline(image, 12, 2, 14, CONCRETE_SEAM)
    vline(image, 13, 2, 14, CONCRETE_HIGHLIGHT)
    vline(image, 21, 17, 29, CONCRETE_SEAM)
    vline(image, 22, 17, 29, CONCRETE_HIGHLIGHT)
    hline(image, 2, 29, 2, CONCRETE_HIGHLIGHT)
    vline(image, 2, 2, 29, CONCRETE_HIGHLIGHT)
    hline(image, 2, 29, 29, CONCRETE_DARK)
    vline(image, 29, 2, 29, CONCRETE_DARK)
    return outline(image)


def editor_ladder():
    return icon_ladder_vertical()


def editor_brick():
    image = new()
    plank(image, 1, 9, 30, 15)
    plank(image, 1, 16, 30, 22)
    for x0, y, length in [(6, 12, 7), (17, 13, 8), (9, 19, 9), (22, 20, 4)]:
        hline(image, x0, x0 + length, y, WOOD_DARK)
    return outline(image)


def editor_eraser():
    """Pink eraser lying at an angle with a blue paper sleeve."""
    image = new()
    body = [(2, 21), (14, 9), (29, 19), (17, 31)]
    polygon(image, body, PINK)
    # Sleeve over the upper right half.
    polygon(image, [(9, 14), (14, 9), (29, 19), (24, 24)], BLUE)
    line(image, (14, 10), (27, 19), BLUE_LIGHT, 1)
    line(image, (9, 14), (24, 24), BLUE_DARK, 1)
    line(image, (3, 21), (9, 15), PINK_LIGHT, 1)
    line(image, (4, 22), (16, 30), PINK_DARK, 1)
    image = outline(image)
    # Crumbs.
    for x, y in ((24, 28), (27, 26), (21, 30)):
        put(image, x, y, PINK_DARK)
    return image


def arched_door(image, x0, x1, top, bottom, frame, frame_light, inside):
    """Stone arch with a coloured opening."""
    cx = (x0 + x1) / 2
    radius = (x1 - x0) / 2
    for y in range(top, bottom + 1):
        for x in range(x0, x1 + 1):
            arch_y = top + radius
            if y >= arch_y or (x + 0.5 - cx - 0.5) ** 2 + (y + 0.5 - arch_y) ** 2 <= radius * radius:
                put(image, x, y, frame)
    inner_r = radius - 3
    for y in range(top + 3, bottom + 1):
        for x in range(x0 + 3, x1 - 2):
            arch_y = top + radius
            if y >= arch_y or (x + 0.5 - cx - 0.5) ** 2 + (y + 0.5 - arch_y) ** 2 <= inner_r * inner_r:
                put(image, x, y, inside)
    vline(image, x0, int(top + radius), bottom, frame_light)


def editor_entrance():
    """A stone arch with a swirling blue portal: where the wizards come in."""
    image = new()
    arched_door(image, 3, 28, 1, 30, CONCRETE_BASE, CONCRETE_HIGHLIGHT, BLUE_DARK)
    # Swirl.
    cx, cy = 15.5, 18.5
    for step in range(0, 200):
        t = step / 200.0
        angle = t * 4.2 * math.pi
        r = 1.0 + t * 8.0
        x, y = cx + r * math.cos(angle), cy + r * math.sin(angle) * 1.2
        if image.getpixel((min(31, max(0, round(x))), min(31, max(0, round(y))))) in (BLUE_DARK, BLUE):
            put(image, round(x), round(y), BLUE_LIGHT if t > 0.35 else BLUE_SHINE)
    for y in range(4, 31):
        for x in range(6, 26):
            if image.getpixel((x, y)) == BLUE_DARK and (x + y) % 3 == 0:
                put(image, x, y, BLUE)
    disc(image, cx, cy, 1.2, BLUE_SHINE)
    # Down arrow on the keystone hints "in".
    rect(image, 14, 2, 17, 3, BLUE_LIGHT)
    image = outline(image)
    return image


def editor_exit():
    """A green door in a wooden frame with a flag on top: the way out."""
    image = new()
    rect(image, 5, 11, 26, 30, WOOD_DARK)
    vline(image, 5, 11, 30, WOOD)
    rect(image, 8, 14, 23, 30, EXIT_GREEN)
    vline(image, 8, 14, 30, EXIT_GREEN_LIGHT)
    vline(image, 23, 14, 30, EXIT_GREEN_DARK)
    hline(image, 8, 23, 14, EXIT_GREEN_LIGHT)
    for y in (19, 25):
        hline(image, 10, 21, y, EXIT_GREEN_DARK)
    rect(image, 19, 21, 20, 22, YELLOW)
    # Flagpole and flag.
    vline(image, 15, 1, 10, METAL_LIGHT)
    vline(image, 16, 1, 10, METAL)
    polygon(image, [(17, 1), (26, 4), (17, 7)], EXIT_GREEN_LIGHT)
    line(image, (17, 6), (25, 4), EXIT_GREEN, 1)
    return outline(image)


def editor_play():
    image = new()
    polygon(image, [(9, 4), (26, 15), (26, 16), (9, 27)], UI_LIGHT)
    line(image, (10, 26), (25, 17), UI_SHADE, 1)
    return outline(image)


def editor_pause():
    image = new()
    for x0 in (7, 18):
        rect(image, x0, 5, x0 + 6, 26, UI_LIGHT)
        vline(image, x0 + 6, 5, 26, UI_SHADE)
        hline(image, x0, x0 + 6, 26, UI_SHADE)
    return outline(image)


def editor_restart():
    """Circular arrow, three quarters of a ring with an arrowhead."""
    image = new()
    cx, cy = 15.5, 16.5
    for y in range(ICON):
        for x in range(ICON):
            dist = math.hypot(x + 0.5 - cx - 0.5, y + 0.5 - cy - 0.5)
            angle = math.degrees(math.atan2(y + 0.5 - cy - 0.5, x + 0.5 - cx - 0.5)) % 360
            if 7.0 <= dist <= 11.2 and not (250 < angle < 330):
                put(image, x, y, UI_LIGHT if dist < 10.2 else UI_SHADE)
    # Arrowhead at the open end (top), pointing clockwise.
    polygon(image, [(17, 0), (26, 7), (16, 13)], UI_LIGHT)
    return outline(image)


def editor_menu():
    image = new()
    for y in (6, 14, 22):
        rect(image, 5, y, 26, y + 3, UI_LIGHT)
        hline(image, 5, 26, y + 3, UI_SHADE)
    return outline(image)


DIGITS = {
    "1": [".##.", "###.", ".##.", ".##.", ".##.", ".##.", ".##.", ".##.", "####"],
    "2": [".##.", "#..#", "...#", "...#", "..#.", ".#..", "#...", "#...", "####"],
    "3": ["###.", "...#", "...#", "...#", ".##.", "...#", "...#", "...#", "###."],
}


def editor_counts():
    """A tally list: "123" over three short lines."""
    image = new()
    digits = new()
    draw_text(digits, "123", 6, 3, UI_LIGHT, letters=DIGITS, spacing=2)
    # Fatten strokes one pixel to the right for 1x legibility.
    for y in range(ICON):
        for x in range(ICON - 1, -1, -1):
            if digits.getpixel((x, y))[3]:
                put(image, x, y, UI_LIGHT)
                put(image, x + 1, y, UI_LIGHT)
    for y in (17, 22, 27):
        rect(image, 4, y, 6, y + 2, YELLOW)
        rect(image, 9, y, 27, y + 2, UI_LIGHT)
        hline(image, 9, 27, y + 2, UI_SHADE)
    return outline(image)


def sound_on():
    image = new()
    speaker(image)
    image = outline(image)
    for radius, colour in ((6, UI_LIGHT), (11, UI_LIGHT)):
        for step in range(-40, 41):
            angle = math.radians(step * 1.2)
            for thickness in (0, 1):
                x = 15 + (radius + thickness) * math.cos(angle)
                y = 15.5 + (radius + thickness) * math.sin(angle)
                put(image, round(x), round(y), colour)
    return outline(image)


def sound_off():
    image = new()
    speaker(image)
    line(image, (19, 10), (28, 21), RED_LIGHT, 3)
    line(image, (28, 10), (19, 21), RED_LIGHT, 3)
    return outline(image)


# ---------------------------------------------------------------------------
# Frame pieces (9-slice)
# ---------------------------------------------------------------------------

FRAME_DARK = rgb("#3a2414")
FRAME_MID = rgb("#5e3a20")
FRAME_LIGHT = rgb("#8a5a32")
FRAME_HIGHLIGHT = rgb("#b07a44")
PANEL_FILL = rgb("#22160f")


# ---------------------------------------------------------------------------
# Stage HUD icons (roguelike info bar and its controls)
# ---------------------------------------------------------------------------

def tiny_wizard(image, x, y, robe=ROBE, robe_light=ROBE_LIGHT):
    """A 7 px wide hooded figure whose hood tip is at (x + 3, y)."""
    polygon(image, [(x + 3, y), (x + 4, y), (x + 7, y + 11), (x, y + 11)], robe)
    rect(image, x + 2, y + 2, x + 5, y + 5, robe_light)
    rect(image, x + 3, y + 3, x + 4, y + 4, SKIN)


def hud_troop():
    """Three hooded wizards side by side: the troop."""
    image = new()
    tiny_wizard(image, 2, 12, rgb("#4a1a5e"), ROBE)
    tiny_wizard(image, 22, 12, rgb("#4a1a5e"), ROBE)
    tiny_wizard(image, 12, 8)
    rect(image, 1, 24, 30, 25, EARTH_BASE)
    return outline(image)


def hud_out():
    """A wizard walking towards an arrow: lemmings still in the stage."""
    image = new()
    tiny_wizard(image, 3, 10)
    rect(image, 14, 14, 23, 17, UI_LIGHT)
    hline(image, 14, 23, 17, UI_SHADE)
    polygon(image, [(23, 9), (30, 15), (30, 16), (23, 22)], UI_LIGHT)
    rect(image, 1, 22, 13, 23, EARTH_BASE)
    return outline(image)


def hud_saved():
    """The green exit door with a check mark over it."""
    image = new()
    arched_door(image, 6, 25, 6, 29, WOOD, WOOD_LIGHT, EXIT_GREEN)
    line(image, (10, 17), (14, 22), EXIT_GREEN_LIGHT, 3)
    line(image, (14, 22), (22, 11), EXIT_GREEN_LIGHT, 3)
    return outline(image)


def hud_lost():
    """A skull: lemmings that did not make it."""
    image = new()
    disc(image, 15.5, 13, 10, CREAM)
    rect(image, 10, 20, 21, 26, CREAM)
    for y in range(32):
        for x in range(32):
            if image.getpixel((x, y)) == CREAM and (x - 15.5) + (y - 13) > 12:
                put(image, x, y, CREAM_DARK)
    for cx in (11, 20):
        disc(image, cx, 14, 3, OUTLINE)
    polygon(image, [(15, 18), (16, 18), (17, 21), (14, 21)], OUTLINE)
    for x in (12, 15, 18):
        vline(image, x, 24, 26, OUTLINE)
    return outline(image)


def hud_clock():
    """An alarm clock: brass bells and feet, a cream face, two hands."""
    image = new()
    for cx in (7, 24):
        disc(image, cx, 6, 4, YELLOW)
        put(image, cx - 1, 4, YELLOW_LIGHT)
    line(image, (9, 27), (6, 30), METAL_DARK, 2)
    line(image, (22, 27), (25, 30), METAL_DARK, 2)
    disc(image, 15.5, 17, 12, ORANGE)
    disc(image, 15.5, 17, 10, CREAM)
    for y in range(32):
        for x in range(32):
            if image.getpixel((x, y)) == CREAM and math.hypot(x - 15.5, y - 17) > 8.5 and x + y > 33:
                put(image, x, y, CREAM_DARK)
    for angle in range(0, 360, 90):
        x = 15.5 + 8 * math.cos(math.radians(angle))
        y = 17 + 8 * math.sin(math.radians(angle))
        put(image, int(round(x)), int(round(y)), LEATHER)
    line(image, (15, 17), (15, 10), OUTLINE, 2)
    line(image, (15, 17), (21, 17), RED, 2)
    disc(image, 15.5, 17, 1, OUTLINE)
    return outline(image)


def hud_coin():
    """A gold coin, slightly turned, with a stamped star."""
    image = new()
    for y in range(32):
        for x in range(32):
            dx, dy = (x + 0.5 - 16) / 12, (y + 0.5 - 16) / 13
            if dx * dx + dy * dy <= 1.0:
                put(image, x, y, rgb("#b07a10"))
            dx = (x + 0.5 - 15) / 11
            if dx * dx + dy * dy <= 0.8:
                put(image, x, y, YELLOW)
    for y in range(32):
        for x in range(32):
            if image.getpixel((x, y)) == YELLOW and (x - 15) + (y - 16) < -9:
                put(image, x, y, YELLOW_LIGHT)
    star = []
    for index in range(10):
        radius = 6 if index % 2 == 0 else 2.6
        angle = math.radians(-90 + index * 36)
        star.append((15 + radius * math.cos(angle), 16 + radius * math.sin(angle)))
    polygon(image, star, rgb("#c99216"))
    return outline(image)


def hud_rescue():
    """A phoenix feather: red at the base, flaming orange and yellow at the tip."""
    image = new()
    for t in range(3, 24):
        x = 6 + 18 * t / 25
        y = 29 - 25 * t / 25
        half = 5 * math.sin(math.pi * (t - 1) / 24)
        colour = RED if t < 10 else (ORANGE if t < 17 else YELLOW)
        for side in (-1, 1):
            for step in range(1, int(half) + 2):
                put(image, int(round(x + side * step * 0.8)), int(round(y + side * step * 0.6)), colour)
                put(image, int(round(x + side * step * 0.8)) + 1, int(round(y + side * step * 0.6)), colour)
    line(image, (6, 29), (24, 4), LEATHER, 1)
    polygon(image, [(22, 6), (27, 1), (25, 7)], YELLOW_LIGHT)
    return outline(image)


def sacrifice():
    """A ceremonial dagger, blade down, violet grip and a gem in the guard:
    the sacrifice. Not a figure, so it is not mistaken for a character's
    own ability."""
    image = new()
    # Blade: a long tapering triangle with a light edge and a central ridge.
    polygon(image, [(13, 14), (19, 14), (16, 31)], METAL)
    line(image, (13, 14), (16, 30), METAL_LIGHT, 1)
    line(image, (16, 15), (16, 28), METAL_SHINE, 1)
    line(image, (19, 14), (16, 30), METAL_DARK, 1)
    # Guard: a curved bar with a red gem.
    rect(image, 7, 11, 25, 13, YELLOW)
    hline(image, 7, 25, 11, YELLOW_LIGHT)
    put(image, 6, 10, YELLOW)
    put(image, 26, 10, YELLOW)
    disc(image, 16, 12, 2, RED)
    put(image, 15, 11, RED_LIGHT)
    # Grip wrapped in violet, and a round pommel.
    rect(image, 14, 3, 18, 10, ROBE)
    for y in (4, 6, 8):
        hline(image, 14, 18, y, ROBE_LIGHT)
    disc(image, 16, 2, 2, YELLOW)
    return outline(image)


def give_up():
    """A white flag on a pole: end the stage now."""
    image = new()
    rect(image, 6, 3, 8, 30, WOOD)
    vline(image, 6, 3, 30, WOOD_LIGHT)
    disc(image, 7, 3, 2, YELLOW)
    for x in range(9, 28):
        wave = int(round(2 * math.sin((x - 9) / 3.2)))
        rect(image, x, 5 + wave, x, 17 + wave, rgb("#f6f6f0"))
        put(image, x, 17 + wave, rgb("#c8c8c0"))
        if (x - 9) % 7 in (5, 6):
            put(image, x, 11 + wave, rgb("#d8d8d0"))
    return outline(image)


def settings():
    """A gear."""
    image = new()
    cx, cy = 15.5, 15.5
    for y in range(32):
        for x in range(32):
            dist = math.hypot(x - cx, y - cy)
            angle = math.degrees(math.atan2(y - cy, x - cx)) % 45
            radius = 13 if angle < 22 else 10
            if dist <= radius:
                put(image, x, y, METAL if x + y < 32 else METAL_DARK)
            if dist <= 8 and x + y < 30:
                put(image, x, y, METAL_LIGHT)
            if dist <= 4:
                put(image, x, y, CLEAR)
    return outline(image)


# ---------------------------------------------------------------------------
# Theme pieces: buttons, check box, slider (UiStyle.build_theme)
# ---------------------------------------------------------------------------

BUTTON_SIZE = 24
BUTTON_MARGIN = 6

# face, light edge, dark edge, rivet: one tuple per state.
BUTTON_STATES = {
    "button": (rgb("#6e4a2c"), rgb("#9c6d40"), rgb("#3e2616"), rgb("#c9a25a")),
    "button_hover": (rgb("#8a5e38"), rgb("#c48b52"), rgb("#4e3020"), YELLOW_LIGHT),
    "button_pressed": (rgb("#4e3320"), rgb("#3a2414"), rgb("#7a5232"), rgb("#a8873e")),
    "button_disabled": (rgb("#4a4642"), rgb("#5e5a55"), rgb("#2e2b28"), rgb("#6a665f")),
    "button_primary": (rgb("#2f7a35"), rgb("#5fbf55"), rgb("#174a1d"), YELLOW),
    "button_primary_hover": (rgb("#3a9442"), rgb("#86de6e"), rgb("#1d5a24"), YELLOW_LIGHT),
    "button_primary_pressed": (rgb("#225a27"), rgb("#174a1d"), rgb("#3f8a45"), rgb("#c99a20")),
}


def theme_button(state):
    """A plank button: near-black outline, a light bevel on top and left and
    a dark one on the bottom and right (swapped when pressed), a wood face
    with two faint grain lines and brass rivets in the corners. Corners
    only carry detail, so a 9-slice stretch (margin 6) keeps it crisp."""
    face, light, dark, rivet = BUTTON_STATES[state]
    size = BUTTON_SIZE
    image = new(size, size)
    rect(image, 0, 0, size - 1, size - 1, OUTLINE)
    rect(image, 1, 1, size - 2, size - 2, face)
    hline(image, 1, size - 2, 1, light)
    vline(image, 1, 1, size - 2, light)
    hline(image, 1, size - 2, size - 2, dark)
    vline(image, size - 2, 1, size - 2, dark)
    hline(image, 2, size - 3, size - 3, dark)
    # Grain: two darker rows across the middle, stretched along with it.
    grain = tuple(max(c - 14, 0) for c in face[:3]) + (255,)
    hline(image, 6, size - 7, 9, grain)
    hline(image, 6, size - 7, 14, grain)
    for x, y in ((3, 3), (size - 4, 3), (3, size - 5), (size - 4, size - 5)):
        put(image, x, y, rivet)
    return image


def theme_check(checked):
    """A small wooden box with a gold check mark when on."""
    image = new(20, 20)
    rect(image, 1, 1, 18, 18, OUTLINE)
    rect(image, 2, 2, 17, 17, rgb("#2b1a10"))
    hline(image, 2, 17, 17, rgb("#6b4a30"))
    vline(image, 17, 2, 17, rgb("#6b4a30"))
    if checked:
        line(image, (5, 10), (8, 14), YELLOW, 3)
        line(image, (8, 14), (15, 5), YELLOW, 3)
        put(image, 14, 5, YELLOW_LIGHT)
    return image


def theme_slider_track():
    """The groove a slider runs in: 12x8, 9-slice margins 4."""
    image = new(12, 8)
    rect(image, 0, 0, 11, 7, OUTLINE)
    rect(image, 1, 1, 10, 6, rgb("#2b1a10"))
    hline(image, 1, 10, 1, rgb("#1a0f0a"))
    hline(image, 1, 10, 6, rgb("#5a3c24"))
    return image


def theme_slider_fill():
    """The filled part of the groove, left of the knob: gold."""
    image = new(12, 8)
    rect(image, 0, 0, 11, 7, OUTLINE)
    rect(image, 1, 1, 10, 6, rgb("#c99216"))
    hline(image, 1, 10, 2, YELLOW)
    hline(image, 1, 10, 6, rgb("#8a6210"))
    return image


def theme_slider_knob(highlight):
    """A round brass knob, brighter under the mouse."""
    image = new(20, 20)
    disc(image, 9.5, 9.5, 8, rgb("#8a6210"))
    disc(image, 9.5, 9.0, 6.5, YELLOW_LIGHT if highlight else YELLOW)
    disc(image, 7.5, 7.0, 2, rgb("#fffbe0"))
    return outline(image)


def dev():
    """A wrench crossed over a screwdriver: the developer tools."""
    image = new()
    line(image, (7, 25), (22, 10), METAL, 4)
    line(image, (8, 25), (22, 11), METAL_LIGHT, 1)
    disc(image, 23, 8, 5, METAL)
    disc(image, 25, 6, 2.5, CLEAR)
    rect(image, 25, 2, 29, 6, CLEAR)
    disc(image, 6, 26, 3, METAL)
    line(image, (8, 8), (19, 19), YELLOW, 3)
    line(image, (19, 19), (26, 26), METAL_LIGHT, 2)
    rect(image, 5, 5, 9, 9, RED)
    return outline(image)


def display():
    """A monitor on a stand: the display settings."""
    image = new()
    rect(image, 3, 5, 28, 22, METAL_DARK)
    rect(image, 5, 7, 26, 20, BLUE_DARK)
    polygon(image, [(6, 8), (14, 8), (6, 15)], BLUE)
    put(image, 7, 9, BLUE_SHINE)
    rect(image, 14, 23, 17, 26, METAL_DARK)
    rect(image, 9, 27, 22, 28, METAL)
    return outline(image)


def hud_goal():
    """A target, red and cream rings with a gold centre: the share of the
    lemmings a level asks to save."""
    image = new()
    for radius, colour in ((13, RED), (10.5, CREAM), (8, RED), (5.5, CREAM), (3, YELLOW)):
        disc(image, 15.5, 15.5, radius, colour)
    for y in range(32):
        for x in range(32):
            if image.getpixel((x, y)) == RED and x + y > 36:
                put(image, x, y, RED_DARK)
    return outline(image)


THEME_PIECES = {
    **{name: (lambda state=name: theme_button(state)) for name in BUTTON_STATES},
    "check_on": lambda: theme_check(True),
    "check_off": lambda: theme_check(False),
    "slider_track": theme_slider_track,
    "slider_fill": theme_slider_fill,
    "slider_knob": lambda: theme_slider_knob(False),
    "slider_knob_hover": lambda: theme_slider_knob(True),
}


def bevel_box(size, bands, fill):
    """Concentric square bands from the outside in, each band given as
    (thickness, top_left_colour, bottom_right_colour). Bands are uniform
    along their length so they stretch cleanly as a 9-slice edge."""
    image = Image.new("RGBA", (size, size), fill)
    inset = 0
    for thickness, light, dark in bands:
        for _ in range(thickness):
            last = size - 1 - inset
            for i in range(inset, last + 1):
                image.putpixel((i, inset), light)
                image.putpixel((inset, i), light)
                image.putpixel((i, last), dark)
                image.putpixel((last, i), dark)
            # The two off corners split the difference.
            image.putpixel((last, inset), dark)
            image.putpixel((inset, last), dark)
            inset += 1
    return image


def panel():
    """Dark wooden frame: outline, raised two tone bevel, wood, a sunken
    lip and the flat dark inside. Rivets in the corners only."""
    image = bevel_box(PANEL_SIZE, [
        (1, OUTLINE, OUTLINE),
        (1, FRAME_HIGHLIGHT, FRAME_DARK),
        (4, FRAME_LIGHT, FRAME_MID),
        (1, FRAME_DARK, FRAME_HIGHLIGHT),
        (1, OUTLINE, OUTLINE),
    ], PANEL_FILL)
    # Rivets sit inside the corner squares, which a 9-slice never stretches.
    for corner_x, corner_y in ((3, 3), (PANEL_SIZE - 5, 3), (3, PANEL_SIZE - 5), (PANEL_SIZE - 5, PANEL_SIZE - 5)):
        rect(image, corner_x, corner_y, corner_x + 1, corner_y + 1, METAL_DARK)
        put(image, corner_x, corner_y, METAL_LIGHT)
    return image


SLOT_STATES = {
    # name: (outer ring light, outer ring dark, inner fill, inner shade line)
    "slot": (rgb("#6b4a30"), rgb("#2b1a10"), rgb("#3a2a20"), rgb("#2a1c14")),
    "slot_hover": (rgb("#d4a066"), rgb("#6a4428"), rgb("#5e4632"), rgb("#44321f")),
    "slot_selected": (YELLOW_LIGHT, rgb("#c08a18"), rgb("#5a4426"), rgb("#3e2e1a")),
    "slot_disabled": (rgb("#6a6a6a"), rgb("#353535"), rgb("#2c2c2c"), rgb("#222222")),
}


def slot(state):
    light, dark, fill, shade = SLOT_STATES[state]
    bands = [
        (1, OUTLINE, OUTLINE),
        (2, light, dark),
        (1, shade, fill),   # sunken lip: dark on top left, so the inside looks recessed
    ]
    if state == "slot_selected":
        bands = [(1, OUTLINE, OUTLINE), (2, light, dark), (1, rgb("#7a5a14"), fill)]
    return bevel_box(SLOT_SIZE, bands, fill)


# ---------------------------------------------------------------------------
# Output
# ---------------------------------------------------------------------------

TOOL_ICONS = {
    "digger": icon_digger,
    "builder": icon_builder,
    "ladder_vertical": icon_ladder_vertical,
    "bridge": icon_bridge,
    "floater": icon_floater,
    "climber": icon_climber,
    "block": icon_block,
    "dynamite": icon_dynamite,
    "tnt": icon_tnt,
    "basher": icon_basher,
    "miner": icon_miner,
}

EDITOR_ICONS = {
    "editor_earth": editor_earth,
    "editor_concrete": editor_concrete,
    "editor_ladder": editor_ladder,
    "editor_brick": editor_brick,
    "editor_eraser": editor_eraser,
    "editor_entrance": editor_entrance,
    "editor_exit": editor_exit,
    "editor_play": editor_play,
    "editor_pause": editor_pause,
    "editor_restart": editor_restart,
    "editor_menu": editor_menu,
    "editor_counts": editor_counts,
    "sound_on": sound_on,
    "sound_off": sound_off,
    "hud_troop": hud_troop,
    "hud_out": hud_out,
    "hud_saved": hud_saved,
    "hud_lost": hud_lost,
    "hud_clock": hud_clock,
    "hud_coin": hud_coin,
    "hud_rescue": hud_rescue,
    "sacrifice": sacrifice,
    "give_up": give_up,
    "settings": settings,
    "dev": dev,
    "display": display,
    "hud_goal": hud_goal,
}


def nine_slice(image, margin, width, height):
    """Stretches like Godot's StyleBoxTexture (axis stretch mode STRETCH)."""
    out = Image.new("RGBA", (width, height), CLEAR)
    w, h = image.size
    xs = [(0, margin, 0, margin), (margin, w - margin, margin, width - margin), (w - margin, w, width - margin, width)]
    ys = [(0, margin, 0, margin), (margin, h - margin, margin, height - margin), (h - margin, h, height - margin, height)]
    for sx0, sx1, dx0, dx1 in xs:
        for sy0, sy1, dy0, dy1 in ys:
            piece = image.crop((sx0, sy0, sx1, sy1)).resize((dx1 - dx0, dy1 - dy0), Image.NEAREST)
            out.paste(piece, (dx0, dy0))
    return out


def preview(icons, frames, path):
    names = list(icons)
    columns = 7
    rows = math.ceil(len(names) / columns)
    pad = 6
    sheets = []
    for background in (rgb("#15131a"), rgb("#d9d6cc")):
        for scale in (1, 3):
            cell = ICON * scale + pad * 2
            sheet = Image.new("RGBA", (cell * columns, cell * rows), background)
            for index, name in enumerate(names):
                icon = icons[name].resize((ICON * scale, ICON * scale), Image.NEAREST)
                x = (index % columns) * cell + pad
                y = (index // columns) * cell + pad
                sheet.alpha_composite(icon, (x, y))
            sheets.append(sheet)
        # Toolbar mockup: panel stretched with slots holding icons, at 2x.
        bar = Image.new("RGBA", (12 + 6 * 46, 64), background)
        bar.alpha_composite(nine_slice(frames["panel"], PANEL_MARGIN, bar.width - 4, 60), (2, 2))
        states = ["slot", "slot_hover", "slot_selected", "slot_disabled", "slot", "slot"]
        sample = ["digger", "builder", "miner", "basher", "dynamite", "floater"]
        for i, (state, name) in enumerate(zip(states, sample)):
            sx = 12 + i * 46
            bar.alpha_composite(frames[state], (sx, 12))
            icon = icons[name]
            if state == "slot_disabled":
                grey = icon.convert("LA").convert("RGBA")
                grey.putalpha(icon.getchannel("A").point(lambda a: a * 6 // 10))
                icon = grey
            bar.alpha_composite(icon, (sx + 4, 16))
        sheets.append(bar)
        sheets.append(bar.resize((bar.width * 3, bar.height * 3), Image.NEAREST))
        raw = Image.new("RGBA", (PANEL_SIZE + 4 * (SLOT_SIZE + 4) + 4, SLOT_SIZE), background)
        raw.alpha_composite(frames["panel"], (0, 0))
        for i, state in enumerate(["slot", "slot_hover", "slot_selected", "slot_disabled"]):
            raw.alpha_composite(frames[state], (PANEL_SIZE + 4 + i * (SLOT_SIZE + 4), 0))
        sheets.append(raw.resize((raw.width * 3, raw.height * 3), Image.NEAREST))
    width = max(s.width for s in sheets)
    height = sum(s.height + 8 for s in sheets)
    out = Image.new("RGBA", (width, height), rgb("#808080"))
    y = 0
    for s in sheets:
        out.alpha_composite(s, (0, y))
        y += s.height + 8
    out.save(path)


def main():
    os.makedirs(ICON_DIR, exist_ok=True)
    icons = {}
    for name, build in {**TOOL_ICONS, **EDITOR_ICONS}.items():
        image = build()
        assert image.size == (ICON, ICON), name
        image.save(os.path.join(ICON_DIR, name + ".png"))
        icons[name] = image
    frames = {"panel": panel()}
    for state in SLOT_STATES:
        frames[state] = slot(state)
    for name, build in THEME_PIECES.items():
        frames[name] = build()
    for name, image in frames.items():
        image.save(os.path.join(OUT_DIR, name + ".png"))
    print("ui art written to", os.path.normpath(OUT_DIR))
    if len(sys.argv) > 1:
        preview(icons, frames, sys.argv[1])
        print("preview written to", sys.argv[1])


if __name__ == "__main__":
    main()
