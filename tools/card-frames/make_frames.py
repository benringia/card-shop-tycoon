"""Full-art TCG frames (style of the MeshEntity reference): thick rarity border, art fills the card,
rarity ribbon top-left, hex badge top-right, name panel at the bottom with an element socket.
Usage: python -I make_frames_v2.py <pylib> <out dir>. Boxes are in a 600x840 card (Config/CardDesign)."""
import math
import sys

sys.path.insert(0, sys.argv[1])
from PIL import Image, ImageChops, ImageDraw, ImageFilter  # noqa: E402

OUT = sys.argv[2]
W, H = 600, 840
SS = 2

GOLD = ((255, 240, 170), (232, 182, 62), (140, 90, 20))
SILVER = ((248, 248, 252), (185, 190, 200), (95, 100, 115))
PAL = {
    "Common": ((205, 208, 214), (140, 144, 154), (70, 72, 84), SILVER, 0),
    "Rare": ((140, 195, 255), (50, 115, 230), (18, 45, 125), SILVER, 1),
    "VeryRare": ((140, 240, 230), (25, 175, 165), (8, 85, 90), GOLD, 2),
    "Epic": ((210, 150, 255), (145, 65, 225), (60, 18, 115), GOLD, 3),
    "Legendary": ((255, 232, 140), (238, 165, 35), (150, 78, 8), GOLD, 4),
    "Frontier": ((130, 110, 220), (58, 42, 118), (22, 16, 52), GOLD, 4),
}
OUTLINE = (22, 16, 32, 255)
BORDER = 30
ART = (BORDER, BORDER, W - BORDER, H - BORDER)
PANEL = (40, 420, 560, 796)  # the info panel: about half the card
DIVIDER_Y = 598  # between the level row and the stats row (Config/CardDesign TEXT rows)
RIBBON = (24, 16, 300, 70)
HEX = (530, 64, 46)
SOCKET = (514, 463, 28)


def s(v):
    return int(round(v * SS))


def bx(b):
    return tuple(s(v) for v in b)


def vgrad(size, top, mid, bottom, alpha=255):
    w, h = size
    col = Image.new("RGBA", (1, h))
    px = col.load()
    for y in range(h):
        t = y / max(h - 1, 1)
        a, b, u = (top, mid, t / 0.5) if t < 0.5 else (mid, bottom, (t - 0.5) / 0.5)
        px[0, y] = tuple(int(a[i] + (b[i] - a[i]) * u) for i in range(3)) + (alpha,)
    return col.resize((w, h))


def mask(fn):
    m = Image.new("L", (s(W), s(H)), 0)
    fn(ImageDraw.Draw(m))
    return m


def hexagon(cx, cy, r):
    return [(s(cx + r * math.cos(math.radians(60 * i - 90))), s(cy + r * math.sin(math.radians(60 * i - 90)))) for i in range(6)]


def diamond(cx, cy, r):
    return [(s(cx), s(cy - r)), (s(cx + r * 0.8), s(cy)), (s(cx), s(cy + r)), (s(cx - r * 0.8), s(cy))]


def tab(b, notch):
    x0, y0, x1, y1 = b
    mid = (y0 + y1) / 2
    return [(s(x0), s(y0)), (s(x1), s(y0)), (s(x1 - notch), s(mid)), (s(x1), s(y1)), (s(x0), s(y1))]


