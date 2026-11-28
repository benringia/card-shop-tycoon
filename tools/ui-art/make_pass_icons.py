"""The Robux round's Creator Hub icons (spec docs/superpowers/specs/2026-11-28-robux-round-design.md): VIP, Quick Open,
Night Shift (game passes) and the Starter Pack (developer product), 512 x 512 PNGs in assets/ui/passes/.

Each is the Store tile's look: its gradient in a rounded square with the game's thick white outline, and its picture
drawn as shapes (a crown, a lightning bolt, a moon with a star, a gift box), so no AI credits. Drawn at twice the size
and scaled down for smooth edges.

Usage: python tools/ui-art/make_pass_icons.py
"""

from pathlib import Path

from PIL import Image, ImageChops, ImageDraw

SIZE = 512
SCALE = 2  # drawn at twice the size, then scaled down
BIG = SIZE * SCALE
OUT = Path(__file__).resolve().parents[2] / "assets" / "ui" / "passes"

# The Store tiles' colours (src/client/Controllers/StoreController.luau PASS_LOOKS, the Starter banner)
LOOKS = {
    "VIP": ((118, 70, 217), (162, 116, 255)),
    "QuickOpen": ((180, 224, 255), (79, 180, 255)),
    "NightShift": ((40, 48, 112), (88, 70, 170)),
    "StarterPack": ((255, 127, 184), (255, 148, 104)),
}
GOLD = (255, 210, 63)
GOLD_DEEP = (255, 178, 30)
GOLD_INK = (74, 42, 0)
WHITE = (255, 255, 255)


def gradient(top: tuple, bottom: tuple) -> Image.Image:
    """A diagonal gradient from the top-left colour to the bottom-right one."""
    image = Image.new("RGB", (BIG, BIG))
    pixels = image.load()
    for y in range(BIG):
        for x in range(BIG):
            share = (x + y) / (2 * (BIG - 1))
            pixels[x, y] = tuple(round(top[i] + (bottom[i] - top[i]) * share) for i in range(3))
    return image


def to_box(points, box: float = 300) -> list:
    """Points of a 24-unit icon (the mockups' SVG view box) placed in the middle of the icon, `box` px wide."""
    scale = box * SCALE / 24
    offset = (BIG - 24 * scale) / 2
    return [(offset + x * scale, offset + y * scale) for x, y in points]


def width(units: float, box: float = 300) -> int:
    return max(1, round(units * box * SCALE / 24))


LINE = 0.55  # outline width in icon units (about 7 px at 512)


def crown(draw: ImageDraw.ImageDraw):
    body = to_box([(3.5, 17.5), (2.5, 7.5), (7.7, 11.8), (12, 4.5), (16.3, 11.8), (21.5, 7.5), (20.5, 17.5)], 320)
    draw.polygon(body, fill=GOLD, outline=GOLD_INK, width=width(LINE, 320))
    base = to_box([(3.6, 17.5), (20.4, 20.1)], 320)
    draw.rounded_rectangle(base, radius=width(0.8, 320), fill=GOLD_DEEP, outline=GOLD_INK, width=width(LINE, 320))
    gem = to_box([(10.6, 12.1), (13.4, 14.9)], 320)
    draw.ellipse(gem, fill=(224, 48, 111), outline=GOLD_INK, width=width(0.4, 320))


def bolt(draw: ImageDraw.ImageDraw):
    shape = to_box([(13.5, 2.5), (5, 13.5), (11, 13.5), (9.5, 21.5), (18, 10.5), (12, 10.5)], 340)
    draw.polygon(shape, fill=WHITE, outline=(28, 95, 160), width=width(LINE, 340))


