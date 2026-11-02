"""Draws the terrain art: block interiors, edge strips, ladder and brick.

    python tools/build_terrain_art.py
    godot --headless --path . --import
    godot --headless --script res://tools/build_terrain_tileset.gd

Everything is drawn pixel by pixel at game scale (1 texel = 1 screen pixel),
which is also the size of one art cell of the wizard at scale 0.15, so the
terrain and the character share one pixel grid. Same palette logic as the
wizard: a near-black outline on every edge that faces open air, flat colour
bands inside, a little noise for texture.

What each file is for:

  terrain_atlas.png      the gameplay tiles (one row per material, one column
                         per dig stage). They show only the INTERIOR look,
                         with no edges, because whether a block is a floor or
                         a wall depends on its neighbours, which a tile does
                         not know. Stage N is the full block with its top
                         N/4 transparent; the tileset builder gives it the
                         matching collision.
  <material>_floor.png   strip drawn over a block whose top faces air.
  earth_floor_dug.png    the same for a dug or never-grassy earth surface.
  <material>_wall_left/right.png   strips for a side that faces air.
  <material>_ceiling.png strip for a bottom that faces air.
  <material>_corner_left/right.png caps where a floor meets a wall.
  earth_details.png      a row of small extras (stones, a root) scattered
                         over buried earth to break up the repeating tile.
  ladder.png             the ladder tile (no collision).
  brick.png              the 32x8 piece the bridge and the diagonal ladder lay.

TerrainEdgeOverlay (scripts/level/terrain_edge_overlay.gd) decides which
strip goes where and must agree with the strip geometry below:
FLOOR_OVERHANG rows above the surface, CEILING_OVERHANG rows below it.

Python rather than GDScript because this is per-pixel drawing with a seeded
random generator, which is shorter here; the tileset itself is still built by
tools/build_terrain_tileset.gd.
"""

import os
import random

from PIL import Image

TILE = 32
DIG_STAGES = 4
STAGE_HEIGHT = TILE // DIG_STAGES

# Strip geometry, shared with TerrainEdgeOverlay.
FLOOR_STRIP_HEIGHT = 10
FLOOR_OVERHANG = 3        # rows of a floor strip drawn above the surface
CEILING_STRIP_HEIGHT = 8
CEILING_OVERHANG = 2      # rows of a ceiling strip drawn below the surface
WALL_STRIP_WIDTH = 6
CORNER_WIDTH = 6

OUT_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "sprites", "terrain")

CLEAR = (0, 0, 0, 0)


def rgb(hex_colour):
    hex_colour = hex_colour.lstrip("#")
    return tuple(int(hex_colour[i:i + 2], 16) for i in (0, 2, 4)) + (255,)


# Earth: warm browns, kept darker and less saturated than the wizard's
# purple robe (#62247a) so he stands out on top of it.
EARTH_OUTLINE = rgb("#24140c")
EARTH_DARK = rgb("#4a2d1b")
EARTH_BASE = rgb("#6a4327")
EARTH_MID = rgb("#7b5030")
EARTH_LIGHT = rgb("#94643b")
EARTH_CUT = rgb("#a8774a")       # freshly dug surface
PEBBLE_DARK = rgb("#45352b")
PEBBLE = rgb("#6f6056")
PEBBLE_LIGHT = rgb("#8f8072")
ROOT = rgb("#3a2414")

GRASS_OUTLINE = rgb("#12301a")
GRASS_DARK = rgb("#2c6a2e")
GRASS = rgb("#45943a")
GRASS_LIGHT = rgb("#79c24e")

# Concrete: cool greys, a seam around each slab.
CONCRETE_OUTLINE = rgb("#1e2026")
CONCRETE_SEAM = rgb("#5a5e66")
CONCRETE_DARK = rgb("#6f737c")
CONCRETE_BASE = rgb("#868a93")
CONCRETE_LIGHT = rgb("#a2a6ae")
CONCRETE_HIGHLIGHT = rgb("#c4c8ce")

# Wood for the ladder and the bricks: lighter and warmer than the earth so
# a ladder against a dirt wall still reads.
WOOD_OUTLINE = rgb("#2a160a")
WOOD_DARK = rgb("#7a4a22")
WOOD = rgb("#a86c34")
WOOD_LIGHT = rgb("#d39a55")
NAIL = rgb("#3c3f46")


def new(width, height):
    return Image.new("RGBA", (width, height), CLEAR)


def put(image, x, y, colour):
    if 0 <= x < image.width and 0 <= y < image.height:
        image.putpixel((x, y), colour)


