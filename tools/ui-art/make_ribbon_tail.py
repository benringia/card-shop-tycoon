"""The welcome title's ribbon tail (owner 2026-11-16, welcome mockup A "Ribbon banner"; Config/Welcome TITLE.ribbonTail).

A white swallowtail, notched on its left (the left tail; the right one is the same picture turned half round), tinted
in game with ImageColor3. Drawn 4x and scaled down for smooth edges.

    python tools/ui-art/make_ribbon_tail.py [out.png]

Writes assets/ui/welcome/ribbon_tail.png (128 x 192) by default.
"""
import os
import sys

from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, "..", ".."))
WIDTH, HEIGHT, NOTCH = 128, 192, 0.34  # the notch reaches this share of the width in

if __name__ == "__main__":
    out = sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, "assets", "ui", "welcome", "ribbon_tail.png")
    big = Image.new("RGBA", (WIDTH * 4, HEIGHT * 4), (255, 255, 255, 0))
    w, h = WIDTH * 4, HEIGHT * 4
    ImageDraw.Draw(big).polygon([(0, 0), (w, 0), (w, h), (0, h), (w * NOTCH, h / 2)], fill=(255, 255, 255, 255))
    os.makedirs(os.path.dirname(out), exist_ok=True)
    big.resize((WIDTH, HEIGHT), Image.LANCZOS).save(out, optimize=True)
    print(out)
