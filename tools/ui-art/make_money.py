"""The cash drawer's notes and coins (owner 2026-11-16: "we need a model for the cash and coins inside register").

Our own play money, nothing copied from real notes: each note its own colour (kids tell them apart at a glance), the
game's name across the top, a paw medallion in the middle and the value big in the corners; coins gold, silver and
copper with the value in the middle. Fredoka Bold (tools/ui-art/fonts, SIL OFL).

    python tools/ui-art/make_money.py [out_dir]

Writes note_<cents>.png (512 x 256) and coin_<cents>.png (256 x 256, round, clear outside) into out_dir
(default assets/ui/money), plus preview.png with all of them, for the mockup.
"""
import math
import os
import sys

from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
FONT = os.path.join(HERE, "fonts", "Fredoka.ttf")

NOTES = {
    100: {"color": (92, 196, 132), "words": "ONE"},
    500: {"color": (82, 162, 236), "words": "FIVE"},
    1000: {"color": (158, 112, 236), "words": "TEN"},
    2000: {"color": (244, 140, 82), "words": "TWENTY"},
}
COINS = {
    25: {"color": (244, 196, 72), "label": "25¢"},
    10: {"color": (206, 212, 224), "label": "10¢"},
    5: {"color": (186, 198, 214), "label": "5¢"},
    1: {"color": (212, 128, 78), "label": "1¢"},
}


def font(size):
    face = ImageFont.truetype(FONT, size)
    try:
        face.set_variation_by_axes([700, 100])  # Bold (the variable font's axes: weight, width)
    except Exception:
        pass
    return face


def shade(color, amount):
    return tuple(max(0, min(255, int(c * amount))) for c in color)


