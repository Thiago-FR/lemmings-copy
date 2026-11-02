"""64x64 card portraits of the four roguelike characters drawn from scratch.

Imported by tools/build_card_art.py (which keeps the wizard's portrait).
Each portrait is the bust of the in-game design from
tools/character_designs.py, in three quarters to the right like the walk
frames, with the same colours. Every part is drawn on its own layer and
outlined before it is stacked, as in the rest of the card art, and the
silhouette carries the character on its own (hard hat and lamp, cap and
planks, pointed hood and scarf, wild hair and antenna): the character
select screen shows locked characters as a black silhouette.
"""

from build_ui_art import CLEAR, OUTLINE, disc, hline, line, outline, polygon, put, rect, vline
from character_designs import COMMON, ENGINEER, MINER, SCOUT, TINKERER
from PIL import Image

SIZE = 64

SKIN = COMMON["s"]
SKIN_SHADE = COMMON["z"]
EYE = COMMON["e"]
WHITE = COMMON["w"]
METAL = COMMON["M"]
METAL_LIGHT = COMMON["m"]
METAL_DARK = COMMON["N"]


def layer():
    return Image.new("RGBA", (SIZE, SIZE), CLEAR)


def stack(image, part):
    image.alpha_composite(outline(part))


def ellipse(image, cx, cy, rx, ry, colour, top_only=False, bottom_only=False):
    for y in range(int(cy - ry) - 1, int(cy + ry) + 2):
        if top_only and y > cy:
            continue
        if bottom_only and y < cy:
            continue
        for x in range(int(cx - rx) - 1, int(cx + rx) + 2):
            if ((x + 0.5 - cx) / rx) ** 2 + ((y + 0.5 - cy) / ry) ** 2 <= 1.0:
                put(image, x, y, colour)


def recolour_rim(image, colour, new_colour, test):
    """Repaints pixels of one colour where test(x, y) holds: the quick way to
    add a lit edge or a shaded side to a flat shape."""
    for y in range(SIZE):
        for x in range(SIZE):
            if image.getpixel((x, y)) == colour and test(x, y):
                put(image, x, y, new_colour)


def face(image, cx, cy, rx, ry, eye_x, eye_y, mouth=True):
    """Three-quarter face to the right: skin oval, shaded back, one big eye
    with a glint, and a nose on the front edge."""
    ellipse(image, cx, cy, rx, ry, SKIN)
    recolour_rim(image, SKIN, SKIN_SHADE, lambda x, y: x < cx - rx + 3)
    rect(image, eye_x, eye_y, eye_x + 2, eye_y + 3, EYE)
    put(image, eye_x + 1, eye_y, WHITE)
    rect(image, int(cx + rx) - 1, eye_y + 4, int(cx + rx) + 1, eye_y + 6, SKIN)
    put(image, int(cx + rx) - 1, eye_y + 7, SKIN_SHADE)
    if mouth:
        hline(image, eye_x + 1, eye_x + 4, eye_y + 10, SKIN_SHADE)


# ---------------------------------------------------------------------------
# Miner
# ---------------------------------------------------------------------------

def miner_portrait():
    c = MINER.colour
    image = layer()
    body = layer()
    polygon(body, [(1, 63), (4, 47), (14, 41), (50, 41), (60, 47), (63, 63)], c("R"))
    polygon(body, [(1, 63), (4, 47), (12, 43), (10, 63)], c("r"))
    polygon(body, [(52, 43), (60, 47), (63, 63), (56, 63)], c("Q"))
    for x in (17, 47):
        rect(body, x, 42, x + 2, 63, c("U"))
    stack(image, body)
    head = layer()
    face(head, 34, 29, 13, 11, 39, 24, mouth=False)
    # Sideburns and hair at the back, under the hat.
    rect(head, 20, 21, 25, 33, c("B"))
    vline(head, 20, 21, 33, c("b"))
    stack(image, head)
    beard = layer()
    polygon(beard, [(21, 32), (25, 36), (36, 38), (47, 34), (49, 39), (46, 52), (38, 61), (30, 61), (22, 50)], c("B"))
    polygon(beard, [(21, 32), (25, 36), (27, 48), (30, 61), (22, 50)], c("b"))
    line(beard, (34, 42), (36, 56), c("b"), 1)
    line(beard, (42, 42), (41, 54), c("b"), 1)
    # Mouth under the moustache.
    hline(beard, 39, 44, 37, c("b"))
    stack(image, beard)
    hat = layer()
    ellipse(hat, 32, 20, 16, 15, c("H"), top_only=True)
    rect(hat, 4, 19, 60, 23, c("h"))
    hline(hat, 6, 60, 19, c("H"))
    recolour_rim(hat, c("H"), c("j"), lambda x, y: (x - 32) ** 2 + (y - 20) ** 2 > 12 ** 2 and x > 30 and y < 15)
    recolour_rim(hat, c("H"), c("h"), lambda x, y: x < 21 and y > 8)
    # Ridge over the crown.
    vline(hat, 32, 6, 18, c("j"))
    stack(image, hat)
    lamp = layer()
    rect(lamp, 41, 9, 50, 17, METAL)
    hline(lamp, 41, 50, 9, METAL_LIGHT)
    disc(lamp, 46.5, 13.5, 3.2, c("L"))
    put(lamp, 45, 12, WHITE)
    rect(lamp, 51, 11, 53, 16, METAL_DARK)
    stack(image, lamp)
    return image


