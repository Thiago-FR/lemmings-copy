"""Draws the level entrance (a hanging trapdoor) and exit (a glowing stone
doorway with a flag).

    python tools/build_portal_art.py [preview.png]
    godot --headless --path . --import

Outputs, all in assets/sprites/level/:

  entrance_open_0..4.png   48x46  the trapdoor opening, closed -> open
  entrance_idle_0..3.png   48x46  open trapdoor loop (blue shimmer, motes)
  exit_idle_0..3.png       44x56  exit loop (flickering glow, waving flag)

Same rules as tools/build_ui_art.py, whose palette and helpers it imports:
pixel by pixel at 1x (1 texel = 1 screen pixel, the wizard's art cell), no
randomness that is not seeded, and every part drawn as flat fills on its own
layer and then ringed with a one pixel near-black outline before the layers
are stacked, so overlapping parts (a swinging door over the frame) keep a
dark edge between them.

The entrance is blue inside like the editor's entrance icon, the exit uses
the editor exit icon's green flag, so the palette icons and the level pieces
read as the same objects.

Passing a path writes a preview sheet: every frame at 1x and 3x next to a
wizard walk frame and a grassy earth tile for scale.
"""

import math
import os
import random
import sys

from PIL import Image, ImageOps

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from build_ui_art import (  # noqa: E402
    BLUE, BLUE_DARK, BLUE_LIGHT, BLUE_SHINE, CLEAR, CONCRETE_BASE, CONCRETE_DARK,
    CONCRETE_HIGHLIGHT, CONCRETE_LIGHT, CONCRETE_SEAM, EXIT_GREEN,
    EXIT_GREEN_DARK, EXIT_GREEN_LIGHT, METAL, METAL_DARK, METAL_LIGHT, NAIL,
    OUTLINE, WOOD, WOOD_DARK, WOOD_LIGHT, YELLOW, hline,
    outline, put, rect, rgb, vline,
)

OUT_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "sprites", "level")
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")

ENTRANCE_WIDTH = 48
ENTRANCE_HEIGHT = 46
ENTRANCE_OPEN_ANGLES = (0, 20, 40, 60, 80)   # door swing per opening frame
ENTRANCE_IDLE_FRAMES = 4
RING_BOTTOM = 4           # iron ring the chains hang from
CHAIN_ANCHOR = 15         # where the left chain meets the beam
BEAM_TOP = 10
HOPPER_TOP = BEAM_TOP + 6
VALANCE_BOTTOM = HOPPER_TOP + 4   # front boards cover the mouth down to here
MOUTH_BOTTOM = 31         # last row of the box; the doors hang from here
SIDE_OUTER_TOP = 3        # hopper side, outer column at the top and bottom
SIDE_OUTER_BOTTOM = 7
SIDE_WIDTH = 5
# Trapdoor leaves: the left one is hinged at the bottom left corner of the
# mouth, the right one is its mirror image; closed, they meet in the middle.
LEAF_HINGE = (SIDE_OUTER_BOTTOM + SIDE_WIDTH + 0.0, MOUTH_BOTTOM + 0.0)
LEAF_LENGTH = ENTRANCE_WIDTH / 2.0 - LEAF_HINGE[0]
LEAF_THICKNESS = 3.0

EXIT_WIDTH = 44
EXIT_HEIGHT = 56
EXIT_IDLE_FRAMES = 4

HOLE_DEEP = rgb("#120c22")
HOLE = rgb("#1e1638")
HOLE_PLANK = rgb("#2a2048")
GLOW_EDGE = EXIT_GREEN_DARK
GLOW_PALE = rgb("#d8f7b0")
WHITE_HOT = rgb("#fffbe6")


def new(width, height):
    return Image.new("RGBA", (width, height), CLEAR)


def stack(base, *layers):
    for layer in layers:
        base.alpha_composite(layer)
    return base


# ---------------------------------------------------------------------------
# Entrance
# ---------------------------------------------------------------------------

