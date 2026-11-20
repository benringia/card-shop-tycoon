"""Cut a product picture (Order Stock, Prices) out of a Studio screen capture.

Round 5 (spec 2026-11-04-round5-design section 6): the pack and deck box are rendered big in a ViewportFrame on a
key-colour background (RGB 255, 0, 255) and captured with the Studio MCP's screen_capture. This keys the magenta out
by each pixel's distance from it (so purple surfaces stay), un-mixes the key from the soft edge pixels, trims to the
picture and scales it to 256 px tall.

Also the weapon portraits (weapons round 1, docs/weapons.md): a model whose colours sit near magenta (the Shade Forge
Sword's purple gems) is captured on green instead and cut with --key 0,255,0.

A model whose look is SurfaceGuis (the sealed booster box, the sleeve packets, 2026-11-20) can't be drawn in a
ViewportFrame, and a Neon backdrop in the world glows onto its edges (a pink fringe). Shoot it in Play in front of a
plain magenta part (SmoothPlastic, post effects and Atmosphere off on the client) and cut with --lit: the backdrop is
then lit by the world, so it is keyed by what magenta looks like (red and blue high, green low) in any shade, and the
mask is pulled in a pixel to drop the mixed edge.

Usage: python tools/ui-art/cut_product_picture.py [--key R,G,B | --lit] <capture> <out.png> [left top right bottom]
The optional box crops the capture first (when it holds more than one model). Needs Pillow.
"""
import math
import sys

from PIL import Image

HEIGHT = 256
KEY = (255, 0, 255)
CLEAR = 70  # this close to the key colour (RGB distance): transparent
OPAQUE = 150  # this far or more: fully the picture; in between, an edge pixel


def cut(source, box=None, key=KEY):
    image = Image.open(source).convert('RGBA')
    if box:
        image = image.crop(box)
    pixels = image.load()
    for y in range(image.size[1]):
        for x in range(image.size[0]):
            r, g, b, _ = pixels[x, y]
            distance = math.dist((r, g, b), key)
            if distance <= CLEAR:
                pixels[x, y] = (0, 0, 0, 0)
            elif distance < OPAQUE:
                alpha = (distance - CLEAR) / (OPAQUE - CLEAR)
                # the edge pixel is picture * alpha + key * (1 - alpha): take the key back out
                colour = tuple(max(0, min(255, round((c - k * (1 - alpha)) / alpha))) for c, k in zip((r, g, b), key))
                pixels[x, y] = (*colour, round(alpha * 255))
    bounds = image.getbbox()
    if bounds:
        image = image.crop(bounds)
    width = round(image.size[0] * HEIGHT / image.size[1])
    return image.resize((width, HEIGHT), Image.LANCZOS)


def cut_lit(source, box=None):
    from PIL import ImageChops, ImageFilter
    image = Image.open(source).convert('RGBA')
    if box:
        image = image.crop(box)
    r, g, b, _ = image.split()
    # the backdrop in any light: red and blue well over green
    backdrop = ImageChops.multiply(
        ImageChops.multiply(r.point(lambda v: 255 if v > 120 else 0), b.point(lambda v: 255 if v > 150 else 0)),
        g.point(lambda v: 255 if v < 80 else 0),
    )
    alpha = ImageChops.invert(backdrop).filter(ImageFilter.MinFilter(3)).filter(ImageFilter.GaussianBlur(0.6))
    image.putalpha(alpha)
    bounds = alpha.point(lambda v: 255 if v > 8 else 0).getbbox()
    if bounds:
        image = image.crop(bounds)
    width = round(image.size[0] * HEIGHT / image.size[1])
    return image.resize((width, HEIGHT), Image.LANCZOS)


def main():
    args = sys.argv[1:]
    key = KEY
    if args and args[0] == '--lit':
        args = args[1:]
        if len(args) not in (2, 6):
            print(__doc__)
            sys.exit(1)
        box = tuple(int(v) for v in args[2:6]) if len(args) == 6 else None
        cut_lit(args[0], box).save(args[1])
        print('saved', args[1])
        return
    if len(args) >= 2 and args[0] == '--key':
        key = tuple(int(v) for v in args[1].split(','))
        args = args[2:]
    if len(args) not in (2, 6) or len(key) != 3:
        print(__doc__)
        sys.exit(1)
    box = tuple(int(v) for v in args[2:6]) if len(args) == 6 else None
    cut(args[0], box, key).save(args[1])
    print('saved', args[1])


if __name__ == '__main__':
    main()
