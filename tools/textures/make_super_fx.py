"""The super moves' textures (spec 2026-11-05-super-moves-design): white with the shape in the alpha, so the game tints
them per look. Written to assets/ui/fx-super (uploaded as images; ids in Config/SuperFx TEXTURES):

  firestrip  tongues of flame rising along a strip, for beams (a beam runs a texture's height along its length)
  crack      glowing cracks spreading from the middle, for the ground (Inferno's S lava, Magma Slam)

Particle textures are square. Usage: python tools/textures/make_super_fx.py [out dir]. Needs Pillow."""
import math
import os
import random
import sys

from PIL import Image, ImageChops, ImageDraw, ImageFilter

OUT = sys.argv[1] if len(sys.argv) > 1 else "assets/ui/fx-super"


def white(mask):
    img = Image.new("RGBA", mask.size, (255, 255, 255, 0))
    img.putalpha(mask)
    return img


def firestrip():
    """Flame tongues for a beam: soft licks rising up the strip (the texture tiles along the beam's length), brighter
    in the middle, with a few cut-out gaps so it flickers as it scrolls."""
    size = 256
    rng = random.Random(7)
    mask = Image.new("L", (size, size), 0)
    d = ImageDraw.Draw(mask)
    for _ in range(20):
        x = rng.uniform(40, 216)
        y = rng.uniform(0, size)
        w = rng.uniform(26, 56)
        h = rng.uniform(70, 140)
        # a tongue: a teardrop pointing up, wider at its foot
        points = []
        for step in range(25):
            t = step / 24
            half = w / 2 * math.sin(math.pi * t) ** 0.6 * (1 - 0.55 * t)
            points.append((x + half, y + h / 2 - h * t))
        for step in range(24, -1, -1):
            t = step / 24
            half = w / 2 * math.sin(math.pi * t) ** 0.6 * (1 - 0.55 * t)
            points.append((x - half, y + h / 2 - h * t))
        for shift in (-size, 0, size):  # wrap round so it tiles along the strip
            d.polygon([(px, py + shift) for px, py in points], fill=int(rng.uniform(200, 255)))
    # brighter down the middle, fading to the strip's edges
    fade = Image.new("L", (size, size), 0)
    fd = ImageDraw.Draw(fade)
    for x in range(size):
        t = abs(x - size / 2) / (size / 2)
        fd.line((x, 0, x, size), fill=int(255 * max(0.0, 1 - t ** 3)))
    mask = ImageChops.multiply(mask.filter(ImageFilter.GaussianBlur(2.5)), fade)
    return white(mask)


def crack():
    """Glowing cracks spreading out from the middle: a few jagged branches with smaller forks, a soft glow round them."""
    size = 512
    c = size / 2
    rng = random.Random(11)
    lines = Image.new("L", (size, size), 0)
    d = ImageDraw.Draw(lines)

    def branch(x, y, angle, length, width, depth):
        steps = max(3, int(length / 18))
        points = [(x, y)]
        for _ in range(steps):
            angle += rng.uniform(-0.45, 0.45)
            x += math.cos(angle) * length / steps
            y += math.sin(angle) * length / steps
            points.append((x, y))
        d.line(points, fill=255, width=max(2, int(width)), joint="curve")
        if depth > 0:
            for _ in range(2):
                i = rng.randrange(1, len(points))
                bx, by = points[i]
                branch(bx, by, angle + rng.choice((-1, 1)) * rng.uniform(0.5, 1.1), length * 0.45, width * 0.6, depth - 1)

    for k in range(7):
        branch(c, c, k * 2 * math.pi / 7 + rng.uniform(-0.2, 0.2), rng.uniform(170, 235), 9, 2)
    d.ellipse((c - 26, c - 26, c + 26, c + 26), fill=255)
    glow = lines.filter(ImageFilter.GaussianBlur(10))
    mask = ImageChops.add(lines, ImageChops.multiply(glow, Image.new("L", (size, size), 200)))
    # fade out towards the edge so the decal has no hard border
    fade = Image.new("L", (size, size), 0)
    fd = ImageDraw.Draw(fade)
    for r in range(int(c), 0, -2):
        fd.ellipse((c - r, c - r, c + r, c + r), fill=int(255 * min(1.0, (c - r) / (c * 0.25) + 0.0) if r > c * 0.75 else 255))
    return white(ImageChops.multiply(mask, fade))


def main():
    os.makedirs(OUT, exist_ok=True)
    for name, make in (("firestrip", firestrip), ("crack", crack)):
        make().save(os.path.join(OUT, f"{name}.png"))
        print("wrote", name)


if __name__ == "__main__":
    main()
