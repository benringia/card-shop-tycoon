"""The town's falling leaf (owner 2026-11-19: "do town beauties"): a white leaf with a midrib and a short stem on a
transparent square (particle textures must be square; the game tints it green to amber, Config/TownDress LEAVES).
Writes assets/ui/fx-town/leaf.png (128 px), uploaded as an image (id in Config/TownDress LEAVES.texture).
Run: python tools/textures/make_leaf.py"""
import math
import os

from PIL import Image, ImageDraw, ImageFilter

BIG = 512  # drawn big, then shrunk for smooth edges
SIZE = 128
OUT = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "ui", "fx-town", "leaf.png")


def main():
    alpha = Image.new("L", (BIG, BIG), 0)
    draw = ImageDraw.Draw(alpha)
    # the blade: two arcs meeting in points at the tip (top right) and the base (bottom left)
    tip = (BIG * 0.80, BIG * 0.16)
    base = (BIG * 0.26, BIG * 0.74)
    length = math.dist(tip, base)
    ux, uy = (tip[0] - base[0]) / length, (tip[1] - base[1]) / length
    px, py = -uy, ux
    outline = []
    steps = 40
    for side in (1, -1):
        points = []
        for step in range(steps + 1):
            t = step / steps
            # widest a little under the middle, pinched at both ends
            width = length * 0.30 * math.sin(math.pi * t) ** 0.8 * (1.15 - 0.3 * t)
            points.append((base[0] + ux * length * t + px * width * side, base[1] + uy * length * t + py * width * side))
        outline.extend(points if side == 1 else reversed(points))
    draw.polygon(outline, fill=255)
    # the midrib and side veins as thin cuts, so it reads as a leaf at any size
    rib = int(BIG * 0.016)
    draw.line([base, (tip[0] - ux * length * 0.06, tip[1] - uy * length * 0.06)], fill=110, width=rib)
    for t in (0.3, 0.5, 0.7):
        at = (base[0] + ux * length * t, base[1] + uy * length * t)
        reach = length * 0.2 * math.sin(math.pi * t)
        for side in (1, -1):
            end = (at[0] + ux * reach * 0.6 + px * reach * side, at[1] + uy * reach * 0.6 + py * reach * side)
            draw.line([at, end], fill=150, width=max(2, rib // 2))
    # the stem
    draw.line([base, (base[0] - ux * length * 0.16, base[1] - uy * length * 0.16)], fill=255, width=int(BIG * 0.022))
    alpha = alpha.filter(ImageFilter.GaussianBlur(BIG * 0.004)).resize((SIZE, SIZE), Image.LANCZOS)
    image = Image.new("RGBA", (SIZE, SIZE), (255, 255, 255, 0))
    image.putalpha(alpha)
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    image.save(OUT)
    print(os.path.abspath(OUT))


if __name__ == "__main__":
    main()