def make(name, pal):
    light, base, dark, trim, tier = pal
    size = (s(W), s(H))
    card = Image.new("RGBA", size, (0, 0, 0, 0))

    # Thick metallic border with sheen streaks
    body = mask(lambda d: d.rounded_rectangle((0, 0, s(W) - 1, s(H) - 1), radius=s(42), fill=255))
    metal = vgrad(size, light, base, dark)
    sheen = Image.new("L", size, 0)
    sd = ImageDraw.Draw(sheen)
    for o in (-160, 230, 560):
        sd.polygon([(s(o), 0), (s(o + 70), 0), (s(o + 70 - 420), s(H)), (s(o - 420), s(H))], fill=70)
    sheen = sheen.filter(ImageFilter.GaussianBlur(s(16)))
    metal = Image.composite(Image.new("RGBA", size, (255, 255, 255, 255)), metal, sheen)
    card.paste(metal, (0, 0), body)
    d = ImageDraw.Draw(card)
    d.rounded_rectangle((0, 0, s(W) - 1, s(H) - 1), radius=s(42), outline=OUTLINE, width=s(7))
    d.rounded_rectangle((s(9), s(9), s(W - 9), s(H - 9)), radius=s(34), outline=light + (170,), width=s(2))

    # Art window (cut out) with a gold/silver inner rim
    d.rounded_rectangle(bx((ART[0] - 6, ART[1] - 6, ART[2] + 6, ART[3] + 6)), radius=s(28), fill=trim[1] + (255,))
    d.rounded_rectangle(bx((ART[0] - 3, ART[1] - 3, ART[2] + 3, ART[3] + 3)), radius=s(26), fill=OUTLINE)
    hole = mask(lambda m: m.rounded_rectangle(bx(ART), radius=s(24), fill=255))
    card.putalpha(ImageChops.subtract(card.getchannel("A"), hole))

    # Soft dark vignette inside the window, so text and badges read on any art
    vig = Image.new("L", size, 0)
    vd = ImageDraw.Draw(vig)
    vd.rounded_rectangle(bx(ART), radius=s(24), fill=120)
    vd.rounded_rectangle(bx((ART[0] + 26, ART[1] + 26, ART[2] - 26, ART[3] - 26)), radius=s(40), fill=0)
    vig = ImageChops.multiply(vig.filter(ImageFilter.GaussianBlur(s(22))), hole)
    card = Image.alpha_composite(card, Image.merge("RGBA", (*Image.new("RGB", size, (0, 0, 0)).split(), vig)))
    d = ImageDraw.Draw(card)

    # Name panel at the bottom, over the art: dark glass with a trim border
    d.rounded_rectangle(bx((PANEL[0] - 5, PANEL[1] - 5, PANEL[2] + 5, PANEL[3] + 5)), radius=s(24), fill=OUTLINE)
    d.rounded_rectangle(bx((PANEL[0] - 2, PANEL[1] - 2, PANEL[2] + 2, PANEL[3] + 2)), radius=s(22), fill=trim[1] + (255,))
    pm = mask(lambda m: m.rounded_rectangle(bx(PANEL), radius=s(20), fill=255))
    glass = vgrad(size, (60, 48, 86), (32, 26, 50), (18, 14, 30), 235)
    card.paste(glass, (0, 0), pm)
    d = ImageDraw.Draw(card)
    d.line([(s(PANEL[0] + 24), s(PANEL[1] + 8)), (s(PANEL[2] - 24), s(PANEL[1] + 8))], fill=(255, 255, 255, 45), width=s(3))
    # A divider between the level row and the stats row
    d.line([(s(PANEL[0] + 20), s(DIVIDER_Y)), (s(PANEL[2] - 20), s(DIVIDER_Y))], fill=trim[1] + (160,), width=s(2))

    # Element socket on the panel's right (the game draws the element icon in it)
    cx, cy, r = SOCKET
    d.ellipse(bx((cx - r - 6, cy - r - 6, cx + r + 6, cy + r + 6)), fill=OUTLINE)
    d.ellipse(bx((cx - r - 3, cy - r - 3, cx + r + 3, cy + r + 3)), fill=trim[0] + (255,))
    d.ellipse(bx((cx - r, cy - r, cx + r, cy + r)), fill=(245, 240, 230, 255))

    # Rarity ribbon, top-left, over the border
    d.polygon(tab((RIBBON[0] - 4, RIBBON[1] - 4, RIBBON[2] + 6, RIBBON[3] + 4), 20), fill=OUTLINE)
    d.polygon(tab((RIBBON[0], RIBBON[1], RIBBON[2] + 2, RIBBON[3]), 18), fill=trim[1] + (255,))
    rm = mask(lambda m: m.polygon(tab((RIBBON[0] + 4, RIBBON[1] + 4, RIBBON[2] - 2, RIBBON[3] - 4), 15), fill=255))
    card.paste(vgrad(size, light, base, dark), (0, 0), rm)
    d = ImageDraw.Draw(card)
    d.line([(s(RIBBON[0] + 12), s(RIBBON[1] + 9)), (s(RIBBON[2] - 30), s(RIBBON[1] + 9))], fill=(255, 255, 255, 110), width=s(2))

    # Hex power badge, top-right
    hx, hy, hr = HEX
    d.polygon(hexagon(hx, hy, hr + 7), fill=OUTLINE)
    d.polygon(hexagon(hx, hy, hr + 3), fill=trim[0] + (255,))
    hm = mask(lambda m: m.polygon(hexagon(hx, hy, hr - 2), fill=255))
    card.paste(vgrad(size, (70, 60, 90), (36, 30, 52), (20, 16, 30)), (0, 0), hm)
    d = ImageDraw.Draw(card)
    d.polygon(hexagon(hx, hy, hr - 9), outline=trim[1] + (200,), width=s(2))

    # Rarity studs along the bottom border (none for Common, up to 4)
    for i in range(tier):
        x = W / 2 + (i - (tier - 1) / 2) * 34
        d.polygon(diamond(x, H - 15, 12), fill=OUTLINE)
        d.polygon(diamond(x, H - 15, 8), fill=trim[0] + (255,))

    # Legendary / Frontier: little crown on the top border's middle
    if tier >= 4:
        cx = W / 2 + 60
        pts = [(cx - 56, 32), (cx - 56, 12), (cx - 30, 22), (cx - 14, 2), (cx, 18), (cx + 14, 2), (cx + 30, 22), (cx + 56, 12), (cx + 56, 32)]
        d.polygon([(s(x), s(y)) for x, y in pts], fill=OUTLINE)
        inner = [(cx - 50, 28), (cx - 50, 19), (cx - 28, 27), (cx - 14, 10), (cx, 24), (cx + 14, 10), (cx + 28, 27), (cx + 50, 19), (cx + 50, 28)]
        cm = mask(lambda m: m.polygon([(s(x), s(y)) for x, y in inner], fill=255))
        card.paste(vgrad(size, *GOLD), (0, 0), cm)
        d = ImageDraw.Draw(card)

    card.resize((W, H), Image.LANCZOS).save(f"{OUT}/CardFrame_{name}.png", optimize=True)


for key, pal in PAL.items():
    make(key, pal)
print("done")
