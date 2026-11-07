"""Draws the sprite set and SpriteFrames resource of each roguelike character.

    python tools/build_character_variants.py [preview.png]

The four non-wizard characters (miner, engineer, scout, tinkerer) are drawn
from scratch, each with its own body, from the pixel designs in
tools/character_designs.py. Only the frame contract is shared with the
wizard, so the game code does not change:
  * the animations, frame counts, fps and loop flags are read from the
    "wizard_placeholder" SpriteFrames in scenes/characters/lemming.tscn;
  * every frame has the wizard's file name and canvas (250x250, the float
    frames 250x404 with the extra rows split equally top and bottom), the
    feet on the wizard's floor line and the body centred on the 26x30
    collision box;
  * the tools (shovel, pickaxe, jackhammer, parachute, climbing claws) and
    the dust and chips are drawn by the same functions and with the same
    per-frame poses as the wizard's builders (tools/build_*_frames.py), so
    the timing the gameplay relies on matches. Only the arms holding them
    start from each character's own shoulders.

Everything is drawn on the wizard's art grid (one cell = 7 source pixels,
about one screen pixel in game), each part with a one-cell outline.

Output:
  assets/sprites/characters/<id>/<same file names as the wizard frames>
  resources/sprite_frames/<id>.tres  (wizard.tres points at the wizard frames)

With a path, also writes a preview sheet: one frame of each animation per
character next to the wizard, enlarged and at game scale in 1x and 3x.
Deterministic: no randomness.
"""

import math
import re
import sys
from pathlib import Path

import numpy as np
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))

import build_climb_frames as climb_frames  # noqa: E402
import build_construction_frames as construction_frames  # noqa: E402
import build_death_frames as death_frames  # noqa: E402
import build_dig_frames as dig_frames  # noqa: E402
import build_float_frames as float_frames  # noqa: E402
import build_jackhammer_frames as jackhammer_frames  # noqa: E402
import build_pickaxe_frames as pickaxe_frames  # noqa: E402
import build_rope_frames as rope_frames  # noqa: E402
import wizard_art  # noqa: E402
from character_designs import DESIGNS, FLOOR_ROW, OUTLINE  # noqa: E402
from wizard_art import ART_PIXEL, ArtCanvas, rotate_point  # noqa: E402

PROJECT = Path(__file__).resolve().parent.parent
CHARACTER_DIR = PROJECT / "assets/sprites/characters"
SPRITE_FRAMES_DIR = PROJECT / "resources/sprite_frames"
LEMMING_SCENE = PROJECT / "scenes/characters/lemming.tscn"
SOURCE_CHARACTER = "wizard"
SOURCE_SPRITE_FRAMES = "wizard_placeholder"

