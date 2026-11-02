"""The boss-fight HP bars' slanted neon look (Config/CombatHud HP_BAR) and the red hit flash on the screen's edges
(HIT_FLASH). Bars are parallelograms slanted like the HUD's buttons: a dark rim around a sunken well (hp_back), a white
edge with a soft glow each bar tints in its own colour (hp_edge), a white shaded fill tinted by a UIGradient (hp_fill,
also the ghost and the hit flash) and a slanted tick line (hp_tick). Bars draw them 9-sliced so the slanted ends keep
their angle at any width. hit_vignette is white, clear in the middle and solid at the edges, tinted red in game.
Usage: python tools/textures/make_hp_bars.py [out dir] (default assets/ui/combat). Needs Pillow. Uploaded as images;
ids in Config/CombatHud."""
import math
import sys
from PIL import Image, ImageChops, ImageDraw, ImageFilter

out = sys.argv[1] if len(sys.argv) > 1 else "assets/ui/combat"
S = 4  # supersample
SLANT = math.tan(math.radians(18))  # run per unit of height, Config/CombatHud HP_BAR.SLANT
H = 40  # bar image height (a 20 px bar at 2x)
W = 200
PAD = 16  # room around the edge image for its glow
INSET = 6  # rim thickness at 2x (3 px in game)


def para(draw, x0, y0, x1, y1, fill):
    """A parallelogram in box (x0, y0)-(x1, y1), leaning right like the buttons"""
    run = SLANT * (y1 - y0)
    pts = [(x0 + run, y0), (x1, y0), (x1 - run, y1), (x0, y1)]
    draw.polygon([(x * S, y * S) for x, y in pts], fill=fill)


def save(img, name):
    img.resize((img.width // S, img.height // S), Image.LANCZOS).save(f"{out}/{name}")


# hp_back: the rim shaded top to bottom, the well darker with a shadow along its top
rim_top, rim_bottom = (44, 35, 64), (14, 10, 22)
img = Image.new("RGBA", (W * S, H * S), (0, 0, 0, 0))
mask = Image.new("L", img.size, 0)
para(ImageDraw.Draw(mask), 0, 0, W, H, 255)
shade = Image.new("RGBA", img.size)
sd = ImageDraw.Draw(shade)
for y in range(img.height):
    t = y / (img.height - 1)
    sd.line([(0, y), (img.width, y)], fill=tuple(round(a + (b - a) * t) for a, b in zip(rim_top, rim_bottom)) + (255,))
img.paste(shade, (0, 0), mask)
well = Image.new("L", img.size, 0)
run_in = SLANT * INSET
para(ImageDraw.Draw(well), INSET + run_in * 0.5, INSET, W - INSET - run_in * 0.5, H - INSET, 255)
well_col = Image.new("RGBA", img.size)
wd = ImageDraw.Draw(well_col)
top, bottom = INSET * S, (H - INSET) * S
for y in range(img.height):
    t = min(1, max(0, (y - top) / (0.45 * (bottom - top))))
    v = round(2 + 9 * t)
    wd.line([(0, y), (img.width, y)], fill=(v, max(0, v - 4), v + 5, 255))
img.paste(well_col, (0, 0), well)
save(img, "hp_back.png")

# hp_edge: a white outline just outside the bar (hp_back covers anything inside) with a soft glow beyond it
img = Image.new("RGBA", ((W + 2 * PAD) * S, (H + 2 * PAD) * S), (0, 0, 0, 0))
outer = Image.new("L", img.size, 0)
para(ImageDraw.Draw(outer), PAD - 6, PAD - 6, W + PAD + 6, H + PAD + 6, 255)
inner = Image.new("L", img.size, 0)
para(ImageDraw.Draw(inner), PAD, PAD, W + PAD, H + PAD, 255)
line = outer.copy()
line.paste(0, (0, 0), inner)
glow = Image.eval(outer.filter(ImageFilter.GaussianBlur(6 * S)), lambda v: min(255, round(v * 1.3)))
glow.paste(0, (0, 0), inner)  # no glow over the bar itself
img = Image.new("RGBA", img.size, (255, 255, 255, 0))
img.putalpha(ImageChops.lighter(line, glow))
save(img, "hp_edge.png")

# hp_fill: white, a bright band on top fading to a darker bottom (the UIGradient adds the colour)
FH = H - 2 * INSET
img = Image.new("RGBA", (W * S, FH * S), (0, 0, 0, 0))
mask = Image.new("L", img.size, 0)
para(ImageDraw.Draw(mask), 0, 0, W, FH, 255)
shade = Image.new("RGBA", img.size)
sd = ImageDraw.Draw(shade)
for y in range(img.height):
    t = y / (img.height - 1)
    if t < 0.38:
        v = 255
    else:
        v = round(255 - 95 * (t - 0.38) / 0.62)
    sd.line([(0, y), (img.width, y)], fill=(v, v, v, 255))
img.paste(shade, (0, 0), mask)
save(img, "hp_fill.png")

# hp_tick: a slanted line as tall as the well
TW = 4
run = SLANT * FH
img = Image.new("RGBA", (round(run + TW) * S, FH * S), (0, 0, 0, 0))
para(ImageDraw.Draw(img), 0, 0, run + TW, FH, (255, 255, 255, 255))
save(img, "hp_tick.png")

# hit_vignette: clear in the middle, solid at the edges
VW, VH = 512, 288
img = Image.new("RGBA", (VW, VH), (255, 255, 255, 0))
px = img.load()
for y in range(VH):
    for x in range(VW):
        d = math.hypot((x - VW / 2) / (VW / 2), (y - VH / 2) / (VH / 2))
        t = max(0.0, min(1.0, (d - 0.62) / 0.8))
        px[x, y] = (255, 255, 255, round(255 * t ** 1.6))
img.save(f"{out}/hit_vignette.png")
print("ok")
