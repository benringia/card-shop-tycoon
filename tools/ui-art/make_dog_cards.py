"""The loading screen's binder cards (owner 2026-11-13: Pish, Chikin and Turts instead of the game's cards; 2026-11-14:
painted card art instead of their models): each pose is a painting in the card art's style (Figma's image generator,
prompts in docs/card-art.md "The loading screen's dog cards"), kept 680 wide in assets/ui/loading/dog_cards/art, with
the dog's name on a plate at the bottom (Fredoka Bold, baked in so the loading screen needs no font). Writes
assets/ui/loading/dog_cards/cards/<Dog>_<pose>.jpg at the card art's small size (340 x 507), uploaded as images
(ids in Config/LoadingScreen DOG_CARDS). Needs Pillow.

  python tools/ui-art/make_dog_cards.py
"""
import os

from PIL import Image, ImageDraw, ImageFont, ImageOps

REPO = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
ART = os.path.join(REPO, "assets", "ui", "loading", "dog_cards", "art")
OUT = os.path.join(REPO, "assets", "ui", "loading", "dog_cards", "cards")
SIZE = (340, 507)
FONT = os.path.join(REPO, "tools", "textures", "fonts", "Fredoka.ttf")

CARDS = ["Pish_point", "Pish_tilt", "Pish_bow", "Chikin_point", "Chikin_sit", "Chikin_hop", "Turts_sit", "Turts_tilt",
         "Turts_cheer"]


def card(name):
    painting = Image.open(os.path.join(ART, f"{name}.jpg")).convert("RGBA")
    # the card's shape, cut from the middle (the paintings come a hair wider or taller)
    painting = ImageOps.fit(painting, (painting.width, round(painting.width * SIZE[1] / SIZE[0])), Image.LANCZOS)
    name_plate(painting, name.split("_")[0])
    return painting.convert("RGB").resize(SIZE, Image.LANCZOS)


def name_plate(image, name):
    """A dark rounded plate along the bottom with the dog's name, white with a dark outline"""
    width, height = image.size
    font = ImageFont.truetype(FONT, round(height * 0.1))
    font.set_variation_by_name("Bold")
    plate_h = round(height * 0.14)
    left, right = round(width * 0.08), round(width * 0.92)
    bottom = height - round(height * 0.03)
    plate = Image.new("RGBA", image.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(plate)
    draw.rounded_rectangle((left, bottom - plate_h, right, bottom), radius=plate_h // 2, fill=(22, 16, 40, 215),
                           outline=(255, 214, 110, 255), width=max(3, height // 260))
    draw.text((width / 2, bottom - plate_h / 2), name, font=font, anchor="mm", fill=(255, 255, 255, 255),
              stroke_width=max(2, height // 220), stroke_fill=(22, 16, 40, 255))
    image.alpha_composite(plate)


def main():
    os.makedirs(OUT, exist_ok=True)
    for name in CARDS:
        path = os.path.join(OUT, f"{name}.jpg")
        card(name).save(path, quality=90)
        print("card", path)


if __name__ == "__main__":
    main()
