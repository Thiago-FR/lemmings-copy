"""Draws the art themes: the same blocks, edges, entrance and exit as the
default art, in the colours of another setting.

    python tools/build_terrain_art.py      (the default art, read from here)
    python tools/build_portal_art.py
    python tools/build_terrain_themes.py [preview.png]
    godot --headless --path . --import

Every theme is a folder with exactly the file names of the default art:

  assets/sprites/terrain/themes/<theme>/   terrain_atlas.png and the edge
                                           strips (earth_floor.png, ...)
  assets/sprites/level/themes/<theme>/     entrance_open_*, entrance_idle_*,
                                           exit_idle_*

so TerrainDestructible (art_theme), LevelBackdrop and PortalSprite only
switch folders: tiles, collision and anchors never change.

Blocks are recoloured colour by colour: the default palette of
build_terrain_art.py is named, and each theme gives every name a new colour
(grass becomes snow, dry scrub, glowing crystal tufts or embers). Some
themes also draw their own buried details (crystals, fossils). The entrance
and exit are recoloured by hue bands instead (wood, the blue and green
glow, stone and iron), since their palette is spread over two scripts.

The wizard is purple, so every theme keeps its rock away from purple.
"""

import colorsys
import os
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import build_terrain_art as base  # noqa: E402

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
TERRAIN_DIR = os.path.join(ROOT, "assets", "sprites", "terrain")
PORTAL_DIR = os.path.join(ROOT, "assets", "sprites", "level")
PORTAL_PREFIXES = (("entrance_open", 5), ("entrance_idle", 4), ("exit_idle", 4))

PALETTE_NAMES = [
    "EARTH_OUTLINE", "EARTH_DARK", "EARTH_BASE", "EARTH_MID", "EARTH_LIGHT", "EARTH_CUT",
    "PEBBLE_DARK", "PEBBLE", "PEBBLE_LIGHT", "ROOT",
    "GRASS_OUTLINE", "GRASS_DARK", "GRASS", "GRASS_LIGHT",
    "CONCRETE_OUTLINE", "CONCRETE_SEAM", "CONCRETE_DARK", "CONCRETE_BASE", "CONCRETE_LIGHT", "CONCRETE_HIGHLIGHT",
]