def entrance_chains():
    """Two chains from the beam up to one iron ring: the box hangs."""
    image = new(ENTRANCE_WIDTH, ENTRANCE_HEIGHT)
    for x0, x1 in ((CHAIN_ANCHOR, 22), (ENTRANCE_WIDTH - 1 - CHAIN_ANCHOR, 25)):
        # From the beam (x0, BEAM_TOP - 1) up to the ring side (x1, RING_BOTTOM).
        steps = BEAM_TOP - 1 - RING_BOTTOM
        for i in range(steps + 1):
            t = i / float(steps)
            x = round(x0 + (x1 - x0) * t)
            y = BEAM_TOP - 1 - i
            put(image, x, y, METAL_LIGHT if i % 2 == 0 else METAL_DARK)
    # Ring.
    rect(image, 22, 1, 25, RING_BOTTOM, METAL)
    rect(image, 23, 2, 24, RING_BOTTOM - 1, CLEAR)
    hline(image, 22, 25, 1, METAL_LIGHT)
    return outline(image)


def entrance_beam():
    """Heavy top beam with iron end caps."""
    image = new(ENTRANCE_WIDTH, ENTRANCE_HEIGHT)
    top, bottom = BEAM_TOP, BEAM_TOP + 5
    rect(image, 1, top, 46, bottom, WOOD)
    hline(image, 1, 46, top, WOOD_LIGHT)
    hline(image, 1, 46, bottom, WOOD_DARK)
    for x in (12, 24, 35):
        vline(image, x, top + 1, bottom - 1, WOOD_DARK)
    for x0 in (1, 41):
        rect(image, x0, top, x0 + 5, bottom, METAL)
        hline(image, x0, x0 + 5, top, METAL_LIGHT)
        hline(image, x0, x0 + 5, bottom, METAL_DARK)
        put(image, x0 + 2, top + 2, NAIL)
        put(image, x0 + 3, top + 3, NAIL)
    return outline(image)


def side_outer(y):
    """Outer left column of the hopper side at row y: the sides lean in
    towards the bottom, which keeps the box from reading as a table."""
    t = (y - HOPPER_TOP) / float(MOUTH_BOTTOM - HOPPER_TOP)
    return round(SIDE_OUTER_TOP + (SIDE_OUTER_BOTTOM - SIDE_OUTER_TOP) * t)


def mouth_span(y):
    left = side_outer(y) + SIDE_WIDTH
    return left, ENTRANCE_WIDTH - 1 - left


def entrance_housing(glow_phase):
    """Slanted sides, a planked front valance and the dark mouth under it.
    glow_phase None = no light (closed), otherwise the frame index of the
    blue shimmer loop."""
    image = new(ENTRANCE_WIDTH, ENTRANCE_HEIGHT)
    for y in range(HOPPER_TOP, MOUTH_BOTTOM + 1):
        left, right = mouth_span(y)
        hline(image, left, right, y, HOLE if y > VALANCE_BOTTOM + 3 else HOLE_DEEP)
    for x in (17, 23, 24, 30):
        vline(image, x, VALANCE_BOTTOM + 1, MOUTH_BOTTOM, HOLE_DEEP)
    if glow_phase is not None:
        entrance_glow(image, glow_phase)
    # Valance: horizontal boards across the top of the mouth.
    for y in range(HOPPER_TOP, VALANCE_BOTTOM + 1):
        left, right = mouth_span(y)
        colour = WOOD
        if y in (HOPPER_TOP, HOPPER_TOP + 3):
            colour = WOOD_LIGHT
        elif y in (HOPPER_TOP + 2, VALANCE_BOTTOM):
            colour = WOOD_DARK
        hline(image, left, right, y, colour)
    for x, y in ((14, HOPPER_TOP + 1), (33, HOPPER_TOP + 1), (16, HOPPER_TOP + 4), (31, HOPPER_TOP + 4)):
        put(image, x, y, NAIL)
    # Slanted sides.
    for y in range(HOPPER_TOP, MOUTH_BOTTOM + 1):
        x0 = side_outer(y)
        for x, colour in ((x0, WOOD_LIGHT), (x0 + 1, WOOD), (x0 + 2, WOOD), (x0 + 3, WOOD), (x0 + 4, WOOD_DARK)):
            put(image, x, y, colour)
            put(image, ENTRANCE_WIDTH - 1 - x, y, WOOD_DARK if colour == WOOD_LIGHT else (WOOD_LIGHT if colour == WOOD_DARK else colour))
    # Iron straps across the sides.
    for y in (HOPPER_TOP + 3, HOPPER_TOP + 4):
        x0 = side_outer(y)
        for x in range(x0, x0 + SIDE_WIDTH):
            colour = METAL if y == HOPPER_TOP + 3 else METAL_DARK
            put(image, x, y, colour)
            put(image, ENTRANCE_WIDTH - 1 - x, y, colour)
    # Shadow line under the valance.
    left, right = mouth_span(VALANCE_BOTTOM + 1)
    hline(image, left, right, VALANCE_BOTTOM + 1, OUTLINE)
    return outline(image)


