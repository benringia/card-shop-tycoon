"""The boss-fight HUD's slanted "anime slash" button shape (Config/CombatHud): a white fill and a white edge (thick top
and bottom bands, thin sides) that each button tints in its own colour. Usage: python tools/textures/make_slant_buttons.py
[out dir] (default assets/ui/combat). Needs Pillow. Uploaded as images; ids in Config/CombatHud."""
import sys
from PIL import Image, ImageDraw
out = sys.argv[1] if len(sys.argv) > 1 else "assets/ui/combat"
S = 4  # supersample
W, H = 256, 160
slant = 0.25 * W
def shape(draw, inset, fill=None, outline=None, width=0):
    pts = [(slant + inset, inset), (W - inset, inset), (W - slant - inset, H - inset), (inset, H - inset)]
    pts = [(x * S, y * S) for x, y in pts]
    draw.polygon(pts, fill=fill, outline=outline)
# fill
img = Image.new("RGBA", (W * S, H * S), (0, 0, 0, 0))
d = ImageDraw.Draw(img)
shape(d, 0, fill=(255, 255, 255, 255))
img.resize((W, H), Image.LANCZOS).save(out + "/slant_fill.png")
# edge: thick top and bottom bands, thin sides
img = Image.new("RGBA", (W * S, H * S), (0, 0, 0, 0))
d = ImageDraw.Draw(img)
shape(d, 0, fill=(255, 255, 255, 255))
inner = Image.new("RGBA", (W * S, H * S), (0, 0, 0, 0))
di = ImageDraw.Draw(inner)
t, side = 10, 3
pts = [(slant + side + t * 0.25, t), (W - side, t), (W - slant - side - t * 0.25, H - t), (side, H - t)]
di.polygon([(x * S, y * S) for x, y in pts], fill=(255, 255, 255, 255))
edge = Image.new("RGBA", (W * S, H * S), (0, 0, 0, 0))
edge.paste(img, (0, 0))
edge.paste((0, 0, 0, 0), (0, 0), inner)
edge.resize((W, H), Image.LANCZOS).save(out + "/slant_edge.png")
print("ok")