# ---------------------------------------------------------------------------
# Interiors (tileable, no edges)
# ---------------------------------------------------------------------------

def earth_interior():
    rng = random.Random(1991)
    image = Image.new("RGBA", (TILE, TILE), EARTH_BASE)

    def wrap_put(x, y, colour):
        image.putpixel((x % TILE, y % TILE), colour)

    # Soft blotches of darker and lighter soil, wrapped so the tile repeats
    # without a seam.
    for _ in range(22):
        cx, cy = rng.randrange(TILE), rng.randrange(TILE)
        colour = rng.choice([EARTH_DARK, EARTH_MID, EARTH_MID])
        for dx, dy in [(0, 0), (1, 0), (0, 1), (1, 1), (2, 0), (-1, 1)]:
            if rng.random() < 0.8:
                wrap_put(cx + dx, cy + dy, colour)
    # Short horizontal strata, the cue that this is packed earth.
    for _ in range(6):
        cx, cy = rng.randrange(TILE), rng.randrange(TILE)
        for dx in range(rng.randrange(3, 7)):
            wrap_put(cx + dx, cy, EARTH_DARK)
            if rng.random() < 0.5:
                wrap_put(cx + dx, cy - 1, EARTH_MID)
    # Single-pixel specks.
    for _ in range(18):
        wrap_put(rng.randrange(TILE), rng.randrange(TILE), rng.choice([EARTH_LIGHT, EARTH_DARK]))
    # A few pebbles, lit from the top-left like the wizard.
    for cx, cy, size in [(6, 9, 2), (23, 22, 3), (14, 27, 1)]:
        for dy in range(size):
            for dx in range(size + 1):
                wrap_put(cx + dx, cy + dy, PEBBLE)
        wrap_put(cx, cy, PEBBLE_LIGHT)
        wrap_put(cx + 1, cy, PEBBLE_LIGHT)
        for dx in range(size + 1):
            wrap_put(cx + dx, cy + size, PEBBLE_DARK)
        wrap_put(cx + size + 1, cy + size - 1, PEBBLE_DARK)
    return image


def concrete_interior():
    rng = random.Random(42)
    image = Image.new("RGBA", (TILE, TILE), CONCRETE_BASE)
    # One slab per cell: a seam along the bottom and the right, a bevel
    # highlight along the top and the left. Symmetric about the diagonal, so
    # a side-dug (transposed) tile still has its light on the top-left.
    for i in range(TILE):
        image.putpixel((i, TILE - 1), CONCRETE_SEAM)
        image.putpixel((TILE - 1, i), CONCRETE_SEAM)
    for i in range(TILE - 1):
        image.putpixel((i, 0), CONCRETE_LIGHT)
        image.putpixel((0, i), CONCRETE_LIGHT)
    for i in range(1, TILE - 1):
        image.putpixel((i, TILE - 2), CONCRETE_DARK)
        image.putpixel((TILE - 2, i), CONCRETE_DARK)
    # Aggregate speckle.
    for _ in range(40):
        x, y = rng.randrange(2, TILE - 3), rng.randrange(2, TILE - 3)
        image.putpixel((x, y), rng.choice([CONCRETE_DARK, CONCRETE_DARK, CONCRETE_LIGHT]))
    # Two small pits and a hairline crack.
    for x, y in [(9, 20), (23, 10)]:
        image.putpixel((x, y), CONCRETE_SEAM)
        image.putpixel((x + 1, y), CONCRETE_DARK)
        image.putpixel((x, y + 1), CONCRETE_LIGHT)
    for x, y in [(17, 22), (18, 23), (19, 23), (20, 24), (21, 25)]:
        image.putpixel((x, y), CONCRETE_SEAM)
    return image


def build_atlas(interiors):
    atlas = new(TILE * DIG_STAGES, TILE * len(interiors))
    for row, interior in enumerate(interiors):
        for stage in range(DIG_STAGES):
            dug = stage * STAGE_HEIGHT
            atlas.paste(interior.crop((0, dug, TILE, TILE)), (stage * TILE, row * TILE + dug))
    return atlas


# ---------------------------------------------------------------------------
# Earth edges
# ---------------------------------------------------------------------------

