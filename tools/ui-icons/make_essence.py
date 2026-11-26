# The Mutation Essence icon (owner 2026-11-26, pick A of the mockups): the XP Tonic's glossy flask
# (assets/ui/icons/XpTonic.png) with its green liquid and glass turned violet to pink, and three sparkles in the icons'
# sticker style (a white border round a dark plum outline). Needs Pillow.
# Usage: python tools/ui-icons/make_essence.py   (writes assets/ui/icons/Essence.png, 256 px)
import colorsys
import math
import os

from PIL import Image, ImageDraw

ROOT = os.path.join(os.path.dirname(__file__), "..", "..")
SOURCE = os.path.join(ROOT, "assets", "ui", "icons", "XpTonic.png")
OUT = os.path.join(ROOT, "assets", "ui", "icons", "Essence.png")

OUTLINE_HUE = 0.80  # the flask's dark outline: one deep violet
DARK = 0.42  # pixels darker than this are the outline
# x, y, radius, fill of each sparkle (the big one top right, by the cork)
STARS = [(200, 70, 22, (255, 255, 255, 255)), (52, 110, 14, (255, 246, 200, 255)), (214, 150, 11, (255, 255, 255, 255))]


def is_green(h: float, s: float, v: float) -> bool:
    return 0.24 <= h <= 0.48 and s > 0.18 and v > 0.15


def recolour(base: Image.Image) -> Image.Image:
    width, height = base.size
    image = base.copy()
    pixels = image.load()
    middle = height * 0.58  # the liquid's middle: deeper violet below it, pinker above
    for y in range(height):
        for x in range(width):
            r, g, b, a = pixels[x, y]
            if a == 0:
                continue
            h, s, v = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
            if not is_green(h, s, v):
                continue
            hue = OUTLINE_HUE if v < DARK else 0.80 + (y - middle) / 900
            nr, ng, nb = colorsys.hsv_to_rgb(hue % 1, min(1.0, s * 1.1), v)
            pixels[x, y] = (round(nr * 255), round(ng * 255), round(nb * 255), a)
    return image


def star_points(x: float, y: float, radius: float, scale: int) -> list:
    points = []
    for i in range(8):
        angle = math.pi / 4 * i - math.pi / 2
        reach = radius if i % 2 == 0 else radius * 0.3
        points.append((x * scale + math.cos(angle) * reach * scale, y * scale + math.sin(angle) * reach * scale))
    return points


def sparkle(image: Image.Image) -> Image.Image:
    scale = 4  # drawn 4x and scaled down: smooth edges
    width, height = image.size
    layer = Image.new("RGBA", (width * scale, height * scale), (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    for x, y, radius, fill in STARS:
        draw.polygon(star_points(x, y, radius + 6, scale), fill=(255, 255, 255, 255))
        draw.polygon(star_points(x, y, radius + 2.5, scale), fill=(52, 24, 66, 255))
        draw.polygon(star_points(x, y, radius, scale), fill=fill)
    layer = layer.resize((width, height), Image.LANCZOS)
    out = image.copy()
    out.alpha_composite(layer)
    return out


def main() -> None:
    base = Image.open(SOURCE).convert("RGBA")
    sparkle(recolour(base)).save(OUT)
    print(f"wrote {os.path.normpath(OUT)}")


if __name__ == "__main__":
    main()