# ---------------------------------------------------------------------------
# Engineer
# ---------------------------------------------------------------------------

def engineer_portrait():
    c = ENGINEER.colour
    image = layer()
    planks = layer()
    for index, (x, top) in enumerate(((3, 6), (8, 2), (13, 5))):
        rect(planks, x, top, x + 4, 63, c("X") if index == 1 else c("x"))
        vline(planks, x, top, 63, c("Z"))
        put(planks, x + 2, top + 8, c("Z"))
        put(planks, x + 2, top + 30, c("Z"))
    for y in (20, 44):
        rect(planks, 2, y, 18, y + 2, c("t"))
    stack(image, planks)
    body = layer()
    polygon(body, [(6, 63), (9, 49), (18, 43), (48, 43), (57, 49), (60, 63)], c("Y"))
    polygon(body, [(6, 63), (9, 49), (16, 45), (14, 63)], c("y"))
    rect(body, 23, 48, 47, 63, c("U"))
    rect(body, 23, 48, 25, 63, c("u"))
    rect(body, 30, 52, 39, 57, c("u"))
    hline(body, 30, 39, 52, c("U"))
    for x in (24, 45):
        rect(body, x, 43, x + 2, 48, c("U"))
        put(body, x + 1, 49, c("G"))
    stack(image, body)
    head = layer()
    face(head, 34, 31, 13, 12, 40, 27)
    rect(head, 20, 22, 25, 34, c("n"))
    vline(head, 20, 22, 34, ENGINEER.colour("n"))
    # Ear.
    rect(head, 26, 29, 28, 33, SKIN_SHADE)
    stack(image, head)
    cap = layer()
    ellipse(cap, 32, 23, 15, 15, c("C"), top_only=True)
    rect(cap, 17, 20, 47, 24, c("C"))
    # Long bill pointing forward.
    polygon(cap, [(44, 20), (61, 21), (61, 25), (44, 25)], c("c"))
    hline(cap, 45, 61, 21, c("C"))
    recolour_rim(cap, c("C"), c("q"), lambda x, y: (x - 32) ** 2 + (y - 23) ** 2 > 12 ** 2 and x > 30 and y < 18)
    recolour_rim(cap, c("C"), c("c"), lambda x, y: x < 22)
    stack(image, cap)
    goggles = layer()
    hline(goggles, 18, 46, 15, c("t"))
    hline(goggles, 18, 46, 16, c("t"))
    for gx, radius in ((34, 4.4), (43, 4.6)):
        disc(goggles, gx, 15, radius, c("G"))
        disc(goggles, gx, 15, radius - 1.7, c("g"))
        put(goggles, gx - 1, 14, WHITE)
    stack(image, goggles)
    return image


# ---------------------------------------------------------------------------
# Scout
# ---------------------------------------------------------------------------

