"""Cleans white glyph icons cut from a magenta sheet (slice_icons.py): keying out the magenta eats into the thin dark
purple outline (it comes out dotted) and leaves speckle in dark areas. Rebuilds each icon as its white shape, its
purple details inside (pupils, plus signs, lines) in one exact purple, and a fresh even purple outline round the lot.

Usage: python tools/ui-icons/clean_glyphs.py <Name>[:open] [...]   (icons in assets/ui/icons, cleaned in place;
       ":open" also clears small white specks out of dark areas, e.g. MoveEclipse:open)
Needs Pillow."""
import os
import sys

from PIL import Image, ImageFilter

ICONS = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "ui", "icons")
PURPLE = (59, 26, 82)
SCALE = 4  # work at 4x for smooth edges
OUTLINE = 4  # outline width in pixels at the icon's 256 px


def clean(path: str, despeckle: bool = False):
    icon = Image.open(path).convert("RGBA")
    size = icon.size
    big = icon.resize((size[0] * SCALE, size[1] * SCALE), Image.LANCZOS)
    pixels = big.load()
    white = Image.new("L", big.size, 0)
    detail = Image.new("L", big.size, 0)
    wp, dp = white.load(), detail.load()
    for y in range(big.size[1]):
        for x in range(big.size[0]):
            r, g, b, a = pixels[x, y]
            if a < 110:
                continue
            if min(r, g, b) > 170:
                wp[x, y] = 255
            else:
                dp[x, y] = 255
    if despeckle:
        white = white.filter(ImageFilter.MinFilter(13)).filter(ImageFilter.MaxFilter(13))
    shape = Image.eval(Image.merge("L", [white]), lambda v: v)
    body = Image.new("L", big.size, 0)
    body.paste(255, (0, 0), white)
    body.paste(255, (0, 0), detail)
    # close small holes (speckle) in the body, then grow it for the outline
    hole = 21 if despeckle else 5
    closed = body.filter(ImageFilter.MaxFilter(hole)).filter(ImageFilter.MinFilter(hole))
    outline = closed
    grow = OUTLINE * SCALE
    while grow > 0:
        step = min(grow, 6)
        outline = outline.filter(ImageFilter.MaxFilter(step * 2 + 1 if step * 2 + 1 <= 13 else 13))
        grow -= step
    outline = outline.filter(ImageFilter.GaussianBlur(SCALE * 0.6))
    out = Image.new("RGBA", big.size, PURPLE + (0,))
    out.putalpha(outline)
    inner = closed.filter(ImageFilter.GaussianBlur(SCALE * 0.5))
    purple_layer = Image.new("RGBA", big.size, PURPLE + (255,))
    out.paste(purple_layer, (0, 0), inner)
    white_layer = Image.new("RGBA", big.size, (255, 255, 255, 255))
    out.paste(white_layer, (0, 0), shape.filter(ImageFilter.GaussianBlur(SCALE * 0.5)))
    out.resize(size, Image.LANCZOS).save(path)


if __name__ == "__main__":
    for arg in sys.argv[1:]:
        name, _, flag = arg.partition(":")
        clean(os.path.join(ICONS, name + ".png"), flag == "open")
        print(name)
