"""Builds one sprite set and one SpriteFrames resource per roguelike character.

    python tools/build_character_variants.py [preview.png]

Every frame the lemming uses (read from the "wizard_placeholder" SpriteFrames
in scenes/characters/lemming.tscn, so a new animation is picked up without
touching this script) is copied for each character with:
  * the purple robe and hood recoloured to the character's hue. The purple is
    a ramp of a few flat tones; each pixel is mapped by its brightness onto a
    matching ramp in the character's hue (the same ramp the card portraits in
    build_card_art.py use), so the shading survives. Outline, the dark face
    opening, eyes, skin, backpack, tools and the parachute are not purple and
    are left alone;
  * a small accessory (miner: hood lamp, engineer: wrench tucked behind the
    head, scout: feather in the hood, tinkerer: goggles) drawn on the art
    grid. Its position is found per frame from the pixels: the eyes give the
    face, the dark opening above them gives the brim, the first opaque pixel
    of a column gives the hood top. Where the eyes sit inside the hood tells
    side view from front view; no eyes means the back view (vertical ladder).

Output:
  assets/sprites/characters/<id>/<same file names as the wizard frames>
  resources/sprite_frames/<id>.tres  (wizard.tres points at the wizard frames)

The ids, colours and accessories match modes/roguelike/scripts/characters/
character_catalog.gd and the card portraits. Deterministic: no randomness.
"""

import colorsys
import re
import sys
from pathlib import Path

import numpy as np
from PIL import Image

PROJECT = Path(__file__).resolve().parent.parent
CHARACTER_DIR = PROJECT / "assets/sprites/characters"
SPRITE_FRAMES_DIR = PROJECT / "resources/sprite_frames"
LEMMING_SCENE = PROJECT / "scenes/characters/lemming.tscn"
SOURCE_CHARACTER = "wizard"
SOURCE_SPRITE_FRAMES = "wizard_placeholder"

# One art pixel of the wizard art is 7 source pixels (see wizard_art.py); at
# the in-game scale of 0.15 that is about one screen pixel.
ART_PIXEL = 7

OUTLINE = (25, 14, 32, 255)

# Colours from character_catalog.gd.
CHARACTERS = {
    "miner": (0.95, 0.55, 0.2),
    "engineer": (1.0, 0.85, 0.2),
    "scout": (0.35, 0.85, 0.4),
    "tinkerer": (0.3, 0.8, 1.0),
}

# --- Recolour ---------------------------------------------------------------

# Which pixels are robe: purple hue, clearly saturated, brighter than the
# near-black outline and face opening (value ~0.11-0.16, also purple-ish).
ROBE_HUE_RANGE = (235.0, 315.0)
ROBE_MIN_SATURATION = 0.3
ROBE_MIN_VALUE = 0.19

# The wizard robe's flat tones by HSV value (deep shadow, shade, base,
# highlight sleeve) and which tone of the character ramp each one becomes.
# Values in between are interpolated, so the few blended edge pixels of the
# rotated frames still land between the right two tones.
WIZARD_TONE_VALUES = [0.19, 0.27, 0.34, 0.48, 0.62, 0.80]
RAMP_INDEX_FOR_TONE = ["edge", 4, 3, 2, 1, 0]

# Saturation factor and value of each ramp tone, highlight to deepest shade.
# Same numbers as hood_ramp() in build_card_art.py, so sprite and portrait
# share the colours.
RAMP_TONES = ((0.55, 1.0), (0.78, 0.92), (0.9, 0.76), (0.95, 0.54), (0.95, 0.34))
# The darkest robe pixels sit against the outline; they get the deepest tone
# pulled this far towards the outline, so the edge stays soft.
EDGE_DARKEN = 0.55


def hood_ramp(colour):
    hue, saturation, _ = colorsys.rgb_to_hsv(*colour)
    tones = []
    for s_factor, value in RAMP_TONES:
        r, g, b = colorsys.hsv_to_rgb(hue, saturation * s_factor, value)
        tones.append(np.array([r * 255, g * 255, b * 255]))
    return tones


