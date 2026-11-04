"""Cut a product picture (Order Stock, Prices) out of a Studio screen capture.

Round 5 (spec 2026-11-04-round5-design section 6): the pack and deck box are rendered big in a ViewportFrame on a
key-colour background (RGB 255, 0, 255) and captured with the Studio MCP's screen_capture. This keys the magenta out
by each pixel's distance from it (so purple surfaces stay), un-mixes the key from the soft edge pixels, trims to the
picture and scales it to 256 px tall.

Usage: python tools/ui-art/cut_product_picture.py <capture> <out.png> [left top right bottom]
The optional box crops the capture first (when it holds more than one model). Needs Pillow.
"""
import math
import sys

from PIL import Image

HEIGHT = 256
KEY = (255, 0, 255)
CLEAR = 70  # this close to the key colour (RGB distance): transparent
OPAQUE = 150  # this far or more: fully the picture; in between, an edge pixel


def cut(source, box=None):
    image = Image.open(source).convert('RGBA')
    if box:
        image = image.crop(box)
    pixels = image.load()
    for y in range(image.size[1]):
        for x in range(image.size[0]):
            r, g, b, _ = pixels[x, y]
            distance = math.dist((r, g, b), KEY)
            if distance <= CLEAR:
                pixels[x, y] = (0, 0, 0, 0)
            elif distance < OPAQUE:
                alpha = (distance - CLEAR) / (OPAQUE - CLEAR)
                # the edge pixel is picture * alpha + key * (1 - alpha): take the key back out
                colour = tuple(max(0, min(255, round((c - k * (1 - alpha)) / alpha))) for c, k in zip((r, g, b), KEY))
                pixels[x, y] = (*colour, round(alpha * 255))
    bounds = image.getbbox()
    if bounds:
        image = image.crop(bounds)
    width = round(image.size[0] * HEIGHT / image.size[1])
    return image.resize((width, HEIGHT), Image.LANCZOS)


def main():
    if len(sys.argv) not in (3, 7):
        print(__doc__)
        sys.exit(1)
    box = tuple(int(v) for v in sys.argv[3:7]) if len(sys.argv) == 7 else None
    cut(sys.argv[1], box).save(sys.argv[2])
    print('saved', sys.argv[2])


if __name__ == '__main__':
    main()