def entrance_glow(image, phase):
    """Blue light rising from below: brighter bands near the bottom of the
    mouth, breathing one row up and down over the loop."""
    lift = (0, 1, 2, 1)[phase % 4]
    for y in range(VALANCE_BOTTOM + 2, MOUTH_BOTTOM + 1):
        depth = MOUTH_BOTTOM - y          # 0 at the bottom of the mouth
        left, right = mouth_span(y)
        for x in range(left, right + 1):
            edge = min(x - left, right - x)
            if depth <= 1 + lift and edge > 1:
                colour = BLUE if edge > 4 else BLUE_DARK
            elif depth <= 4 + lift and edge > 2:
                colour = BLUE_DARK if (x + y + phase) % 2 == 0 else HOLE_PLANK
            elif depth <= 6 + lift and edge > 4 and (x + y + phase) % 3 == 0:
                colour = HOLE_PLANK
            else:
                continue
            put(image, x, y, colour)
    # A thin bright line along the very bottom, where the doors were.
    left, right = mouth_span(MOUTH_BOTTOM)
    hline(image, left + 3, right - 3, MOUTH_BOTTOM, BLUE_LIGHT if phase % 2 == 0 else BLUE_SHINE)


def leaf_layer(angle_degrees):
    """The left trapdoor leaf rotated down by angle around its hinge, sampled
    per pixel so the rotation stays clean."""
    image = new(ENTRANCE_WIDTH, ENTRANCE_HEIGHT)
    angle = math.radians(angle_degrees)
    along = (math.cos(angle), math.sin(angle))
    across = (-math.sin(angle), math.cos(angle))
    hx, hy = LEAF_HINGE
    for y in range(ENTRANCE_HEIGHT):
        for x in range(ENTRANCE_WIDTH):
            dx, dy = x + 0.5 - hx, y + 0.5 - hy
            u = dx * along[0] + dy * along[1]
            v = dx * across[0] + dy * across[1]
            if not (0.0 <= u < LEAF_LENGTH and 0.0 <= v < LEAF_THICKNESS):
                continue
            if u < 3.0:
                colour = METAL_LIGHT if v < 1.0 else METAL   # iron hinge strap
            elif v < 1.0:
                colour = WOOD_LIGHT
            elif int(u) == 7:
                colour = WOOD_DARK                           # plank seam
            else:
                colour = WOOD
            put(image, x, y, colour)
    return outline(image)


def hinge_knuckles():
    image = new(ENTRANCE_WIDTH, ENTRANCE_HEIGHT)
    hx = int(LEAF_HINGE[0])
    for x0 in (hx - 2, ENTRANCE_WIDTH - 1 - hx):
        rect(image, x0, MOUTH_BOTTOM - 2, x0 + 2, MOUTH_BOTTOM + 1, METAL_DARK)
        put(image, x0 + 1, MOUTH_BOTTOM - 1, METAL_LIGHT)
        put(image, x0, MOUTH_BOTTOM - 2, METAL)
    return outline(image)


def falling_motes(phase):
    """Specks of blue light drifting down out of the open hatch."""
    image = new(ENTRANCE_WIDTH, ENTRANCE_HEIGHT)
    for column, start in ((18, 0), (24, 2), (29, 1), (21, 3)):
        y = MOUTH_BOTTOM + 3 + ((phase + start) % ENTRANCE_IDLE_FRAMES) * 4
        if y < ENTRANCE_HEIGHT - 1:
            put(image, column, y, BLUE_SHINE if (phase + start) % 2 == 0 else BLUE_LIGHT)
    return image