# name -> hex, in PALETTE_NAMES order. "portal" recolours the entrance and
# exit: (hue in degrees, saturation factor, value factor) for the wood, the
# hue of the glow, and a tint for stone and iron.
THEMES = {
    # Desert: sandstone, dry scrub on top, carved stone slabs.
    "sand": {
        "palette": ["#3a220e", "#8a5a2c", "#b9833f", "#c99550", "#dcae6a", "#e8c48a",
                    "#6e3d22", "#9a5a35", "#c07a4c", "#6b4423",
                    "#3b2a0c", "#8a6a1e", "#b8932e", "#e0c457",
                    "#2c1d14", "#6e5038", "#8c6a4c", "#a8845f", "#c4a37a", "#e0c69c"],
        "details": "fossils",
        "portal": {"wood": (32, 0.9, 1.15), "glow": 45, "stone": "#c4a070"},
    },
    # Crystal cavern: blue slate, glowing cyan tufts, pink crystal slabs.
    "crystal": {
        "palette": ["#0c0d1a", "#1f2340", "#2e3459", "#383f69", "#4a5380", "#66709c",
                    "#1c2440", "#2c4c6a", "#4f8fa6", "#252a4a",
                    "#0c2a33", "#1f8a9a", "#3fd0d8", "#b4fbff",
                    "#1e0c22", "#5e2f5e", "#844a84", "#a466a0", "#c88ec0", "#ecc8e4"],
        "details": "crystals",
        "portal": {"wood": (225, 0.7, 0.9), "glow": 185, "stone": "#7078a8"},
    },
    # Snowfield: frozen blue rock under snow, blocks of ice.
    "snow": {
        "palette": ["#141c26", "#3b4a5c", "#56687e", "#63778e", "#7b90a8", "#9fb4c8",
                    "#2e3a48", "#8597ab", "#c2d0de", "#2a3442",
                    "#3a4c63", "#b5c8dc", "#e4eef7", "#ffffff",
                    "#10304a", "#5aa0c8", "#7cc0e0", "#9ed6f0", "#c4ecfa", "#f0fcff"],
        "details": None,
        "portal": {"wood": (205, 0.35, 1.1), "glow": 195, "stone": "#b8c8dc"},
    },
    # Volcano: black basalt with glowing embers and a crust of lava on top,
    # obsidian slabs.
    "basalt": {
        "palette": ["#0c0808", "#241a18", "#342624", "#3e2e2a", "#52403a", "#6a524a",
                    "#4a1a10", "#8a3418", "#c8642a", "#8a2a10",
                    "#2a0c06", "#a8320e", "#e8661a", "#ffc04a",
                    "#050408", "#2a2238", "#3a3050", "#4a4064", "#6a5e8a", "#9a90c0"],
        "details": None,
        "portal": {"wood": (10, 0.55, 0.55), "glow": 22, "stone": "#4a3a38"},
    },
    # City: old red brick and rubble with moss, steel-grey concrete.
    "city": {
        "palette": ["#1e0f0c", "#5a2a22", "#7a3a2c", "#8a4634", "#a65a42", "#c07a5c",
                    "#3a3436", "#5e585a", "#8a8486", "#4a2a20",
                    "#1a2414", "#3e5a2a", "#5a7a36", "#86a64e",
                    "#0e1016", "#3a404c", "#4e5664", "#646c7c", "#828a9a", "#aab2c2"],
        "details": None,
        "portal": {"wood": (220, 0.25, 0.9), "glow": 50, "stone": "#7a8290"},
    },
    # Another planet: purple soil, teal pebbles, glowing cyan moss, dark
    # teal crystal slabs.
    "alien": {
        "palette": ["#14081e", "#3e1a4e", "#5a2a6a", "#6a3478", "#844a92", "#a26ab0",
                    "#1a4a4e", "#2a7a7a", "#4ab0a6", "#2a1438",
                    "#062a26", "#16806e", "#2ad6b0", "#a8ffe8",
                    "#06141a", "#123a44", "#1a5058", "#22666e", "#3a8a8e", "#6ac2c0"],
        "details": None,
        "portal": {"wood": (285, 0.6, 0.8), "glow": 165, "stone": "#6a4a82"},
    },
    # Space: grey-brown asteroid rock with pale dust on top, bright metal
    # plates.
    "station": {
        "palette": ["#0c0a0a", "#2e2826", "#443c38", "#504842", "#665c54", "#80766c",
                    "#22201e", "#3a3634", "#5a5450", "#2a2420",
                    "#1e1c1c", "#6a6460", "#8e8882", "#b8b2aa",
                    "#0a0c12", "#4a5262", "#64708a", "#7c88a2", "#9aa6bc", "#c8d2e2"],
        "details": None,
        "portal": {"wood": (210, 0.3, 1.0), "glow": 200, "stone": "#9aa6bc"},
    },
}


def rgb(hex_colour):
    return base.rgb(hex_colour)


def default_terrain_images():
    """The default block art, by file name, exactly as build_terrain_art.py
    draws it (ladder and brick are wood in every setting, so not here)."""
    images = {"terrain_atlas": base.build_atlas([base.earth_interior(), base.concrete_interior()])}
    floor = base.earth_floor()
    images["earth_floor"] = floor
    images["earth_floor_dug"] = base.earth_floor_dug()
    wall = base.earth_wall_left()
    images["earth_wall_left"] = wall
    images["earth_wall_right"] = base.mirror(wall)
    images["earth_ceiling"] = base.earth_ceiling()
    corner = base.earth_corner_left(floor)
    images["earth_corner_left"] = corner
    images["earth_corner_right"] = base.mirror(corner)
    images["earth_details"] = base.earth_details()
    floor = base.concrete_floor()
    images["concrete_floor"] = floor
    images["concrete_wall_left"] = base.concrete_wall_left()
    images["concrete_wall_right"] = base.concrete_wall_right()
    images["concrete_ceiling"] = base.concrete_ceiling()
    images["concrete_corner_left"] = base.concrete_corner_left(floor)
    images["concrete_corner_right"] = base.concrete_corner_right(floor)
    return images


def recolour(image, mapping):
    out = image.copy()
    pixels = out.load()
    for y in range(out.height):
        for x in range(out.width):
            r, g, b, a = pixels[x, y]
            if a == 0:
                continue
            new = mapping.get((r, g, b, 255)) or mapping.get((r, g, b))
            if new is not None:
                pixels[x, y] = (new[0], new[1], new[2], a)
    return out


def palette_mapping(theme):
    mapping = {}
    for name, hex_colour in zip(PALETTE_NAMES, theme["palette"]):
        old = getattr(base, name)
        mapping[tuple(old[:3])] = rgb(hex_colour)
    return mapping


def themed_colour(theme, name):
    return rgb(theme["palette"][PALETTE_NAMES.index(name)])


