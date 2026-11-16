"""The game page's thumbnails (1920x1080; Creator Hub -> the game -> Places -> start place -> Thumbnails).

The scene is painted without text (Figma's image generator: AI text comes out wrong); this puts the title on in the
game's font (Fredoka Bold, tools/ui-art/fonts, SIL OFL) the way the top Roblox games do: one giant line, a thick
black outline, a rainbow or gold fill with a shine, a soft drop shadow, and an optional smaller line under it. It can
also fan real card paintings (assets/ui/card-art) in front of the scene, framed in their rarity colours.

    python tools/ui-art/make_thumbnail.py <scene.png> <out.png> --title "BEAT THE HYDRA!" [--sub "60,000 HP"]
        [--fill rainbow|gold|ice|fire] [--sub-fill gold] [--size 200] [--y 150] [--sub-size 70]
        [--cards "Eclipse_Fox:Epic,Solarion:Legendary:foil,..."] [--cards-top 470] [--cards-height 430] [--card-names]
        [--phone]  (also saves <out>_phone.png at 320x180, how it reads on a phone's home row)

Keep every number on a thumbnail true (the odds, HP): Roblox removes misleading thumbnails and players notice.
"""
import argparse
import math
import os

from PIL import Image, ImageDraw, ImageFilter, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
FONT = os.path.join(HERE, "fonts", "Fredoka.ttf")
CARD_ART = os.path.join(HERE, "..", "..", "assets", "ui", "card-art")
SIZE = (1920, 1080)

FILLS = {
    "rainbow": [(255, 70, 70), (255, 170, 40), (255, 235, 60), (90, 230, 90), (60, 190, 255), (180, 110, 255)],
    "gold": [(255, 248, 170), (255, 210, 60), (255, 150, 30)],
    "ice": [(235, 252, 255), (130, 220, 255), (90, 140, 255)],
    "fire": [(255, 240, 120), (255, 150, 40), (255, 70, 50)],
}
# Config/Rarities colours
RARITY = {
    "Common": (160, 160, 160),
    "Rare": (70, 140, 255),
    "Very Rare": (40, 210, 200),
    "Epic": (170, 80, 255),
    "Legendary": (255, 200, 40),
}


def bold(size):
    font = ImageFont.truetype(FONT, size)
    font.set_variation_by_axes([700, 100])  # Weight (Bold), Width (normal)
    return font


def gradient(size, box, stops):
    """A left-to-right gradient image the size of the canvas, spanning the box's width."""
    grad = Image.new("RGBA", size)
    draw = ImageDraw.Draw(grad)
    x0, x1 = box
    for px in range(x0, x1 + 1):
        t = (px - x0) / max(1, x1 - x0)
        seg = min(int(t * (len(stops) - 1)), len(stops) - 2)
        local = t * (len(stops) - 1) - seg
        color = tuple(int(stops[seg][k] + (stops[seg + 1][k] - stops[seg][k]) * local) for k in range(3))
        draw.line([(px, 0), (px, size[1])], fill=color + (255,))
    return grad


def title(img, text, size, center_y, stops, stroke, shadow):
    font = bold(size)
    measure = ImageDraw.Draw(img)
    left, top, right, bottom = measure.textbbox((0, 0), text, font=font, stroke_width=stroke)
    width, height = right - left, bottom - top
    x = (img.width - width) // 2 - left
    y = center_y - height // 2 - top
    shade = Image.new("RGBA", img.size, (0, 0, 0, 0))
    ImageDraw.Draw(shade).text((x + shadow, y + shadow), text, font=font, fill=(0, 0, 0, 170), stroke_width=stroke, stroke_fill=(0, 0, 0, 170))
    img.alpha_composite(shade.filter(ImageFilter.GaussianBlur(6)))
    ImageDraw.Draw(img).text((x, y), text, font=font, fill=(0, 0, 0, 255), stroke_width=stroke, stroke_fill=(0, 0, 0, 255))
    mask = Image.new("L", img.size, 0)
    ImageDraw.Draw(mask).text((x, y), text, font=font, fill=255)
    fill = gradient(img.size, (x + left, x + left + width), stops)
    shine = Image.new("RGBA", img.size, (255, 255, 255, 0))
    ImageDraw.Draw(shine).rectangle([0, y + top, img.width, y + top + int(height * 0.45)], fill=(255, 255, 255, 70))
    fill.alpha_composite(shine)
    img.paste(fill, (0, 0), mask)