def moon(image: Image.Image):
    """A gold crescent (a disc with an offset disc cut out) and a white four-point star."""
    disc = Image.new("L", (BIG, BIG), 0)
    ImageDraw.Draw(disc).ellipse(to_box([(2.5, 4.5), (19.5, 21.5)]), fill=255)
    bite = Image.new("L", (BIG, BIG), 0)
    ImageDraw.Draw(bite).ellipse(to_box([(8.5, 2.5), (22.5, 16.5)]), fill=255)
    crescent = ImageChops.subtract(disc, bite)
    edge = Image.new("L", (BIG, BIG), 0)
    ImageDraw.Draw(edge).ellipse(to_box([(2.1, 4.1), (19.9, 21.9)]), fill=255)
    outline = ImageChops.subtract(edge, ImageChops.subtract(edge, ImageChops.add(crescent, ImageChops.subtract(edge, bite))))
    image.paste((176, 118, 0), mask=ImageChops.subtract(outline, bite))
    image.paste((255, 213, 74), mask=crescent)
    star = to_box([(18.5, 3.2), (19.3, 5.2), (21.3, 6), (19.3, 6.8), (18.5, 8.8), (17.7, 6.8), (15.7, 6), (17.7, 5.2)])
    ImageDraw.Draw(image).polygon(star, fill=WHITE)


def gift(draw: ImageDraw.ImageDraw):
    ink = (122, 42, 80)
    ribbon = (255, 213, 74)
    line = width(LINE)
    # the bow: two loops leaning out from the knot, then the knot
    left = [(12, 6.6), (10.2, 3.6), (8.2, 2.6), (6.6, 3.4), (6.8, 5.2), (8.8, 6.4)]
    right = [(24 - x, y) for x, y in left]
    draw.polygon(to_box(left), fill=ribbon, outline=ink, width=line)
    draw.polygon(to_box(right), fill=ribbon, outline=ink, width=line)
    draw.rounded_rectangle(to_box([(3.5, 9.5), (20.5, 20.5)]), radius=width(1.6), fill=(255, 255, 255), outline=ink, width=line)
    draw.rounded_rectangle(to_box([(2.5, 6.5), (21.5, 10.5)]), radius=width(1.2), fill=(255, 224, 238), outline=ink, width=line)
    draw.rectangle(to_box([(10.6, 6.5), (13.4, 20.5)]), fill=ribbon, outline=ink, width=line)
    draw.ellipse(to_box([(10.9, 5.4), (13.1, 7.4)]), fill=ribbon, outline=ink, width=line)


def icon(key: str) -> Image.Image:
    top, bottom = LOOKS[key]
    face = gradient(top, bottom).convert("RGBA")
    draw = ImageDraw.Draw(face)
    if key == "NightShift":
        for x, y, r in ((0.2, 0.22, 6), (0.78, 0.16, 5), (0.15, 0.7, 4), (0.84, 0.78, 6), (0.62, 0.86, 4)):
            draw.ellipse((x * BIG - r * SCALE, y * BIG - r * SCALE, x * BIG + r * SCALE, y * BIG + r * SCALE), fill=(255, 255, 255, 200))
    if key == "VIP":
        crown(draw)
    elif key == "QuickOpen":
        bolt(draw)
    elif key == "NightShift":
        moon(face)
    else:
        gift(draw)
    # the rounded square with the game's thick white outline
    mask = Image.new("L", (BIG, BIG), 0)
    margin = 10 * SCALE
    ImageDraw.Draw(mask).rounded_rectangle((margin, margin, BIG - margin, BIG - margin), radius=96 * SCALE, fill=255)
    out = Image.new("RGBA", (BIG, BIG), (0, 0, 0, 0))
    out.paste(face, mask=mask)
    ImageDraw.Draw(out).rounded_rectangle(
        (margin, margin, BIG - margin, BIG - margin), radius=96 * SCALE, outline=WHITE, width=18 * SCALE
    )
    return out.resize((SIZE, SIZE), Image.LANCZOS)


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    for key in LOOKS:
        path = OUT / f"{key}.png"
        icon(key).save(path)
        print(f"wrote {path}")


if __name__ == "__main__":
    main()