def hsv_arrays(pixels):
    """Hue in degrees, saturation and value of an RGBA uint8 array."""
    rgb = pixels[:, :, :3].astype(float) / 255.0
    maximum = rgb.max(axis=2)
    minimum = rgb.min(axis=2)
    delta = maximum - minimum
    saturation = np.where(maximum > 0, delta / np.maximum(maximum, 1e-9), 0.0)
    red, green, blue = rgb[:, :, 0], rgb[:, :, 1], rgb[:, :, 2]
    safe = np.maximum(delta, 1e-9)
    hue = np.where(
        maximum == red, (green - blue) / safe % 6,
        np.where(maximum == green, (blue - red) / safe + 2, (red - green) / safe + 4),
    ) * 60.0
    hue = np.where(delta > 0, hue, 0.0)
    return hue, saturation, maximum


def robe_mask(pixels):
    hue, saturation, value = hsv_arrays(pixels)
    return (
        (pixels[:, :, 3] > 0)
        & (hue >= ROBE_HUE_RANGE[0]) & (hue <= ROBE_HUE_RANGE[1])
        & (saturation >= ROBE_MIN_SATURATION)
        & (value >= ROBE_MIN_VALUE)
    )


def recolour(pixels, colour):
    ramp = hood_ramp(colour)
    anchors = []
    for index in RAMP_INDEX_FOR_TONE:
        if index == "edge":
            anchors.append(ramp[4] * (1 - EDGE_DARKEN) + np.array(OUTLINE[:3]) * EDGE_DARKEN)
        else:
            anchors.append(ramp[index])
    anchors = np.array(anchors)
    mask = robe_mask(pixels)
    _, _, value = hsv_arrays(pixels)
    values = value[mask]
    result = np.zeros((values.size, 3))
    for channel in range(3):
        result[:, channel] = np.interp(values, WIZARD_TONE_VALUES, anchors[:, channel])
    out = pixels.copy()
    out[mask, :3] = np.clip(np.round(result), 0, 255).astype(np.uint8)
    return out


# --- Landmarks --------------------------------------------------------------


class Landmarks:
    """Where the head is in one frame, all in source pixels.

    view: "side" (facing right), "front" or "back".
    eye_box: (left, top, right, bottom) of the yellow eyes, None from the back.
    centre_x: the column the accessory is centred on (middle of the eyes, or
        of the hood from the back).
    hood_top: first opaque row in centre_x.
    face_top: top of the dark face opening above the eyes (the brim's lower
        edge); from the back, a few cells below the hood top.
    phase: (x, y) offset of the art grid in this frame, so accessories land
        on the same 7px cells as the art.
    """


def eye_mask(pixels):
    red = pixels[:, :, 0].astype(int)
    green = pixels[:, :, 1].astype(int)
    blue = pixels[:, :, 2].astype(int)
    return (pixels[:, :, 3] > 128) & (red > 200) & (green > 150) & (blue < 110)


def dark_mask(pixels):
    _, _, value = hsv_arrays(pixels)
    return (pixels[:, :, 3] > 128) & (value < ROBE_MIN_VALUE)


