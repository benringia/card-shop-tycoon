"""Textures for a set's 3D pack, deck box and display box (UI project 3, spec 2026-10-29-cards-in-world-and-pack-opening).

Usage: python tools/textures/make_pack_textures.py <art.jpg> <font.ttf> <out_dir> "<SET NAME>"
  art   the set's pack art (assets/ui/packs/<Set>.jpg)
  font  Fredoka (OFL), e.g. tools/textures/fonts/Fredoka.ttf (git-ignored; fetch it from
        https://raw.githubusercontent.com/google/fonts/main/ofl/fredoka/Fredoka%5Bwdth,wght%5D.ttf)

Writes to out_dir (assets/blender/Pack/):
  Pack.png         front | back, 2048 x 1600 (Blender); Pack_1024.png the 1024 x 800 copy for upload
  Pack_metal.png   metalness 1024 x 800 (the crimped seals are metal), Pack_rough.png roughness 1024 x 800
  DeckBox.png      1024 x 1024 atlas: front, back, side, lid band (regions in DECK below)
  DisplayBox.png   1024 x 1024 atlas: lid art, front panel, cardboard, inside (regions in DISPLAY below)
The build scripts in tools/blender map their UVs to these same regions.
"""
import math
import os
import random
import sys

from PIL import Image, ImageDraw, ImageFont

W, H = 1024, 1600  # one face of the pack
CRIMP = 112  # px of crimped seal at the top and bottom of a face
CUT = 0.105  # the tear line, as a share of the height from the top
# Atlas regions (left, top, right, bottom) in px of a 1024 x 1024 image
DECK = {"front": (0, 0, 512, 640), "back": (512, 0, 1024, 640), "side": (0, 640, 512, 1024), "lid": (512, 640, 1024, 1024)}
DISPLAY = {"lid": (0, 0, 1024, 560), "front": (0, 560, 1024, 800), "cardboard": (0, 800, 512, 1024), "inside": (512, 800, 1024, 1024)}
GEMS = [(233, 237, 243), (70, 140, 255), (40, 210, 200), (170, 80, 255), (255, 200, 40)]


def font(path, size, weight="Bold"):
    f = ImageFont.truetype(path, size)
    try:
        f.set_variation_by_name(weight)
    except (OSError, ValueError):
        pass
    return f


def outlined(draw, xy, text, f, fill, stroke, width, anchor="mm"):
    draw.text(xy, text, font=f, fill=fill, stroke_width=width, stroke_fill=stroke, anchor=anchor)


def cover(art, w, h, sky=0.17):
    """The art scaled to cover w x h, its plain sky (top share) skipped (the First Spark art has a seam at 0.24)."""
    scale = max(w / art.width, h / (art.height * (1 - sky)))
    big = art.resize((int(art.width * scale) + 1, int(art.height * scale) + 1), Image.LANCZOS)
    left = (big.width - w) // 2
    top = int(big.height * sky)
    return big.crop((left, top, left + w, top + h))


