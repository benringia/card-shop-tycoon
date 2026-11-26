# A card's grade you notice (owner 2026-11-26: "Make grade more noticeable in general", pick A "Medal + glow" of the
# mockups in artifact DHqTbCQGqpWaK4fTAFCbzz): the four grade medals, the A and S cards' glow and the S cards' sparkle.
#   medal_<C|B|A|S>.png  a round medal with a white ring (as thick as the mockup's 3 px on its 32 / 38 / 44 / 50 px
#                        medals), its fill (flat grey C, flat green B; A blue and S gold, lit from the top left as the
#                        mockup's radial gradients), its letter in Fredoka Bold with the mockup's drop shadow and a thin
#                        edge in the medal's dark tone (so a small one still reads), a soft shadow under it. The circle
#                        fills PICTURE of the square picture (Config/GradeLook PICTURE), the shadow in the margin.
#   card_glow.png        white with alpha: a card (1 : 1.4, its corner rounded as CardDesign's) a little bigger, blurred,
#                        with GLOW_REACH of its width round it on every side (Config/GradeLook GLOW_PICTURE.reach):
#                        stretched behind a card, it glows past its edges.
#   sparkle.png          a gold four-point star with a white edge (the mockup's).
# Drawn 4x and scaled down for smooth edges. Needs Pillow. Fredoka (tools/ui-art/fonts, SIL OFL).
# Usage: python tools/ui-art/make_grade_look.py   (writes assets/ui/grade/)
import os

from PIL import Image, ImageDraw, ImageFilter, ImageFont

HERE = os.path.dirname(__file__)
OUT = os.path.join(HERE, "..", "..", "assets", "ui", "grade")
FONT = os.path.join(HERE, "fonts", "Fredoka.ttf")

SCALE = 4  # drawn this many times bigger, then scaled down
MEDAL_SIZE = 256  # the medal pictures, px square
PICTURE = 0.8  # the circle's share of the picture (Config/GradeLook PICTURE)
WHITE = (255, 255, 255, 255)

# Per grade (the mockup's numbers): the fill (flat, or light to dark lit from the top left), the ring and the letter as
# shares of the medal's size (3 px and 17 / 21 / 25 / 29 px on 32 / 38 / 44 / 50 px medals), the letter's shadow and
# its thin edge
GRADES = {
    "C": {"fill": ((142, 142, 160), None), "ring": 3 / 32, "letter": 17 / 32, "shadow": (0, 0, 0, 89), "edge": (84, 84, 100)},
    "B": {"fill": ((57, 178, 90), None), "ring": 3 / 38, "letter": 21 / 38, "shadow": (0, 0, 0, 89), "edge": (28, 112, 52)},
    "A": {"fill": ((156, 200, 255), (47, 111, 232)), "ring": 3 / 44, "letter": 25 / 44, "shadow": (0, 0, 0, 89), "edge": (24, 70, 170)},
    "S": {"fill": ((255, 242, 168), (240, 160, 32)), "ring": 3 / 50, "letter": 29 / 50, "shadow": (120, 60, 0, 153), "edge": (150, 85, 0)},
}
SHADOW_DROP = 2 / 44  # the letter's drop shadow (the mockup's "0 2px 0" on a 44 px medal), of the medal's size
LETTER_EDGE = 0.012  # the letter's thin edge, of the medal's size (thicker fills the B's and the A's holes)
MEDAL_SHADOW = {"drop": 0.05, "blur": 0.05, "alpha": 77}  # the soft shadow under the medal ("0 3px 6px" at 0.3)

GLOW_CARD = (200, 280)  # the card in the glow picture, px
GLOW_REACH = 0.25  # of the card's width, round it on every side (Config/GradeLook GLOW_PICTURE.reach)
GLOW_SPREAD = 0.054  # of the card's width, the glowing shape past the card's edge before the blur (the mockup's 6 px)
GLOW_CORNER = 0.07  # of the card's width, its corner (Config/CardDesign CORNER)
GLOW_BLUR = 0.098  # of the card's width (the mockup's 22 px blur: 11 px deviation on a 112 px card)

SPARKLE_SIZE = 128
SPARKLE = [(12, 1), (14.5, 9.5), (23, 12), (14.5, 14.5), (12, 23), (9.5, 14.5), (1, 12), (9.5, 9.5)]  # on a 24 box
SPARKLE_FILL = (255, 230, 128, 255)


def lerp(a: tuple, b: tuple, t: float) -> tuple:
    return tuple(round(a[i] + (b[i] - a[i]) * t) for i in range(3))


def medal_fill(canvas: int, box: tuple, colours: tuple) -> Image.Image:
    """The medal's fill over `box` (left, top, right, bottom): flat, or the mockup's radial gradient: light at 35% across
    and 30% down, dark from 70% of the way to the farthest corner"""
    light, dark = colours
    fill = Image.new("RGBA", (canvas, canvas), light + (255,))
    if dark is None:
        return fill
    left, top, right, bottom = box
    wide = right - left
    cx, cy = left + 0.35 * wide, top + 0.3 * wide
    reach = 0.7 * ((right - cx) ** 2 + (bottom - cy) ** 2) ** 0.5
    paint = ImageDraw.Draw(fill)
    # concentric discs from the outside in, each a little lighter
    radius = int(reach * 1.6)
    while radius > 0:
        colour = lerp(light, dark, min(1.0, radius / reach)) + (255,)
        paint.ellipse([cx - radius, cy - radius, cx + radius, cy + radius], fill=colour)
        radius -= 1
    return fill


