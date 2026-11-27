# The tutorial's cue arrows (owner 2026-11-27: "Maybe just use arrows instead of paws. to be simple", picks B and 1 of
# the mockups in artifact CS1X1JKgH9R5JeMQ3J7QLz; spec docs/superpowers/specs/2026-11-27-tutorial-arrows-design.md):
# ArrowCue, the chunky gold arrow pointing down at what to use (a dark outline round a white sticker edge, a gold
# body, a shine along its shaft), and Chevron, the arrow lying on the ground along the way, pointing forward (the same
# three layers; drawn taller than it looks, as lying down flattens it). Drawn from the mockup's shapes, 4x and scaled
# down for smooth edges. Needs Pillow.
# Usage: python tools/ui-icons/make_cue_arrows.py   (writes assets/ui/icons/ArrowCue.png and Chevron.png, 256 px)
import os

from PIL import Image, ImageDraw

ROOT = os.path.join(os.path.dirname(__file__), "..", "..")
ICONS = os.path.join(ROOT, "assets", "ui", "icons")

SIZE = 256
SCALE = 4  # drawn this many times bigger, then scaled down
CANVAS = SIZE * SCALE

DARK = (58, 29, 11, 255)
WHITE = (255, 255, 255, 255)
TOP = (255, 231, 137)  # the gold, top to bottom
BOTTOM = (255, 178, 31)
SHINE = (255, 248, 214, 217)

# The mockup's arrow (its units, centred on 0,0, pointing down): a shaft, then the head to the tip
ARROW = [(-15, -40), (15, -40), (15, -2), (35, -2), (0, 38), (-35, -2), (-15, -2)]
ARROW_BOX = 100  # units across the picture
# The chevron seen from above, pointing up (forward)
CHEVRON = [(-24, 20), (0, -20), (24, 20)]
CHEVRON_BOX = 76


class Pen:
    """The mockup's units to canvas pixels, for a picture `box` units across with 0,0 in its middle"""

    def __init__(self, box: float):
        self.unit = CANVAS / box

    def at(self, point: tuple) -> tuple:
        return (CANVAS / 2 + point[0] * self.unit, CANVAS / 2 + point[1] * self.unit)


def stroke_mask(pen: Pen, points: list, width: float, closed: bool):
    """A mask of a stroke `width` units wide along `points` with round joins and ends (closed: back to the first)"""
    mask = Image.new("L", (CANVAS, CANVAS), 0)
    draw = ImageDraw.Draw(mask)
    corners = [pen.at(point) for point in points]
    pixels = width * pen.unit
    count = len(corners) if closed else len(corners) - 1
    for index in range(count):
        draw.line([corners[index], corners[(index + 1) % len(corners)]], fill=255, width=max(1, round(pixels)))
    radius = pixels / 2
    for x, y in corners:
        draw.ellipse([x - radius, y - radius, x + radius, y + radius], fill=255)
    return mask, draw, corners


def gradient(top: float, bottom: float) -> Image.Image:
    """The gold, lighter at the top, from `top` to `bottom` (canvas px)"""
    fill = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    paint = ImageDraw.Draw(fill)
    for y in range(CANVAS):
        share = min(1.0, max(0.0, (y - top) / max(1.0, bottom - top)))
        colour = tuple(round(TOP[i] + (BOTTOM[i] - TOP[i]) * share) for i in range(3)) + (255,)
        paint.line([(0, y), (CANVAS, y)], fill=colour)
    return fill


def layer(image: Image.Image, mask: Image.Image, paint):
    """`paint` (a colour or a picture) through `mask` onto `image`"""
    top = paint if isinstance(paint, Image.Image) else Image.new("RGBA", (CANVAS, CANVAS), paint)
    shaped = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    shaped.paste(top, (0, 0), mask)
    image.alpha_composite(shaped)


def arrow() -> Image.Image:
    pen = Pen(ARROW_BOX)
    image = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    # the dark outline, then the white sticker edge inside it: the shape grown by each round stroke, filled
    for width, colour in ((16, DARK), (9, WHITE)):
        mask, draw, corners = stroke_mask(pen, ARROW, width, True)
        draw.polygon(corners, fill=255)
        layer(image, mask, colour)
    body = Image.new("L", (CANVAS, CANVAS), 0)
    corners = [pen.at(point) for point in ARROW]
    ImageDraw.Draw(body).polygon(corners, fill=255)
    heights = [y for _, y in corners]
    layer(image, body, gradient(min(heights), max(heights)))
    shine, _, _ = stroke_mask(pen, [(-7, -33), (-7, -8)], 5, False)
    layer(image, shine, SHINE)
    return image


def chevron() -> Image.Image:
    pen = Pen(CHEVRON_BOX)
    image = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    for width, colour in ((22, DARK), (14, WHITE)):
        mask, _, _ = stroke_mask(pen, CHEVRON, width, False)
        layer(image, mask, colour)
    mask, _, corners = stroke_mask(pen, CHEVRON, 7, False)
    heights = [y for _, y in corners]
    layer(image, mask, gradient(min(heights), max(heights)))
    return image


def save(image: Image.Image, name: str):
    path = os.path.join(ICONS, name)
    image.resize((SIZE, SIZE), Image.LANCZOS).save(path)
    print("wrote", os.path.normpath(path))


if __name__ == "__main__":
    os.makedirs(ICONS, exist_ok=True)
    save(arrow(), "ArrowCue.png")
    save(chevron(), "Chevron.png")
