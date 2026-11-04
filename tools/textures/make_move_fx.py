"""The Pet button moves' textures (spec 2026-11-05-pet-moves-design): white with the shape in the alpha, so the game
tints them per grade. Written to assets/ui/fx-moves (uploaded as images; ids in Config/MoveFx TEXTURES):

  raindrop   a falling drop: a thin upright streak, its round head at the bottom (Healing Rain's falling beams)
  vine       a leafy vine strip (Vine Snare at C and B; grey shading, tinted by the beam's colour)
  bark       a thick root strip with wavy grain (Vine Snare at A and S; grey shading, tinted)

Particle textures are square (particles draw square). Usage: python tools/textures/make_move_fx.py [out dir]. Needs
Pillow."""
import os
import sys

from PIL import Image, ImageChops, ImageDraw, ImageFilter

OUT = sys.argv[1] if len(sys.argv) > 1 else "assets/ui/fx-moves"


def white(mask):
    """A white image with `mask` as its alpha."""
    img = Image.new("RGBA", mask.size, (255, 255, 255, 0))
    img.putalpha(mask)
    return img


def add(*masks):
    out = masks[0]
    for m in masks[1:]:
        out = ImageChops.add(out, m)
    return out


def raindrop():
    size = 256
    cx = size / 2
    tail = Image.new("L", (size, size), 0)
    d = ImageDraw.Draw(tail)
    # a tapering streak from a hair-thin top to the drop's width near the bottom, fading in from the top
    for y in range(12, 200):
        t = (y - 12) / (200 - 12)
        half = 3 + 19 * t
        d.line((cx - half, y, cx + half, y), fill=int(110 + 145 * t ** 1.2))
    tail = tail.filter(ImageFilter.GaussianBlur(2))
    head = Image.new("L", (size, size), 0)
    ImageDraw.Draw(head).ellipse((cx - 30, 176, cx + 30, 246), fill=255)
    head = head.filter(ImageFilter.GaussianBlur(4))
    return add(tail, head)


def vine():
    """A leafy vine strip for a beam (a beam runs the texture's height along its length and tiles it): a shaded stem
    down the middle, a leaf out to each side. Grey shading in the colour (a beam's colour multiplies it)."""
    size = 256
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    # the stem: lighter in the middle, darker at its edges
    for x in range(92, 165):
        t = abs(x - 128) / 36
        v = int(235 - 95 * t ** 1.5)
        d.line((x, 0, x, size), fill=(v, v, v, 255))
    # two pointed leaves growing out of the stem, one each side, each with a darker midrib
    import math
    for base, tip, half in (((100, 92), (14, 40), 26), ((156, 210), (242, 158), 26)):
        bx, by = base
        tx, ty = tip
        length = math.hypot(tx - bx, ty - by)
        ux, uy = (tx - bx) / length, (ty - by) / length
        nx, ny = -uy, ux
        outline = []
        for step in range(21):
            t = step / 20
            w = half * math.sin(math.pi * t) ** 0.8
            outline.append((bx + ux * length * t + nx * w, by + uy * length * t + ny * w))
        for step in range(20, -1, -1):
            t = step / 20
            w = half * math.sin(math.pi * t) ** 0.8
            outline.append((bx + ux * length * t - nx * w, by + uy * length * t - ny * w))
        d.polygon(outline, fill=(225, 225, 225, 255))
        d.line((base, (bx + ux * length * 0.92, by + uy * length * 0.92)), fill=(140, 140, 140, 255), width=5)
    return img.filter(ImageFilter.GaussianBlur(1.2))


def bark():
    """A thick root strip for a beam: rounded edges, wavy darker grain running along it, a knot. Grey shading in the
    colour, like vine."""
    size = 256
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    for x in range(14, 243):
        t = abs(x - 128) / 114
        v = int(210 - 90 * t ** 2)
        a = 255 if t < 0.92 else int(255 * (1 - (t - 0.92) / 0.08))
        d.line((x, 0, x, size), fill=(v, v, v, a))
    import math
    for lane in range(7):
        x = 40 + lane * 30
        points = [(x + 7 * math.sin(y / 256 * 2 * math.pi * 2 + lane), y) for y in range(0, size + 1, 8)]
        d.line(points, fill=(105, 105, 105, 255), width=4)
    d.ellipse((150, 90, 190, 140), fill=(95, 95, 95, 255))
    d.ellipse((160, 102, 180, 128), fill=(160, 160, 160, 255))
    return img.filter(ImageFilter.GaussianBlur(1))


