"""Draws the reward card art for the roguelike mode: one card frame per card
family (normal and hover), and the 64x64 illustrations that sit in the
card's art window.

    python tools/build_card_art.py [preview.png]
    godot --headless --path . --import

Outputs, all in assets/sprites/ui/cards/:

  card_<family>.png        120x168 card background (tool, recruit, relic,
  card_<family>_hover.png  rescue), plus a glowing gold-rimmed variant for
                           hover / selected.
  relic_<relic id>.png     64x64 illustration per relic (ids from
                           modes/roguelike/scripts/run/relics.gd).
  character_<id>.png       64x64 portrait per character (ids and colours from
                           modes/roguelike/scripts/characters/character_catalog.gd).
  rescue_phoenix.png       64x64 phoenix feather.

Tool cards (charges, new tool) put the 32x32 tool icon scaled 2x in the art
window, so they need no illustration of their own.

Same rules as tools/build_ui_art.py, whose palette and drawing helpers this
script reuses: pixel by pixel at 1x, fixed random seeds, flat fills with a
one pixel near-black outline. The banner and the text panel are flat dark
fills so cream text reads on them; the layout rectangles below are what the
game code lays text and art on, and are documented in docs/art_pipeline.md.

Passing a path writes a preview sheet of every frame with a sample
illustration and sample text, and every illustration, at 1x and 2x.
"""

import colorsys
import math
import os
import random
import sys

from PIL import Image, ImageDraw, ImageFont

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import build_ui_art as ui  # noqa: E402
from build_ui_art import (  # noqa: E402
    CLEAR, OUTLINE, rgb, put, rect, hline, vline, polygon, line, disc, outline,
    WOOD_DARK, WOOD, WOOD_LIGHT, NAIL, METAL_DARK, METAL, METAL_LIGHT, METAL_SHINE,
    ROBE, ROBE_LIGHT, RED_DARK, RED, RED_LIGHT, CREAM, CREAM_DARK, YELLOW,
    YELLOW_LIGHT, ORANGE, LEATHER_DARK, LEATHER, BLUE_DARK, BLUE, BLUE_LIGHT,
    BLUE_SHINE, GRASS, GRASS_LIGHT,
    FRAME_DARK, FRAME_MID, FRAME_LIGHT, FRAME_HIGHLIGHT, PANEL_FILL,
)

CARD_W = 120
CARD_H = 168
ART = 64

# Layout rectangles (x, y, width, height), in card pixels at 1x. The frame
# drawn around each one sits outside the rectangle, so everything inside is
# free for text or art.
BANNER = (12, 11, 96, 15)
WINDOW = (28, 34, ART, ART)
TEXT_PANEL = (12, 108, 96, 50)

OUT_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "sprites", "ui", "cards")
ICON_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "sprites", "ui", "icons")

BRASS_SHINE = rgb("#fff0b0")
BRASS_LIGHT = rgb("#f0c860")
BRASS = rgb("#c8963c")
BRASS_DARK = rgb("#7e5420")
GOLD_GLOW = rgb("#fff6c8")
FACE_DARK = rgb("#140a18")
WHITE = rgb("#fffaf0")


def mix(a, b, t):
    return tuple(round(a[i] + (b[i] - a[i]) * t) for i in range(3)) + (255,)


def new(width=ART, height=ART):
    return Image.new("RGBA", (width, height), CLEAR)


def rect_xywh(image, box, colour):
    x, y, w, h = box
    rect(image, x, y, x + w - 1, y + h - 1, colour)


def ring(image, x0, y0, x1, y1, light, dark):
    """One pixel rectangular ring, light on top and left, dark on bottom and
    right; the two off corners take the dark colour."""
    hline(image, x0, x1, y0, light)
    vline(image, x0, y0, y1, light)
    hline(image, x0, x1, y1, dark)
    vline(image, x1, y0, y1, dark)
    put(image, x1, y0, dark)
    put(image, x0, y1, dark)


def ring_around(image, box, distance, light, dark):
    x, y, w, h = box
    ring(image, x - distance, y - distance, x + w - 1 + distance, y + h - 1 + distance, light, dark)


def card_ring(image, inset, light, dark):
    ring(image, inset, inset, CARD_W - 1 - inset, CARD_H - 1 - inset, light, dark)


def sparkle(image, x, y, size=2, core=WHITE, arm=YELLOW_LIGHT):
    """Four pointed glint, drawn after outlining so it reads as light."""
    put(image, x, y, core)
    for step in range(1, size + 1):
        colour = arm if step < size else YELLOW
        for dx, dy in ((step, 0), (-step, 0), (0, step), (0, -step)):
            put(image, x + dx, y + dy, colour)


# ---------------------------------------------------------------------------
# Card families
# ---------------------------------------------------------------------------
#
# Every family shares one structure (outer border, title plaque, art window,
# text panel) and differs in palette, body texture and corner ornaments.

FAMILIES = {
    "tool": {
        "bevel": (FRAME_HIGHLIGHT, FRAME_DARK),
        "band": [FRAME_HIGHLIGHT, FRAME_LIGHT, FRAME_MID, FRAME_MID],
        "trim": (BRASS_LIGHT, BRASS_DARK),
        "body": (FRAME_MID, FRAME_DARK, rgb("#4a2e18")),
        "banner": rgb("#2e1c10"),
        "text": PANEL_FILL,
        "window": (rgb("#1c120c"), rgb("#3a2618")),
        "gem": (BLUE_SHINE, BLUE_LIGHT, BLUE, BLUE_DARK),
    },
    "recruit": {
        "bevel": (rgb("#a05cc8"), rgb("#24093a")),
        "band": [rgb("#8e46b4"), ROBE_LIGHT, ROBE, ROBE],
        "trim": (YELLOW, rgb("#9a6a10")),
        "body": (rgb("#4a1c64"), rgb("#3a1250"), rgb("#2e0c42")),
        "banner": rgb("#2a0c3e"),
        "text": rgb("#1e0a2c"),
        "window": (rgb("#160822"), rgb("#36164e")),
        "gem": (YELLOW_LIGHT, YELLOW, rgb("#d09a18"), rgb("#8a5a10")),
    },
    "relic": {
        "bevel": (rgb("#7a788a"), rgb("#16141c")),
        "band": [rgb("#6a6878"), rgb("#55535f"), rgb("#45434f"), rgb("#3a3844")],
        "trim": (BRASS_LIGHT, BRASS_DARK),
        "body": (rgb("#34323e"), rgb("#2a2832"), rgb("#1e1c24")),
        "banner": rgb("#1c1a24"),
        "text": rgb("#15131b"),
        "window": (rgb("#0e0c14"), rgb("#262838")),
        "gem": (rgb("#ffc2c2"), RED_LIGHT, RED, RED_DARK),
    },
    "rescue": {
        "bevel": (RED_LIGHT, rgb("#3e0a0a")),
        "band": [rgb("#f08a3a"), ORANGE, rgb("#c4502a"), RED],
        "trim": (YELLOW_LIGHT, rgb("#b06010")),
        "body": (rgb("#6a1a14"), rgb("#521210"), rgb("#3e0c0c")),
        "banner": rgb("#360c0c"),
        "text": rgb("#280808"),
        "window": (rgb("#1e0606"), rgb("#4a1610")),
        "gem": (YELLOW_LIGHT, YELLOW, ORANGE, RED_DARK),
    },
}


