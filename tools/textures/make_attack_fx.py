"""The fight effects' textures (spec 2026-11-02-attack-animations-design, the glowing look of the owner's reference: hot
white cores, soft glows, long streaks): white with the shape in the alpha, so the game tints them per element and
layers a coloured glow under a white core. Written to assets/ui/fx-attack (uploaded as images; ids in
Config/AttackFx TEXTURES):

  glow       a soft round glow                         flare    a four-point star flare
  streak     a comet: bright head, long tapering tail   spark    a thin streak of light, upright (flies along its speed)
  ring       a thin shockwave ring                      bolt     jagged lightning with branches
  slash      a crescent slash, sharp at both ends       shard    a tall crystal shard (ground eruptions)
  impact     a starburst of spikes                      flame    a flame tongue
Textures drawn by particles are square (particles draw square); the bolt is upright (a beam runs a texture's height
along its length).
  smoke      a soft puff

Usage: python tools/textures/make_attack_fx.py [out dir]. Needs Pillow."""
import math
import os
import random
import sys

from PIL import Image, ImageChops, ImageDraw, ImageFilter

OUT = sys.argv[1] if len(sys.argv) > 1 else "assets/ui/fx-attack"
random.seed(7)


def white(mask):
    """A white image with `mask` as its alpha."""
    img = Image.new("RGBA", mask.size, (255, 255, 255, 0))
    img.putalpha(mask)
    return img


def radial(size, power, scale=1.0):
    """Alpha falling off from the centre: (1 - r)^power, r reaching 1 at scale x the half size."""
    w, h = size
    cx, cy = w / 2, h / 2
    data = []
    for y in range(h):
        for x in range(w):
            r = math.hypot((x - cx) / (w / 2 * scale), (y - cy) / (h / 2 * scale))
            data.append(int(255 * max(0.0, 1 - r) ** power))
    mask = Image.new("L", size)
    mask.putdata(data)
    return mask


def add(*masks):
    out = masks[0]
    for m in masks[1:]:
        out = ImageChops.add(out, m)
    return out


def boost(mask, factor):
    return mask.point(lambda v: min(255, int(v * factor)))


def glow():
    return radial((256, 256), 2.2)


def flare():
    size = 512
    core = radial((size, size), 3.0, 0.5)
    rays = Image.new("L", (size, size), 0)
    d = ImageDraw.Draw(rays)
    c = size / 2
    for angle, length, width in ((0, 0.98, 6), (90, 0.98, 6), (45, 0.45, 3), (135, 0.45, 3)):
        a = math.radians(angle)
        dx, dy = math.cos(a) * c * length, math.sin(a) * c * length
        d.line((c - dx, c - dy, c + dx, c + dy), fill=255, width=width)
    rays = rays.filter(ImageFilter.GaussianBlur(3))
    # the rays thin out toward their tips
    taper = radial((size, size), 1.2)
    rays = ImageChops.multiply(boost(rays, 1.6), taper)
    return add(core, rays, boost(radial((size, size), 1.5, 0.18), 1.0))