FRAME_SIZE = 250
CELLS = -(-FRAME_SIZE // ART_PIXEL)

# --- Cell layers ---------------------------------------------------------------


def blank(rows=CELLS):
    return np.zeros((rows, CELLS, 4), dtype=np.uint8)


def set_cell(layer, row, column, colour):
    if 0 <= row < layer.shape[0] and 0 <= column < layer.shape[1]:
        layer[row, column] = colour


def paint(layer, design, pattern, column, row):
    for dy, line in enumerate(pattern):
        for dx, char in enumerate(line):
            if char != ".":
                set_cell(layer, row + dy, column + dx, design.colour(char))


def outlined(layer):
    """Rings the layer's cells with a one-cell outline."""
    solid = layer[:, :, 3] > 0
    grown = solid.copy()
    grown[1:, :] |= solid[:-1, :]
    grown[:-1, :] |= solid[1:, :]
    grown[:, 1:] |= solid[:, :-1]
    grown[:, :-1] |= solid[:, 1:]
    layer[grown & ~solid] = OUTLINE
    return layer


def over(base, top):
    mask = top[:, :, 3] > 0
    base[mask] = top[mask]
    return base


def line_cells(start, end):
    (col_a, row_a), (col_b, row_b) = start, end
    steps = max(abs(row_b - row_a), abs(col_b - col_a), 1)
    return [(round(col_a + (col_b - col_a) * i / steps), round(row_a + (row_b - row_a) * i / steps))
            for i in range(steps + 1)]


def to_cell(point):
    """Source pixels to the cell ArtCanvas puts them in."""
    return int(round(point[0] / ART_PIXEL)), int(round(point[1] / ART_PIXEL))


def to_pixels(layer, height=FRAME_SIZE):
    image = Image.fromarray(layer, "RGBA")
    big = image.resize((layer.shape[1] * ART_PIXEL, layer.shape[0] * ART_PIXEL), Image.NEAREST)
    return big.crop((0, 0, FRAME_SIZE, height))


def shear(layer, angle, pivot_row):
    """Leans the layer by `angle` degrees (counter-clockwise positive, as PIL
    rotates) about a row, shifting whole rows by whole cells. A real
    rotation of the 7px blocks breaks every edge into steps of 1-6 pixels;
    the shear keeps the cells crisp and is the same to within a cell for
    the few degrees the poses use."""
    if angle == 0:
        return layer
    out = np.zeros_like(layer)
    slope = math.tan(math.radians(angle))
    for row in range(layer.shape[0]):
        shift = round((row - pivot_row) * slope)
        if shift > 0:
            out[row, shift:] = layer[row, :-shift]
        elif shift < 0:
            out[row, :shift] = layer[row, -shift:]
        else:
            out[row] = layer[row]
    return out


def shear_point(point, angle, pivot_row):
    column, row = point
    return column + round((row - pivot_row) * math.tan(math.radians(angle))), row


# --- Body parts ------------------------------------------------------------------


def leg(design, hip, foot_dx, foot_dy, view, rows=CELLS):
    """A leg from the hip down to a boot whose sole is on the floor (raised
    by -foot_dy cells), the boot's heel foot_dx cells from the hip."""
    layer = blank(rows)
    boot = design.boot_side if view == "side" else design.boot_front
    boot_top = FLOOR_ROW - len(boot) + 1 + foot_dy
    hip_column, hip_row = hip
    foot_column = hip_column + foot_dx
    colour = design.colour(design.leg)
    shade = design.legend.get(design.leg.lower())
    for column, row in line_cells((hip_column, hip_row), (foot_column, boot_top)):
        for offset in range(design.leg_width):
            set_cell(layer, row, column + offset, shade if (offset == 0 and shade and design.leg_width > 2) else colour)
    boot_column = foot_column + getattr(design, "boot_offset", 0) if view == "side" else foot_column
    paint(layer, design, boot, boot_column, boot_top)
    return outlined(layer)


def arm(design, shoulder, hand, rows=CELLS, claws=False, draw_hand=True, sleeve=None):
    """A sleeve two cells thick from the shoulder to a two-by-two hand whose
    top-left cell is `hand` (all in cells)."""
    layer = blank(rows)
    colour = design.colour(sleeve or design.sleeve)
    dx, dy = hand[0] - shoulder[0], hand[1] - shoulder[1]
    offset = (1, 0) if abs(dy) >= abs(dx) else (0, 1)
    for column, row in line_cells(shoulder, hand):
        set_cell(layer, row, column, colour)
        set_cell(layer, row + offset[1], column + offset[0], colour)
    if draw_hand:
        for row in (0, 1):
            for column in (0, 1):
                set_cell(layer, hand[1] + row, hand[0] + column, design.colour(design.hand))
    if claws:
        for row in (0, 1):
            set_cell(layer, hand[1] + row, hand[0] + 2, wizard_art.METAL_LIGHT)
    return outlined(layer)


def upper(design, view, dx=0, dy=0, rows=CELLS, variant=None):
    layer = blank(rows)
    pattern = getattr(design, view)
    if variant is not None and hasattr(design, view + "_variants"):
        pattern = getattr(design, view + "_variants")[variant % len(getattr(design, view + "_variants"))]
    column, row = getattr(design, view + "_origin")
    paint(layer, design, pattern, column + dx, row + dy)
    return outlined(layer)


def behind(design, view, dx=0, dy=0, rows=CELLS, variant=0, layer_name="behind"):
    """Separately outlined parts of a view: "behind" ones (scarf tails,
    planks, antenna) are drawn before the upper body, "front" ones after
    it. A list of (pattern, top-left cell) is one variant per frame."""
    patterns = getattr(design, view + "_" + layer_name, None)
    layer = blank(rows)
    if not patterns:
        return layer
    pattern, (column, row) = patterns[variant % len(patterns)]
    paint(layer, design, pattern, column + dx, row + dy)
    return outlined(layer)


def offset(point, dx=0, dy=0):
    return point[0] + dx, point[1] + dy


def body(design, view, feet, dx=0, dy=0, rows=CELLS, variant=0, legs_dx=None, lean=0):
    """Legs, the parts behind, and the upper body. feet: ((dx, dy), (dx, dy))
    for the back and front (or left and right) foot. lean tilts the upper
    body about the hips (degrees, counter-clockwise positive)."""
    layer = blank(rows)
    hips = getattr(design, view + "_hips")
    legs_dx = dx if legs_dx is None else legs_dx
    for hip, (foot_dx, foot_dy) in zip(hips, feet):
        over(layer, leg(design, offset(hip, legs_dx, dy), foot_dx + dx - legs_dx, foot_dy, view, rows))
    torso = blank(rows)
    over(torso, behind(design, view, dx, dy, rows, variant))
    over(torso, upper(design, view, dx, dy, rows, variant))
    over(torso, behind(design, view, dx, dy, rows, variant, "front"))
    over(layer, shear(torso, lean, hips[0][1] + dy))
    return layer


# --- Animations ------------------------------------------------------------------

# Walk cycle: contact, passing (body up a cell, the moving foot lifted),
# contact the other way, passing. The near arm swings against the legs.
WALK = [
    {"dy": 0, "feet": ((-2, 0), (2, 0)), "hand": (-2, 5)},
    {"dy": -1, "feet": ((0, -1), (0, 0)), "hand": (0, 5)},
    {"dy": 0, "feet": ((2, 0), (-2, 0)), "hand": (2, 5)},
    {"dy": -1, "feet": ((0, 0), (0, -1)), "hand": (0, 5)},
]


def walk_frame(design, index):
    pose = WALK[index]
    lean = getattr(design, "walk_lean", 0)
    layer = body(design, "side", pose["feet"], dy=pose["dy"], variant=index, lean=lean)
    shoulder = shear_point(offset(design.side_shoulder, 0, pose["dy"]), lean, design.side_hips[0][1] + pose["dy"])
    over(layer, arm(design, shoulder, offset(shoulder, *pose["hand"])))
    return to_pixels(layer)


# Dig (front view, shovel): the body crouches a few cells with the feet
# planted (the wizard squashes by the same amounts), spreading the knees.
DIG_CROUCH = [0, 1, 3, 2]


def recoloured_hands(image, colour):
    pixels = np.array(image)
    skin = np.all(pixels == np.array(wizard_art.SKIN), axis=2)
    pixels[skin] = colour
    return Image.fromarray(pixels)


def dig_frame(design, index):
    crouch = DIG_CROUCH[index]
    spread = (crouch + 1) // 2
    layer = body(design, "front", ((-spread, 0), (spread, 0)), dy=crouch)
    grip, blade_join = dig_frames.SHOVEL_POSES[index]
    hands = []
    for fraction in dig_frames.HAND_POSITIONS:
        x = grip[0] + (blade_join[0] - grip[0]) * fraction
        y = grip[1] + (blade_join[1] - grip[1]) * fraction
        hands.append(to_cell((x - ART_PIXEL, y)))
    left_shoulder, right_shoulder = (offset(s, 0, crouch) for s in design.front_shoulders)
    # Near hand (higher on the handle) from the right shoulder; the other
    # arm crosses the chest to the lower hand.
    over(layer, arm(design, left_shoulder, hands[1], draw_hand=False))
    over(layer, arm(design, right_shoulder, hands[0], draw_hand=False))
    image = to_pixels(layer)
    shovel = recoloured_hands(dig_frames.draw_shovel(FRAME_SIZE, grip, blade_join), design.colour(design.hand))
    image.alpha_composite(shovel)
    return image


# Vertical ladder (back view): hands alternate reaching for the rung above
# the head and holding at the shoulder, the opposite foot lifted.
LADDER = [
    {"dy": 0, "hands": (-8, -3), "feet": ((0, 0), (0, -2))},
    {"dy": -1, "hands": (-6, -5), "feet": ((0, 0), (0, -1))},
    {"dy": 0, "hands": (-3, -8), "feet": ((0, -2), (0, 0))},
    {"dy": -1, "hands": (-5, -6), "feet": ((0, -1), (0, 0))},
]


def ladder_frame(design, index):
    pose = LADDER[index]
    layer = body(design, "back", pose["feet"], dy=pose["dy"], variant=index)
    for side, shoulder in enumerate(design.back_shoulders):
        shoulder = offset(shoulder, 0, pose["dy"])
        over(layer, arm(design, shoulder, (shoulder[0] - 1, shoulder[1] + pose["hands"][side])))
    return to_pixels(layer)


# How far (cells) the climbing hands reach out from the front shoulder, and
# the most a body may step towards the wall from its walking position.
CLIMB_ARM_REACH = 4
CLIMB_MAX_STEP = 3


def climb_frame(design, index):
    """Side view against the wall on the right, leaning in, claws on the
    wall (see build_climb_frames.py for the poses)."""
    pose = climb_frames.FRAMES[index]
    hand_column = to_cell((climb_frames.HAND_X, 0))[0]
    # The wizard steps back two cells to make room for its arms; a slimmer
    # body steps up to the wall instead, so its arms stay short.
    shift = max(climb_frames.BODY_SHIFT_X // ART_PIXEL,
                min(CLIMB_MAX_STEP, hand_column - CLIMB_ARM_REACH - design.side_front_shoulder[0]))
    lift = pose["lift"]
    angle = climb_frames.LEAN_DEGREES
    pivot_row = climb_frames.LEAN_PIVOT[1] / ART_PIXEL
    wall_toe = to_cell((climb_frames.HAND_X, 0))[0] + 1
    boot_width = len(design.boot_side[-1])
    feet = []
    for hip, (_, foot_dy) in zip(design.side_hips, (pose["back_foot"], pose["front_foot"])):
        if foot_dy < 0:
            # The pushing foot: toe against the wall.
            feet.append((wall_toe - boot_width + 1 - hip[0], foot_dy + lift))
        else:
            feet.append((shift, foot_dy + lift))
    rows = CELLS
    legs = blank(rows)
    for hip, (foot_dx, foot_dy) in zip(design.side_hips, feet):
        over(legs, leg(design, offset(hip, 0, lift), foot_dx, foot_dy, "side", rows))
    torso = blank(rows)
    over(torso, behind(design, "side", shift, lift, rows, index))
    over(torso, upper(design, "side", shift, lift, rows, index))
    over(torso, behind(design, "side", shift, lift, rows, index, "front"))
    torso = shear(torso, angle, pivot_row)
    layer = blank(rows)
    far = shear_point(offset(design.side_front_shoulder, shift - 2, lift), angle, pivot_row)
    near = shear_point(offset(design.side_front_shoulder, shift, lift), angle, pivot_row)
    over(layer, arm(design, far, (hand_column, to_cell((0, pose["far_hand"]))[1]), claws=True))
    over(layer, legs)
    over(layer, torso)
    over(layer, arm(design, near, (hand_column, to_cell((0, pose["near_hand"]))[1]), claws=True))
    return to_pixels(layer)


def stance(design, variant=0):
    """Standing side-on with the feet a little apart, for the tool poses."""
    return body(design, "side", ((-1, 0), (1, 0)), variant=variant)


def pickaxe_frame(design, index):
    pose = pickaxe_frames.FRAMES[index]
    pivot_row = FLOOR_ROW + 1
    layer = shear(stance(design, variant=index), pose["lean"], pivot_row)
    image = to_pixels(layer)
    feet_pivot = pickaxe_feet_pivot()
    grip = rotate_point(pose["grip"], pose["lean"], feet_pivot)
    shoulder = shear_point(design.side_shoulder, pose["lean"], pivot_row)
    canvas = ArtCanvas(FRAME_SIZE)
    pickaxe_frames.draw_pickaxe(canvas, grip, pose["angle"])
    tool = canvas.cells
    hand = to_cell((grip[0] - ART_PIXEL // 2, grip[1] - ART_PIXEL // 2))
    arm_layer = arm(design, shoulder, hand)
    tool_layer = outlined_tool(tool)
    image.alpha_composite(to_pixels(over(tool_layer, arm_layer)))
    image.alpha_composite(pickaxe_frames.draw_chips(FRAME_SIZE, pose["chips"]))
    return image


def outlined_tool(cells):
    layer = blank()
    rows = min(layer.shape[0], cells.shape[0])
    layer[:rows] = cells[:rows]
    return outlined(layer)


_PIVOT = []


def pickaxe_feet_pivot():
    """The wizard's builder rocks the body about the middle of its feet;
    the grips are rotated about that same point so the tool lands where the
    wizard's does."""
    if not _PIVOT:
        body_image = wizard_art.side_body_without_hand()
        left, _, right, bottom = wizard_art.occupied_box(body_image)
        _PIVOT.append(((left + right) // 2, bottom))
    return _PIVOT[0]


def jackhammer_frame(design, index):
    pose = jackhammer_frames.FRAMES[index]
    back = -jackhammer_frames.BODY_BACK_CELLS
    shake_x, shake_y = pose["shake"]
    # The feet shake sideways only; the upper body bobs down with dy.
    layer = body(design, "side", ((-1, 0), (1, 0)), dx=back + shake_x, dy=shake_y, variant=index,
                 legs_dx=back + shake_x)
    image = to_pixels(layer)
    canvas = ArtCanvas(FRAME_SIZE)
    offset_px = (shake_x * ART_PIXEL, shake_y * ART_PIXEL)
    hand, bit_x, bit_y = jackhammer_frames.draw_drill(canvas, offset_px)
    jackhammer_frames.draw_bit(canvas, bit_x, bit_y, pose["bit"])
    tool_layer = outlined_tool(canvas.cells)
    shoulder = offset(design.side_shoulder, back + shake_x, shake_y)
    over(tool_layer, arm(design, shoulder, to_cell(hand)))
    image.alpha_composite(to_pixels(tool_layer))
    image.alpha_composite(jackhammer_frames.draw_dust(FRAME_SIZE, pose["dust"], bit_y))
    return image


def padded(image, size, pad):
    """The 250 frame on a larger canvas, offset by pad (see
    build_construction_frames: padding both sides keeps the body where the
    other frames have it)."""
    frame = Image.new("RGBA", size, (0, 0, 0, 0))
    frame.alpha_composite(image, pad)
    return frame


def ladder_fit_frame(design, index):
    """Back view, pulling a ladder segment out of the backpack and fitting it
    on the cell above (poses from build_construction_frames)."""
    pose = construction_frames.LADDER_FRAMES[index]
    pad_y = construction_frames.LADDER_PAD_Y
    frame = construction_frames.ladder_segment(pose["bottom"])
    frame.alpha_composite(to_pixels(body(design, "back", ((0, 0), (0, 0)))), (0, pad_y))
    # The hands reach above the 250 frame, so the arms are drawn on the
    # padded frame's rows: everything moves down by the padding.
    pad_rows = pad_y // ART_PIXEL
    height = construction_frames.LADDER_FRAME[1]
    rows = -(-height // ART_PIXEL)
    arms = blank(rows)
    for shoulder, hand in zip(design.back_shoulders, construction_frames.ladder_hands(pose["bottom"])):
        over(arms, arm(design, offset(shoulder, 0, pad_rows), offset(to_cell(hand), 0, pad_rows), rows=rows))
    frame.alpha_composite(to_pixels(arms, height))
    if pose["dust"]:
        canvas = construction_frames.PaddedCanvas(construction_frames.LADDER_FRAME)
        construction_frames.ladder_dust(canvas, pad_y)
        frame.alpha_composite(canvas.to_image())
    return frame


def rope_slide_frame(design, index):
    """Back view, the arms straight up past the head and both hands on the
    rope above it, one over the other, the legs crossed in around it (poses
    from build_rope_frames)."""
    pose = rope_frames.FRAMES[index]
    feet = [(rope_frames.FEET_IN, 0), (-rope_frames.FEET_IN, 0)]
    raised = pose["raised_foot"]
    feet[raised] = (feet[raised][0], -1)
    image = to_pixels(body(design, "back", tuple(feet), variant=index))
    head_top_row = wizard_art.occupied_box(image)[1] // ART_PIXEL
    frame = padded(image, rope_frames.FRAME, (0, rope_frames.PAD_Y))
    pad_rows = rope_frames.PAD_CELLS
    rows = -(-rope_frames.FRAME[1] // ART_PIXEL)
    arms = blank(rows)
    for side in rope_frames.drawing_order(pose):
        shoulder = design.back_shoulders[side]
        elbow, hand = rope_frames.arm_points(shoulder, head_top_row, pose["hands"][side])
        over(arms, arm(design, offset(shoulder, 0, pad_rows), offset(elbow, 0, pad_rows), rows=rows, draw_hand=False))
        over(arms, arm(design, offset(elbow, 0, pad_rows), offset(hand, 0, pad_rows), rows=rows))
    frame.alpha_composite(to_pixels(arms, rope_frames.FRAME[1]))
    return frame


def lay_frame(design, index, surface, stance):
    """Side view, bent over the spot in front, setting a plank down and
    hammering it (poses from build_construction_frames)."""
    pose = construction_frames.LAY_FRAMES[index]
    leg_rows = FLOOR_ROW - design.side_hips[0][1]
    crouch, lean = round(leg_rows * stance["leg_share"]), stance["body_lean"]
    pad = (construction_frames.PLANK_PAD_X, construction_frames.PLANK_PAD_Y)
    size = construction_frames.PLANK_FRAME
    layer = body(design, "side", ((-2, 0), (1, 0)), dy=crouch, lean=lean)
    frame = padded(to_pixels(layer), size, pad)
    frame.alpha_composite(construction_frames.plank(surface, pose["lift"]))
    canvas = construction_frames.PaddedCanvas(size)
    hand = construction_frames.lay_tool(canvas, surface, pose)
    canvas.outline()
    frame.alpha_composite(canvas.to_image())
    hips_row = design.side_hips[0][1] + crouch
    shoulder = shear_point(offset(design.side_front_shoulder, 0, crouch), lean, hips_row)
    hand_cell = to_cell((hand[0] - pad[0], hand[1] - pad[1]))
    frame.alpha_composite(padded(to_pixels(arm(design, shoulder, hand_cell)), size, pad))
    frame.alpha_composite(construction_frames.lay_dust(surface, pose))
    return frame


def stair_lay_frame(design, index):
    return lay_frame(design, index, construction_frames.STAIR_SURFACE, construction_frames.STAIR_STANCE)


def bridge_lay_frame(design, index):
    return lay_frame(design, index, construction_frames.BRIDGE_SURFACE, construction_frames.BRIDGE_STANCE)


_CANOPY = []


def canopy_anchor():
    """Where the wizard's builder puts the canopy: centred on the walk
    frame's body, its rim CORD_GAP_CELLS above the hood."""
    if not _CANOPY:
        upper_image, _, _ = wizard_art.split_feet(wizard_art.side_body_without_hand())
        left, top, right, _ = wizard_art.occupied_box(upper_image)
        rim_y = float_frames.VERTICAL_PADDING + top - float_frames.CORD_GAP_CELLS * ART_PIXEL
        _CANOPY.append(((left + right) // 2, rim_y))
    return _CANOPY[0]


def float_frame(design, index):
    pose = float_frames.FRAMES[index]
    pad = float_frames.VERTICAL_PADDING // ART_PIXEL
    height = FRAME_SIZE + 2 * float_frames.VERTICAL_PADDING
    rows = -(-height // ART_PIXEL)
    angle = pose["angle"]
    pivot = (float_frames.SWING_PIVOT[0], float_frames.SWING_PIVOT[1] + float_frames.VERTICAL_PADDING)
    pivot_row = pivot[1] / ART_PIXEL
    feet = (pose["back_foot"], pose["front_foot"])
    layer = blank(rows)
    hips = design.side_hips
    for hip, (foot_dx, foot_dy) in zip(hips, feet):
        over(layer, leg(design, offset(hip, 0, pad), foot_dx, foot_dy + pad, "side", rows))
    over(layer, behind(design, "side", 0, pad, rows, index))
    over(layer, upper(design, "side", 0, pad, rows, index))
    over(layer, behind(design, "side", 0, pad, rows, index, "front"))
    layer = shear(layer, angle, pivot_row)
    hands = []
    arms_layer = blank(rows)
    for shoulder, (_, hand) in ((design.side_back_shoulder, float_frames.BACK_ARM),
                                (design.side_front_shoulder, float_frames.FRONT_ARM)):
        centre = rotate_point((hand[0] + ART_PIXEL // 2, hand[1] + ART_PIXEL // 2 + float_frames.VERTICAL_PADDING),
                              angle, pivot)
        hands.append(centre)
        hand_cell = to_cell((centre[0] - ART_PIXEL // 2, centre[1] - ART_PIXEL // 2))
        moved = shear_point(offset(shoulder, 0, pad), angle, pivot_row)
        over(arms_layer, arm(design, moved, hand_cell, rows))
    over(layer, arms_layer)
    canvas = ArtCanvas(height)
    centre_x, rim_y = canopy_anchor()
    float_frames.draw_parachute(canvas, centre_x, rim_y, pose["swing"], pose["tilt"], *hands)
    frame = Image.new("RGBA", (FRAME_SIZE, height), (0, 0, 0, 0))
    frame.alpha_composite(canvas.to_image().crop((0, 0, FRAME_SIZE, height)))
    frame.alpha_composite(to_pixels(layer, height))
    return frame


def death_frame(design, index, walk_zero):
    left, _, right, bottom = wizard_art.occupied_box(walk_zero)
    cropped = walk_zero.crop(wizard_art.occupied_box(walk_zero))
    height_fraction, width_fraction = death_frames.SQUASH_PER_FRAME[index]
    frame, body_left, body_right = death_frames.squash(
        cropped, height_fraction, width_fraction, FRAME_SIZE, (left + right) // 2, bottom)
    frame.alpha_composite(death_frames.dust(FRAME_SIZE, body_left, body_right, bottom,
                                            death_frames.DUST_PER_FRAME[index]))
    return frame


def dead_body(design):
    """The standing frame the fall flattens: walk contact pose without the
    swinging arm, the hand down at the side."""
    layer = body(design, "side", ((-1, 0), (1, 0)))
    over(layer, arm(design, design.side_shoulder, offset(design.side_shoulder, 0, 5)))
    return to_pixels(layer)


BUILDERS = {
    "walk_aligned": walk_frame,
    "dig_aligned": dig_frame,
    "climb_aligned": ladder_frame,
    "climb_side": climb_frame,
    "pickaxe": pickaxe_frame,
    "jackhammer": jackhammer_frame,
    "float": float_frame,
    "ladder_fit": ladder_fit_frame,
    "stair_lay": stair_lay_frame,
    "bridge_lay": bridge_lay_frame,
    "rope_slide": rope_slide_frame,
}


def build_frame(design, name, cache):
    stem = Path(name).stem
    prefix, _, number = stem.rpartition("_")
    index = int(number)
    if prefix == "death_fall":
        if "dead" not in cache:
            cache["dead"] = dead_body(design)
        return death_frame(design, index, cache["dead"])
    assert prefix in BUILDERS, "No drawing for frames '%s_*': add a builder to %s" % (prefix, __file__)
    return BUILDERS[prefix](design, index)


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


def frame_files(animations):
    files = []
    for animation in animations:
        for _, texture in animation["frames"]:
            name = Path(texture).name
            if name not in files:
                files.append(name)
    return files


def build_character(design, files):
    out_dir = CHARACTER_DIR / design.id
    out_dir.mkdir(parents=True, exist_ok=True)
    cache = {}
    for name in files:
        image = build_frame(design, name, cache)
        wizard_size = Image.open(CHARACTER_DIR / SOURCE_CHARACTER / name).size
        assert image.size == wizard_size, "%s/%s is %s, the wizard's is %s" % (design.id, name, image.size, wizard_size)
        image.save(out_dir / name)


# --- Preview --------------------------------------------------------------------

GAME_SCALE = 0.15
PREVIEW_BACKGROUND = (92, 120, 150, 255)


def preview_frame(animation):
    """The frame of each animation shown in the preview: the second one."""
    frames = animation["frames"]
    return Path(frames[min(1, len(frames) - 1)][1]).name


def preview_body(image):
    """Frame cropped to the body (and canopy) so every column lines up: the
    float frames have empty rows added at the bottom, see build_float_frames."""
    pad = (image.height - FRAME_SIZE) // 2
    if pad > 0:
        return image.crop((0, 0, image.width, image.height - pad))
    return image


def build_preview(animations, path, frame_picker=preview_frame):
    characters = [SOURCE_CHARACTER] + [design.id for design in DESIGNS]
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
            body_image = preview_body(Image.open(CHARACTER_DIR / character_id / frame_picker(animation)).convert("RGBA"))
            x0 = 10 + index * column
            y0 = 10 + row * row_height
            big = body_image.resize((round(body_image.width * enlarged_scale), round(body_image.height * enlarged_scale)), Image.NEAREST)
            sheet.alpha_composite(big, (x0, y0 + enlarged_band - big.height))
            small = body_image.resize((round(body_image.width * GAME_SCALE), round(body_image.height * GAME_SCALE)), Image.BOX)
            sheet.alpha_composite(small, (x0, y0 + enlarged_band + small_band - small.height))
            zoomed = small.resize((small.width * zoom, small.height * zoom), Image.NEAREST)
            sheet.alpha_composite(zoomed, (x0 + small.width + 6, y0 + enlarged_band + small_band - zoomed.height))
    sheet.save(path)


def main():
    scene_text = LEMMING_SCENE.read_text(encoding="utf-8")
    animations = parse_sprite_frames(scene_text, SOURCE_SPRITE_FRAMES)
    files = frame_files(animations)
    for design in DESIGNS:
        build_character(design, files)
        print("drew", design.id, len(files), "frames")
    write_sprite_frames(SOURCE_CHARACTER, animations, SPRITE_FRAMES_DIR / ("%s.tres" % SOURCE_CHARACTER))
    for design in DESIGNS:
        write_sprite_frames(design.id, animations, SPRITE_FRAMES_DIR / ("%s.tres" % design.id))
    print("animations:", ", ".join(a["name"] for a in animations))
    if len(sys.argv) > 1:
        build_preview(animations, sys.argv[1])


if __name__ == "__main__":
    main()