# ---------------------------------------------------------------------------
# Buried details drawn per theme (same sheet layout as earth_details.png)
# ---------------------------------------------------------------------------

def crystal_details(theme):
    """Clusters of small glowing crystals, a vein and a geode, in the cyan of
    the tufts, so the cavern's walls glint."""
    sheet = base.new(base.DETAIL_WIDTH * 4, base.DETAIL_HEIGHT)
    outline = themed_colour(theme, "GRASS_OUTLINE")
    dark = themed_colour(theme, "GRASS_DARK")
    mid = themed_colour(theme, "GRASS")
    light = themed_colour(theme, "GRASS_LIGHT")

    def crystal(ox, bottom, height):
        for y in range(height):
            put = base.put
            put(sheet, ox, bottom - y, mid if y < height - 1 else light)
            put(sheet, ox + 1, bottom - y, dark)
            put(sheet, ox - 1, bottom - y, outline)
            put(sheet, ox + 2, bottom - y, outline)
        base.put(sheet, ox, bottom - height, outline)
        base.put(sheet, ox + 1, bottom - height, outline)

    crystal(2, 7, 5)
    crystal(5, 7, 3)
    crystal(base.DETAIL_WIDTH + 4, 7, 6)
    for x, y in [(0, 6), (1, 5), (2, 5), (3, 4), (4, 4), (5, 3), (6, 3), (7, 2), (8, 2)]:
        base.put(sheet, base.DETAIL_WIDTH * 2 + x, y, dark)
        base.put(sheet, base.DETAIL_WIDTH * 2 + x, y - 1, light if x % 3 == 0 else mid)
    ox = base.DETAIL_WIDTH * 3
    for x, y in [(3, 1), (4, 1), (5, 1), (2, 2), (6, 2), (2, 3), (6, 3), (2, 4), (6, 4), (3, 5), (4, 5), (5, 5)]:
        base.put(sheet, ox + x, y, outline)
    for x, y in [(3, 2), (4, 2), (5, 2), (3, 3), (5, 3), (3, 4), (4, 4), (5, 4)]:
        base.put(sheet, ox + x, y, mid)
    base.put(sheet, ox + 4, 3, light)
    return sheet


def fossil_details(theme):
    """A spiral shell, a small bone, a stone and a darker patch: things
    buried in the sand."""
    sheet = base.new(base.DETAIL_WIDTH * 4, base.DETAIL_HEIGHT)
    outline = themed_colour(theme, "EARTH_DARK")
    bone = rgb("#efe2c4")
    shade = rgb("#cdb894")
    for x, y in [(3, 1), (4, 1), (5, 1), (2, 2), (6, 2), (2, 3), (4, 3), (6, 3), (2, 4), (4, 4), (5, 4), (6, 4), (3, 5), (4, 5), (5, 5)]:
        base.put(sheet, x, y, outline)
    for x, y in [(3, 2), (4, 2), (5, 2), (3, 3), (5, 3), (3, 4)]:
        base.put(sheet, x, y, bone)
    ox = base.DETAIL_WIDTH
    for x in range(1, 8):
        base.put(sheet, ox + x, 3, bone)
        base.put(sheet, ox + x, 4, shade)
    for x, y in [(0, 2), (0, 5), (8, 2), (8, 5), (1, 2), (7, 5)]:
        base.put(sheet, ox + x, y, bone)
    ox = base.DETAIL_WIDTH * 2
    for y in range(2, 6):
        for x in range(2, 7):
            base.put(sheet, ox + x, y, themed_colour(theme, "PEBBLE"))
    for x in range(2, 7):
        base.put(sheet, ox + x, 1, themed_colour(theme, "PEBBLE_DARK"))
        base.put(sheet, ox + x, 6, themed_colour(theme, "PEBBLE_DARK"))
    base.put(sheet, ox + 3, 2, themed_colour(theme, "PEBBLE_LIGHT"))
    ox = base.DETAIL_WIDTH * 3
    for x, y in [(2, 3), (3, 3), (4, 3), (5, 3), (3, 4), (4, 4), (5, 4), (6, 4), (4, 5)]:
        base.put(sheet, ox + x, y, themed_colour(theme, "EARTH_MID"))
    return sheet


DETAIL_PAINTERS = {"crystals": crystal_details, "fossils": fossil_details}


# ---------------------------------------------------------------------------
# Entrance and exit, by hue band
# ---------------------------------------------------------------------------

