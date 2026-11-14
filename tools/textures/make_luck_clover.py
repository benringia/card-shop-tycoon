"""The lucky aura's clover (owner 2026-11-14: "there should be a lucky aura around the character while the lucky buff
that is bought from the store is active"): a white four-leaf clover with a short stem and a soft edge on a transparent
square (particle textures must be square; the game tints it green, or rainbow for 3x Super Luck).
Writes assets/ui/fx-luck/clover.png (128 px), uploaded as an image (id in Config/Luck AURA.CLOVER).
Run: python tools/textures/make_luck_clover.py"""
import math
import os

from PIL import Image, ImageDraw, ImageFilter

BIG = 512  # drawn big, then shrunk for smooth edges
SIZE = 128
OUT = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "ui", "fx-luck", "clover.png")


def heart(draw, cx, cy, size, angle):
    """One heart-shaped leaf pointing out from the middle at `angle`: two round lobes and a point at the centre"""
    ux, uy = math.cos(angle), math.sin(angle)
    px, py = -uy, ux
    lobe = size * 0.32
    for side in (-1, 1):
        lx = cx + ux * size * 0.62 + px * side * size * 0.27
        ly = cy + uy * size * 0.62 + py * side * size * 0.27
        draw.ellipse((lx - lobe, ly - lobe, lx + lobe, ly + lobe), fill=255)
    tip = (cx + ux * size * 0.04, cy + uy * size * 0.04)
    left = (cx + ux * size * 0.66 + px * size * 0.58, cy + uy * size * 0.66 + py * size * 0.58)
    right = (cx + ux * size * 0.66 - px * size * 0.58, cy + uy * size * 0.66 - py * size * 0.58)
    draw.polygon([tip, left, right], fill=255)


def main():
    alpha = Image.new("L", (BIG, BIG), 0)
    draw = ImageDraw.Draw(alpha)
    cx, cy = BIG * 0.5, BIG * 0.42
    leaf = BIG * 0.3
    for index in range(4):
        heart(draw, cx, cy, leaf, math.radians(45 + 90 * index))
    # gaps between the leaves (along the axes), so it reads as four hearts and not a cloud
    gap = int(BIG * 0.045)
    draw.line([(cx - BIG, cy), (cx + BIG, cy)], fill=0, width=gap)
    draw.line([(cx, cy - BIG), (cx, cy + BIG)], fill=0, width=gap)
    # the stem curving down to the right
    draw.line([(cx, cy + BIG * 0.2), (cx + BIG * 0.03, cy + BIG * 0.36), (cx + BIG * 0.1, cy + BIG * 0.46)], fill=255, width=int(BIG * 0.035), joint="curve")
    alpha = alpha.filter(ImageFilter.GaussianBlur(BIG * 0.004))
    image = Image.new("RGBA", (BIG, BIG), (255, 255, 255, 0))
    image.putalpha(alpha)
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    image.resize((SIZE, SIZE), Image.LANCZOS).save(OUT)
    print("wrote", os.path.normpath(OUT))


if __name__ == "__main__":
    main()