def rune():
    """Curse's circle on the ground: two rings, a seven-point star {7/3} inside (not a five-point pentagram, spec), short
    rune strokes between the rings."""
    import math
    size = 512
    c = size / 2
    mask = Image.new("L", (size, size), 0)
    d = ImageDraw.Draw(mask)
    d.ellipse((c - 246, c - 246, c + 246, c + 246), outline=255, width=10)
    d.ellipse((c - 200, c - 200, c + 200, c + 200), outline=255, width=7)
    points = [(c + 196 * math.cos(math.radians(k * 360 / 7 - 90)), c + 196 * math.sin(math.radians(k * 360 / 7 - 90))) for k in range(7)]
    star = [points[(k * 3) % 7] for k in range(8)]
    d.line(star, fill=255, width=8, joint="curve")
    # rune strokes between the rings: little bars, ticks and hooks round the band
    for k in range(28):
        a = math.radians(k * 360 / 28)
        r0, r1 = 210, 236
        x0, y0 = c + r0 * math.cos(a), c + r0 * math.sin(a)
        x1, y1 = c + r1 * math.cos(a), c + r1 * math.sin(a)
        d.line((x0, y0, x1, y1), fill=255, width=5)
        if k % 2 == 0:
            ax = c + 223 * math.cos(a + 0.05)
            ay = c + 223 * math.sin(a + 0.05)
            d.ellipse((ax - 5, ay - 5, ax + 5, ay + 5), fill=255)
    glow = mask.filter(ImageFilter.GaussianBlur(9)).point(lambda v: int(v * 0.8))
    return add(mask.filter(ImageFilter.GaussianBlur(1.2)), glow)


def sigil():
    """Curse's mark over the foe: an eye in a broken ring, a slit pupil, three drips below."""
    size = 512
    c = size / 2
    mask = Image.new("L", (size, size), 0)
    d = ImageDraw.Draw(mask)
    for k in range(6):
        start = k * 60 + 8
        d.arc((c - 230, c - 230, c + 230, c + 230), start, start + 44, fill=255, width=18)
    # the eye: an almond outline, a slit pupil
    import math
    outline = []
    for step in range(41):
        t = step / 40
        x = c - 150 + 300 * t
        outline.append((x, c - 92 * math.sin(math.pi * t)))
    for step in range(40, -1, -1):
        t = step / 40
        x = c - 150 + 300 * t
        outline.append((x, c + 92 * math.sin(math.pi * t)))
    d.line(outline + [outline[0]], fill=255, width=16, joint="curve")
    d.ellipse((c - 24, c - 70, c + 24, c + 70), fill=255)
    for x, drop in ((c - 60, 150), (c, 205), (c + 60, 165)):
        top = c + 92 * math.sin(math.pi * (x - (c - 150)) / 300) - 10
        d.polygon([(x - 7, top), (x + 7, top), (x + 13, c + drop - 14), (x - 13, c + drop - 14)], fill=255)
        d.ellipse((x - 16, c + drop - 30, x + 16, c + drop + 4), fill=255)
    glow = mask.filter(ImageFilter.GaussianBlur(12)).point(lambda v: int(v * 0.7))
    return add(mask.filter(ImageFilter.GaussianBlur(1.2)), glow)


MASKS = {"raindrop": raindrop, "rune": rune, "sigil": sigil}
SHADED = {"vine": vine, "bark": bark}

if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    for name, make in MASKS.items():
        white(make()).save(os.path.join(OUT, name + ".png"))
        print(name)
    for name, make in SHADED.items():
        make().save(os.path.join(OUT, name + ".png"))
        print(name)