def crimp_band(img, top):
    band = Image.new("RGB", (W, CRIMP))
    d = ImageDraw.Draw(band)
    for x in range(W):
        v = int(150 + 80 * (0.5 + 0.5 * math.sin(x / 3.2)))
        d.line([(x, 0), (x, CRIMP)], fill=(v, int(v * 0.93), int(v * 0.8)))
    shade = Image.linear_gradient("L").resize((W, CRIMP))
    if not top:
        shade = shade.transpose(Image.FLIP_TOP_BOTTOM)
    band = Image.composite(band, Image.new("RGB", (W, CRIMP), (90, 70, 50)), shade.point(lambda p: 255 - p // 3))
    img.paste(band, (0, 0 if top else H - CRIMP))
    y = CRIMP - 4 if top else H - CRIMP
    ImageDraw.Draw(img).rectangle([0, y, W, y + 3], fill=(120, 60, 20))


def star(draw, c, outer, inner, fill, outline):
    pts = []
    for i in range(10):
        a = -math.pi / 2 + i * math.pi / 5
        r = outer if i % 2 == 0 else inner
        pts.append((c[0] + r * math.cos(a), c[1] + r * math.sin(a)))
    draw.polygon(pts, fill=fill, outline=outline)


def pack_front(art, fnt, words):
    img = cover(art, W, H)
    shade = Image.new("L", (W, H), 0)
    sd = ImageDraw.Draw(shade)
    for y in range(H):
        a = max(0, 1 - (y - CRIMP) / 420) * 150 + max(0, (y - (H - 520)) / 520) * 140
        sd.line([(0, y), (W, y)], fill=int(min(200, a)))
    img = Image.composite(Image.new("RGB", (W, H), (35, 8, 25)), img, shade)
    d = ImageDraw.Draw(img)
    for inset, col in ((26, (255, 214, 110)), (34, (150, 80, 20))):
        d.rectangle([inset, CRIMP + 20, W - inset, H - CRIMP - 20], outline=col, width=5)
    first, second = words
    outlined(d, (W // 2, CRIMP + 185), first, font(fnt, 170), (255, 246, 220), (110, 30, 0), 14)
    outlined(d, (W // 2, CRIMP + 350), second, font(fnt, 200), (255, 210, 80), (110, 30, 0), 16)
    d.rounded_rectangle([W // 2 - 260, CRIMP + 460, W // 2 + 260, CRIMP + 530], radius=34, fill=(255, 120, 30), outline=(110, 30, 0), width=6)
    outlined(d, (W // 2, CRIMP + 496), "BOOSTER PACK", font(fnt, 48), (255, 255, 255), (110, 30, 0), 5)
    d.rounded_rectangle([W // 2 - 190, H - CRIMP - 190, W // 2 + 190, H - CRIMP - 90], radius=48, fill=(40, 12, 40), outline=(255, 214, 110), width=6)
    outlined(d, (W // 2, H - CRIMP - 140), "5 CARDS", font(fnt, 64), (255, 246, 220), (40, 12, 40), 4)
    cut = int(H * CUT)
    for x in (18, W - 18):
        d.polygon([(x - 12, cut - 10), (x + 12, cut - 10), (x, cut + 8)], fill=(255, 240, 200))
    crimp_band(img, True)
    crimp_band(img, False)
    return img


def pack_back(fnt, name):
    random.seed(7)
    img = Image.new("RGB", (W, H))
    d = ImageDraw.Draw(img)
    for y in range(H):
        t = y / H
        d.line([(0, y), (W, y)], fill=(int(40 + 30 * t), int(18 + 10 * t), int(80 + 40 * (1 - t))))
    for _ in range(140):
        x, y, r = random.randint(0, W), random.randint(CRIMP, H - CRIMP), random.choice((2, 3, 3, 4, 6))
        d.ellipse([x - r, y - r, x + r, y + r], fill=(255, 220, 150) if r > 4 else (200, 180, 255))
    d.rectangle([W // 2 - 40, CRIMP, W // 2 + 40, H - CRIMP], fill=(70, 34, 110))
    for x in range(W // 2 - 40, W // 2 + 40, 6):
        d.line([(x, CRIMP), (x, H - CRIMP)], fill=(95, 50, 140), width=2)
    c = (W // 2, H // 2 - 80)
    d.ellipse([c[0] - 190, c[1] - 190, c[0] + 190, c[1] + 190], fill=(30, 12, 60), outline=(255, 214, 110), width=10)
    star(d, c, 140, 60, (255, 200, 60), (150, 80, 20))
    outlined(d, (W // 2, H // 2 + 200), name, font(fnt, 96), (255, 246, 220), (40, 12, 60), 8)
    outlined(d, (W // 2, H // 2 + 300), "5 random cards inside", font(fnt, 46, "SemiBold"), (210, 200, 255), (40, 12, 60), 4)
    for i, col in enumerate(GEMS):
        d.regular_polygon((W // 2 + (i - 2) * 90, H // 2 + 400, 30), 6, fill=col, outline=(20, 10, 40))
    crimp_band(img, True)
    crimp_band(img, False)
    return img


def pack_maps():
    """Metalness and roughness, 1024 x 800 like the upload copy: seals metal and smooth, the art a little metal."""
    w, h = 1024, 800
    crimp = int(CRIMP * h / H)
    metal = Image.new("L", (w, h), 30)
    rough = Image.new("L", (w, h), 97)
    for img, seal in ((metal, 230), (rough, 70)):
        d = ImageDraw.Draw(img)
        d.rectangle([0, 0, w, crimp], fill=seal)
        d.rectangle([0, h - crimp, w, h], fill=seal)
    return metal, rough


def region(img, box):
    return box[0], box[1], box[2] - box[0], box[3] - box[1]


def deck_atlas(art, fnt, name):
    img = Image.new("RGB", (1024, 1024), (120, 70, 180))
    d = ImageDraw.Draw(img)
    x, y, w, h = region(img, DECK["front"])
    img.paste(cover(art, w, h, sky=0.25), (x, y))
    d.rectangle([x, y, x + w, y + h], outline=(255, 214, 110), width=10)
    outlined(d, (x + w // 2, y + 110), name, font(fnt, 70), (255, 246, 220), (60, 20, 90), 7)
    d.rounded_rectangle([x + 90, y + h - 150, x + w - 90, y + h - 70], radius=30, fill=(150, 95, 210), outline=(255, 214, 110), width=5)
    outlined(d, (x + w // 2, y + h - 110), "DECK BOX", font(fnt, 48), (255, 255, 255), (60, 20, 90), 4)
    x, y, w, h = region(img, DECK["back"])
    d.rectangle([x, y, x + w, y + h], fill=(110, 60, 170))
    star(d, (x + w // 2, y + 230), 120, 50, (255, 200, 60), (150, 80, 20))
    outlined(d, (x + w // 2, y + 420), "5 CARDS", font(fnt, 60), (255, 246, 220), (60, 20, 90), 5)
    outlined(d, (x + w // 2, y + 500), "2 Rare or better", font(fnt, 40, "SemiBold"), (230, 210, 255), (60, 20, 90), 3)
    x, y, w, h = region(img, DECK["side"])
    d.rectangle([x, y, x + w, y + h], fill=(130, 80, 195))
    for i in range(0, w, 40):
        d.line([(x + i, y), (x + i, y + h)], fill=(140, 90, 205), width=12)
    x, y, w, h = region(img, DECK["lid"])
    for i in range(h):
        t = i / h
        d.line([(x, y + i), (x + w, y + i)], fill=(int(250 - 40 * t), int(205 - 50 * t), int(110 - 50 * t)))
    outlined(d, (x + w // 2, y + h // 2), name, font(fnt, 56), (255, 250, 230), (140, 80, 10), 5)
    return img


def display_atlas(art, fnt, words, name):
    img = Image.new("RGB", (1024, 1024), (200, 160, 110))
    d = ImageDraw.Draw(img)
    x, y, w, h = region(img, DISPLAY["lid"])
    img.paste(cover(art, w, h, sky=0.25), (x, y))
    d.rectangle([x + 12, y + 12, x + w - 12, y + h - 12], outline=(255, 214, 110), width=12)
    outlined(d, (x + w // 2, y + 120), f"{words[0]} {words[1]}", font(fnt, 120), (255, 246, 220), (110, 30, 0), 12)
    d.rounded_rectangle([x + w // 2 - 330, y + h - 140, x + w // 2 + 330, y + h - 60], radius=36, fill=(255, 120, 30), outline=(110, 30, 0), width=6)
    outlined(d, (x + w // 2, y + h - 100), "BOOSTER BOX · 24 PACKS", font(fnt, 50), (255, 255, 255), (110, 30, 0), 5)
    x, y, w, h = region(img, DISPLAY["front"])
    strip = cover(art, w, h, sky=0.45)
    img.paste(Image.blend(strip, Image.new("RGB", (w, h), (40, 10, 30)), 0.45), (x, y))
    d.rectangle([x + 8, y + 8, x + w - 8, y + h - 8], outline=(255, 214, 110), width=8)
    outlined(d, (x + w // 2, y + h // 2), f"{name} · 24", font(fnt, 110), (255, 246, 220), (110, 30, 0), 10)
    x, y, w, h = region(img, DISPLAY["cardboard"])
    d.rectangle([x, y, x + w, y + h], fill=(196, 152, 102))
    for i in range(0, h, 18):
        d.line([(x, y + i), (x + w, y + i)], fill=(186, 142, 94), width=3)
    x, y, w, h = region(img, DISPLAY["inside"])
    d.rectangle([x, y, x + w, y + h], fill=(120, 88, 60))
    return img


def main():
    art_path, font_path, out_dir, name = sys.argv[1:5]
    if not os.path.exists(font_path):
        sys.exit(f"Font missing: {font_path}\nFetch Fredoka (OFL) into it, see this script's docstring.")
    os.makedirs(out_dir, exist_ok=True)
    art = Image.open(art_path).convert("RGB")
    words = name.split(" ", 1) if " " in name else (name, "")
    pack = Image.new("RGB", (W * 2, H))
    pack.paste(pack_front(art, font_path, words), (0, 0))
    pack.paste(pack_back(font_path, name), (W, 0))
    pack.save(os.path.join(out_dir, "Pack.png"))
    pack.resize((1024, 800), Image.LANCZOS).save(os.path.join(out_dir, "Pack_1024.png"))
    metal, rough = pack_maps()
    metal.save(os.path.join(out_dir, "Pack_metal.png"))
    rough.save(os.path.join(out_dir, "Pack_rough.png"))
    deck_atlas(art, font_path, name).save(os.path.join(out_dir, "DeckBox.png"))
    display_atlas(art, font_path, words, name).save(os.path.join(out_dir, "DisplayBox.png"))
    print("wrote textures to", out_dir)


if __name__ == "__main__":
    main()
