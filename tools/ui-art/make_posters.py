"""Shop window posters (owner 2026-11-19: "add like 5 poster arts players could place in on the glass part of their
shop", then "I want the posters to be funny you can use figma to design something"): five funny portrait posters. Their
scenes come from Figma's image generator with no text (assets/ui/posters/art/<id>.jpg, 1024 x 1280: a kid buried in
pack wrappers, a crying empty wallet, Pish as a guard dog, Chikin caught with a Legendary, Turts asleep on the
register); this puts each one's joke on a title band in Fredoka. Writes assets/ui/posters/poster_<id>.png (512 x 768) and a
contact sheet (posters_all.png). Uploaded as images once approved (ids then go in Config/Posters).
Run: python tools/ui-art/make_posters.py"""
import os

from PIL import Image, ImageDraw, ImageFilter, ImageFont

HERE = os.path.dirname(__file__)
ROOT = os.path.join(HERE, "..", "..")
OUT = os.path.join(ROOT, "assets", "ui", "posters")
FONT = os.path.join(HERE, "fonts", "Fredoka.ttf")
W, H = 512, 768
BAND = 150  # the title band's height

# id, art file, where to centre the crop (x, y as shares of the art), title lines, band colour, ink
POSTERS = [
    ("onemore", "assets/ui/posters/art/onemore.jpg", (0.5, 0.42), ["JUST ONE MORE", "I said that 40 packs ago"], (255, 205, 60), (95, 55, 0)),
    ("wallet", "assets/ui/posters/art/wallet.jpg", (0.5, 0.55), ["MISSING: WALLET", "Last seen near the packs"], (120, 170, 235), (255, 255, 255)),
    ("beware", "assets/ui/posters/art/beware.jpg", (0.5, 0.5), ["BEWARE OF DOG", "He will lick you"], (225, 60, 60), (255, 255, 255)),
    ("wanted", "assets/ui/posters/art/wanted.jpg", (0.5, 0.45), ["WANTED", "For eating a Legendary"], (245, 225, 180), (90, 55, 20)),
    ("employee", "assets/ui/posters/art/employee.jpg", (0.5, 0.5), ["TOP EMPLOYEE", "Asleep since Monday"], (60, 170, 120), (255, 255, 255)),
]


def cover(art: Image.Image, width: int, height: int, focus) -> Image.Image:
    """The art scaled to fill width x height, cropped round `focus`"""
    scale = max(width / art.width, height / art.height)
    big = art.resize((round(art.width * scale), round(art.height * scale)), Image.LANCZOS)
    left = min(max(round(big.width * focus[0] - width / 2), 0), big.width - width)
    top = min(max(round(big.height * focus[1] - height / 2), 0), big.height - height)
    return big.crop((left, top, left + width, top + height))


def fit_font(draw, text: str, width: int, start: int) -> ImageFont.FreeTypeFont:
    size = start
    while size > 12:
        font = ImageFont.truetype(FONT, size)
        font.set_variation_by_name("Bold")
        if draw.textlength(text, font=font) <= width:
            return font
        size -= 2
    return font


def poster(spec) -> Image.Image:
    name, path, focus, lines, band, ink = spec
    art = Image.open(os.path.join(ROOT, path)).convert("RGBA")
    back = Image.new("RGBA", art.size, (40, 30, 60, 255))
    back.alpha_composite(art)
    image = Image.new("RGBA", (W, H), (255, 255, 255, 255))
    image.paste(cover(back, W, H - BAND, focus), (0, 0))
    draw = ImageDraw.Draw(image)
    draw.rectangle((0, H - BAND, W, H), fill=band + (255,))
    # a soft shade where the art meets the band
    shade = Image.new("RGBA", (W, 40), (0, 0, 0, 0))
    shade_draw = ImageDraw.Draw(shade)
    for row in range(40):
        shade_draw.line((0, row, W, row), fill=(0, 0, 0, int(90 * row / 40)))
    image.alpha_composite(shade, (0, H - BAND - 40))
    title = fit_font(draw, lines[0], W - 60, 78)
    sub = fit_font(draw, lines[1], W - 80, 38)
    draw.text((W / 2, H - BAND + 52), lines[0], font=title, fill=ink, anchor="mm")
    draw.text((W / 2, H - BAND + 112), lines[1], font=sub, fill=ink, anchor="mm")
    # a white paper edge, rounded
    mask = Image.new("L", (W, H), 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, W - 1, H - 1), radius=26, fill=255)
    framed = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    framed.paste(image, (0, 0), mask)
    ImageDraw.Draw(framed).rounded_rectangle((5, 5, W - 6, H - 6), radius=22, outline=(255, 255, 255, 255), width=10)
    return framed


def main():
    os.makedirs(OUT, exist_ok=True)
    made = []
    for spec in POSTERS:
        image = poster(spec)
        image.save(os.path.join(OUT, f"poster_{spec[0]}.png"))
        made.append(image)
    gap = 24
    sheet = Image.new("RGBA", (len(made) * (W // 2) + (len(made) + 1) * gap, H // 2 + 2 * gap), (70, 80, 100, 255))
    for index, image in enumerate(made):
        small = image.resize((W // 2, H // 2), Image.LANCZOS)
        sheet.alpha_composite(small, (gap + index * (W // 2 + gap), gap))
    sheet.save(os.path.join(OUT, "posters_all.png"))
    print(os.path.abspath(os.path.join(OUT, "posters_all.png")))


if __name__ == "__main__":
    main()
