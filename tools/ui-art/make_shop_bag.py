"""The shop bag's face (owner 2026-11-16: "customers that bought something should carry a shopping bag on their way out.
shopping bag should have pish and chikin design on them").

One picture covers each wide side of the bag (Config/Customers BAG), so the bag stays one part and two decals: the
paper, the dogs' art and the game's name are baked in. Three looks from the mockup:
  A  kraft paper, the gold seal from the card back (Pish and Chikin holding a pack), the name stamped in brown
  B  cotton candy pink, the Support card's sticker (the dogs with their golden heart), the name in white
  C  white and pink stripes, a label with a small seal and the name

    python tools/ui-art/make_shop_bag.py <A|B|C> [out.png]

Reads assets/ui/card-back/CardBack.png and assets/ui/support/SupportDogs.png; writes assets/ui/bag/bag_<look>.png
(400 x 440, the bag face's proportions). Fredoka Bold (tools/ui-art/fonts, SIL OFL).
"""
import os
import sys

from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, "..", ".."))
FONT = os.path.join(HERE, "fonts", "Fredoka.ttf")
CARD_BACK = os.path.join(ROOT, "assets", "ui", "card-back", "CardBack.png")
DOGS = os.path.join(ROOT, "assets", "ui", "support", "SupportDogs.png")
SIZE = (400, 440)
SEAL_CIRCLE = (350, 505, 232)  # the gold disc on the card back: centre x, y and radius in its 700 x 1000 pixels
NAME = "One More Pack"


def font(size):
    face = ImageFont.truetype(FONT, size)
    try:
        face.set_variation_by_axes([700, 100])
    except Exception:
        pass
    return face


def seal(diameter):
    """The card back's gold seal, cut round"""
    cx, cy, r = SEAL_CIRCLE
    art = Image.open(CARD_BACK).convert("RGBA").crop((cx - r, cy - r, cx + r, cy + r))
    art = art.resize((diameter, diameter), Image.LANCZOS)
    mask = Image.new("L", (diameter * 4, diameter * 4), 0)
    ImageDraw.Draw(mask).ellipse((4, 4, diameter * 4 - 4, diameter * 4 - 4), fill=255)
    art.putalpha(mask.resize((diameter, diameter), Image.LANCZOS))
    return art


def ringed(diameter, rings):
    """The seal inside coloured rings, outermost first: [(width, rgb)]"""
    total = diameter + 2 * sum(width for width, _ in rings)
    out = Image.new("RGBA", (total, total), (0, 0, 0, 0))
    draw = ImageDraw.Draw(out)
    inset = 0
    for width, rgb in rings:
        draw.ellipse((inset, inset, total - inset - 1, total - inset - 1), fill=rgb + (255,))
        inset += width
    out.alpha_composite(seal(diameter), (inset, inset))
    return out


def centred_text(draw, y, text, size, fill, stroke=0, stroke_fill=None):
    face = font(size)
    box = draw.textbbox((0, 0), text, font=face, stroke_width=stroke)
    x = (SIZE[0] - (box[2] - box[0])) / 2 - box[0]
    draw.text((x, y), text, font=face, fill=fill, stroke_width=stroke, stroke_fill=stroke_fill)


def fold(img, shade):
    """The paper's folded top edge"""
    band = Image.new("RGBA", (SIZE[0], 34), shade)
    img.alpha_composite(band, (0, 0))


def look_a():
    img = Image.new("RGBA", SIZE, (201, 154, 99, 255))
    fold(img, (0, 0, 0, 22))
    badge = ringed(220, [(7, (198, 125, 18)), (6, (255, 243, 196))])
    img.alpha_composite(badge, ((SIZE[0] - badge.width) // 2, 70))
    centred_text(ImageDraw.Draw(img), 340, NAME, 44, (74, 47, 23))
    return img


def look_b():
    img = Image.new("RGBA", SIZE, (255, 196, 226, 255))
    fold(img, (0, 0, 0, 18))
    dogs = Image.open(DOGS).convert("RGBA")
    width = 330
    dogs = dogs.resize((width, round(dogs.height * width / dogs.width)), Image.LANCZOS)
    img.alpha_composite(dogs, ((SIZE[0] - width) // 2, 80))
    centred_text(ImageDraw.Draw(img), 336, NAME, 46, (255, 255, 255), 6, (139, 102, 217))
    return img


def look_c():
    img = Image.new("RGBA", SIZE, (255, 255, 255, 255))
    draw = ImageDraw.Draw(img)
    for x in range(0, SIZE[0], 50):
        draw.rectangle((x + 25, 0, x + 49, SIZE[1]), fill=(255, 224, 239, 255))
    fold(img, (0, 0, 0, 14))
    draw.rounded_rectangle((60, 110, 340, 370), radius=34, fill=(255, 255, 255, 255), outline=(255, 143, 179, 255), width=8)
    badge = ringed(150, [(5, (198, 125, 18))])
    img.alpha_composite(badge, ((SIZE[0] - badge.width) // 2, 128))
    centred_text(draw, 306, NAME, 36, (139, 102, 217))
    return img


LOOKS = {"A": look_a, "B": look_b, "C": look_c}

if __name__ == "__main__":
    if len(sys.argv) < 2 or sys.argv[1].upper() not in LOOKS:
        sys.exit("usage: make_shop_bag.py <A|B|C> [out.png]")
    look = sys.argv[1].upper()
    out = sys.argv[2] if len(sys.argv) > 2 else os.path.join(ROOT, "assets", "ui", "bag", f"bag_{look}.png")
    os.makedirs(os.path.dirname(out), exist_ok=True)
    LOOKS[look]().save(out, optimize=True)
    print(out)