def streak():
    w, h = 1024, 256
    mask = Image.new("L", (w, h), 0)
    d = ImageDraw.Draw(mask)
    head = 840
    # the body: a tapering wedge from the head back to the tail
    d.polygon([(head, h / 2 - 52), (40, h / 2 - 6), (40, h / 2 + 6), (head, h / 2 + 52)], fill=190)
    d.ellipse((head - 54, h / 2 - 54, head + 54, h / 2 + 54), fill=255)
    body = mask.filter(ImageFilter.GaussianBlur(12))
    # speed lines streaming off it
    lines = Image.new("L", (w, h), 0)
    ld = ImageDraw.Draw(lines)
    for _ in range(40):
        y = h / 2 + random.gauss(0, 30)
        start = random.uniform(80, 600)
        end = random.uniform(start + 150, head - 20)
        ld.line((start, y, end, y), fill=random.randint(120, 255), width=random.choice((1, 2, 2, 3)))
    lines = lines.filter(ImageFilter.GaussianBlur(1.2))
    # fade toward the tail
    fade = Image.linear_gradient("L").rotate(90, expand=True).resize((w, h))
    fade = fade.point(lambda v: int(255 * (v / 255) ** 1.6))
    core = Image.new("L", (w, h), 0)
    ImageDraw.Draw(core).ellipse((head - 30, h / 2 - 24, head + 36, h / 2 + 24), fill=255)
    core = core.filter(ImageFilter.GaussianBlur(7))
    halo = Image.new("L", (w, h), 0)
    ImageDraw.Draw(halo).ellipse((head - 80, h / 2 - 70, head + 80, h / 2 + 70), fill=110)
    halo = halo.filter(ImageFilter.GaussianBlur(28))
    return add(ImageChops.multiply(add(body, lines), fade), core, halo)


def spark():
    # square and vertical: particles draw square, and a velocity-facing particle's up is its direction
    size = 256
    mask = Image.new("L", (size, size), 0)
    ImageDraw.Draw(mask).ellipse((size / 2 - 7, 8, size / 2 + 7, size - 8), fill=255)
    soft = mask.filter(ImageFilter.GaussianBlur(5))
    core = Image.new("L", (size, size), 0)
    ImageDraw.Draw(core).ellipse((size / 2 - 2, 50, size / 2 + 2, size - 50), fill=255)
    return add(boost(soft, 1.3), core.filter(ImageFilter.GaussianBlur(1.5)))