def card(name, rarity, foil, height, named):
    """A card painting in a rounded frame of its rarity colour (a rainbow frame for a foil), its name on a plate when
    `named` (too small to read on most thumbnails)."""
    width = int(height * 0.7)
    border = max(8, height // 30)
    radius = height // 14
    face = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    frame_mask = Image.new("L", (width, height), 0)
    ImageDraw.Draw(frame_mask).rounded_rectangle([0, 0, width - 1, height - 1], radius=radius, fill=255)
    if foil:
        frame = gradient((width, height), (0, width), FILLS["rainbow"])
    else:
        frame = Image.new("RGBA", (width, height), RARITY[rarity] + (255,))
    face.paste(frame, (0, 0), frame_mask)
    art = Image.open(os.path.join(CARD_ART, name + ".jpg")).convert("RGBA")
    inner = (width - 2 * border, height - 2 * border)
    scale = max(inner[0] / art.width, inner[1] / art.height)
    art = art.resize((math.ceil(art.width * scale), math.ceil(art.height * scale)), Image.LANCZOS)
    art = art.crop(((art.width - inner[0]) // 2, (art.height - inner[1]) // 2, (art.width - inner[0]) // 2 + inner[0], (art.height - inner[1]) // 2 + inner[1]))
    art_mask = Image.new("L", inner, 0)
    ImageDraw.Draw(art_mask).rounded_rectangle([0, 0, inner[0] - 1, inner[1] - 1], radius=max(4, radius - border), fill=255)
    face.paste(art, (border, border), art_mask)
    if named:
        name_plate(face, name, width, height, border)
    # a gloss across the top
    gloss = Image.new("RGBA", (width, height), (255, 255, 255, 0))
    ImageDraw.Draw(gloss).polygon([(0, 0), (width, 0), (width, height * 0.18), (0, height * 0.32)], fill=(255, 255, 255, 38))
    face.alpha_composite(Image.composite(gloss, Image.new("RGBA", (width, height), (0, 0, 0, 0)), frame_mask))
    return face


def name_plate(face, name, width, height, border):
    plate_h = height // 9
    plate = [border * 2, height - border * 2 - plate_h, width - border * 2, height - border * 2]
    ImageDraw.Draw(face).rounded_rectangle(plate, radius=plate_h // 2, fill=(20, 16, 30, 215))
    label = name.replace("_", " ")
    font = bold(int(plate_h * 0.6))
    draw = ImageDraw.Draw(face)
    l, t, r, b = draw.textbbox((0, 0), label, font=font)
    draw.text(((width - (r - l)) // 2 - l, plate[1] + (plate_h - (b - t)) // 2 - t), label, font=font, fill=(255, 255, 255, 255))


def fan(img, specs, top, height, named):
    """Cards fanned across the bottom middle: the middle one upright and in front, the others tilted out behind it."""
    count = len(specs)
    middle = (count - 1) / 2
    spread = 13  # degrees between cards
    step = int(height * 0.6)
    order = sorted(range(count), key=lambda i: -abs(i - middle))  # outer cards first, the middle one last
    for i in order:
        name, rarity, foil = specs[i]
        face = card(name, rarity, foil, height, named)
        angle = (middle - i) * spread
        shadow = Image.new("RGBA", face.size, (0, 0, 0, 0))
        shadow.paste((0, 0, 0, 140), (0, 0), face.split()[3])
        shadow = shadow.rotate(angle, resample=Image.BICUBIC, expand=True).filter(ImageFilter.GaussianBlur(10))
        turned = face.rotate(angle, resample=Image.BICUBIC, expand=True)
        cx = img.width // 2 + int((i - middle) * step)
        cy = top + height // 2 + int(abs(i - middle) ** 1.6 * height * 0.07)
        img.alpha_composite(shadow, (cx - shadow.width // 2 + 10, cy - shadow.height // 2 + 14))
        img.alpha_composite(turned, (cx - turned.width // 2, cy - turned.height // 2))


def parse_cards(text):
    specs = []
    for item in text.split(","):
        parts = item.strip().split(":")
        if len(parts) < 2 or parts[1] not in RARITY:
            raise SystemExit(f"bad card {item!r}: use Name:Rarity[:foil] with a Config/Rarities name")
        specs.append((parts[0], parts[1], len(parts) > 2 and parts[2] == "foil"))
    return specs


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("scene")
    parser.add_argument("out")
    parser.add_argument("--title", required=True)
    parser.add_argument("--sub")
    parser.add_argument("--fill", default="rainbow", choices=FILLS)
    parser.add_argument("--sub-fill", default="gold", choices=FILLS)
    parser.add_argument("--size", type=int, default=200)
    parser.add_argument("--y", type=int, default=150)
    parser.add_argument("--sub-size", type=int, default=70)
    parser.add_argument("--cards")
    parser.add_argument("--cards-top", type=int, default=470)
    parser.add_argument("--cards-height", type=int, default=430)
    parser.add_argument("--card-names", action="store_true")
    parser.add_argument("--phone", action="store_true")
    args = parser.parse_args()

    img = Image.open(args.scene).convert("RGBA").resize(SIZE, Image.LANCZOS)
    if args.cards:
        fan(img, parse_cards(args.cards), args.cards_top, args.cards_height, args.card_names)
    title(img, args.title, args.size, args.y, FILLS[args.fill], stroke=max(10, args.size // 9), shadow=10)
    if args.sub:
        sub_y = args.y + int(args.size * 0.5) + int(args.sub_size * 0.95)
        title(img, args.sub, args.sub_size, sub_y, FILLS[args.sub_fill], stroke=max(8, args.sub_size // 5), shadow=6)
    img.convert("RGB").save(args.out)
    if args.phone:
        root, ext = os.path.splitext(args.out)
        img.convert("RGB").resize((320, 180), Image.LANCZOS).save(root + "_phone" + ext)
    print("saved", args.out)


if __name__ == "__main__":
    main()
