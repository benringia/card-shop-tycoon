"""The closing-ring warning's textures (look B, spec 2026-11-02-you-in-the-fight-design; Config/SwordFx): white, so the
game tints them. ring_outline / ring_glow: a circle's thin outline and the thicker glowing ring that closes onto it.
cone_outline / cone_glow: the same for a swipe, a sector with its point at the top centre, as wide as the swipe's
angle (Config/Bosses RING_SWIPE_HALF_ANGLE either side). Usage: python tools/textures/make_ring_textures.py
[out dir] (default assets/ui/combat). Needs Pillow. Uploaded as images; ids in Config/SwordFx."""
import math
import sys

from PIL import Image, ImageDraw, ImageFilter

OUT = sys.argv[1] if len(sys.argv) > 1 else "assets/ui/combat"
HALF_ANGLE = 35  # Config/Bosses RING_SWIPE_HALF_ANGLE
SIZE = 512


def ring(width, blur):
    img = Image.new("RGBA", (SIZE, SIZE), (255, 255, 255, 0))
    mask = Image.new("L", (SIZE, SIZE), 0)
    d = ImageDraw.Draw(mask)
    pad = width / 2 + blur * 2 + 2
    d.ellipse((pad, pad, SIZE - pad, SIZE - pad), outline=255, width=int(width))
    if blur:
        glow = mask.filter(ImageFilter.GaussianBlur(blur))
        mask = Image.eval(Image.merge("L", [glow]), lambda v: min(255, int(v * 1.6)))
        mask.paste(255, (0, 0), Image.new("L", (SIZE, SIZE), 0))
    img.putalpha(mask)
    return img


def cone_points(height, inset):
    """The sector's outline points: its point at the top centre, its arc at the bottom."""
    width = 2 * height * math.sin(math.radians(HALF_ANGLE))
    cx = width / 2
    pts = [(cx, inset)]
    steps = 24
    for i in range(steps + 1):
        a = math.radians(-HALF_ANGLE + 2 * HALF_ANGLE * i / steps)
        r = height - inset
        pts.append((cx + r * math.sin(a), r * math.cos(a)))
    return width, pts


def cone(width_px, blur):
    height = SIZE
    width, pts = cone_points(height, width_px / 2 + blur * 2 + 2)
    mask = Image.new("L", (int(math.ceil(width)), height), 0)
    d = ImageDraw.Draw(mask)
    d.line(pts + [pts[0]], fill=255, width=int(width_px), joint="curve")
    if blur:
        glow = mask.filter(ImageFilter.GaussianBlur(blur))
        mask = Image.eval(glow, lambda v: min(255, int(v * 1.6)))
    img = Image.new("RGBA", mask.size, (255, 255, 255, 0))
    img.putalpha(mask)
    return img


ring(8, 0).save(f"{OUT}/ring_outline.png")
ring(14, 6).save(f"{OUT}/ring_glow.png")
cone(8, 0).save(f"{OUT}/cone_outline.png")
cone(14, 6).save(f"{OUT}/cone_glow.png")
print("ok")