def make_medal(grade: str, look: dict):
    canvas = MEDAL_SIZE * SCALE
    diameter = canvas * PICTURE
    left = (canvas - diameter) / 2
    top = left - diameter * MEDAL_SHADOW["drop"] / 2  # a little up, the shadow under it
    box = (left, top, left + diameter, top + diameter)
    image = Image.new("RGBA", (canvas, canvas), (0, 0, 0, 0))
    # the soft shadow under it
    shadow = Image.new("RGBA", (canvas, canvas), (0, 0, 0, 0))
    drop = diameter * MEDAL_SHADOW["drop"]
    ImageDraw.Draw(shadow).ellipse([box[0], box[1] + drop, box[2], box[3] + drop], fill=(0, 0, 0, MEDAL_SHADOW["alpha"]))
    image.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(diameter * MEDAL_SHADOW["blur"])))
    # the white ring: the whole disc white, the fill inside it
    draw = ImageDraw.Draw(image)
    draw.ellipse(box, fill=WHITE)
    ring = diameter * look["ring"]
    inner = (box[0] + ring, box[1] + ring, box[2] - ring, box[3] - ring)
    mask = Image.new("L", (canvas, canvas), 0)
    ImageDraw.Draw(mask).ellipse(inner, fill=255)
    fill = medal_fill(canvas, box, look["fill"])
    image.paste(fill, (0, 0), mask)
    # the letter, its middle on the medal's, a drop shadow under it and a thin edge round it
    face = ImageFont.truetype(FONT, round(diameter * look["letter"]))
    face.set_variation_by_axes([700, 100])
    left_edge, top_edge, right_edge, bottom_edge = face.getbbox(grade)
    x = (box[0] + box[2]) / 2 - (left_edge + right_edge) / 2
    y = (box[1] + box[3]) / 2 - (top_edge + bottom_edge) / 2
    edge = max(1, round(diameter * LETTER_EDGE))
    letter_shadow = Image.new("RGBA", (canvas, canvas), (0, 0, 0, 0))
    ImageDraw.Draw(letter_shadow).text((x, y + diameter * SHADOW_DROP), grade, font=face, fill=look["shadow"], stroke_width=edge, stroke_fill=look["shadow"])
    image.alpha_composite(letter_shadow)
    draw = ImageDraw.Draw(image)
    draw.text((x, y), grade, font=face, fill=WHITE, stroke_width=edge, stroke_fill=look["edge"] + (255,))
    image = image.resize((MEDAL_SIZE, MEDAL_SIZE), Image.LANCZOS)
    image.save(os.path.join(OUT, f"medal_{grade}.png"))


def make_glow():
    wide, tall = GLOW_CARD
    margin = round(wide * GLOW_REACH)
    size = (wide + 2 * margin, tall + 2 * margin)
    canvas = (size[0] * SCALE, size[1] * SCALE)
    alpha = Image.new("L", canvas, 0)
    spread = wide * GLOW_SPREAD
    edge = (margin - spread) * SCALE
    ImageDraw.Draw(alpha).rounded_rectangle(
        [edge, edge, canvas[0] - edge, canvas[1] - edge], radius=(wide * GLOW_CORNER + spread) * SCALE, fill=255
    )
    alpha = alpha.filter(ImageFilter.GaussianBlur(wide * GLOW_BLUR * SCALE))
    image = Image.new("RGBA", canvas, (255, 255, 255, 0))
    image.putalpha(alpha)
    image = image.resize(size, Image.LANCZOS)
    image.save(os.path.join(OUT, "card_glow.png"))


def make_sparkle():
    canvas = SPARKLE_SIZE * SCALE
    unit = canvas / 24
    points = [(x * unit, y * unit) for x, y in SPARKLE]
    image = Image.new("RGBA", (canvas, canvas), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    # the white edge: each side a thick line and each corner a disc (round joins), then the gold over it
    width = 1.5 * unit
    for index, start in enumerate(points):
        end = points[(index + 1) % len(points)]
        draw.line([start, end], fill=WHITE, width=round(width))
        draw.ellipse([start[0] - width / 2, start[1] - width / 2, start[0] + width / 2, start[1] + width / 2], fill=WHITE)
    draw.polygon(points, fill=SPARKLE_FILL)
    image = image.resize((SPARKLE_SIZE, SPARKLE_SIZE), Image.LANCZOS)
    image.save(os.path.join(OUT, "sparkle.png"))


def main():
    os.makedirs(OUT, exist_ok=True)
    for grade, look in GRADES.items():
        make_medal(grade, look)
    make_glow()
    make_sparkle()
    print("wrote", os.path.normpath(OUT))


if __name__ == "__main__":
    main()