def find_landmarks(pixels):
    opaque = pixels[:, :, 3] > 128
    eyes = eye_mask(pixels)
    robe = robe_mask(pixels)
    found = Landmarks()
    eye_rows, eye_columns = np.where(eyes)
    if eye_rows.size < 20:
        # Back view: the head is the robe-coloured blob at the top.
        robe_rows, robe_columns = np.where(robe)
        top = robe_rows.min()
        band = robe[top:top + 6 * ART_PIXEL]
        columns = np.where(band.any(axis=0))[0]
        found.view = "back"
        found.eye_box = None
        found.centre_x = int((columns.min() + columns.max()) // 2)
        found.hood_top = int(np.where(opaque[:, found.centre_x])[0].min())
        found.face_top = found.hood_top + 4 * ART_PIXEL
        found.hood_left = int(columns.min())
        found.hood_right = int(columns.max())
        found.phase = (int(columns.min()) % ART_PIXEL, int(top) % ART_PIXEL)
        return found
    left, top = int(eye_columns.min()), int(eye_rows.min())
    right, bottom = int(eye_columns.max()) + 1, int(eye_rows.max()) + 1
    found.eye_box = (left, top, right, bottom)
    found.centre_x = (left + right) // 2
    found.phase = (left % ART_PIXEL, top % ART_PIXEL)
    # Hood extent on the eye row: opaque run containing the eyes. Side views
    # have the eyes in the front (right) part of the hood.
    row = opaque[(top + bottom) // 2]
    hood_left = found.centre_x
    while hood_left > 0 and row[hood_left - 1]:
        hood_left -= 1
    hood_right = found.centre_x
    while hood_right < row.size - 1 and row[hood_right + 1]:
        hood_right += 1
    # The backpack touches the hood on the left in side views; only count
    # columns whose top is robe, not the pack, by using the robe band above.
    above = robe[max(0, top - 6 * ART_PIXEL):top]
    robe_columns = np.where(above.any(axis=0))[0]
    if robe_columns.size:
        hood_left = max(hood_left, int(robe_columns.min()))
        hood_right = min(hood_right, int(robe_columns.max()))
    found.hood_left, found.hood_right = hood_left, hood_right
    relative = (found.centre_x - hood_left) / max(1, hood_right - hood_left)
    found.view = "front" if 0.38 <= relative <= 0.62 else "side"
    found.hood_top = int(np.where(opaque[:, found.centre_x])[0].min())
    # Climb up from the eyes through the dark opening to the brim.
    dark = dark_mask(pixels)
    y = top - 1
    while y > found.hood_top and (dark[y, found.centre_x] or eyes[y, found.centre_x]):
        y -= 1
    found.face_top = y + 1
    return found


# --- Accessories --------------------------------------------------------------

# Accessory colours, picked to read against both the dark outline and every
# hood colour at about one screen pixel per cell.
LAMP_BODY = (150, 152, 168, 255)
# Paler than the eyes' yellow, so a front-facing lamp is not read as a
# third eye.
LAMP_LIGHT = (255, 250, 200, 255)
STRAP = (64, 36, 28, 255)
BRASS = (222, 170, 60, 255)
LENS = (190, 240, 255, 255)
METAL = (150, 152, 168, 255)
METAL_LIGHT = (205, 207, 218, 255)
FEATHER = (240, 236, 222, 255)
FEATHER_TIP = (196, 58, 58, 255)
QUILL = (160, 78, 52, 255)

PALETTE = {
    "L": LAMP_LIGHT, "M": METAL, "H": METAL_LIGHT, "S": STRAP, "B": BRASS,
    "G": LENS, "F": FEATHER, "T": FEATHER_TIP, "Q": QUILL, "O": OUTLINE,
}

# Patterns, one character per art cell, "." empty. Side patterns face right.
# Each gets a one-cell outline when drawn.
# A 2x2 light: one cell of light was lost in the outline at game scale.
LAMP_SIDE = ["MLL", "MLL"]
LAMP_FRONT = ["MLLM", "MLLM"]
# Two round lenses of 2x2 cells in brass rims: a 1-cell lens with a flat
# rim read as a single tan bar in game.
GOGGLES_FRONT = [
    ".BB.BB.",
    "BGGBGGB",
    "BGGBGGB",
    ".BB.BB.",
]
# In profile only the near lens shows, with the strap running back.
GOGGLES_SIDE = [
    "..BB.",
    "SBGGB",
    "SBGGB",
    "..BB.",
]
STRAP_BACK = ["S"]
FEATHER_SIDE = [
    "..TT",
    ".FT.",
    ".F..",
    "FF..",
    "F...",
    "Q...",
]
FEATHER_FRONT = [
    ".T",
    "FT",
    "F.",
    "F.",
    "Q.",
]
# Leaning back out of the hood, open jaw up and away from the face. The
# bottom-right cell is the end pushed into the hood.
WRENCH = [
    "H.H...",
    "HHH...",
    ".HH...",
    "...M..",
    "....M.",
    ".....M",
]


class Stamp:
    """A pattern placed at a source-pixel position (its top-left cell)."""

    def __init__(self, pattern, x, y, layer="front", over_robe_only=False):
        self.pattern = pattern
        self.x = x
        self.y = y
        # "front": drawn over the robe; "behind": only fills transparent
        # pixels, so it reads as tucked behind the head.
        self.layer = layer
        self.over_robe_only = over_robe_only


def pattern_size(pattern):
    return len(pattern[0]), len(pattern)


def snap(value, phase):
    return int(round((value - phase) / ART_PIXEL)) * ART_PIXEL + phase


def squash(pattern, factor):
    """Drops rows so a pattern flattens with a squashed body (death frames)."""
    if factor >= 0.95:
        return pattern
    rows = max(1, round(len(pattern) * factor))
    return [pattern[min(len(pattern) - 1, int(i * len(pattern) / rows))] for i in range(rows)]


def hood_band_rows(found):
    """Height of the brim (hood top to face opening) in cells."""
    return max(1, (found.face_top - found.hood_top) // ART_PIXEL)


def lamp_stamps(found, squash_factor):
    if found.view == "back":
        return strap_stamps(found, STRAP)
    pattern = squash(LAMP_SIDE if found.view == "side" else LAMP_FRONT, squash_factor)
    width, height = pattern_size(pattern)
    # Sit on the brim, just above the face opening, centred on the eyes
    # (pushed a cell forward in side view, where the brim leans out).
    x = found.centre_x - width * ART_PIXEL // 2
    if found.view == "side":
        x += ART_PIXEL
    y = found.face_top - height * ART_PIXEL
    y = max(y, found.hood_top + ART_PIXEL)
    return [Stamp(pattern, x, y)]


def goggles_stamps(found, squash_factor):
    if found.view == "back":
        return strap_stamps(found, STRAP)
    pattern = squash(GOGGLES_SIDE if found.view == "side" else GOGGLES_FRONT, squash_factor)
    width, height = pattern_size(pattern)
    x = found.centre_x - width * ART_PIXEL // 2
    if found.view == "side":
        x += ART_PIXEL
    # Lower lens row overlaps the top of the face opening, like goggles
    # pushed up on the forehead.
    y = found.face_top - (height - 1) * ART_PIXEL
    y = max(y, found.hood_top)
    return [Stamp(pattern, x, y)]


def strap_stamps(found, colour_unused):
    """From the back only the strap of a lamp or goggles shows: a band across
    the hood, painted on robe pixels only so it follows the hood's outline."""
    y = found.hood_top + 3 * ART_PIXEL
    width_cells = (found.hood_right - found.hood_left) // ART_PIXEL + 1
    pattern = ["S" * width_cells]
    return [Stamp(pattern, found.hood_left, y, over_robe_only=True)]


def feather_stamps(found, squash_factor):
    if found.view == "side":
        pattern = squash(FEATHER_SIDE, squash_factor)
        width, height = pattern_size(pattern)
        # Quill in the hood top, a little behind the face, leaning forward.
        x = found.centre_x - 2 * ART_PIXEL
        top = column_top(found, x)
        return [Stamp(pattern, x, top - (height - 2) * ART_PIXEL)]
    pattern = squash(FEATHER_FRONT, squash_factor)
    width, height = pattern_size(pattern)
    # Front and back: on the right side of the hood top, as on the card.
    x = found.centre_x + (found.hood_right - found.centre_x) // 2
    top = column_top(found, x)
    return [Stamp(pattern, x, top - (height - 2) * ART_PIXEL)]


def wrench_stamps(found, squash_factor):
    pattern = squash(WRENCH, squash_factor)
    width, height = pattern_size(pattern)
    # Tucked behind the head: the handle end goes into the hood top a few
    # cells behind the face (side view) or left of centre (front, back).
    if found.view == "side":
        root_x = found.centre_x - 3 * ART_PIXEL
    else:
        root_x = found.centre_x - 2 * ART_PIXEL
    # Only the last cell goes into the hood, so jaw and handle both show.
    root_y = column_top(found, root_x) + ART_PIXEL
    x = root_x - (width - 1) * ART_PIXEL
    y = root_y - (height - 1) * ART_PIXEL
    # Frames whose hood nearly touches the top of the canvas would cut the
    # jaw off: push the wrench further into the hood instead.
    y = max(y, found.phase[1] + ART_PIXEL)
    # From the back it is in plain sight, over the hood.
    layer = "front" if found.view == "back" else "behind"
    return [Stamp(pattern, x, y, layer=layer)]


ACCESSORIES = {
    "miner": lamp_stamps,
    "engineer": wrench_stamps,
    "scout": feather_stamps,
    "tinkerer": goggles_stamps,
}


def column_top(found, x):
    """First opaque row of column x (set by draw_accessory before placing)."""
    x = int(np.clip(x, 0, found.opaque.shape[1] - 1))
    rows = np.where(found.opaque[:, x])[0]
    return int(rows.min()) if rows.size else found.hood_top


def draw_stamp(pixels, stamp, phase, robe, source_opaque):
    pattern = stamp.pattern
    width, height = pattern_size(pattern)
    origin_x = snap(stamp.x, phase[0])
    origin_y = snap(stamp.y, phase[1])
    # Keep the whole accessory, outline included, inside the canvas: the
    # walk frames leave only a few cells above the hood. Pushed down, it
    # simply sits deeper in the hood.
    origin_y = max(origin_y, phase[1] + ART_PIXEL)
    cells = np.zeros((height + 2, width + 2, 4), dtype=np.uint8)
    for row, line in enumerate(pattern):
        for column, char in enumerate(line):
            if char != ".":
                cells[row + 1, column + 1] = PALETTE[char]
    if not stamp.over_robe_only:
        solid = cells[:, :, 3] > 0
        grown = solid.copy()
        grown[1:, :] |= solid[:-1, :]
        grown[:-1, :] |= solid[1:, :]
        grown[:, 1:] |= solid[:, :-1]
        grown[:, :-1] |= solid[:, 1:]
        cells[grown & ~solid] = OUTLINE
        origin_x -= ART_PIXEL
        origin_y -= ART_PIXEL
    else:
        cells = cells[1:-1, 1:-1]
    layer = np.kron(cells, np.ones((ART_PIXEL, ART_PIXEL, 1), dtype=np.uint8))
    frame_height, frame_width = pixels.shape[:2]
    for dy in range(layer.shape[0]):
        y = origin_y + dy
        if not 0 <= y < frame_height:
            continue
        for dx in range(layer.shape[1]):
            x = origin_x + dx
            if not 0 <= x < frame_width or layer[dy, dx, 3] == 0:
                continue
            if stamp.over_robe_only and not robe[y, x]:
                continue
            if stamp.layer == "behind" and source_opaque[y, x]:
                continue
            if stamp.layer == "front" and not stamp.over_robe_only and blocks_accessory(pixels[y, x], robe[y, x]):
                continue
            pixels[y, x] = layer[dy, dx]


def blocks_accessory(pixel, is_robe):
    """Tools, hands and props held in front of the hood stay in front of the
    accessory: only robe, outline, the dark face and empty pixels are drawn
    over."""
    if pixel[3] < 128 or is_robe:
        return False
    red, green, blue = int(pixel[0]), int(pixel[1]), int(pixel[2])
    return max(red, green, blue) >= 0.19 * 255


def draw_accessory(pixels, character_id, found, squash_factor, source_pixels):
    found.opaque = source_pixels[:, :, 3] > 128
    robe = robe_mask(source_pixels)
    for stamp in ACCESSORIES[character_id](found, squash_factor):
        draw_stamp(pixels, stamp, found.phase, robe, found.opaque)


# --- SpriteFrames -------------------------------------------------------------


def parse_sprite_frames(scene_text, resource_name):
    """(ext_resource paths by id, animations) of the SpriteFrames whose
    resource_name matches, as written in the scene."""
    paths = dict(
        (match.group(2), match.group(1))
        for match in re.finditer(r'\[ext_resource type="Texture2D"[^\]]*?path="([^"]+)" id="([^"]+)"\]', scene_text)
    )
    block_match = re.search(
        r'\[sub_resource type="SpriteFrames"[^\]]*\]\s*resource_name = "%s"\s*animations = (\[.*?\}\])\s*\n(?=\[|\Z)' % re.escape(resource_name),
        scene_text, re.S,
    )
    assert block_match, "SpriteFrames '%s' not found in %s" % (resource_name, LEMMING_SCENE)
    block = block_match.group(1)
    animations = []
    pattern = re.compile(
        r'\{\s*"frames": \[(.*?)\],\s*"loop": (true|false),\s*"name": &"([^"]+)",\s*"speed": ([0-9.]+)\s*\}', re.S)
    for match in pattern.finditer(block):
        frames = [
            (duration, paths[resource_id])
            for duration, resource_id in re.findall(r'"duration": ([0-9.]+),\s*"texture": ExtResource\("([^"]+)"\)', match.group(1))
        ]
        animations.append({"name": match.group(3), "loop": match.group(2), "speed": match.group(4), "frames": frames})
    assert animations and len(animations) == block.count('"name": &'), "Could not parse every animation of %s" % resource_name
    return animations


def write_sprite_frames(character_id, animations, path):
    """A text SpriteFrames resource in the same layout Godot writes inside a
    scene, with textures pointing at the character's folder."""
    texture_ids = {}
    lines_ext = []
    for animation in animations:
        for _, texture in animation["frames"]:
            target = texture.replace("/characters/%s/" % SOURCE_CHARACTER, "/characters/%s/" % character_id)
            if target not in texture_ids:
                stem = Path(target).stem
                texture_ids[target] = "%d_%s" % (len(texture_ids) + 1, stem)
                lines_ext.append('[ext_resource type="Texture2D" path="%s" id="%s"]' % (target, texture_ids[target]))
    chunks = []
    for animation in animations:
        frames = []
        for duration, texture in animation["frames"]:
            target = texture.replace("/characters/%s/" % SOURCE_CHARACTER, "/characters/%s/" % character_id)
            frames.append('{\n"duration": %s,\n"texture": ExtResource("%s")\n}' % (duration, texture_ids[target]))
        chunks.append('{\n"frames": [%s],\n"loop": %s,\n"name": &"%s",\n"speed": %s\n}' % (
            ", ".join(frames), animation["loop"], animation["name"], animation["speed"]))
    text = '[gd_resource type="SpriteFrames" format=3]\n\n%s\n\n[resource]\nresource_name = "%s"\nanimations = [%s]\n' % (
        "\n".join(lines_ext), character_id, ", ".join(chunks))
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text, encoding="utf-8", newline="\n")


# --- Build --------------------------------------------------------------------


def frame_files(animations):
    files = []
    for animation in animations:
        for _, texture in animation["frames"]:
            name = Path(texture).name
            if name not in files:
                files.append(name)
    return files


def reference_brim(files):
    """Brim height of the first walk frame: frames whose brim is much lower
    (the squashed death frames) get their accessory squashed to match."""
    reference = next((name for name in files if name.startswith("walk")), files[0])
    pixels = np.array(Image.open(CHARACTER_DIR / SOURCE_CHARACTER / reference).convert("RGBA"))
    found = find_landmarks(pixels)
    return found.face_top - found.hood_top


def build_character(character_id, files, reference):
    colour = CHARACTERS[character_id]
    out_dir = CHARACTER_DIR / character_id
    out_dir.mkdir(parents=True, exist_ok=True)
    report = []
    for name in files:
        source = np.array(Image.open(CHARACTER_DIR / SOURCE_CHARACTER / name).convert("RGBA"))
        found = find_landmarks(source)
        factor = 1.0
        if found.view != "back":
            factor = min(1.0, max(0.4, (found.face_top - found.hood_top) / max(1, reference)))
        pixels = recolour(source, colour)
        draw_accessory(pixels, character_id, found, factor, source)
        Image.fromarray(pixels).save(out_dir / name)
        report.append("%s:%s" % (name, found.view))
    return report


# --- Preview --------------------------------------------------------------------

GAME_SCALE = 0.15
PREVIEW_BACKGROUND = (92, 120, 150, 255)


def preview_frame(animation):
    """The frame of each animation shown in the preview: the second one, or
    the second-to-last for the dying animation (the last is nearly flat)."""
    frames = animation["frames"]
    return Path(frames[min(1, len(frames) - 1)][1]).name


def preview_body(image):
    """Frame cropped to the body (and canopy) so every column lines up: the
    float frames have empty rows added at the bottom, see build_float_frames."""
    pad = (image.height - 250) // 2
    if pad > 0:
        return image.crop((0, 0, image.width, image.height - pad))
    return image


def build_preview(animations, path):
    characters = [SOURCE_CHARACTER] + list(CHARACTERS)
    enlarged_scale = 0.5
    zoom = 3
    column = 165
    enlarged_band = 170
    small_band = 155
    row_height = enlarged_band + small_band + 15
    width = column * len(animations) + 20
    height = row_height * len(characters) + 20
    sheet = Image.new("RGBA", (width, height), PREVIEW_BACKGROUND)
    for row, character_id in enumerate(characters):
        for index, animation in enumerate(animations):
            body = preview_body(Image.open(CHARACTER_DIR / character_id / preview_frame(animation)).convert("RGBA"))
            x0 = 10 + index * column
            y0 = 10 + row * row_height
            big = body.resize((round(body.width * enlarged_scale), round(body.height * enlarged_scale)), Image.NEAREST)
            sheet.alpha_composite(big, (x0, y0 + enlarged_band - big.height))
            small = body.resize((round(body.width * GAME_SCALE), round(body.height * GAME_SCALE)), Image.BOX)
            sheet.alpha_composite(small, (x0, y0 + enlarged_band + small_band - small.height))
            zoomed = small.resize((small.width * zoom, small.height * zoom), Image.NEAREST)
            sheet.alpha_composite(zoomed, (x0 + small.width + 6, y0 + enlarged_band + small_band - zoomed.height))
    sheet.save(path)


def main():
    scene_text = LEMMING_SCENE.read_text(encoding="utf-8")
    animations = parse_sprite_frames(scene_text, SOURCE_SPRITE_FRAMES)
    files = frame_files(animations)
    reference = reference_brim(files)
    for character_id in CHARACTERS:
        report = build_character(character_id, files, reference)
        print(character_id, " ".join(report))
    write_sprite_frames(SOURCE_CHARACTER, animations, SPRITE_FRAMES_DIR / ("%s.tres" % SOURCE_CHARACTER))
    for character_id in CHARACTERS:
        write_sprite_frames(character_id, animations, SPRITE_FRAMES_DIR / ("%s.tres" % character_id))
    print("animations:", ", ".join(a["name"] for a in animations))
    if len(sys.argv) > 1:
        build_preview(animations, sys.argv[1])


if __name__ == "__main__":
    main()