def earth_floor():
    """Grass on top of an untouched earth surface. The surface is row
    FLOOR_OVERHANG; blades poke up to two rows above it."""
    rng = random.Random(7)
    image = new(TILE, FLOOR_STRIP_HEIGHT)
    surface = FLOOR_OVERHANG
    blade_heights = [rng.choice([0, 0, 1, 1, 2]) for _ in range(TILE)]
    fringe = [rng.choice([1, 2, 2, 3]) for _ in range(TILE)]
    for x in range(TILE):
        top = surface - blade_heights[x]
        put(image, x, top - 1, GRASS_OUTLINE)
        put(image, x, top, GRASS_LIGHT)
        for y in range(top + 1, surface + 2):
            put(image, x, y, GRASS)
        put(image, x, surface + 2, GRASS_DARK)
        for y in range(surface + 3, surface + 3 + fringe[x] - 1):
            put(image, x, y, GRASS_DARK)
        # Shadow the grass casts on the soil just under it.
        put(image, x, surface + 2 + fringe[x], EARTH_DARK)
    return image


def earth_floor_dug():
    """A surface someone dug into, or one that was buried when the level
    started (a tunnel floor): bare, freshly cut soil, no grass."""
    rng = random.Random(8)
    image = new(TILE, FLOOR_STRIP_HEIGHT)
    surface = FLOOR_OVERHANG
    for x in range(TILE):
        put(image, x, surface, EARTH_OUTLINE)
        put(image, x, surface + 1, EARTH_CUT)
        if rng.random() < 0.6:
            put(image, x, surface + 2, EARTH_LIGHT)
        if rng.random() < 0.15:
            put(image, x, surface - 1, EARTH_OUTLINE)   # a loose crumb
    return image


def earth_wall_left():
    """A cliff face: outline, a shaded band of irregular depth and a few
    lit stones sticking out of it, so a wall reads as a different surface
    from both the grass on top and the plain interior."""
    rng = random.Random(9)
    image = new(WALL_STRIP_WIDTH, TILE)
    depth = 2
    for y in range(TILE):
        # Depth drifts by one pixel at a time so the band looks eroded, not
        # noisy.
        depth = max(1, min(WALL_STRIP_WIDTH - 2, depth + rng.choice([-1, 0, 0, 1])))
        put(image, 0, y, EARTH_OUTLINE)
        put(image, 1, y, EARTH_DARK)
        for x in range(2, 2 + depth):
            put(image, x, y, EARTH_DARK if x < 2 + depth - 1 else EARTH_MID)
    for x, y in [(1, 5), (1, 6), (2, 5), (1, 22), (2, 22), (1, 23)]:
        put(image, x, y, PEBBLE)
    put(image, 1, 5, PEBBLE_LIGHT)
    put(image, 1, 22, PEBBLE_LIGHT)
    # A root poking out of the wall.
    for x, y in [(1, 13), (2, 14), (3, 14), (4, 15)]:
        put(image, x, y, ROOT)
    return image


def earth_ceiling():
    """Underside of earth facing air. The surface is the last row inside the
    block (CEILING_STRIP_HEIGHT - CEILING_OVERHANG - 1); roots hang below."""
    rng = random.Random(10)
    image = new(TILE, CEILING_STRIP_HEIGHT)
    surface = CEILING_STRIP_HEIGHT - CEILING_OVERHANG - 1
    for x in range(TILE):
        put(image, x, surface, EARTH_OUTLINE)
        put(image, x, surface - 1, EARTH_DARK)
        if rng.random() < 0.5:
            put(image, x, surface - 2, EARTH_DARK)
    for x in [4, 13, 14, 25]:
        for y in range(surface + 1, surface + 1 + rng.choice([1, 2])):
            put(image, x, y, ROOT)
    return image


def earth_corner_left(floor):
    """Grass wrapping over the top-left corner of a block: the left end of
    the floor strip, rounded off, with the grass hanging a little down the
    wall and the wall outline continuing underneath."""
    image = floor.crop((0, 0, CORNER_WIDTH, FLOOR_STRIP_HEIGHT))
    surface = FLOOR_OVERHANG
    # Round the top corner off.
    for y in range(0, surface + 1):
        put(image, 0, y, CLEAR)
    put(image, 1, surface - 2, CLEAR)
    put(image, 1, surface - 3, CLEAR)
    put(image, 1, surface, GRASS_OUTLINE)
    put(image, 1, surface - 1, GRASS_OUTLINE)
    put(image, 2, surface - 1, GRASS_OUTLINE)
    # Grass hanging down the wall side.
    for y in range(surface + 1, surface + 5):
        put(image, 0, y, GRASS_OUTLINE)
        put(image, 1, y, GRASS if y < surface + 3 else GRASS_DARK)
    put(image, 0, surface + 5, GRASS_OUTLINE)
    put(image, 1, surface + 5, EARTH_DARK)
    for y in range(surface + 6, FLOOR_STRIP_HEIGHT):
        put(image, 0, y, EARTH_OUTLINE)
        put(image, 1, y, EARTH_DARK)
    return image


