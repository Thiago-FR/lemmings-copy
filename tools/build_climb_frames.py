"""Builds the side-on wall climbing animation ("climb", the Garras skill).

    python tools/build_climb_frames.py

Same approach as the other wizard builders: the body is the side-on walk
frame (waist hand removed, see wizard_art.py), leaning a few degrees into
the wall it faces. Arms are drawn on the art-pixel grid reaching up the
wall, short, each hand ending in small metal claws. Over four frames the
hands alternate (one gripping at head height while the other holds lower
by the chest, then they swap), the body pulls itself up a cell between
grips and the feet take turns pushing against the wall.

The art faces right like the walk frames; LemmingController mirrors the
sprite with flip_h when the lemming faces left, so the wall is always on
the side the wizard looks at. The hands and claws reach the right edge of
the 26x30 collision box, which is where the wall face is while climbing.

The back-view frames (climb_aligned_*) are not touched: they stay in the
SpriteFrames as the "ladder" animation.
"""

from PIL import Image

from wizard_art import (
    ART_PIXEL, ArtCanvas, rotate_point, save, shifted, side_body_without_hand, split_feet,
)

OUTPUT_PREFIX = "climb_side"

# Lean into the wall, in degrees (negative is clockwise, as PIL rotates):
# the hood tips towards the wall and the feet swing out from it, which is
# what reads as hanging on a vertical face rather than standing.
LEAN_DEGREES = -6
# The body is moved back from the wall by this much so the arms have room
# between the hood and the wall face.
BODY_SHIFT_X = -2 * ART_PIXEL
LEAN_PIVOT = (132, 138)

# Shoulders before any offset, in source pixels of the 250px walk frame. The
# far arm starts behind the body and only shows where it leaves the
# silhouette; the near arm is drawn over the body along the hood's front.
FAR_SHOULDER = (172, 162)
NEAR_SHOULDER = (190, 150)

# Hand heights on the wall (source pixels, top of the hand) and the x they
# grip at: just inside the right edge of the collision box, so the claws
# touch the wall. The hands stay between the lower half of the hood and the
# chest: reaching above the hood made the arms twice as long as the body
# allows and the wizard read as a rubber doll. The climb is carried by the
# body lift and the feet instead, with the arms kept short.
HAND_X = 204
HAND_HIGH = 104
# Halfway grips, used while the hands trade places: one a little above the
# other, so the two hands never merge into one blob.
HAND_MID_UPPER = 118
HAND_MID_LOWER = 136
HAND_LOW = 150

# Per frame: body lift in cells (negative is up), far and near hand heights,
# and the back and front foot offsets in cells (dx, dy) from the walk frame,
# lift not included. A raised foot is the one pushing: it is moved forward
# until its toe touches the wall and drawn over the robe.
FRAMES = [
    {"lift": 0, "far_hand": HAND_LOW, "near_hand": HAND_HIGH, "back_foot": (-1, 0), "front_foot": (5, -2)},
    {"lift": -1, "far_hand": HAND_MID_LOWER, "near_hand": HAND_MID_UPPER, "back_foot": (2, 0), "front_foot": (3, -1)},
    {"lift": 0, "far_hand": HAND_HIGH, "near_hand": HAND_LOW, "back_foot": (13, -2), "front_foot": (-2, 0)},
    {"lift": -1, "far_hand": HAND_MID_UPPER, "near_hand": HAND_MID_LOWER, "back_foot": (9, -1), "front_foot": (0, 0)},
]


def build_body(upper, back_foot, front_foot, pose):
    """Feet and robe for one frame in the 250px frame. The robe leans and
    lifts; the feet are placed afterwards, straight, at their own offsets
    from where the walk frame has them, so a pushing foot can be put right
    against the wall regardless of the lean. A raised foot (the one
    pushing) is drawn over the robe; a hanging one tucks behind it."""
    robe = upper.rotate(LEAN_DEGREES, resample=Image.NEAREST, center=LEAN_PIVOT)
    robe = shifted(robe, BODY_SHIFT_X, pose["lift"] * ART_PIXEL)

    feet = []
    for foot, (dx, dy) in ((back_foot, pose["back_foot"]), (front_foot, pose["front_foot"])):
        feet.append((shifted(foot, dx * ART_PIXEL, (dy + pose["lift"]) * ART_PIXEL), dy < 0))

    body = Image.new("RGBA", upper.size, (0, 0, 0, 0))
    for layer, pushing in feet:
        if not pushing:
            body.alpha_composite(layer)
    body.alpha_composite(robe)
    for layer, pushing in feet:
        if pushing:
            body.alpha_composite(layer)
    return body


def place_shoulder(shoulder, lift):
    """Where a shoulder ends up after the lean, the shift and the lift."""
    x, y = rotate_point(shoulder, LEAN_DEGREES, LEAN_PIVOT)
    return (x + BODY_SHIFT_X, y + lift * ART_PIXEL)


def draw_arm(size, shoulder, hand_y, lift):
    canvas = ArtCanvas(size)
    canvas.arm(place_shoulder(shoulder, lift), (HAND_X, hand_y), claws=True)
    canvas.outline()
    return canvas.to_image()


def main():
    upper, back_foot, front_foot = split_feet(side_body_without_hand())
    size = upper.width

    for index, pose in enumerate(FRAMES):
        frame = Image.new("RGBA", (size, size), (0, 0, 0, 0))
        frame.alpha_composite(draw_arm(size, FAR_SHOULDER, pose["far_hand"], pose["lift"]))
        frame.alpha_composite(build_body(upper, back_foot, front_foot, pose))
        frame.alpha_composite(draw_arm(size, NEAR_SHOULDER, pose["near_hand"], pose["lift"]))
        save(frame, f"{OUTPUT_PREFIX}_{index}")

    print(f"wrote {len(FRAMES)} {OUTPUT_PREFIX} frames")


if __name__ == "__main__":
    main()
