# The recipe arrow (owner 2026-11-26: "change the arrow into a better icon arrow", pick C of the mockups in artifact
# DHqTbCQGqpWaK4fTAFCbzz, "Gold sparkle arrow"): a chunky arrow in the gold of the big buttons, a white sticker border
# round a dark gold edge, a shine along its shaft and two little sparkles. Drawn from the mockup's shapes (a 72 x 54
# box), 4x and scaled down for smooth edges. Needs Pillow.
# Usage: python tools/ui-icons/make_arrow.py   (writes assets/ui/icons/ArrowGold.png, 256 px square, the arrow centred)
import os

from PIL import Image, ImageDraw

ROOT = os.path.join(os.path.dirname(__file__), "..", "..")
OUT = os.path.join(ROOT, "assets", "ui", "icons", "ArrowGold.png")

SIZE = 256
SCALE = 4  # drawn this many times bigger, then scaled down
BOX = (72, 54)  # the mockup's drawing box

ARROW = [(8, 21), (36, 21), (36, 10), (60, 27), (36, 44), (36, 33), (8, 33)]
SPARKLES = [
    [(62, 5), (64, 10), (69, 12), (64, 14), (62, 19), (60, 14), (55, 12), (60, 10)],
    [(18, 41), (19.4, 44.6), (23, 46), (19.4, 47.4), (18, 51), (16.6, 47.4), (13, 46), (16.6, 44.6)],
]
WHITE = (255, 255, 255, 255)
EDGE = (184, 110, 0, 255)  # the dark gold edge
TOP = (255, 230, 128)  # the fill's gradient, top to bottom
BOTTOM = (245, 166, 35)
SPARKLE = (255, 216, 77, 255)

CANVAS = SIZE * SCALE
UNIT = CANVAS / BOX[0]  # canvas pixels per mockup unit (the arrow fills the width)
DOWN = (CANVAS - BOX[1] * UNIT) / 2  # centred top to bottom


def at(point: tuple) -> tuple:
    return (point[0] * UNIT, point[1] * UNIT + DOWN)


def stroke(draw: ImageDraw.ImageDraw, points: list, width: float, fill: tuple):
    """A closed stroke of `width` mockup units centred on the shape's edge, its corners round (each edge a thick
    line, each corner a disc), as the mockup's stroke-linejoin round"""
    pixels = width * UNIT
    corners = [at(point) for point in points]
    for index, start in enumerate(corners):
        end = corners[(index + 1) % len(corners)]
        draw.line([start, end], fill=fill, width=max(1, round(pixels)))
    for x, y in corners:
        radius = pixels / 2
        draw.ellipse([x - radius, y - radius, x + radius, y + radius], fill=fill)


def gradient_fill(points: list) -> Image.Image:
    """The arrow filled with its top-to-bottom gradient (over the arrow's own height)"""
    corners = [at(point) for point in points]
    top = min(y for _, y in corners)
    bottom = max(y for _, y in corners)
    fill = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    paint = ImageDraw.Draw(fill)
    for y in range(int(top), int(bottom) + 1):
        share = (y - top) / max(1, bottom - top)
        colour = tuple(round(TOP[i] + (BOTTOM[i] - TOP[i]) * share) for i in range(3)) + (255,)
        paint.line([(0, y), (CANVAS, y)], fill=colour)
    mask = Image.new("L", (CANVAS, CANVAS), 0)
    ImageDraw.Draw(mask).polygon(corners, fill=255)
    shaped = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    shaped.paste(fill, (0, 0), mask)
    return shaped


def main():
    image = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    # the white sticker border: the shape grown by a 10-unit round stroke, filled
    draw.polygon([at(point) for point in ARROW], fill=WHITE)
    stroke(draw, ARROW, 10, WHITE)
    # the gold body over it, then its dark edge (a 2.5-unit stroke on the edge)
    image.alpha_composite(gradient_fill(ARROW))
    draw = ImageDraw.Draw(image)
    stroke(draw, ARROW, 2.5, EDGE)
    # the shine along the top of the shaft: a soft white line with round ends
    shine = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    shine_draw = ImageDraw.Draw(shine)
    width = 3.5 * UNIT
    (x0, y0), (x1, y1) = at((13, 25)), at((37, 25))
    shine_draw.line([(x0, y0), (x1, y1)], fill=(255, 255, 255, 191), width=round(width))
    for x, y in ((x0, y0), (x1, y1)):
        shine_draw.ellipse([x - width / 2, y - width / 2, x + width / 2, y + width / 2], fill=(255, 255, 255, 191))
    image.alpha_composite(shine)
    # the two sparkles: gold with a white edge
    draw = ImageDraw.Draw(image)
    for points in SPARKLES:
        stroke(draw, points, 1.5, WHITE)
        draw.polygon([at(point) for point in points], fill=SPARKLE)
    image = image.resize((SIZE, SIZE), Image.LANCZOS)
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    image.save(OUT)
    print("wrote", os.path.normpath(OUT))


if __name__ == "__main__":
    main()