def body_tool(image, palette, rng):
    """Horizontal dark planks with nail heads, the toolbar's wood."""
    light, base, dark = palette["body"]
    rect(image, 0, 0, CARD_W - 1, CARD_H - 1, base)
    for y in range(0, CARD_H, 12):
        hline(image, 0, CARD_W - 1, y, OUTLINE)
        hline(image, 0, CARD_W - 1, y + 1, light)
        # Grain streaks.
        for _ in range(6):
            gx, gy = rng.randint(0, CARD_W - 12), y + rng.randint(3, 10)
            hline(image, gx, gx + rng.randint(4, 10), gy, dark)
        # Plank joints, staggered row by row.
        joint = 30 + (y // 12 % 2) * 40
        vline(image, joint, y + 1, y + 11, OUTLINE)
        put(image, joint - 3, y + 6, NAIL)
        put(image, joint + 3, y + 6, NAIL)


def body_recruit(image, palette, rng):
    """Woven cloth: a fine diagonal twill in three close purples."""
    light, base, dark = palette["body"]
    for y in range(CARD_H):
        for x in range(CARD_W):
            k = (x + y) % 4
            colour = light if k == 0 else dark if k == 2 else base
            if (x - y) % 8 == 0:
                colour = dark
            image.putpixel((x, y), colour)


def body_relic(image, palette, rng):
    """Dark stone blocks with offset seams and chipped highlights."""
    light, base, dark = palette["body"]
    rect(image, 0, 0, CARD_W - 1, CARD_H - 1, base)
    for _ in range(260):
        put(image, rng.randint(0, CARD_W - 1), rng.randint(0, CARD_H - 1), rng.choice([light, dark]))
    for row, y in enumerate(range(0, CARD_H, 10)):
        hline(image, 0, CARD_W - 1, y, dark)
        hline(image, 0, CARD_W - 1, y + 1, light)
        offset = 0 if row % 2 == 0 else 12
        for x in range(offset, CARD_W, 24):
            vline(image, x, y, y + 9, dark)
            vline(image, x + 1, y + 1, y + 9, light)


def body_rescue(image, palette, rng):
    """Deep red that warms toward the bottom, with rising embers."""
    light, base, dark = palette["body"]
    for y in range(CARD_H):
        t = y / (CARD_H - 1)
        colour = mix(dark, light, t)
        hline(image, 0, CARD_W - 1, y, colour)
    # Ordered dither between bands so the gradient has no hard steps.
    for y in range(CARD_H):
        for x in range(CARD_W):
            if (x + 2 * y) % 5 == 0:
                put(image, x, y, mix(image.getpixel((x, y)), dark, 0.35))
    for _ in range(70):
        x, y = rng.randint(0, CARD_W - 1), rng.randint(0, CARD_H - 1)
        colour = rng.choice([ORANGE, rgb("#c4502a"), rgb("#c4502a"), YELLOW])
        put(image, x, y, colour)
        if colour == YELLOW:
            put(image, x, y + 1, ORANGE)


BODIES = {"tool": body_tool, "recruit": body_recruit, "relic": body_relic, "rescue": body_rescue}


def outlined_shape(size, draw):
    """Draws flat fills on a small layer, outlines it and returns it."""
    layer = new(size, size)
    draw(layer)
    return outline(layer)


def corner_tool(palette):
    """Brass L bracket with three rivets."""
    def draw(layer):
        for y in range(15):
            for x in range(15):
                if (y < 6 and x < 15 - y // 3) or (x < 6 and y < 15 - x // 3):
                    put(layer, x + 1, y + 1, BRASS)
        hline(layer, 1, 14, 1, BRASS_LIGHT)
        vline(layer, 1, 1, 14, BRASS_LIGHT)
        hline(layer, 7, 13, 6, BRASS_DARK)
        vline(layer, 6, 7, 13, BRASS_DARK)
        for x, y in ((3, 3), (11, 3), (3, 11)):
            rect(layer, x, y, x + 1, y + 1, METAL_DARK)
            put(layer, x, y, METAL_SHINE)
    return outlined_shape(17, draw)


def corner_recruit(palette):
    """Gold knot: a diamond with a cross stitch and a tassel bead."""
    def draw(layer):
        cx, cy = 7, 7
        for y in range(15):
            for x in range(15):
                if abs(x - cx) + abs(y - cy) <= 6:
                    put(layer, x, y, YELLOW)
        for y in range(15):
            for x in range(15):
                d = abs(x - cx) + abs(y - cy)
                if d == 6 and (x <= cx and y <= cy):
                    put(layer, x, y, YELLOW_LIGHT)
                elif d == 6:
                    put(layer, x, y, rgb("#b07a10"))
        for i in range(-3, 4):
            put(layer, cx + i, cy + i, rgb("#9a6a10"))
            put(layer, cx + i, cy - i, rgb("#9a6a10"))
        put(layer, cx, cy, ROBE)
        disc(layer, 12.5, 12.5, 1.6, rgb("#d09a18"))
        put(layer, 12, 12, YELLOW_LIGHT)
    return outlined_shape(17, draw)


def corner_relic(palette):
    """Gold filigree: a curl springing from the corner with two tendrils
    running along the edges."""
    def draw(layer):
        # Tendrils along both edges.
        hline(layer, 2, 16, 1, BRASS)
        vline(layer, 1, 2, 16, BRASS)
        hline(layer, 2, 15, 2, BRASS_DARK)
        vline(layer, 2, 3, 15, BRASS_DARK)
        # Spiral curl.
        cx, cy = 8.0, 8.0
        for step in range(0, 120):
            t = step / 119
            angle = math.pi * 1.25 + t * 3.2 * math.pi
            r = 5.2 * (1 - t) + 0.6
            put(layer, round(cx + r * math.cos(angle)), round(cy + r * math.sin(angle)), BRASS_LIGHT)
        put(layer, 8, 8, BRASS_SHINE)
        # Leaf buds at the tendril ends.
        for x, y in ((16, 1), (1, 16)):
            rect(layer, x - 1, y - 1, x, y, BRASS_LIGHT)
    return outlined_shape(19, draw)


def corner_rescue(palette):
    """A flame tongue curling out of the corner."""
    def draw(layer):
        for y in range(17):
            for x in range(17):
                # Teardrop along the diagonal, pointing in toward the card.
                u = (x + y) / 2
                v = (x - y) / 2
                width = 5.2 * math.sin(math.pi * min(u, 15) / 15) ** 0.8
                if 0.5 < u < 15 and abs(v) <= width:
                    t = abs(v) / max(width, 0.1)
                    colour = YELLOW_LIGHT if t < 0.3 and u < 10 else YELLOW if t < 0.6 else ORANGE
                    put(layer, x, y, colour)
        # Side licks.
        polygon(layer, [(1, 9), (4, 13), (1, 15)], ORANGE)
        polygon(layer, [(9, 1), (13, 4), (15, 1)], ORANGE)
    return outlined_shape(19, draw)


CORNERS = {"tool": corner_tool, "recruit": corner_recruit, "relic": corner_relic, "rescue": corner_rescue}


def paste_corners(image, piece, offset):
    """Places the top left ornament and its three mirror images. They sit
    over the panel frames but are kept out of the flat text areas (and the
    shadow ring around them), so text never runs over an ornament."""
    w = piece.width
    layer = Image.new("RGBA", (CARD_W, CARD_H), CLEAR)
    flips = [
        (piece, (offset, offset)),
        (piece.transpose(Image.FLIP_LEFT_RIGHT), (CARD_W - offset - w, offset)),
        (piece.transpose(Image.FLIP_TOP_BOTTOM), (offset, CARD_H - offset - w)),
        (piece.transpose(Image.ROTATE_180), (CARD_W - offset - w, CARD_H - offset - w)),
    ]
    for flipped, position in flips:
        layer.alpha_composite(flipped, position)
    for x, y, width, height in (BANNER, TEXT_PANEL):
        rect(layer, x - 1, y - 1, x + width, y + height, CLEAR)
    image.alpha_composite(layer)


def band_details(image, family, palette, hover):
    """Repeating details along the border band (insets 2..5)."""
    if family == "tool":
        # Grain line through the middle of the band, rivets every 20 px.
        for x in range(4, CARD_W - 4):
            if x % 9 < 5:
                put(image, x, 4, FRAME_DARK)
                put(image, x, CARD_H - 5, FRAME_DARK)
        for y in range(4, CARD_H - 4):
            if y % 9 < 5:
                put(image, 4, y, FRAME_DARK)
                put(image, CARD_W - 5, y, FRAME_DARK)
        for y in range(28, CARD_H - 24, 20):
            for x in (3, CARD_W - 5):
                rect(image, x, y, x + 1, y + 1, BRASS_DARK)
                put(image, x, y, BRASS_LIGHT)
    elif family == "recruit":
        # Running gold stitch along the middle of the band.
        stitch = YELLOW_LIGHT if hover else rgb("#d8a830")
        for x in range(4, CARD_W - 4):
            if x % 4 < 2:
                put(image, x, 4, stitch)
                put(image, x, CARD_H - 5, stitch)
        for y in range(4, CARD_H - 4):
            if y % 4 < 2:
                put(image, 4, y, stitch)
                put(image, CARD_W - 5, y, stitch)
    elif family == "relic":
        # Stone block seams across the band.
        for x in range(14, CARD_W - 14, 16):
            vline(image, x, 2, 5, rgb("#26242e"))
            vline(image, x, CARD_H - 6, CARD_H - 3, rgb("#26242e"))
        for y in range(14, CARD_H - 14, 16):
            hline(image, 2, 5, y, rgb("#26242e"))
            hline(image, CARD_W - 6, CARD_W - 3, y, rgb("#26242e"))
    elif family == "rescue":
        # Flame flicks licking inward from the band.
        for x in range(10, CARD_W - 10, 6):
            put(image, x, 6, YELLOW)
            put(image, x + 1, 6, ORANGE)
            put(image, x, CARD_H - 7, YELLOW)
            put(image, x + 1, CARD_H - 7, ORANGE)
        for y in range(10, CARD_H - 10, 6):
            put(image, 6, y, YELLOW)
            put(image, 6, y + 1, ORANGE)
            put(image, CARD_W - 7, y, YELLOW)
            put(image, CARD_W - 7, y + 1, ORANGE)


def chamfer(image, size=3):
    """Cuts the four card corners into a short bevel and re-outlines them."""
    for cy in range(size + 1):
        for cx in range(size + 1):
            for x, y in ((cx, cy), (CARD_W - 1 - cx, cy), (cx, CARD_H - 1 - cy), (CARD_W - 1 - cx, CARD_H - 1 - cy)):
                if cx + cy < size:
                    image.putpixel((x, y), CLEAR)
                elif cx + cy == size:
                    image.putpixel((x, y), image.getpixel((0, CARD_H // 2)))


def gem(image, cx, cy, colours):
    shine, light, base, dark = colours
    layer = new(CARD_W, CARD_H)
    for y in range(cy - 4, cy + 5):
        for x in range(cx - 4, cx + 5):
            d = abs(x - cx) + abs(y - cy)
            if d <= 4:
                colour = base
                if d == 4:
                    colour = light if (x <= cx and y <= cy) else dark
                put(layer, x, y, colour)
    put(layer, cx - 1, cy - 1, shine)
    put(layer, cx, cy - 2, light)
    outline(layer)
    # Brass setting behind the stone.
    setting = new(CARD_W, CARD_H)
    rect(setting, cx - 6, cy - 2, cx + 6, cy + 2, BRASS)
    hline(setting, cx - 6, cx + 6, cy - 2, BRASS_LIGHT)
    hline(setting, cx - 6, cx + 6, cy + 2, BRASS_DARK)
    outline(setting)
    image.alpha_composite(setting)
    image.alpha_composite(layer)


def plaque(image, box, fill, trim, hover):
    """Flat title plaque with a trim line, an outline and little end caps."""
    x, y, w, h = box
    light, dark = trim
    if hover:
        light, dark = YELLOW_LIGHT, YELLOW
    # End caps sticking out on both sides, as if the plaque were pinned on.
    for cap_x in (x - 5, x + w + 1):
        rect(image, cap_x - 1, y + 2, cap_x + 4, y + h - 3, OUTLINE)
        rect(image, cap_x, y + 3, cap_x + 3, y + h - 4, BRASS)
        hline(image, cap_x, cap_x + 3, y + 3, BRASS_LIGHT)
        hline(image, cap_x, cap_x + 3, y + h - 4, BRASS_DARK)
    rect_xywh(image, box, fill)
    ring_around(image, box, 1, light, dark)
    ring_around(image, box, 2, OUTLINE, OUTLINE)


def art_window(image, box, palette, hover):
    """Recessed square window: outline, trim, outline, inner shadow, and a
    soft radial backdrop for the illustration."""
    x, y, w, h = box
    edge, centre = palette["window"]
    cx, cy = x + w / 2, y + h / 2 - 4
    radius = w * 0.62
    for py in range(y, y + h):
        for px in range(x, x + w):
            d = math.hypot(px + 0.5 - cx, py + 0.5 - cy) / radius
            # Four flat steps with a checker dither at each step edge.
            level = min(3, int(d * 4 + (0.25 if (px + py) % 2 else 0)))
            put(image, px, py, mix(centre, edge, level / 3))
    light, dark = palette["trim"]
    if hover:
        light, dark = YELLOW_LIGHT, YELLOW
    ring_around(image, box, 1, mix(edge, OUTLINE, 0.5), mix(centre, edge, 0.3))
    ring_around(image, box, 2, OUTLINE, OUTLINE)
    ring_around(image, box, 3, light, dark)
    ring_around(image, box, 4, OUTLINE, OUTLINE)
    # Corner studs on the window frame.
    for sx, sy in ((x - 4, y - 4), (x + w + 1, y - 4), (x - 4, y + h + 1), (x + w + 1, y + h + 1)):
        rect(image, sx - 1, sy - 1, sx + 4, sy + 4, OUTLINE)
        rect(image, sx, sy, sx + 3, sy + 3, light)
        rect(image, sx + 1, sy + 1, sx + 3, sy + 3, dark)
        put(image, sx + 1, sy + 1, BRASS_SHINE if not hover else WHITE)


def text_panel(image, box, palette, hover):
    x, y, w, h = box
    rect_xywh(image, box, palette["text"])
    light, dark = palette["trim"]
    if hover:
        light, dark = YELLOW_LIGHT, YELLOW
    ring_around(image, box, 1, mix(palette["text"], OUTLINE, 0.6), mix(palette["text"], OUTLINE, 0.6))
    ring_around(image, box, 2, light, dark)
    ring_around(image, box, 3, OUTLINE, OUTLINE)


def card(family, hover=False):
    palette = FAMILIES[family]
    rng = random.Random(sum(map(ord, family)))
    image = Image.new("RGBA", (CARD_W, CARD_H), CLEAR)
    BODIES[family](image, palette, rng)

    # Outer border: outline, bevel, four band rows, trim, outline.
    bevel_light, bevel_dark = palette["bevel"]
    trim_light, trim_dark = palette["trim"]
    band = palette["band"]
    if hover:
        rings = [(GOLD_GLOW, GOLD_GLOW), (YELLOW_LIGHT, YELLOW), (YELLOW, ORANGE)]
        band = band[1:]
        trim_light, trim_dark = YELLOW_LIGHT, YELLOW
    else:
        rings = [(OUTLINE, OUTLINE), (bevel_light, bevel_dark)]
    for inset, (light, dark) in enumerate(rings):
        card_ring(image, inset, light, dark)
    for offset, colour in enumerate(band):
        inset = len(rings) + offset
        card_ring(image, inset, colour, colour if offset < len(band) - 1 else mix(colour, OUTLINE, 0.3))
    card_ring(image, 6, trim_light, trim_dark)
    card_ring(image, 7, OUTLINE, OUTLINE)
    band_details(image, family, palette, hover)
    chamfer(image)

    text_panel(image, TEXT_PANEL, palette, hover)
    art_window(image, WINDOW, palette, hover)
    paste_corners(image, CORNERS[family](palette), 1)
    plaque(image, BANNER, palette["banner"], palette["trim"], hover)
    gem(image, CARD_W // 2, CARD_H - 4, palette["gem"])
    return image


# ---------------------------------------------------------------------------
# Illustration helpers: scaled versions of the 32 px icon shapes
# ---------------------------------------------------------------------------

class Pen:
    """Draws on an image through a scale, an offset and an optional
    horizontal mirror, so the 32 px icon geometry can be reused bigger."""

    def __init__(self, image, scale=1.0, dx=0.0, dy=0.0, mirror=False, width=32):
        self.image, self.scale, self.dx, self.dy = image, scale, dx, dy
        self.mirror, self.width = mirror, width

    def p(self, point):
        x, y = point
        if self.mirror:
            x = self.width - 1 - x
        return (round(x * self.scale + self.dx), round(y * self.scale + self.dy))

    def line(self, p0, p1, colour, width=1):
        line(self.image, self.p(p0), self.p(p1), colour, max(1, round(width * self.scale)))

    def polygon(self, points, colour):
        polygon(self.image, [self.p(q) for q in points], colour)


def shovel(image, pen):
    pen.line((25, 6), (15, 16), WOOD, 3)
    pen.line((26, 5), (16, 15), WOOD_LIGHT, 1)
    pen.line((22, 3), (28, 9), WOOD_DARK, 3)
    pen.line((22, 2), (28, 8), WOOD, 1)
    pen.line((16, 15), (13, 18), METAL_DARK, 4)
    pen.polygon([(9, 13), (18, 22), (13, 27), (4, 28), (4, 18)], METAL)
    pen.line((12, 19), (6, 25), METAL_DARK, 1)


def pickaxe(image, pen):
    pen.line((4, 28), (20, 12), WOOD, 3)
    pen.line((4, 27), (19, 12), WOOD_LIGHT, 1)
    cx, cy = 21.0, 11.0
    for step in range(-80, 81):
        t = step / 80.0
        bow = 4.5 * (1 - t * t)
        px = cx + (t * 12.0) * 0.7071 + bow * 0.7071 - 1.59
        py = cy + (t * 12.0) * 0.7071 - bow * 0.7071 + 1.59
        radius = (1.9 * (1 - abs(t)) + 0.4) * pen.scale
        x, y = pen.p((px, py))
        disc(image, x, y, radius, METAL)
    for step in range(-60, 61):
        t = step / 80.0
        bow = 4.5 * (1 - t * t) + 1.1
        px = cx + (t * 12.0) * 0.7071 + bow * 0.7071 - 1.59
        py = cy + (t * 12.0) * 0.7071 - bow * 0.7071 + 1.59
        x, y = pen.p((px, py))
        if ui.opaque(image, x, y):
            put(image, x, y, METAL_LIGHT)
    x0, y0 = pen.p((19, 11))
    x1, y1 = pen.p((22.5, 14.5))
    rect(image, min(x0, x1), min(y0, y1), max(x0, x1), max(y0, y1), METAL_DARK)


def dynamite_sticks(image, x0, y0, stick_w, height, count):
    """Upright red sticks tied with a leather band, gaps outlined."""
    for i in range(count):
        sx = x0 + i * (stick_w + 1)
        rect(image, sx, y0, sx + stick_w - 1, y0 + height, RED)
        vline(image, sx + 1, y0 + 1, y0 + height - 1, RED_LIGHT)
        vline(image, sx + 2, y0 + 2, y0 + height - 2, RED_LIGHT)
        vline(image, sx + stick_w - 1, y0, y0 + height, RED_DARK)
        rect(image, sx, y0, sx + stick_w - 1, y0 + 1, CREAM_DARK)
        hline(image, sx, sx + stick_w - 1, y0 + height, RED_DARK)
        if i:
            vline(image, sx - 1, y0, y0 + height, OUTLINE)
    band_y = y0 + height // 2
    right = x0 + count * (stick_w + 1) - 2
    rect(image, x0 - 1, band_y - 2, right + 1, band_y + 3, LEATHER_DARK)
    hline(image, x0 - 1, right + 1, band_y - 2, LEATHER)
    return right


def arrow_double(image, x0, x1, y, colour, shade):
    """Horizontal double headed arrow, 3 px shaft."""
    rect(image, x0 + 4, y - 1, x1 - 4, y + 1, colour)
    hline(image, x0 + 4, x1 - 4, y + 1, shade)
    for i in range(6):
        vline(image, x0 + i, y - i, y + i, colour)
        vline(image, x1 - i, y - i, y + i, colour)
    put(image, x0 + 5, y + 5, shade)
    put(image, x1 - 5, y + 5, shade)


def arrow_up(image, x, y0, y1, colour, shade):
    rect(image, x - 1, y0 + 5, x + 1, y1, colour)
    vline(image, x + 1, y0 + 5, y1, shade)
    for i in range(6):
        hline(image, x - i, x + i, y0 + i, colour)


def plus_badge(image, cx, cy):
    rect(image, cx - 2, cy - 7, cx + 2, cy + 7, YELLOW)
    rect(image, cx - 7, cy - 2, cx + 7, cy + 2, YELLOW)
    hline(image, cx - 2, cx + 2, cy - 7, YELLOW_LIGHT)
    hline(image, cx - 7, cx + 7, cy - 2, YELLOW_LIGHT)
    vline(image, cx + 2, cy - 6, cy + 7, ORANGE)
    hline(image, cx - 6, cx + 7, cy + 2, ORANGE)


# ---------------------------------------------------------------------------
# Relic illustrations
# ---------------------------------------------------------------------------

def relic_sharp_blades():
    """Shovel and pickaxe crossed, edges gleaming."""
    image = new()
    pick = new()
    # Pickaxe head top right, shovel blade bottom right: the handles cross
    # and the two heads never cover each other.
    pickaxe(pick, Pen(pick, 1.8, 1, 2))
    outline(pick)
    spade = new()
    sx = Pen(spade, 1.8, 6, 7, mirror=True)
    shovel(spade, sx)
    # Bright cutting edge along the blade.
    sx.line((4, 27), (13, 26), METAL_SHINE, 1)
    sx.line((5, 18), (5, 26), METAL_LIGHT, 1)
    sx.line((9, 14), (5, 18), METAL_LIGHT, 1)
    outline(spade)
    image.alpha_composite(pick)
    image.alpha_composite(spade)
    for x, y, size in ((56, 60, 3), (60, 38, 2), (8, 8, 2), (40, 4, 2)):
        sparkle(image, x, y, size)
    return image


def relic_long_bridge():
    """A long plank bridge between two grassy banks, a gold arrow above."""
    image = new()
    for x0, x1, seed in ((0, 9, 3), (54, 63, 4)):
        ui.earth_fill(image, x0, 40, x1, 63, seed)
        ui.grass_top(image, x0, x1, 36)
    for x0 in range(2, 60, 10):
        ui.plank(image, x0, 31, min(x0 + 11, 61), 37)
    for x in (4, 58):
        rect(image, x, 18, x + 2, 30, WOOD_DARK)
        vline(image, x, 18, 30, WOOD)
    for x in range(7, 58):
        sag = round(4.5 * math.sin(math.pi * (x - 6) / 52))
        put(image, x, 20 + sag, CREAM_DARK)
        put(image, x, 21 + sag, CREAM_DARK)
    outline(image)
    arrow = new()
    arrow_double(arrow, 8, 55, 9, YELLOW, ORANGE)
    outline(arrow)
    image.alpha_composite(arrow)
    return image


def relic_long_ladders():
    """A tall ladder whose top rungs are fresh gold wood, an arrow beside it."""
    image = new()
    ui.ladder_shape(image, 2, 63, left=10, right=36, spacing=8)
    # The extra pieces: the top section in new, golden wood.
    for y in range(2, 22):
        for x in range(10, 40):
            colour = image.getpixel((x, y))
            if colour in (WOOD, WOOD_LIGHT, WOOD_DARK):
                put(image, x, y, {WOOD: YELLOW, WOOD_LIGHT: YELLOW_LIGHT, WOOD_DARK: ORANGE}[colour])
    outline(image)
    arrow = new()
    arrow_up(arrow, 52, 6, 50, YELLOW, ORANGE)
    outline(arrow)
    image.alpha_composite(arrow)
    sparkle(image, 7, 6, 2)
    sparkle(image, 43, 16, 2)
    return image


def relic_short_fuse():
    """Dynamite with a stub of fuse already sparking, and a stopwatch."""
    image = new()
    sticks = new()
    right = dynamite_sticks(sticks, 4, 28, 7, 32, 3)
    vline(sticks, 15, 23, 27, CREAM_DARK)
    vline(sticks, 16, 23, 27, CREAM_DARK)
    outline(sticks)
    watch = new()
    cx, cy = 46, 42
    rect(watch, cx - 2, cy - 18, cx + 2, cy - 14, METAL)
    rect(watch, cx - 4, cy - 20, cx + 4, cy - 18, METAL_LIGHT)
    disc(watch, cx, cy, 13.5, METAL)
    disc(watch, cx - 0.5, cy - 0.5, 11, CREAM)
    for angle in range(0, 360, 30):
        a = math.radians(angle)
        put(watch, round(cx + 9 * math.cos(a)), round(cy + 9 * math.sin(a)), CREAM_DARK)
    # Red wedge: the two seconds left.
    for y in range(cy - 11, cy + 1):
        for x in range(cx, cx + 12):
            a = math.degrees(math.atan2(y - cy, x - cx))
            if -90 <= a <= -30 and math.hypot(x - cx, y - cy) <= 10:
                put(watch, x, y, RED_LIGHT)
    line(watch, (cx, cy), (cx, cy - 9), OUTLINE, 1)
    line(watch, (cx, cy), (cx + 5, cy - 8), RED_DARK, 1)
    disc(watch, cx, cy, 1, OUTLINE)
    outline(watch)
    image.alpha_composite(sticks)
    image.alpha_composite(watch)
    for x, y, colour in [(16, 20, WHITE), (15, 20, YELLOW_LIGHT), (17, 20, YELLOW_LIGHT), (16, 19, YELLOW_LIGHT),
                         (16, 21, YELLOW), (14, 18, YELLOW), (18, 18, YELLOW), (18, 22, ORANGE), (13, 22, ORANGE),
                         (16, 16, ORANGE), (12, 19, ORANGE), (20, 19, ORANGE), (19, 16, RED_LIGHT), (13, 15, RED_LIGHT)]:
        put(image, x, y, colour)
    return image


def relic_extra_pocket():
    """A leather pouch with a brass clasp and a gold plus."""
    image = new()
    pouch = new()
    polygon(pouch, [(8, 22), (50, 22), (54, 54), (46, 61), (12, 61), (4, 54)], LEATHER)
    # Shading: light left side, darker bottom.
    for y in range(22, 62):
        for x in range(0, 64):
            if pouch.getpixel((x, y)) == LEATHER:
                if y > 52 or x > 46:
                    put(pouch, x, y, LEATHER_DARK)
                elif x < 12:
                    put(pouch, x, y, rgb("#8a5634"))
    # Stitching.
    for x in range(10, 50, 3):
        put(pouch, x, 57, CREAM_DARK)
    for y in range(26, 55, 3):
        put(pouch, 8, y, CREAM_DARK)
        put(pouch, 49, y, CREAM_DARK)
    # Flap.
    polygon(pouch, [(6, 18), (52, 18), (50, 34), (29, 42), (8, 34)], rgb("#8a5634"))
    hline(pouch, 7, 51, 18, rgb("#a8714a"))
    line(pouch, (8, 34), (29, 42), LEATHER_DARK, 1)
    line(pouch, (29, 42), (50, 34), LEATHER_DARK, 1)
    for x in range(10, 49, 3):
        put(pouch, x, 21, CREAM_DARK)
    # Clasp.
    rect(pouch, 25, 36, 33, 44, BRASS)
    hline(pouch, 25, 33, 36, BRASS_LIGHT)
    vline(pouch, 33, 36, 44, BRASS_DARK)
    rect(pouch, 28, 39, 30, 41, BRASS_DARK)
    outline(pouch)
    badge = new()
    plus_badge(badge, 52, 12)
    outline(badge)
    image.alpha_composite(pouch)
    image.alpha_composite(badge)
    sparkle(image, 41, 6, 2)
    return image


def relic_spare_parachute():
    """A packed parachute bag with the striped canopy peeking out of it."""
    image = new()
    canopy = new()
    cx = 31.5
    for y in range(4, 26):
        for x in range(4, 60):
            dx = (x + 0.5 - cx) / 27
            dy = (y + 0.5 - 26) / 22
            if dx * dx + dy * dy <= 1.0:
                stripe = int((x - 4) // 8) % 2
                put(canopy, x, y, RED if stripe else CREAM)
    for x in range(4, 60):
        if (x - 4) % 8 in (0, 7):
            put(canopy, x, 25, CLEAR)
    for x in range(5, 59):
        top = next((y for y in range(4, 26) if canopy.getpixel((x, y))[3]), None)
        if top is not None:
            colour = canopy.getpixel((x, top + 1))
            put(canopy, x, top, RED_LIGHT if colour == RED else WHITE)
            if canopy.getpixel((x, 24))[3]:
                put(canopy, x, 24, RED_DARK if canopy.getpixel((x, 24)) == RED else CREAM_DARK)
    for start in ((8, 26), (20, 26), (43, 26), (55, 26)):
        line(canopy, start, (24 if start[0] < 32 else 39, 36), CREAM_DARK, 1)
    outline(canopy)
    pack = new()
    rect(pack, 14, 34, 49, 62, LEATHER)
    vline(pack, 14, 34, 62, rgb("#8a5634"))
    rect(pack, 44, 34, 49, 62, LEATHER_DARK)
    hline(pack, 14, 49, 62, LEATHER_DARK)
    # Flap, two plain straps and a cross strap with one buckle (buckles in
    # a row read as a face).
    rect(pack, 13, 34, 50, 41, rgb("#8a5634"))
    hline(pack, 13, 50, 34, rgb("#a8714a"))
    hline(pack, 13, 50, 41, LEATHER_DARK)
    for sx in (20, 40):
        rect(pack, sx, 41, sx + 3, 62, LEATHER_DARK)
    rect(pack, 14, 51, 49, 53, LEATHER_DARK)
    rect(pack, 29, 50, 34, 54, BRASS)
    hline(pack, 29, 34, 50, BRASS_LIGHT)
    rect(pack, 31, 51, 32, 53, LEATHER_DARK)
    outline(pack)
    # Red rip cord handle hanging off the right side.
    handle = new()
    vline(handle, 52, 44, 50, CREAM_DARK)
    rect(handle, 51, 50, 56, 53, RED)
    hline(handle, 51, 56, 50, RED_LIGHT)
    rect(handle, 53, 51, 54, 52, RED_DARK)
    outline(handle)
    pack.alpha_composite(handle)
    image.alpha_composite(canopy)
    image.alpha_composite(pack)
    return image


RELICS = {
    "sharp_blades": relic_sharp_blades,
    "long_bridge": relic_long_bridge,
    "long_ladders": relic_long_ladders,
    "short_fuse": relic_short_fuse,
    "extra_pocket": relic_extra_pocket,
    "spare_parachute": relic_spare_parachute,
}


# ---------------------------------------------------------------------------
# Rescue: phoenix feather
# ---------------------------------------------------------------------------

def rescue_phoenix():
    """A big flame coloured feather on a curved quill, embers rising."""
    image = new()
    feather = new()

    def spine(t):
        # Quadratic curve from the quill at the bottom left to the tip.
        p0, p1, p2 = (8, 60), (18, 22), (56, 5)
        x = (1 - t) ** 2 * p0[0] + 2 * (1 - t) * t * p1[0] + t * t * p2[0]
        y = (1 - t) ** 2 * p0[1] + 2 * (1 - t) * t * p1[1] + t * t * p2[1]
        return x, y

    def tangent(t):
        x0, y0 = spine(max(0, t - 0.01))
        x1, y1 = spine(min(1, t + 0.01))
        length = math.hypot(x1 - x0, y1 - y0)
        return (x1 - x0) / length, (y1 - y0) / length

    ramp = [YELLOW_LIGHT, YELLOW, ORANGE, rgb("#e0522a"), RED, RED_DARK]
    steps = 420
    for i in range(steps):
        t = 0.14 + 0.86 * i / steps
        sx, sy = spine(t)
        tx, ty = tangent(t)
        nx, ny = -ty, tx
        width = 15 * math.sin(math.pi * (t - 0.14) / 0.86) ** 0.65
        for side in (-1, 1):
            # Barbs sweep back toward the quill.
            for k in range(int(width * 10)):
                d = k / 10
                bx = sx + side * nx * d - tx * d * 0.55
                by = sy + side * ny * d - ty * d * 0.55
                u = d / max(width, 0.1)
                level = min(len(ramp) - 1, int(u * 3.2 + (1 - t) * 2.4))
                # Notches in the vane, like a real feather's split barbs.
                if (i // 18) % 5 == 4 and u > 0.55 and side == 1:
                    continue
                put(feather, round(bx), round(by), ramp[level])
    # Quill and rachis.
    for i in range(200):
        t = i / 199
        x, y = spine(t)
        put(feather, round(x), round(y), CREAM if t > 0.14 else CREAM_DARK)
        if t < 0.6:
            put(feather, round(x) + 1, round(y), CREAM_DARK)
    # Fluff at the base of the vane.
    for x, y in ((11, 48), (14, 50), (9, 46), (16, 46)):
        disc(feather, x, y, 1.2, YELLOW_LIGHT)
    outline(feather)
    image.alpha_composite(feather)
    rng = random.Random(77)
    for _ in range(14):
        x, y = rng.randint(28, 62), rng.randint(14, 62)
        if not ui.opaque(image, x, y):
            put(image, x, y, rng.choice([YELLOW, ORANGE, YELLOW_LIGHT]))
    sparkle(image, 50, 30, 2)
    sparkle(image, 40, 52, 2)
    sparkle(image, 6, 10, 2)
    return image


# ---------------------------------------------------------------------------
# Character portraits
# ---------------------------------------------------------------------------

# Colours from character_catalog.gd. The wizard keeps the robe colours of
# the in-game sprite (its catalog colour is a lighter UI tint of the same).
CHARACTERS = {
    "wizard": (0.62, 0.45, 1.0),
    "miner": (0.95, 0.55, 0.2),
    "engineer": (1.0, 0.85, 0.2),
    "scout": (0.35, 0.85, 0.4),
    "tinkerer": (0.3, 0.8, 1.0),
}

WIZARD_RAMP = [rgb("#a05cc8"), ROBE_LIGHT, ROBE, rgb("#3a1752"), rgb("#24093a")]


def hood_ramp(character_id):
    """Five tones, highlight to deepest shade, in the character's hue."""
    if character_id == "wizard":
        return WIZARD_RAMP
    hue, saturation, _ = colorsys.rgb_to_hsv(*CHARACTERS[character_id])
    tones = []
    for s_factor, value in ((0.55, 1.0), (0.78, 0.92), (0.9, 0.76), (0.95, 0.54), (0.95, 0.34)):
        r, g, b = colorsys.hsv_to_rgb(hue, saturation * s_factor, value)
        tones.append((round(r * 255), round(g * 255), round(b * 255), 255))
    return tones


def hood_figure(ramp):
    """Hooded head and shoulders, three quarters to the right like the
    walk frames: pointed hood tip falling back, dark face opening with the
    two glowing eyes, backpack strap across the chest."""
    hi, light, base, shade, deep = ramp
    image = new()
    # Backpack behind the left shoulder.
    rect(image, 2, 38, 15, 58, LEATHER)
    hline(image, 2, 15, 38, rgb("#8a5634"))
    rect(image, 2, 44, 15, 46, LEATHER_DARK)
    vline(image, 15, 38, 58, LEATHER_DARK)
    # Shoulders and robe.
    polygon(image, [(5, 63), (9, 50), (19, 43), (45, 43), (55, 50), (59, 63)], base)
    polygon(image, [(5, 63), (9, 50), (17, 45), (14, 63)], shade)
    polygon(image, [(50, 47), (55, 50), (59, 63), (52, 63)], light)
    line(image, (30, 50), (28, 63), shade, 1)
    # Hood: round dome plus a tip falling back to the upper left.
    disc(image, 31, 28, 19.5, base)
    polygon(image, [(14, 22), (4, 5), (12, 9), (26, 10)], base)
    polygon(image, [(6, 7), (12, 9), (14, 13)], light)
    # Light from the upper right: rim highlight, shaded back of the hood.
    for y in range(4, 50):
        for x in range(0, 64):
            if image.getpixel((x, y)) != base:
                continue
            d = math.hypot(x - 31, y - 28)
            if d > 17.5 and x > 26 and y < 30:
                put(image, x, y, hi)
            elif d > 15.5 and x > 22 and y < 34:
                put(image, x, y, light)
            elif x < 20 and y > 24:
                put(image, x, y, shade)
    # Face opening with a lighter hood lip around it.
    cx, cy = 37, 31
    for y in range(14, 46):
        for x in range(20, 54):
            e = ((x + 0.5 - cx) / 11.5) ** 2 + ((y + 0.5 - cy) / 12.5) ** 2
            if e <= 1.0:
                put(image, x, y, FACE_DARK)
            elif e <= 1.32 and image.getpixel((x, y))[3]:
                put(image, x, y, light if x < cx + 6 else hi)
    # Shadow at the top of the opening, under the hood's brim.
    for y in range(19, 23):
        for x in range(28, 47):
            if image.getpixel((x, y)) == FACE_DARK:
                put(image, x, y, deep)
    # Eyes.
    for ex in (32, 40):
        rect(image, ex, 28, ex + 2, 33, YELLOW)
        hline(image, ex, ex + 2, 28, YELLOW_LIGHT)
        hline(image, ex, ex + 2, 33, ORANGE)
    # Strap across the chest.
    line(image, (46, 46), (30, 63), LEATHER, 3)
    line(image, (45, 45), (29, 62), rgb("#8a5634"), 1)
    rect(image, 37, 53, 40, 56, BRASS)
    put(image, 37, 53, BRASS_LIGHT)
    return outline(image)


def prop_wizard(ramp):
    """Staff with a glowing blue orb."""
    image = new()
    rect(image, 53, 20, 55, 63, WOOD)
    vline(image, 53, 20, 63, WOOD_LIGHT)
    vline(image, 55, 20, 63, WOOD_DARK)
    rect(image, 51, 18, 57, 21, BRASS)
    hline(image, 51, 57, 18, BRASS_LIGHT)
    disc(image, 54, 12, 5.6, BLUE)
    disc(image, 53.3, 11.3, 4, BLUE_LIGHT)
    rect(image, 51, 9, 52, 10, BLUE_SHINE)
    image = outline(image)
    sparkle(image, 46, 5, 2)
    sparkle(image, 61, 22, 1)
    sparkle(image, 45, 17, 1)
    return image


def prop_miner(ramp):
    """Pickaxe over the shoulder and a lamp on the hood."""
    image = new()
    pickaxe(image, Pen(image, 1.25, 28, 22))
    outline(image)
    lamp = new()
    rect(lamp, 29, 9, 39, 14, METAL_DARK)
    hline(lamp, 29, 39, 9, METAL)
    disc(lamp, 34, 11.5, 2.6, YELLOW)
    put(lamp, 33, 10, YELLOW_LIGHT)
    outline(lamp)
    image.alpha_composite(lamp)
    return image


def prop_engineer(ramp):
    """Wrench in front and a plank on the shoulder."""
    image = new()
    plank_layer = new()
    ui.plank(plank_layer, 0, 45, 24, 51)
    outline(plank_layer)
    wrench = new()
    line(wrench, (36, 63), (52, 43), METAL, 5)
    line(wrench, (35, 62), (51, 42), METAL_LIGHT, 1)
    disc(wrench, 54.5, 40.5, 6.5, METAL)
    disc(wrench, 53.8, 39.8, 5, METAL_LIGHT)
    # Open jaw.
    polygon(wrench, [(54, 40), (58, 32), (63, 37)], CLEAR)
    rect(wrench, 54, 37, 57, 40, CLEAR)
    outline(wrench)
    image.alpha_composite(plank_layer)
    image.alpha_composite(wrench)
    return image


def prop_scout(ramp):
    """A feather in the hood and a winged boot."""
    image = new()
    feather = new()
    for i in range(16):
        t = i / 15
        x = 46 + t * 12
        y = 22 - t * 18
        w = 2.6 * math.sin(math.pi * t) + 0.6
        disc(feather, x, y, w, GRASS_LIGHT if i % 3 else GRASS)
    line(feather, (46, 22), (58, 4), CREAM, 1)
    outline(feather)
    # Boot facing right (toe to the right), a small wing swept back and up
    # from the ankle: the scout's strong legs.
    boot = new()
    rect(boot, 48, 49, 56, 59, LEATHER)
    polygon(boot, [(48, 58), (58, 57), (62, 60), (62, 62), (48, 62)], LEATHER)
    vline(boot, 48, 50, 61, rgb("#8a5634"))
    vline(boot, 56, 50, 57, LEATHER_DARK)
    # Folded cuff and sole.
    rect(boot, 47, 47, 57, 50, rgb("#a8714a"))
    hline(boot, 47, 57, 50, LEATHER_DARK)
    hline(boot, 48, 62, 62, LEATHER_DARK)
    hline(boot, 57, 61, 58, rgb("#8a5634"))
    for y in (53, 56):
        put(boot, 54, y, CREAM_DARK)
        put(boot, 55, y, CREAM_DARK)
    outline(boot)
    # One wing swept back from the heel, scalloped trailing edge.
    wing = new()
    polygon(wing, [(48, 52), (45, 47), (40, 44), (34, 43), (37, 46), (33, 48),
                   (37, 50), (34, 53), (39, 54), (37, 57), (43, 57), (48, 58)], WHITE)
    line(wing, (47, 54), (38, 48), CREAM_DARK, 1)
    line(wing, (47, 56), (39, 52), CREAM_DARK, 1)
    outline(wing)
    image.alpha_composite(feather)
    image.alpha_composite(wing)
    image.alpha_composite(boot)
    return image


def prop_tinkerer(ramp):
    """Goggles on the hood and a brass gear."""
    image = new()
    goggles = new()
    hline(goggles, 24, 50, 14, LEATHER_DARK)
    hline(goggles, 24, 50, 15, LEATHER_DARK)
    for gx in (32, 42):
        disc(goggles, gx, 14.5, 4.6, BRASS)
        disc(goggles, gx, 14.5, 3, BLUE_LIGHT)
        put(goggles, gx - 1, 13, BLUE_SHINE)
    outline(goggles)
    gear = new()
    cx, cy = 50.5, 51.5
    for y in range(36, 64):
        for x in range(34, 64):
            a = math.atan2(y + 0.5 - cy, x + 0.5 - cx)
            r = math.hypot(x + 0.5 - cx, y + 0.5 - cy)
            tooth = math.cos(a * 8) > 0.2
            if r <= 9 or (tooth and r <= 12):
                put(gear, x, y, BRASS if r > 3.2 else CLEAR)
                if 6.5 < r <= 9 and y < cy:
                    put(gear, x, y, BRASS_LIGHT)
                elif 6.5 < r <= 9 and y > cy + 3:
                    put(gear, x, y, BRASS_DARK)
    outline(gear)
    image.alpha_composite(goggles)
    image.alpha_composite(gear)
    return image


PROPS = {
    "wizard": prop_wizard,
    "miner": prop_miner,
    "engineer": prop_engineer,
    "scout": prop_scout,
    "tinkerer": prop_tinkerer,
}


def character_portrait(character_id):
    ramp = hood_ramp(character_id)
    image = hood_figure(ramp)
    image.alpha_composite(PROPS[character_id](ramp))
    return image


# ---------------------------------------------------------------------------
# Output
# ---------------------------------------------------------------------------

def sample_text(image, family, title, body):
    """Draws sample title and description text on a card, roughly the way the
    game will, to check the flat areas stay readable."""
    draw = ImageDraw.Draw(image)
    font = ImageFont.load_default()
    bx, by, bw, bh = BANNER
    text_w = draw.textlength(title, font=font)
    draw.text((bx + (bw - text_w) / 2, by + 2), title, fill=CREAM, font=font)
    tx, ty, tw, th = TEXT_PANEL
    for i, row in enumerate(body):
        draw.text((tx + 4, ty + 4 + i * 13), row, fill=CREAM, font=font)


def preview(cards, illustrations, path):
    icon = Image.open(os.path.join(ICON_DIR, "digger.png")).convert("RGBA")
    icon2 = icon.resize((64, 64), Image.NEAREST)
    samples = {
        "tool": (icon2, "Nova: Pa", ["Ferramenta nova", "na barra, com", "2 cargas."]),
        "recruit": (illustrations["character_miner"], "Recrutar Mineiro", ["Cava duas vezes", "mais rapido com", "Pa e Picareta."]),
        "relic": (illustrations["relic_short_fuse"], "Pavio curto", ["Dinamite e TNT", "explodem em 2s", "em vez de 3s."]),
        "rescue": (illustrations["rescue_phoenix"], "Pena da fenix", ["Traz de volta o", "ultimo boneco", "perdido."]),
    }
    background = rgb("#15131a")
    rows = []
    for scale in (1, 2):
        row = []
        for family in FAMILIES:
            for hover in (False, True):
                card_image = cards[family + ("_hover" if hover else "")].copy()
                art, title, body = samples[family]
                card_image.alpha_composite(art, (WINDOW[0], WINDOW[1]))
                sample_text(card_image, family, title, body)
                row.append(card_image.resize((CARD_W * scale, CARD_H * scale), Image.NEAREST))
        rows.append(row)
    # Every illustration in a recruit/relic window backdrop, 1x and 2x.
    for scale in (1, 2):
        row = []
        for name, art in illustrations.items():
            family = "recruit" if name.startswith("character") else "rescue" if name.startswith("rescue") else "relic"
            tile = cards[family].crop((WINDOW[0] - 4, WINDOW[1] - 4, WINDOW[0] + ART + 4, WINDOW[1] + ART + 4))
            tile.alpha_composite(art, (4, 4))
            row.append(tile.resize((tile.width * scale, tile.height * scale), Image.NEAREST))
        rows.append(row)
    pad = 8
    max_width = 1600
    lines = []
    for row in rows:
        current, width = [], 0
        for tile in row:
            if current and width + tile.width + pad > max_width:
                lines.append(current)
                current, width = [], 0
            current.append(tile)
            width += tile.width + pad
        lines.append(current)
    sheet_w = max(sum(t.width + pad for t in line_) for line_ in lines) + pad
    sheet_h = sum(max(t.height for t in line_) + pad for line_ in lines) + pad
    sheet = Image.new("RGBA", (sheet_w, sheet_h), background)
    y = pad
    for line_ in lines:
        x = pad
        for tile in line_:
            sheet.alpha_composite(tile, (x, y))
            x += tile.width + pad
        y += max(t.height for t in line_) + pad
    sheet.save(path)


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    cards = {}
    for family in FAMILIES:
        for hover in (False, True):
            name = family + ("_hover" if hover else "")
            image = card(family, hover)
            assert image.size == (CARD_W, CARD_H), name
            image.save(os.path.join(OUT_DIR, "card_" + name + ".png"))
            cards[name] = image
    illustrations = {}
    for relic_id, build in RELICS.items():
        illustrations["relic_" + relic_id] = build()
    for character_id in CHARACTERS:
        illustrations["character_" + character_id] = character_portrait(character_id)
    illustrations["rescue_phoenix"] = rescue_phoenix()
    for name, image in illustrations.items():
        assert image.size == (ART, ART), name
        image.save(os.path.join(OUT_DIR, name + ".png"))
    print("card art written to", os.path.normpath(OUT_DIR))
    if len(sys.argv) > 1:
        preview(cards, illustrations, sys.argv[1])
        print("preview written to", sys.argv[1])


if __name__ == "__main__":
    main()
