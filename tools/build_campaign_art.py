"""Draws the icons of the campaign screens, in the style of the other icons
(32x32, flat colours, a 1px near-black outline added at the end):

  icons/campaign.png   a map with a dotted trail ending at a flag: the
                       "Fases" button of the main menu
  icons/lock.png       a padlock: a level not reached yet
  icons/star.png       a gold star: a level already won
  icons/next.png       an arrow: on to the next level

    python tools/build_campaign_art.py [preview.png]
    godot --headless --path . --import

Uses the palette and helpers of build_ui_art.py.
"""

import math
import os
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from build_ui_art import (  # noqa: E402
    CREAM, CREAM_DARK, EXIT_GREEN, EXIT_GREEN_DARK, EXIT_GREEN_LIGHT, ICON, ICON_DIR,
    LEATHER, LEATHER_DARK, METAL, METAL_DARK, METAL_LIGHT, RED, RED_DARK, YELLOW, YELLOW_LIGHT,
    ORANGE, hline, line, new, outline, polygon, put, rect, vline,
)


def icon_campaign():
    """A parchment map, rolled at both ends, with a red dotted trail that
    winds to a small green flag."""
    image = new()
    rect(image, 5, 6, 26, 25, CREAM)
    for x in range(5, 27):
        if (x // 3) % 2:
            put(image, x, 25, CREAM_DARK)
    vline(image, 26, 6, 25, CREAM_DARK)
    for y0 in (4, 24):
        rect(image, 3, y0, 28, y0 + 3, LEATHER)
        hline(image, 3, 28, y0 + 3, LEATHER_DARK)
    trail = [(8, 21), (10, 19), (12, 18), (14, 19), (16, 20), (18, 18), (19, 15), (18, 12), (20, 10)]
    for index, (x, y) in enumerate(trail):
        if index % 2 == 0:
            rect(image, x, y, x + 1, y + 1, RED)
    put(image, 8, 22, RED_DARK)
    vline(image, 22, 9, 15, LEATHER_DARK)
    polygon(image, [(23, 9), (27, 10), (23, 12)], EXIT_GREEN)
    put(image, 23, 10, EXIT_GREEN_LIGHT)
    return outline(image)


def icon_lock():
    """A grey padlock: steel shackle, brass body with a keyhole."""
    image = new()
    for y in range(4, 16):
        for x in range(8, 24):
            dist = math.hypot(x + 0.5 - 16, y + 0.5 - 14)
            if 5.0 <= dist <= 8.0 and y < 15:
                put(image, x, y, METAL_LIGHT if dist < 6.5 else METAL)
    rect(image, 7, 14, 24, 27, YELLOW)
    hline(image, 7, 24, 27, ORANGE)
    vline(image, 24, 14, 27, ORANGE)
    hline(image, 8, 23, 15, YELLOW_LIGHT)
    rect(image, 15, 18, 16, 21, METAL_DARK)
    rect(image, 15, 21, 16, 24, METAL_DARK)
    put(image, 14, 19, METAL_DARK)
    put(image, 17, 19, METAL_DARK)
    return outline(image)


def icon_star():
    """A five-pointed gold star with a lighter upper left."""
    image = new()
    cx, cy = 15.5, 16.5
    points = []
    for index in range(10):
        radius = 13.0 if index % 2 == 0 else 5.6
        angle = math.radians(-90 + index * 36)
        points.append((cx + radius * math.cos(angle), cy + radius * math.sin(angle)))
    polygon(image, points, YELLOW)
    inner = [(cx + (x - cx) * 0.55 - 1.5, cy + (y - cy) * 0.55 - 1.5) for x, y in points]
    polygon(image, inner, YELLOW_LIGHT)
    for index in range(1, 10, 2):
        x, y = points[index]
        put(image, int(x), int(y), ORANGE)
    return outline(image)


def icon_next():
    """A green arrow pointing right, a step to the next level."""
    image = new()
    rect(image, 5, 12, 17, 19, EXIT_GREEN)
    polygon(image, [(16, 5), (27, 15), (27, 16), (16, 26)], EXIT_GREEN)
    hline(image, 5, 17, 12, EXIT_GREEN_LIGHT)
    line(image, (17, 7), (25, 15), EXIT_GREEN_LIGHT, 1)
    hline(image, 5, 16, 19, EXIT_GREEN_DARK)
    line(image, (17, 24), (25, 16), EXIT_GREEN_DARK, 1)
    return outline(image)


def icon_back():
    """The same arrow pointing left: back to the page before (menus)."""
    return icon_next().transpose(Image.FLIP_LEFT_RIGHT)


ICONS = {"campaign": icon_campaign, "lock": icon_lock, "star": icon_star, "next": icon_next, "back": icon_back}


def main():
    os.makedirs(ICON_DIR, exist_ok=True)
    images = {}
    for name, draw in ICONS.items():
        image = draw()
        image.save(os.path.join(ICON_DIR, name + ".png"))
        images[name] = image
    print("campaign icons written to", os.path.normpath(ICON_DIR))
    if len(sys.argv) > 1:
        scale = 4
        sheet = Image.new("RGBA", (len(images) * (ICON + 8) * scale, (ICON + 8) * scale * 2), (0, 0, 0, 0))
        for row, background in enumerate(((60, 44, 34, 255), (220, 210, 190, 255))):
            for column, image in enumerate(images.values()):
                tile = Image.new("RGBA", (ICON + 8, ICON + 8), background)
                tile.alpha_composite(image, (4, 4))
                sheet.paste(tile.resize(((ICON + 8) * scale, (ICON + 8) * scale), Image.NEAREST),
                            (column * (ICON + 8) * scale, row * (ICON + 8) * scale))
        sheet.save(sys.argv[1])
        print("preview written to", sys.argv[1])


if __name__ == "__main__":
    main()
