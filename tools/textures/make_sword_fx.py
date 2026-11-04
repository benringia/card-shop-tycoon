"""The sword-moves round's effect textures (spec 2026-11-04-sword-moves-design, "Effects"): white with the shape in the
alpha, tinted in game with the sword's slash colour. Written to assets/ui/fx-sword (uploaded as images; ids in
Config/SwordFx TEXTURES):

  Crescent  128 x 512  the candy sparkle arc's body: a bright core with a soft glow either side, sharp at both ends.
                       Upright, because a Beam runs a texture's height along its length (the same as the fight
                       effects' bolt); the Beam's curve bends it into the swing's arc and its Transparency wipes it.
  Burst     1024       a 4 x 4 flipbook (Grid4x4) of an 8-spike star popping out and fading: the hit's star burst.
  Line      32 x 256   a sharp streak tapered at both ends, upright: the dash slash's cut lines (Beams).
  Star      128        a 4-point sparkle: the stars the arc sheds (particles draw square).

Usage: python tools/textures/make_sword_fx.py [out dir]. Needs Pillow."""
import math
import os
import sys

from PIL import Image

OUT = sys.argv[1] if len(sys.argv) > 1 else "assets/ui/fx-sword"


def white(mask):
    """A white image with `mask` (an L image) as its alpha."""
    img = Image.new("RGBA", mask.size, (255, 255, 255, 0))
    img.putalpha(mask)
    return img


def from_function(size, alpha):
    """An L mask from alpha(u, v) in 0..1, u and v the pixel centre in 0..1 across and down."""
    w, h = size
    mask = Image.new("L", size)
    mask.putdata([
        int(255 * max(0.0, min(1.0, alpha((x + 0.5) / w, (y + 0.5) / h))))
        for y in range(h)
        for x in range(w)
    ])
    return mask


def smoothstep(edge0, edge1, x):
    t = max(0.0, min(1.0, (x - edge0) / (edge1 - edge0)))
    return t * t * (3 - 2 * t)


def crescent():
    def alpha(u, v):
        taper = math.sin(math.pi * v) ** 0.6  # full in the middle, a sharp point at each end
        half = 0.48 * taper
        across = abs(u - 0.5)
        if half <= 1e-4 or across >= half:
            return 0.0
        core = 1 - smoothstep(half * 0.18, half * 0.32, across)  # the hard bright line
        glow = (1 - across / half) ** 1.8  # the soft body round it
        return max(core, 0.75 * glow) * (0.55 + 0.45 * taper)

    return from_function((128, 512), alpha)


def burst_frame(t):
    """One frame of the star burst, t from 0 (popping out) to 1 (gone)."""
    grow = 1 - (1 - min(1.0, t / 0.45)) ** 3  # ease-out cubic
    scale = 0.3 + 0.7 * grow
    fade = 1.0 if t < 0.35 else max(0.0, 1 - (t - 0.35) / 0.65) ** 1.5
    sharp = 3 + 6 * t  # the spikes thin as it fades

    def alpha(u, v):
        x, y = u * 2 - 1, v * 2 - 1
        r = math.hypot(x, y)
        theta = math.atan2(y, x)
        spikes = abs(math.cos(4 * theta)) ** sharp
        long = 0.78 + 0.22 * math.cos(4 * theta)  # long and short spikes in turn
        reach = 0.95 * scale * (0.22 + 0.78 * spikes * long)
        star = 1 - smoothstep(reach * 0.82, reach, r)
        core = max(0.0, 1 - r / (0.42 * scale)) ** 1.5
        return max(star * 0.9, core) * fade

    return from_function((256, 256), alpha)


def burst():
    sheet = Image.new("L", (1024, 1024))
    for index in range(16):
        frame = burst_frame(index / 15)
        sheet.paste(frame, ((index % 4) * 256, (index // 4) * 256))
    return sheet


def line():
    def alpha(u, v):
        taper = math.sin(math.pi * v) ** 0.8
        across = abs(u - 0.5) * 2
        width = 0.9 * taper
        if width <= 1e-4:
            return 0.0
        return math.exp(-((across / (0.35 * width + 1e-4)) ** 2)) * taper

    return from_function((32, 256), alpha)


def star():
    def alpha(u, v):
        x, y = abs(u * 2 - 1), abs(v * 2 - 1)
        q = x ** 0.45 + y ** 0.45  # a 4-point star with concave sides
        arms = max(0.0, 1 - q) ** 1.1 * 1.6
        core = max(0.0, 1 - math.hypot(x, y) / 0.3) ** 2
        return max(arms, core)

    return from_function((128, 128), alpha)


def main():
    os.makedirs(OUT, exist_ok=True)
    for name, make in (("Crescent", crescent), ("Burst", burst), ("Line", line), ("Star", star)):
        path = os.path.join(OUT, f"{name}.png")
        white(make()).save(path)
        print("wrote", path)


if __name__ == "__main__":
    main()
