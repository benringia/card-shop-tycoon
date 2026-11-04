"""Turns the level-up pillar's raw renders (tools/blender/build_levelup_fx.py, white light on black) into the textures
uploaded for the game (spec 2026-11-04-round4-design section 9): a soft glow is added and the light becomes white with
alpha, so Roblox can tint them (a Beam's or ParticleEmitter's Color, a Decal's Color3).

Usage: python tools/textures/make_levelup_fx.py <raw_dir> <out_dir>
  raw_dir  what build_levelup_fx.py rendered (Rune.png, Beam.png, Mote.png)
  out_dir  assets/ui/fx-levelup
Rune and Mote stay square (particles and decals), their edges faded so no square shows; the Beam's height runs along
the beam (Roblox stretches it from the ground up), its sides soft and its ends left to the Beam's transparency.
"""
import math
import os
import sys

from PIL import Image, ImageChops, ImageFilter


def edge_fade(size):
    fade = Image.new("L", (size, size))
    px = fade.load()
    for y in range(size):
        for x in range(size):
            d = math.hypot((x + 0.5) / size - 0.5, (y + 0.5) / size - 0.5) * 2
            px[x, y] = int(255 * max(0.0, min(1.0, (1.0 - d) / 0.08)))
    return fade


def glow(light, radius, strength):
    # The sharp light plus a blurred copy of itself, brighter where they overlap
    halo = light.filter(ImageFilter.GaussianBlur(radius)).point(lambda v: min(255, int(v * strength)))
    return ImageChops.lighter(light, halo)


def to_white_alpha(light, fade=None):
    alpha = light if fade is None else ImageChops.multiply(light, fade)
    out = Image.new("RGBA", light.size, (255, 255, 255, 0))
    out.putalpha(alpha)
    return out


def column(width, height, sigma):
    # A soft vertical column, brightest in the middle
    col = Image.new("L", (width, height))
    px = col.load()
    for x in range(width):
        u = (x + 0.5) / width - 0.5
        value = int(255 * math.exp(-((u / sigma) ** 2)))
        for y in range(height):
            px[x, y] = value
    return col


def main(raw_dir, out_dir):
    os.makedirs(out_dir, exist_ok=True)
    rune = Image.open(os.path.join(raw_dir, "Rune.png")).convert("L")
    to_white_alpha(glow(rune, 7, 1.6), edge_fade(rune.width)).save(os.path.join(out_dir, "Rune.png"))

    mote = Image.open(os.path.join(raw_dir, "Mote.png")).convert("L")
    to_white_alpha(glow(mote, 10, 1.8), edge_fade(mote.width)).save(os.path.join(out_dir, "Mote.png"))

    beam = Image.open(os.path.join(raw_dir, "Beam.png")).convert("L")
    streaks = beam.filter(ImageFilter.GaussianBlur(3)).point(lambda v: int(v * 0.8))
    soft = column(beam.width, beam.height, 0.22)
    core = column(beam.width, beam.height, 0.07)
    light = ImageChops.lighter(ImageChops.lighter(soft.point(lambda v: int(v * 0.75)), core), streaks)
    to_white_alpha(light).save(os.path.join(out_dir, "Beam.png"))
    print("wrote", sorted(os.listdir(out_dir)))


if __name__ == "__main__":
    if len(sys.argv) != 3:
        print(__doc__)
        sys.exit(1)
    main(sys.argv[1], sys.argv[2])
