"""The Frontier Pack's art (owner 2026-11-23: Frontier cards in their own pack, pick B), laid out like the First Spark
pack's art (assets/ui/packs/FirstSpark.jpg, 848 x 1264: a plain sky band over the painting, which
tools/textures/make_pack_textures.py skips) and made from our own painting, no generation: an aurora sky over the
Stormking card's storm (assets/ui/card-art/Stormking.jpg). The aurora is the Frontier cards' look everywhere.

Usage: python tools/ui-art/make_frontier_pack_art.py [out.jpg]   (default assets/ui/packs/Frontier.jpg)
Then: python tools/textures/make_pack_textures.py assets/ui/packs/Frontier.jpg tools/ui-art/fonts/Fredoka.ttf
assets/blender/Pack/Frontier "FRONTIER"
"""
import math
import os
import sys

from PIL import Image, ImageDraw, ImageFilter

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
W, H = 848, 1264  # as the First Spark art
SKY = 300  # the plain sky band at the top (the First Spark art's seam is at 0.24)
PAINTING = os.path.join(REPO, "assets", "ui", "card-art", "Stormking.jpg")


def aurora(w, h):
    """A night sky with soft aurora curtains, teal to violet, brightest low down."""
    sky = Image.new("RGB", (w, h))
    px = sky.load()
    for y in range(h):
        t = y / max(1, h - 1)
        top = (22, 16, 54)
        low = (52, 34, 98)
        for x in range(w):
            px[x, y] = tuple(int(top[i] + (low[i] - top[i]) * t) for i in range(3))
    glow = Image.new("RGB", (w, h), (0, 0, 0))
    draw = ImageDraw.Draw(glow)
    for band, (color, phase, base) in enumerate((((60, 230, 180), 0.0, 0.55), ((120, 140, 255), 1.7, 0.4), ((200, 110, 255), 3.1, 0.7))):
        for x in range(0, w, 3):
            wave = math.sin(x / w * math.pi * 2.2 + phase) * 0.12 + math.sin(x / w * math.pi * 5.3 + phase * 2) * 0.05
            y0 = int(h * (base + wave - 0.28))
            y1 = int(h * (base + wave + 0.12))
            draw.line([(x, y0), (x, y1)], fill=color, width=3)
    glow = glow.filter(ImageFilter.GaussianBlur(18))
    sky = Image.blend(sky, Image.eval(glow, lambda v: v), 0.0)
    sky = Image.composite(glow, sky, glow.convert("L").point(lambda v: min(255, int(v * 0.9))))
    stars = ImageDraw.Draw(sky)
    seed = 7
    for _ in range(70):
        seed = (seed * 1103515245 + 12345) % 2 ** 31
        x = seed % w
        seed = (seed * 1103515245 + 12345) % 2 ** 31
        y = seed % h
        r = 1 if seed % 5 else 2
        stars.ellipse([x - r, y - r, x + r, y + r], fill=(235, 240, 255))
    return sky


def main():
    out = sys.argv[1] if len(sys.argv) > 1 else os.path.join(REPO, "assets", "ui", "packs", "Frontier.jpg")
    painting = Image.open(PAINTING).convert("RGB")
    canvas = Image.new("RGB", (W, H))
    canvas.paste(aurora(W, SKY), (0, 0))
    # the painting covers the rest, its top (the storm clouds) kept
    area = (W, H - SKY)
    scale = max(area[0] / painting.width, area[1] / painting.height)
    big = painting.resize((int(painting.width * scale) + 1, int(painting.height * scale) + 1), Image.LANCZOS)
    left = (big.width - area[0]) // 2
    canvas.paste(big.crop((left, 0, left + area[0], area[1])), (0, SKY))
    # an aurora wash over the storm's top, so the two halves belong together
    wash = aurora(W, H - SKY).resize((W, H - SKY))
    fade = Image.linear_gradient("L").resize((W, H - SKY)).point(lambda v: int(max(0, 150 - v) * 0.55))
    lower = canvas.crop((0, SKY, W, H))
    canvas.paste(Image.composite(wash, lower, fade), (0, SKY))
    canvas.save(out, quality=92)
    print("wrote", out, canvas.size)


if __name__ == "__main__":
    main()