def ring():
    size = 512
    mask = Image.new("L", (size, size), 0)
    d = ImageDraw.Draw(mask)
    pad = 40
    d.ellipse((pad, pad, size - pad, size - pad), outline=255, width=14)
    sharp = mask.filter(ImageFilter.GaussianBlur(3))
    soft = mask.filter(ImageFilter.GaussianBlur(18))
    inner = radial((size, size), 6.0, 0.95).point(lambda v: v // 3)
    return add(sharp, boost(soft, 1.5), inner)


def bolt_path(x0, y0, x1, y1, roughness, depth):
    """A jagged line by midpoint displacement."""
    if depth == 0:
        return [(x0, y0), (x1, y1)]
    mx, my = (x0 + x1) / 2, (y0 + y1) / 2 + random.uniform(-roughness, roughness)
    left = bolt_path(x0, y0, mx, my, roughness / 2, depth - 1)
    right = bolt_path(mx, my, x1, y1, roughness / 2, depth - 1)
    return left[:-1] + right


def bolt():
    w, h = 1024, 256
    core = Image.new("L", (w, h), 0)
    d = ImageDraw.Draw(core)
    main = bolt_path(0, h / 2, w, h / 2, 70, 7)
    d.line(main, fill=255, width=14)
    for _ in range(6):
        i = random.randint(8, len(main) - 20)
        x, y = main[i]
        end = (x + random.uniform(80, 220), y + random.choice((-1, 1)) * random.uniform(30, 90))
        d.line(bolt_path(x, y, end[0], end[1], 30, 4), fill=190, width=6)
    second = bolt_path(0, h / 2, w, h / 2, 50, 6)
    d.line(second, fill=140, width=5)
    glow_mask = core.filter(ImageFilter.GaussianBlur(6))
    return add(core.filter(ImageFilter.GaussianBlur(1.5)), boost(glow_mask, 1.3))


def upright_bolt():
    # beams run a texture's height along their length, so the bolt stands upright
    return bolt().rotate(90, expand=True)


def slash():
    size = 512
    outer = Image.new("L", (size, size), 0)
    ImageDraw.Draw(outer).ellipse((20, 60, size - 20, size + 260), fill=255)
    inner = Image.new("L", (size, size), 0)
    ImageDraw.Draw(inner).ellipse((44, 86, size - 44, size + 290), fill=255)
    crescent = ImageChops.subtract(outer, inner)
    # sharp at both ends: fade by distance from the top middle
    taper = radial((size, size), 1.4, 1.05)
    shifted = Image.new("L", (size, size), 0)
    shifted.paste(taper, (0, -150))
    crescent = ImageChops.multiply(crescent, boost(shifted, 2.2))
    edge = crescent.filter(ImageFilter.GaussianBlur(2))
    halo = crescent.filter(ImageFilter.GaussianBlur(14))
    return add(edge, boost(halo, 1.4))


def shard():
    # square, the shard upright in the middle (particles draw square)
    w, h = 512, 512
    mask = Image.new("L", (w, h), 0)
    d = ImageDraw.Draw(mask)
    d.polygon([(w / 2, 10), (w / 2 + 40, h * 0.62), (w / 2, h - 10), (w / 2 - 40, h * 0.62)], fill=170)
    d.polygon([(w / 2, 30), (w / 2 + 14, h * 0.6), (w / 2, h - 40), (w / 2 - 7, h * 0.6)], fill=255)
    body = mask.filter(ImageFilter.GaussianBlur(2))
    halo = mask.filter(ImageFilter.GaussianBlur(20))
    return add(body, boost(halo, 1.2))


def impact():
    size = 512
    c = size / 2
    rays = Image.new("L", (size, size), 0)
    d = ImageDraw.Draw(rays)
    for i in range(14):
        a = i / 14 * math.tau + random.uniform(-0.12, 0.12)
        length = c * random.uniform(0.55, 0.95)
        width = random.uniform(0.05, 0.1)
        tip = (c + math.cos(a) * length, c + math.sin(a) * length)
        side1 = (c + math.cos(a + width) * c * 0.18, c + math.sin(a + width) * c * 0.18)
        side2 = (c + math.cos(a - width) * c * 0.18, c + math.sin(a - width) * c * 0.18)
        d.polygon([side1, tip, side2], fill=random.randint(170, 255))
    rays = rays.filter(ImageFilter.GaussianBlur(2))
    return add(rays, boost(radial((size, size), 2.0, 0.45), 1.3), radial((size, size), 3, 0.9).point(lambda v: v // 2))


def flame():
    # square, the flame upright in the middle (particles draw square)
    w, h = 384, 384
    mask = Image.new("L", (w, h), 0)
    d = ImageDraw.Draw(mask)
    d.ellipse((w * 0.3, h * 0.45, w * 0.7, h * 0.95), fill=255)
    d.polygon([(w * 0.31, h * 0.68), (w * 0.5, h * 0.05), (w * 0.69, h * 0.68)], fill=255)
    soft = mask.filter(ImageFilter.GaussianBlur(16))
    inner = Image.new("L", (w, h), 0)
    ImageDraw.Draw(inner).ellipse((w * 0.4, h * 0.6, w * 0.6, h * 0.9), fill=255)
    return add(boost(soft, 1.1), inner.filter(ImageFilter.GaussianBlur(10)))


def smoke():
    size = 256
    mask = Image.new("L", (size, size), 0)
    d = ImageDraw.Draw(mask)
    for _ in range(14):
        r = random.uniform(30, 70)
        x = size / 2 + random.gauss(0, 30)
        y = size / 2 + random.gauss(0, 30)
        d.ellipse((x - r, y - r, x + r, y + r), fill=random.randint(70, 140))
    mask = mask.filter(ImageFilter.GaussianBlur(14))
    return ImageChops.multiply(boost(mask, 1.6), radial((size, size), 0.9))


TEXTURES = {
    "glow": glow, "flare": flare, "streak": streak, "spark": spark, "ring": ring, "bolt": upright_bolt,
    "slash": slash, "shard": shard, "impact": impact, "flame": flame, "smoke": smoke,
}

if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    for name, make in TEXTURES.items():
        white(make()).save(os.path.join(OUT, name + ".png"))
        print(name)