def recolour_portal(image, spec):
    wood_hue, wood_sat, wood_val = spec["wood"]
    glow_hue = spec["glow"] / 360.0
    stone = rgb(spec["stone"])
    stone_h, stone_s, _ = colorsys.rgb_to_hsv(stone[0] / 255.0, stone[1] / 255.0, stone[2] / 255.0)
    out = image.copy()
    pixels = out.load()
    for y in range(out.height):
        for x in range(out.width):
            r, g, b, a = pixels[x, y]
            if a == 0:
                continue
            h, s, v = colorsys.rgb_to_hsv(r / 255.0, g / 255.0, b / 255.0)
            degrees = h * 360.0
            if v < 0.16:
                continue                      # outlines and the dark hole
            if s < 0.18:
                # Stone and iron: take the theme's stone hue, keep the shading.
                h, s = stone_h, min(1.0, stone_s * (0.6 + s * 2.0))
            elif 10.0 <= degrees <= 50.0:
                h = wood_hue / 360.0
                s = min(1.0, s * wood_sat)
                v = min(1.0, v * wood_val)
            elif 60.0 <= degrees <= 260.0:
                h = glow_hue                  # the blue mouth and the green light
            nr, ng, nb = colorsys.hsv_to_rgb(h, s, v)
            pixels[x, y] = (int(nr * 255), int(ng * 255), int(nb * 255), a)
    return out


def portal_frames():
    frames = {}
    for prefix, count in PORTAL_PREFIXES:
        for index in range(count):
            name = "%s_%d" % (prefix, index)
            frames[name] = Image.open(os.path.join(PORTAL_DIR, name + ".png")).convert("RGBA")
    return frames


def preview(themed, path):
    """Every theme side by side at 3x: a little scene of blocks with floor,
    walls, ceiling, concrete, the entrance and the exit."""
    scale = 3
    cell = base.TILE
    width, height = cell * 7, cell * 5
    sheet = Image.new("RGBA", (width * len(themed) * scale, height * scale), (40, 40, 48, 255))
    for column, (name, images) in enumerate(themed.items()):
        scene = Image.new("RGBA", (width, height), (90, 110, 140, 255))
        atlas = images["terrain_atlas"]
        earth = atlas.crop((0, 0, cell, cell))
        concrete = atlas.crop((0, cell, cell, cell * 2))
        for x in range(7):
            scene.alpha_composite(earth, (x * cell, 4 * cell))
            scene.alpha_composite(images["earth_floor"], (x * cell, 4 * cell - base.FLOOR_OVERHANG))
        scene.alpha_composite(concrete, (5 * cell, 3 * cell))
        scene.alpha_composite(images["concrete_floor"], (5 * cell, 3 * cell - base.FLOOR_OVERHANG))
        scene.alpha_composite(earth, (0, 2 * cell))
        scene.alpha_composite(images["earth_floor"], (0, 2 * cell - base.FLOOR_OVERHANG))
        scene.alpha_composite(images["earth_ceiling"], (0, 3 * cell - base.CEILING_STRIP_HEIGHT + base.CEILING_OVERHANG + 1))
        scene.alpha_composite(images["entrance_idle_0"], (cell, 0))
        scene.alpha_composite(images["exit_idle_0"], (3 * cell, 4 * cell - 56))
        sheet.alpha_composite(scene.resize((width * scale, height * scale), Image.NEAREST), (column * width * scale, 0))
    sheet.save(path)


def main():
    terrain = default_terrain_images()
    portals = portal_frames()
    themed_previews = {}
    for name, theme in THEMES.items():
        mapping = palette_mapping(theme)
        terrain_out = os.path.join(TERRAIN_DIR, "themes", name)
        portal_out = os.path.join(PORTAL_DIR, "themes", name)
        os.makedirs(terrain_out, exist_ok=True)
        os.makedirs(portal_out, exist_ok=True)
        images = {}
        for file_name, image in terrain.items():
            themed = recolour(image, mapping)
            if file_name == "earth_details" and theme["details"]:
                themed = DETAIL_PAINTERS[theme["details"]](theme)
            themed.save(os.path.join(terrain_out, file_name + ".png"))
            images[file_name] = themed
        for file_name, image in portals.items():
            themed = recolour_portal(image, theme["portal"])
            themed.save(os.path.join(portal_out, file_name + ".png"))
            images[file_name] = themed
        themed_previews[name] = images
    print("themes written:", ", ".join(THEMES))
    if len(sys.argv) > 1:
        preview(themed_previews, sys.argv[1])
        print("preview written to", sys.argv[1])


if __name__ == "__main__":
    main()