def mix(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def paw(draw, cx, cy, size, color):
    """A paw print: the pad and four toes."""
    pad = size * 0.42
    draw.ellipse([cx - pad, cy - pad * 0.55, cx + pad, cy + pad * 1.05], fill=color)
    for angle, distance in ((-62, 0.78), (-22, 0.92), (22, 0.92), (62, 0.78)):
        rad = math.radians(angle - 90)
        tx = cx + math.cos(rad) * size * distance * 0.62
        ty = cy + math.sin(rad) * size * distance * 0.62 - size * 0.08
        toe = size * 0.15
        draw.ellipse([tx - toe, ty - toe * 1.15, tx + toe, ty + toe * 1.15], fill=color)


def centred(draw, xy, text, face, fill, stroke=None, stroke_fill=None):
    box = draw.textbbox((0, 0), text, font=face, stroke_width=stroke or 0)
    w, h = box[2] - box[0], box[3] - box[1]
    draw.text((xy[0] - w / 2 - box[0], xy[1] - h / 2 - box[1]), text, font=face, fill=fill, stroke_width=stroke or 0, stroke_fill=stroke_fill)


def note(cents):
    look = NOTES[cents]
    base = look["color"]
    deep, pale = shade(base, 0.62), mix(base, (255, 255, 255), 0.55)
    w, h = 512, 256
    image = Image.new("RGB", (w, h), base)
    draw = ImageDraw.Draw(image)
    # fine diagonal guilloche lines
    for x in range(-h, w, 14):
        draw.line([(x, h), (x + h, 0)], fill=mix(base, (255, 255, 255), 0.12), width=2)
    draw.rectangle([0, 0, w - 1, h - 1], outline=deep, width=12)
    draw.rounded_rectangle([22, 22, w - 23, h - 23], radius=26, outline=pale, width=5)
    # the medallion and its paw
    cx, cy, r = w // 2, h // 2 + 6, 70
    draw.ellipse([cx - r - 8, cy - r - 8, cx + r + 8, cy + r + 8], fill=deep)
    draw.ellipse([cx - r, cy - r, cx + r, cy + r], fill=pale)
    paw(draw, cx, cy + 6, 92, deep)
    value = f"${cents // 100}"
    big, small = font(74), font(30)
    centred(draw, (98, 82), value, big, (255, 255, 255), 6, deep)
    centred(draw, (w - 98, h - 74), value, big, (255, 255, 255), 6, deep)
    centred(draw, (w // 2, 40), "ONE MORE PACK", font(22), (255, 255, 255), 3, deep)
    # the value in words, clear of the title
    centred(draw, (w - 104, 92), look["words"], small, pale, 3, deep)
    centred(draw, (104, h - 92), look["words"], small, pale, 3, deep)
    return image


def drawer_note(cents):
    """The note as it lies in the drawer, lengthwise toward the cashier (owner 2026-11-16: "the numbers on the bills are
    hard to see"): portrait, the value huge and upright, a small paw, the value in words at the foot."""
    look = NOTES[cents]
    base = look["color"]
    deep, pale = shade(base, 0.62), mix(base, (255, 255, 255), 0.55)
    w, h = 352, 512
    image = Image.new("RGB", (w, h), base)
    draw = ImageDraw.Draw(image)
    for y in range(-w, h, 14):
        draw.line([(0, y), (w, y + w)], fill=mix(base, (255, 255, 255), 0.12), width=2)
    draw.rectangle([0, 0, w - 1, h - 1], outline=deep, width=14)
    draw.rounded_rectangle([24, 24, w - 25, h - 25], radius=28, outline=pale, width=5)
    value = f"${cents // 100}"
    size = 200 if cents < 1000 else 150
    centred(draw, (w / 2, h * 0.36), value, font(size), (255, 255, 255), 10, deep)
    cx, cy, r = w / 2, h * 0.68, 46
    draw.ellipse([cx - r - 6, cy - r - 6, cx + r + 6, cy + r + 6], fill=deep)
    draw.ellipse([cx - r, cy - r, cx + r, cy + r], fill=pale)
    paw(draw, cx, cy + 4, 62, deep)
    centred(draw, (w / 2, h * 0.86), look["words"], font(46), (255, 255, 255), 5, deep)
    return image


def coin(cents):
    look = COINS[cents]
    base = look["color"]
    size = 256
    image = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    rim, face_color = shade(base, 0.7), base
    draw.ellipse([2, 2, size - 3, size - 3], fill=rim + (255,))
    # the face: a soft light from the top left
    for step in range(40):
        t = step / 39
        inset = 18 + step * 2.2
        color = mix(mix(base, (255, 255, 255), 0.35), face_color, t)
        draw.ellipse([inset, inset, size - 1 - inset, size - 1 - inset], fill=color + (255,))
    draw.ellipse([18, 18, size - 19, size - 19], outline=mix(base, (255, 255, 255), 0.5) + (255,), width=4)
    # little dots round the rim
    for index in range(24):
        a = index / 24 * math.tau
        x, y = size / 2 + math.cos(a) * 108, size / 2 + math.sin(a) * 108
        draw.ellipse([x - 3, y - 3, x + 3, y + 3], fill=mix(base, (255, 255, 255), 0.6) + (255,))
    centred(draw, (size / 2, size / 2), look["label"], font(84), (255, 255, 255), 6, shade(base, 0.5))
    return image


def main():
    out = sys.argv[1] if len(sys.argv) > 1 else os.path.join(HERE, "..", "..", "assets", "ui", "money")
    os.makedirs(out, exist_ok=True)
    notes = {cents: note(cents) for cents in NOTES}
    coins = {cents: coin(cents) for cents in COINS}
    for cents, image in notes.items():
        image.save(os.path.join(out, f"note_{cents}.png"))
    for cents, image in coins.items():
        image.save(os.path.join(out, f"coin_{cents}.png"))
    for cents in NOTES:
        drawer_note(cents).save(os.path.join(out, f"drawer_{cents}.png"))
    sheet = Image.new("RGBA", (4 * 532 + 20, 256 + 40 + 200), (246, 240, 252, 255))
    for index, cents in enumerate(sorted(notes, reverse=True)):
        sheet.paste(notes[cents], (20 + index * 532, 20))
    for index, cents in enumerate(sorted(coins, reverse=True)):
        small = coins[cents].resize((180, 180))
        sheet.paste(small, (120 + index * 532, 296), small)
    sheet.save(os.path.join(out, "preview.png"))
    print("wrote", out)


if __name__ == "__main__":
    main()
