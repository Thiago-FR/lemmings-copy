"""Builds the wizard's rope animation: sliding down a rope ("rope_slide").

    python tools/build_rope_frames.py

Back view, the same body as the ladder frames (climb_aligned_0 with the
hands at its sides painted over): both arms go straight up past the sides
of the head and the hands grip the rope above it, one over the other,
swapping places frame by frame, hand under hand, as the lemming lets itself
down. The rope itself is the Rope node drawn behind the lemming
(scripts/level/rope.gd), so only the arms and hands are drawn here, on the
rope's line: the body is centred on the rope while sliding
(LemmingController._try_grab_rope), and the collision box centre is one
screen pixel right of the sprite's centre.

The hands reach above the 250x250 frame, so the frames are padded equally
top and bottom (see build_construction_frames: AnimatedSprite2D centres
every frame, so equal padding keeps the body where the other frames have
it).

tools/build_character_variants.py imports the poses from here, so the other
characters grip the rope in the same places at the same times.
"""

from PIL import Image

from wizard_art import ART_PIXEL, SKIN, SLEEVE, load, occupied_box, save

from build_construction_frames import GAME_SCALE, WIZARD_BACK_SHOULDERS, WIZARD_BACK_SOURCE, PaddedCanvas, wizard_back_body

PREFIX = "rope_slide"
FRAME_SIZE = 250
PAD_CELLS = 10
PAD_Y = PAD_CELLS * ART_PIXEL
FRAME = (FRAME_SIZE, FRAME_SIZE + 2 * PAD_Y)
# The rope's line in the frame: the collision box centre, (1, 2) from the
# node (lemming.tscn), at source scale.
ROPE_X = FRAME_SIZE / 2 + 1 / GAME_SCALE
# Left column of the two-cell-wide hands, centred on the rope.
HAND_COLUMN = round(ROPE_X / ART_PIXEL - 1)

# Per frame: rows of each hand's top above the top of the head (left,
# right), and which foot is drawn up (the legs are crossed around the rope).
FRAMES = [
    {"hands": (7, 3), "raised_foot": 1},
    {"hands": (6, 2), "raised_foot": 1},
    {"hands": (3, 7), "raised_foot": 0},
    {"hands": (2, 6), "raised_foot": 0},
]
# How far (cells) each foot steps in towards the rope.
FEET_IN = 2


def drawing_order(pose):
    """The upper hand's arm first, so it never covers the lower hand."""
    return sorted(range(2), key=lambda side: -pose["hands"][side])


def arm_points(shoulder, head_top_row, rows_above):
    """(elbow, hand top-left) in cells, unpadded: the upper arm straight up
    from the shoulder to the top of the head, the forearm in to the rope."""
    return (shoulder[0], head_top_row + 1), (HAND_COLUMN, head_top_row - rows_above)


def build_frames():
    body = wizard_back_body()
    head_top_row = occupied_box(load(WIZARD_BACK_SOURCE))[1] // ART_PIXEL
    for index, pose in enumerate(FRAMES):
        frame = Image.new("RGBA", FRAME, (0, 0, 0, 0))
        frame.alpha_composite(body, (0, PAD_Y))
        canvas = PaddedCanvas(FRAME)
        for side in drawing_order(pose):
            shoulder = WIZARD_BACK_SHOULDERS[side]
            shoulder_cell = (round(shoulder[0] / ART_PIXEL), round(shoulder[1] / ART_PIXEL))
            elbow, hand = arm_points(shoulder_cell, head_top_row, pose["hands"][side])
            points = [(x * ART_PIXEL, (y + PAD_CELLS) * ART_PIXEL) for x, y in (shoulder_cell, elbow, hand)]
            for start, end in zip(points, points[1:]):
                canvas.line(start, end, SLEEVE)
                canvas.line((start[0] + ART_PIXEL, start[1]), (end[0] + ART_PIXEL, end[1]), SLEEVE)
            canvas.rect(points[2][0], points[2][1], 2, 2, SKIN)
        canvas.outline()
        frame.alpha_composite(canvas.to_image())
        save(frame, f"{PREFIX}_{index}")


def main():
    build_frames()
    print("wrote %s frames" % PREFIX)


if __name__ == "__main__":
    main()