def light_shaft(phase, strength):
    """Translucent blue light falling out of the hatch, fading with distance.
    Something visibly pours out of the box. strength 0..1 fades it in while
    the doors open."""
    image = new(ENTRANCE_WIDTH, ENTRANCE_HEIGHT)
    r, g, b, _ = BLUE_LIGHT
    left, right = mouth_span(MOUTH_BOTTOM)
    top = MOUTH_BOTTOM + 1
    for y in range(top, ENTRANCE_HEIGHT):
        fall = (y - top) / float(ENTRANCE_HEIGHT - top)
        half = (right - left + 1) / 2.0 - 1.0 + fall * 2.0
        for x in range(ENTRANCE_WIDTH):
            edge = half - abs(x + 0.5 - ENTRANCE_WIDTH / 2.0)
            if edge <= 0:
                continue
            alpha = 150.0 * (1.0 - fall) * min(1.0, edge / 4.0)
            # Faint vertical streaks drifting sideways over the loop.
            if (x + phase) % 4 == 0:
                alpha *= 1.35
            alpha *= strength
            if alpha >= 8:
                put(image, x, y, (r, g, b, int(min(alpha, 170))))
    return image


def entrance_frame(angle, glow_phase=None, motes=False):
    left = leaf_layer(angle)
    right = ImageOps.mirror(left)
    layers = [entrance_chains(), entrance_housing(glow_phase), entrance_beam()]
    if glow_phase is not None:
        layers.append(light_shaft(glow_phase, min(1.0, angle / float(ENTRANCE_OPEN_ANGLES[-1]))))
    layers += [left, right, hinge_knuckles()]
    if motes:
        layers.append(falling_motes(glow_phase))
    return stack(new(ENTRANCE_WIDTH, ENTRANCE_HEIGHT), *layers)


def entrance_open_frames():
    # Light comes on as soon as the doors part, so the opening reads as "open".
    return [entrance_frame(angle, None if angle == 0 else 0) for angle in ENTRANCE_OPEN_ANGLES]


def entrance_idle_frames():
    # The doors keep swaying a little: a hanging door, not a table leg.
    final = ENTRANCE_OPEN_ANGLES[-1]
    sway = (0, 4, 0, -4)
    return [entrance_frame(final + sway[phase], phase, motes=True) for phase in range(ENTRANCE_IDLE_FRAMES)]


# ---------------------------------------------------------------------------
# Exit
# ---------------------------------------------------------------------------

EXIT_CX = 22.0           # horizontal centre of the doorway (between px 21 and 22)
ARCH_TOP = 14            # first row of the stone arch
ARCH_SPRING = 26         # row where the round top meets the straight sides
OPENING_HALF = 10.5      # opening spans px 11..32
STONE_HALF = 19.5        # stonework spans px 3..40


def inside_arch(x, y, half, top):
    """Round-topped doorway shape centred on EXIT_CX whose sides are straight
    below ARCH_SPRING and whose top reaches row top."""
    cx = x + 0.5 - EXIT_CX
    if abs(cx) > half:
        return False
    if y >= ARCH_SPRING:
        return True
    radius_y = ARCH_SPRING - top
    return (cx / half) ** 2 + ((ARCH_SPRING - (y + 0.5)) / radius_y) ** 2 <= 1.0


def exit_stonework():
    """Grey masonry arch, staggered blocks, a keystone and a threshold."""
    image = new(EXIT_WIDTH, EXIT_HEIGHT)
    rng = random.Random(7)
    for y in range(ARCH_TOP, EXIT_HEIGHT - 1):
        for x in range(EXIT_WIDTH):
            if not inside_arch(x, y, STONE_HALF, ARCH_TOP):
                continue
            if inside_arch(x, y, OPENING_HALF, ARCH_TOP + 6):
                continue
            row = (y - ARCH_TOP) // 6
            offset = 0 if row % 2 == 0 else 5
            colour = CONCRETE_BASE
            if (y - ARCH_TOP) % 6 == 5 or (x + offset) % 10 == 0:
                colour = CONCRETE_SEAM
            elif (y - ARCH_TOP) % 6 == 0:
                colour = CONCRETE_LIGHT
            elif rng.random() < 0.08:
                colour = CONCRETE_DARK
            put(image, x, y, colour)
    # Lit rim: the stones right next to the opening catch the glow.
    for y in range(ARCH_TOP, EXIT_HEIGHT - 1):
        for x in range(EXIT_WIDTH):
            if inside_arch(x, y, OPENING_HALF + 2, ARCH_TOP + 4) and not inside_arch(x, y, OPENING_HALF, ARCH_TOP + 6)                     and inside_arch(x, y, STONE_HALF, ARCH_TOP):
                put(image, x, y, CONCRETE_HIGHLIGHT if y < 44 else CONCRETE_LIGHT)
    # Keystone.
    rect(image, 19, ARCH_TOP + 1, 24, ARCH_TOP + 6, CONCRETE_LIGHT)
    hline(image, 19, 24, ARCH_TOP + 1, CONCRETE_HIGHLIGHT)
    vline(image, 24, ARCH_TOP + 2, ARCH_TOP + 6, CONCRETE_DARK)
    # Threshold slab, a little wider than the arch.
    rect(image, 1, EXIT_HEIGHT - 4, EXIT_WIDTH - 2, EXIT_HEIGHT - 2, CONCRETE_DARK)
    hline(image, 1, EXIT_WIDTH - 2, EXIT_HEIGHT - 4, CONCRETE_LIGHT)
    return outline(image)