DETAIL_WIDTH = 10
DETAIL_HEIGHT = 8


def earth_details():
    """Small extras the overlay scatters over buried earth blocks, picked per
    cell from its coordinates, so the 32px interior tile does not repeat
    identically across a big mass of earth. One row, DETAIL_WIDTH apart."""
    sheet = new(DETAIL_WIDTH * 4, DETAIL_HEIGHT)

    def stone(ox, oy, width, height):
        for y in range(height):
            for x in range(width):
                put(sheet, ox + x, oy + y, PEBBLE)
        for x in range(width):
            put(sheet, ox + x, oy - 1, PEBBLE_DARK)
            put(sheet, ox + x, oy + height, PEBBLE_DARK)
        for y in range(height):
            put(sheet, ox - 1, oy + y, PEBBLE_DARK)
            put(sheet, ox + width, oy + y, PEBBLE_DARK)
        put(sheet, ox, oy, PEBBLE_LIGHT)
        put(sheet, ox + 1, oy, PEBBLE_LIGHT)
        put(sheet, ox, oy + 1, PEBBLE_LIGHT)

    stone(2, 2, 5, 3)                       # a big stone
    stone(DETAIL_WIDTH + 1, 4, 2, 2)        # two small ones
    stone(DETAIL_WIDTH + 5, 2, 3, 2)
    root = [(0, 3), (1, 3), (2, 2), (3, 2), (4, 3), (5, 4), (6, 4), (7, 3), (8, 2), (5, 5), (5, 6)]
    for x, y in root:                       # a buried root
        put(sheet, DETAIL_WIDTH * 2 + x, y, ROOT)
    for x, y in [(2, 2), (3, 2), (4, 2), (1, 3), (2, 3), (3, 3), (4, 3), (5, 3),
                 (2, 4), (3, 4), (4, 4), (5, 4), (6, 4), (3, 5), (4, 5)]:
        put(sheet, DETAIL_WIDTH * 3 + x, y, EARTH_DARK)   # a clay patch
    for x, y in [(3, 3), (4, 4)]:
        put(sheet, DETAIL_WIDTH * 3 + x, y, EARTH_LIGHT)
    return sheet


def mirror(image):
    return image.transpose(Image.Transpose.FLIP_LEFT_RIGHT)


# ---------------------------------------------------------------------------
# Concrete edges
# ---------------------------------------------------------------------------

