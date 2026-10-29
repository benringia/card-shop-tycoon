"""Packs the pack opening's rendered effect frames into Roblox flipbook sheets, plus its plain effect images (UI project 3,
spec section 5). Uploaded images are capped at 1024 x 1024 and particle flipbooks are 2 x 2, 4 x 4 or 8 x 8.

Usage: python tools/textures/make_flipbooks.py <frames_dir> <out_dir>
  frames_dir  what tools/blender/build_pack_fx.py rendered (<frames_dir>/<effect>/NNN.png)
  out_dir     assets/ui/fx
Writes RipBurst.png (8 x 8 of 128 px), ShardHolo.png, ShardGold.png, Glint.png (4 x 4 of 256 px), Mote.png (64 px
soft dot), Rays.png (512 px soft rays), Leak.png (512 x 64 soft bar). Light on black becomes white with alpha (so
Roblox can tint it with a ParticleEmitter's Color) and each frame's edges fade out, so no square shows in game.
"""
import glob
import math
import os
import sys

from PIL import Image, ImageChops, ImageDraw, ImageFilter

SHEETS = [  # (frames folder, output name, grid, frame px, light on black?)
    ("ripburst", "RipBurst", 8, 128, True),
    ("shardholo", "ShardHolo", 4, 256, False),
    ("shardgold", "ShardGold", 4, 256, False),
    ("glint", "Glint", 4, 256, True),
]


def edge_fade(size):
    fade = Image.new("L", (size, size))
    px = fade.load()
    for y in range(size):
        for x in range(size):
            d = math.hypot((x + 0.5) / size - 0.5, (y + 0.5) / size - 0.5) * 2
            px[x, y] = int(255 * max(0.0, min(1.0, (1.0 - d) / 0.12)))
    return fade


def light_to_alpha(img, fade):
    rgb = img.convert("RGB")
    r, g, b = rgb.split()
    alpha = ImageChops.multiply(ImageChops.lighter(ImageChops.lighter(r, g), b), fade)
    out = Image.new("RGBA", rgb.size)
    src, a, o = rgb.load(), alpha.load(), out.load()
    for y in range(rgb.height):
        for x in range(rgb.width):
            al = a[x, y]
            if al:
                k = 255 / al
                cr, cg, cb = src[x, y]
                o[x, y] = (min(255, int(cr * k)), min(255, int(cg * k)), min(255, int(cb * k)), al)
    return out


def sheet(frames_dir, folder, name, grid, size, glow, out_dir):
    files = sorted(glob.glob(os.path.join(frames_dir, folder, "*.png")))[: grid * grid]
    if not files:
        sys.exit(f"No frames in {os.path.join(frames_dir, folder)}: run tools/blender/build_pack_fx.py first")
    fade = edge_fade(size)
    out = Image.new("RGBA", (grid * size, grid * size), (0, 0, 0, 0))
    for i, f in enumerate(files):
        img = Image.open(f).resize((size, size), Image.LANCZOS)
        img = light_to_alpha(img, fade) if glow else img.convert("RGBA")
        out.paste(img, ((i % grid) * size, (i // grid) * size))
    out.save(os.path.join(out_dir, f"{name}.png"))
    print(name, len(files), "frames", out.size)


def mote(out_dir):
    size = 64
    img = Image.new("RGBA", (size, size), (255, 255, 255, 0))
    px = img.load()
    for y in range(size):
        for x in range(size):
            d = math.hypot((x + 0.5) / size - 0.5, (y + 0.5) / size - 0.5) * 2
            px[x, y] = (255, 255, 255, int(255 * max(0.0, 1 - d) ** 2))
    img.save(os.path.join(out_dir, "Mote.png"))


def rays(out_dir):
    size, count = 512, 18
    mask = Image.new("L", (size, size), 0)
    d = ImageDraw.Draw(mask)
    c = size / 2
    for i in range(count):
        a = i / count * math.tau
        w = math.tau / count * 0.28
        d.polygon([(c, c), (c + c * 1.5 * math.cos(a - w), c + c * 1.5 * math.sin(a - w)), (c + c * 1.5 * math.cos(a + w), c + c * 1.5 * math.sin(a + w))], fill=255)
    mask = mask.filter(ImageFilter.GaussianBlur(6))
    falloff = Image.new("L", (size, size))
    px = falloff.load()
    for y in range(size):
        for x in range(size):
            d2 = math.hypot(x + 0.5 - c, y + 0.5 - c) / c
            px[x, y] = int(255 * max(0.0, 1 - d2) ** 1.4)
    img = Image.new("RGBA", (size, size), (255, 255, 255, 0))
    img.putalpha(ImageChops.multiply(mask, falloff))
    img.save(os.path.join(out_dir, "Rays.png"))


def leak(out_dir):
    w, h = 512, 64
    img = Image.new("RGBA", (w, h), (255, 255, 255, 0))
    px = img.load()
    for y in range(h):
        for x in range(w):
            across = max(0.0, 1 - abs((y + 0.5) / h - 0.5) * 2) ** 2.2
            along = max(0.0, 1 - abs((x + 0.5) / w - 0.5) * 2) ** 0.35
            px[x, y] = (255, 250, 230, int(255 * across * along))
    img.save(os.path.join(out_dir, "Leak.png"))


def main():
    frames_dir, out_dir = sys.argv[1:3]
    os.makedirs(out_dir, exist_ok=True)
    for folder, name, grid, size, glow in SHEETS:
        sheet(frames_dir, folder, name, grid, size, glow, out_dir)
    mote(out_dir)
    rays(out_dir)
    leak(out_dir)
    print("wrote", out_dir)


if __name__ == "__main__":
    main()