def exit_glow(phase):
    """The doorway interior: green light (the exit colour of the editor icon
    and of the old placeholder), white hot low in the middle where the
    wizards walk in, flickering by growing and shrinking its bands. Green
    rather than orange: an orange glow in a stone arch reads as a furnace."""
    image = new(EXIT_WIDTH, EXIT_HEIGHT)
    flicker = (0.0, 1.2, 0.4, 1.6)[phase % EXIT_IDLE_FRAMES]
    centre_y = 44.0
    bands = (
        (5.0 + flicker, WHITE_HOT),
        (8.5 + flicker, GLOW_PALE),
        (12.5 + flicker, EXIT_GREEN_LIGHT),
        (18.0 + flicker, EXIT_GREEN),
    )
    for y in range(ARCH_TOP + 6, EXIT_HEIGHT - 4):
        for x in range(EXIT_WIDTH):
            if not inside_arch(x, y, OPENING_HALF, ARCH_TOP + 6):
                continue
            dist = math.hypot((x + 0.5 - EXIT_CX) * 1.3, (y + 0.5 - centre_y) * 0.8)
            colour = GLOW_EDGE
            for radius, band_colour in bands:
                if dist <= radius:
                    colour = band_colour
                    break
            put(image, x, y, colour)
    # Rising sparks, the "something is happening in there" cue.
    for column, start in ((15, 0), (22, 2), (28, 1)):
        y = 42 - ((phase + start) % EXIT_IDLE_FRAMES) * 5
        put(image, column, y, WHITE_HOT)
        put(image, column, y + 1, GLOW_PALE)
    return image


def exit_spill(phase):
    """Light spilling onto the threshold from the doorway."""
    image = new(EXIT_WIDTH, EXIT_HEIGHT)
    reach = 1 if phase % 2 else 0
    hline(image, 12 - reach, 31 + reach, EXIT_HEIGHT - 4, EXIT_GREEN_LIGHT)
    hline(image, 15, 28, EXIT_HEIGHT - 4, GLOW_PALE)
    hline(image, 13, 30, EXIT_HEIGHT - 3, EXIT_GREEN)
    return image


def exit_flag(phase):
    """Pole on the keystone with a green pennant waving in four poses."""
    image = new(EXIT_WIDTH, EXIT_HEIGHT)
    vline(image, 21, 1, ARCH_TOP, METAL_LIGHT)
    vline(image, 22, 1, ARCH_TOP, METAL)
    put(image, 21, 0, YELLOW)
    put(image, 22, 0, YELLOW)
    length = 13
    for i in range(length):
        x = 23 + i
        # A travelling wave: each column bobs, more towards the free end.
        wave = math.sin((i / 3.0) - phase * math.pi / 2.0) * (i / length) * 2.6
        half = 3.0 * (1.0 - i / (length + 2.0))
        top = 4.0 + wave - half
        bottom = 4.0 + wave + half
        for y in range(int(math.floor(top + 0.5)), int(math.floor(bottom + 0.5)) + 1):
            colour = EXIT_GREEN
            if y <= top + 1.0:
                colour = EXIT_GREEN_LIGHT
            elif y >= bottom - 0.5:
                colour = EXIT_GREEN_DARK
            put(image, x, y, colour)
    return outline(image)