def scout_portrait():
    c = SCOUT.colour
    image = layer()
    tails = layer()
    polygon(tails, [(22, 44), (2, 40), (0, 45), (12, 47), (3, 52), (8, 54), (24, 48)], c("F"))
    line(tails, (20, 46), (6, 43), c("f"), 1)
    stack(image, tails)
    body = layer()
    polygon(body, [(4, 63), (8, 50), (18, 45), (46, 45), (56, 50), (60, 63)], c("C"))
    polygon(body, [(18, 50), (46, 50), (50, 63), (16, 63)], c("T"))
    line(body, (32, 50), (32, 63), c("t"), 1)
    rect(body, 14, 58, 52, 60, c("L"))
    rect(body, 35, 58, 38, 60, c("Y"))
    stack(image, body)
    hood = layer()
    ellipse(hood, 33, 28, 17, 18, c("G"))
    # Tip falling back to the upper left.
    polygon(hood, [(20, 18), (6, 4), (10, 3), (30, 11)], c("G"))
    recolour_rim(hood, c("G"), c("v"), lambda x, y: (x - 33) ** 2 + (y - 28) ** 2 > 14.5 ** 2 and x > 30 and y < 30)
    recolour_rim(hood, c("G"), c("g"), lambda x, y: x < 22 and y > 16)
    polygon(hood, [(7, 4), (10, 3), (16, 10)], c("v"))
    stack(image, hood)
    head = layer()
    face(head, 39, 31, 10, 11, 42, 27)
    # Hair fringe under the hood brim.
    rect(head, 30, 20, 47, 22, c("L"))
    image.alpha_composite(head)
    scarf = layer()
    ellipse(scarf, 33, 45, 16, 4.5, c("F"))
    hline(scarf, 20, 46, 47, c("f"))
    stack(image, scarf)
    return image


# ---------------------------------------------------------------------------
# Tinkerer
# ---------------------------------------------------------------------------

def gear(image, cx, cy, radius, colour, light, hole):
    import math
    for y in range(int(cy - radius) - 2, int(cy + radius) + 3):
        for x in range(int(cx - radius) - 2, int(cx + radius) + 3):
            angle = math.atan2(y + 0.5 - cy, x + 0.5 - cx)
            distance = math.hypot(x + 0.5 - cx, y + 0.5 - cy)
            tooth = math.cos(angle * 6) > 0.3
            if distance <= radius - 2 or (tooth and distance <= radius):
                put(image, x, y, hole if distance <= radius * 0.35 else (light if y < cy - 1 else colour))


def tinkerer_portrait():
    c = TINKERER.colour
    image = layer()
    antenna = layer()
    vline(antenna, 9, 4, 30, METAL)
    vline(antenna, 10, 4, 30, METAL_DARK)
    disc(antenna, 9.5, 4, 3.3, c("R"))
    put(antenna, 8, 3, WHITE)
    stack(image, antenna)
    pack = layer()
    rect(pack, 1, 28, 18, 58, c("K"))
    rect(pack, 1, 28, 18, 30, c("B"))
    vline(pack, 18, 28, 58, c("k"))
    gear(pack, 10, 44, 6.5, c("B"), c("j"), c("k"))
    stack(image, pack)
    body = layer()
    polygon(body, [(10, 63), (13, 51), (21, 46), (45, 46), (53, 51), (56, 63)], c("A"))
    polygon(body, [(10, 63), (13, 51), (19, 48), (18, 63)], c("a"))
    polygon(body, [(47, 48), (53, 51), (56, 63), (51, 63)], c("x"))
    # High collar and a row of brass buttons.
    polygon(body, [(24, 44), (33, 50), (42, 44), (40, 49), (33, 54), (26, 49)], c("a"))
    for y in (55, 60):
        put(body, 33, y, c("B"))
    stack(image, body)
    head = layer()
    face(head, 34, 33, 13, 12, 40, 30)
    stack(image, head)
    hair = layer()
    tufts = [(16, 18), (18, 8), (24, 13), (28, 3), (33, 11), (40, 4), (43, 12), (51, 9), (49, 18), (54, 22),
             (47, 24), (22, 26), (15, 30)]
    polygon(hair, tufts, c("W"))
    ellipse(hair, 33, 17, 15, 9, c("W"))
    recolour_rim(hair, c("W"), c("V"), lambda x, y: x < 24 or y > 22)
    # Back of the head stays white hair down to the collar.
    polygon(hair, [(17, 22), (24, 22), (25, 40), (19, 42), (15, 32)], c("W"))
    recolour_rim(hair, c("W"), c("V"), lambda x, y: x < 19)
    stack(image, hair)
    goggles = layer()
    hline(goggles, 20, 30, 27, c("b"))
    hline(goggles, 20, 30, 28, c("b"))
    for gx, gy, radius in ((34, 28, 5.6), (46, 28, 6.4)):
        disc(goggles, gx, gy, radius, c("B"))
        disc(goggles, gx, gy, radius - 2, c("g"))
        rect(goggles, int(gx) - 2, int(gy) - 2, int(gx) - 1, int(gy) - 1, WHITE)
    recolour_rim(goggles, c("B"), c("j"), lambda x, y: y < 25)
    stack(image, goggles)
    return image


PORTRAITS = {
    "miner": miner_portrait,
    "engineer": engineer_portrait,
    "scout": scout_portrait,
    "tinkerer": tinkerer_portrait,
}