def concrete_floor():
    """The top of a slab: a dark outline, a bright chamfer and the shadow
    under the lip. Nothing pokes above the surface."""
    image = new(TILE, FLOOR_STRIP_HEIGHT)
    surface = FLOOR_OVERHANG
    for x in range(TILE):
        put(image, x, surface, CONCRETE_OUTLINE)
        put(image, x, surface + 1, CONCRETE_HIGHLIGHT)
        put(image, x, surface + 2, CONCRETE_LIGHT)
        put(image, x, surface + 3, CONCRETE_SEAM)
    # Slab joints every half block, so a long concrete floor reads as
    # separate slabs.
    for x in (0, TILE // 2):
        put(image, x, surface + 1, CONCRETE_LIGHT)
        put(image, x, surface + 2, CONCRETE_SEAM)
    return image


def concrete_wall_left():
    image = new(WALL_STRIP_WIDTH, TILE)
    for y in range(TILE):
        put(image, 0, y, CONCRETE_OUTLINE)
        put(image, 1, y, CONCRETE_LIGHT)
        put(image, 2, y, CONCRETE_BASE)
    for y in (TILE // 2 - 1, TILE // 2):
        put(image, 1, y, CONCRETE_SEAM)
    return image


def concrete_wall_right():
    image = new(WALL_STRIP_WIDTH, TILE)
    last = WALL_STRIP_WIDTH - 1
    for y in range(TILE):
        put(image, last, y, CONCRETE_OUTLINE)
        put(image, last - 1, y, CONCRETE_SEAM)
        put(image, last - 2, y, CONCRETE_DARK)
    for y in (TILE // 2 - 1, TILE // 2):
        put(image, last - 1, y, CONCRETE_OUTLINE)
    return image


def concrete_ceiling():
    image = new(TILE, CEILING_STRIP_HEIGHT)
    surface = CEILING_STRIP_HEIGHT - CEILING_OVERHANG - 1
    for x in range(TILE):
        put(image, x, surface, CONCRETE_OUTLINE)
        put(image, x, surface - 1, CONCRETE_SEAM)
        put(image, x, surface - 2, CONCRETE_DARK)
    return image


def concrete_corner_left(floor):
    image = floor.crop((0, 0, CORNER_WIDTH, FLOOR_STRIP_HEIGHT))
    surface = FLOOR_OVERHANG
    for y in range(surface, FLOOR_STRIP_HEIGHT):
        put(image, 0, y, CONCRETE_OUTLINE)
    put(image, 1, surface + 1, CONCRETE_HIGHLIGHT)
    for y in range(surface + 2, FLOOR_STRIP_HEIGHT):
        put(image, 1, y, CONCRETE_LIGHT)
    return image


def concrete_corner_right(floor):
    image = floor.crop((TILE - CORNER_WIDTH, 0, TILE, FLOOR_STRIP_HEIGHT))
    surface = FLOOR_OVERHANG
    last = CORNER_WIDTH - 1
    for y in range(surface, FLOOR_STRIP_HEIGHT):
        put(image, last, y, CONCRETE_OUTLINE)
    for y in range(surface + 2, FLOOR_STRIP_HEIGHT):
        put(image, last - 1, y, CONCRETE_SEAM)
    return image


# ---------------------------------------------------------------------------
# Ladder and brick
# ---------------------------------------------------------------------------

def ladder():
    """Two wooden rails and four rungs. Rungs every 8px so stacked ladder
    cells continue without a seam."""
    image = new(TILE, TILE)
    rail_left, rail_right = 6, TILE - 6 - 4
    rung_spacing = 8
    for y in range(4, TILE, rung_spacing):
        for x in range(rail_left + 3, rail_right + 1):
            put(image, x, y - 1, WOOD_OUTLINE)
            put(image, x, y, WOOD_LIGHT)
            put(image, x, y + 1, WOOD)
            put(image, x, y + 2, WOOD_OUTLINE)
    for rail_x in (rail_left, rail_right):
        for y in range(TILE):
            put(image, rail_x, y, WOOD_OUTLINE)
            put(image, rail_x + 1, y, WOOD_LIGHT)
            put(image, rail_x + 2, y, WOOD if y % 11 else WOOD_DARK)
            put(image, rail_x + 3, y, WOOD_OUTLINE)
    # Rung pegs show through the rails.
    for y in range(4, TILE, rung_spacing):
        for rail_x in (rail_left, rail_right):
            put(image, rail_x + 2, y, WOOD_DARK)
    return image


def brick():
    """A 32x8 plank with nails at both ends: the piece of the bridge and the
    steps of the diagonal ladder."""
    width, height = TILE, STAGE_HEIGHT
    image = new(width, height)
    for x in range(width):
        put(image, x, 0, WOOD_OUTLINE)
        put(image, x, height - 1, WOOD_OUTLINE)
        put(image, x, 1, WOOD_LIGHT)
        for y in range(2, height - 2):
            put(image, x, y, WOOD)
        put(image, x, height - 2, WOOD_DARK)
    for y in range(height):
        put(image, 0, y, WOOD_OUTLINE)
        put(image, width - 1, y, WOOD_OUTLINE)
    # Grain.
    for x0, y, length in [(5, 3, 7), (16, 4, 9), (9, 5, 4), (24, 3, 4)]:
        for x in range(x0, x0 + length):
            put(image, x, y, WOOD_DARK)
    for x in (3, width - 4):
        put(image, x, 3, NAIL)
        put(image, x, 4, NAIL)
    return image


def main():
    os.makedirs(OUT_DIR, exist_ok=True)

    def save(image, name):
        image.save(os.path.join(OUT_DIR, name + ".png"))

    save(build_atlas([earth_interior(), concrete_interior()]), "terrain_atlas")

    floor = earth_floor()
    save(floor, "earth_floor")
    save(earth_floor_dug(), "earth_floor_dug")
    wall = earth_wall_left()
    save(wall, "earth_wall_left")
    save(mirror(wall), "earth_wall_right")
    save(earth_ceiling(), "earth_ceiling")
    corner = earth_corner_left(floor)
    save(corner, "earth_corner_left")
    save(mirror(corner), "earth_corner_right")
    save(earth_details(), "earth_details")

    floor = concrete_floor()
    save(floor, "concrete_floor")
    save(concrete_wall_left(), "concrete_wall_left")
    save(concrete_wall_right(), "concrete_wall_right")
    save(concrete_ceiling(), "concrete_ceiling")
    save(concrete_corner_left(floor), "concrete_corner_left")
    save(concrete_corner_right(floor), "concrete_corner_right")

    save(ladder(), "ladder")
    save(brick(), "brick")
    print("terrain art written to", os.path.normpath(OUT_DIR))


if __name__ == "__main__":
    main()