def exit_frame(phase):
    base = new(EXIT_WIDTH, EXIT_HEIGHT)
    stonework = exit_stonework()
    # The glow sits in the hole the outline left inside the arch; its own
    # layer has no outline so it meets the lit rim directly.
    glow = exit_glow(phase)
    stack(base, stonework)
    for y in range(EXIT_HEIGHT):
        for x in range(EXIT_WIDTH):
            pixel = glow.getpixel((x, y))
            under = base.getpixel((x, y))
            if pixel[3] and (under[3] == 0 or under == OUTLINE):
                base.putpixel((x, y), pixel)
    return stack(base, exit_spill(phase), exit_flag(phase))


def exit_idle_frames():
    return [exit_frame(phase) for phase in range(EXIT_IDLE_FRAMES)]


# ---------------------------------------------------------------------------
# Preview and main
# ---------------------------------------------------------------------------

def scale(image, factor):
    return image.resize((image.width * factor, image.height * factor), Image.NEAREST)


def scale_reference():
    """A wizard walk frame at its in-game size and a grassy earth tile."""
    wizard_path = os.path.join(ROOT, "assets", "sprites", "characters", "wizard", "walk_aligned_0.png")
    wizard = Image.open(wizard_path).convert("RGBA")
    size = round(wizard.width * 0.15)
    wizard = wizard.resize((size, size), Image.NEAREST)
    terrain = os.path.join(ROOT, "assets", "sprites", "terrain")
    tile = Image.open(os.path.join(terrain, "terrain_atlas.png")).convert("RGBA").crop((0, 0, 32, 32))
    floor = Image.open(os.path.join(terrain, "earth_floor.png")).convert("RGBA")
    ground = new(32, 32 + 3)
    ground.alpha_composite(tile, (0, 3))
    ground.alpha_composite(floor, (0, 0))
    return wizard, ground


def preview_row(frames, wizard, ground, factor, background):
    """Frames standing on a strip of ground, a wizard beside them."""
    gap = 6 * factor
    tile = scale(ground, factor)
    w = scale(wizard, factor)
    width = gap + w.width + gap + sum(scale(f, factor).width + gap for f in frames)
    height = 8 * factor + max(f.height for f in frames) * factor + tile.height
    row = Image.new("RGBA", (width, height), background)
    floor_y = height - tile.height + 3 * factor
    for x in range(0, width, tile.width):
        row.alpha_composite(tile, (x, height - tile.height))
    x = gap
    # Wizard: its 26x30 body bottom is about 4 texels above the frame bottom.
    row.alpha_composite(w, (x, floor_y - w.height + 4 * factor))
    x += w.width + gap
    for frame in frames:
        f = scale(frame, factor)
        row.alpha_composite(f, (x, floor_y - f.height))
        x += f.width + gap
    return row


def preview(entrance_open, entrance_idle, exits, path):
    wizard, ground = scale_reference()
    rows = []
    for background in (rgb("#3a3f55"), rgb("#9fb8d0")):
        for factor in (1, 3):
            rows.append(preview_row(entrance_open + entrance_idle, wizard, ground, factor, background))
            rows.append(preview_row(exits, wizard, ground, factor, background))
    width = max(r.width for r in rows)
    sheet = Image.new("RGBA", (width, sum(r.height + 4 for r in rows)), rgb("#808080"))
    y = 0
    for r in rows:
        sheet.alpha_composite(r, (0, y))
        y += r.height + 4
    sheet.save(path)


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    entrance_open = entrance_open_frames()
    entrance_idle = entrance_idle_frames()
    exits = exit_idle_frames()
    for prefix, frames in (("entrance_open", entrance_open), ("entrance_idle", entrance_idle), ("exit_idle", exits)):
        for index, frame in enumerate(frames):
            frame.save(os.path.join(OUT_DIR, "%s_%d.png" % (prefix, index)))
    print("portal art written to", os.path.normpath(OUT_DIR))
    if len(sys.argv) > 1:
        preview(entrance_open, entrance_idle, exits, sys.argv[1])
        print("preview written to", sys.argv[1])


if __name__ == "__main__":
    main()
