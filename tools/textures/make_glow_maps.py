"""Makes each weapon's glow map (emissive mask) from its colour map: white where the painting should glow.

Weapon glow (owner 2026-11-06): the painted runes, gems and crystal glow themselves (SurfaceAppearance emissive masks)
instead of a Neon shell over the blade. The maps are uploaded as images and baked into the models by
`lune run tools/weapons/add_glow_maps` (a game script can't set them); `Util/WeaponLook` sets their strength and tint.

Rules (hue, saturation, value 0-1), per model:
- SunforgedBlade: its molten runes (red-orange and bright) and white-hot cores; the gold stays matte.
- VerdantBlade: the pale green crystal and seed gems; the wood and vines stay matte.
- PrismBlade: the rainbow facets and gems (saturated colour), the pearl body faintly.
- ForgeSword: its gems: wherever an element's colour map differs from the base map (one map for all five; same UVs).
Spears (weapons round 2):
- ForgeSpear: its collar gems, as the Forge Sword's.
- MagmaHalberd: its lava cracks, molten spike and fire gem (the Sunforged's molten rule); the obsidian stays matte.
- TidalTrident: the frosted crystal prongs and the aquamarine gem (pale to bright blue-cyan); the pearl shaft and the
  silver spiral stay matte.
- TitansLance: the emerald veins and gem (saturated green); the gold and the wood stay matte.
Scythes (weapons round 3; hues measured on the baked maps 2026-11-09):
- ForgeScythe: its socket gems, as the Forge Sword's.
- WidowsReaper: the lilac edge and the spider's eyes (the brightest violet, value 0.8+); the violet blade, the black
  body and the bone shaft stay matte.
- StormReaper: the lemon lightning crack (hue 0.14-0.18; the gold metal sits at 0.10-0.12 and stays matte) and the
  cyan edge and gem.
- RiftReaper: the vivid violet cracks, crystals and eye (saturated, bright); the black blade and the silver stay matte.

Usage: python tools/textures/make_glow_maps.py   (needs Pillow; writes assets/ui/weapon-glow-maps/<Model>.png)
"""
import colorsys
import os

from PIL import Image, ImageChops, ImageFilter

ROOT = os.path.join(os.path.dirname(__file__), "..", "..")
SOURCES = os.path.join(ROOT, "assets", "blender")
OUT = os.path.join(ROOT, "assets", "ui", "weapon-glow-maps")


def clamp(value):
    return max(0.0, min(1.0, value))


def sunforged(h, s, v):
    molten = clamp((0.085 - h) / 0.03) * clamp((s - 0.55) / 0.25) * clamp((v - 0.55) / 0.3)
    white_hot = clamp((v - 0.97) / 0.03) if h < 0.14 else 0.0
    return max(molten, white_hot)


def verdant(h, s, v):
    return clamp(1 - abs(h - 0.3) / 0.12) * clamp((v - 0.62) / 0.25) * clamp((s - 0.08) / 0.2)


def prism(h, s, v):
    return max(clamp((s - 0.35) / 0.3) * clamp((v - 0.5) / 0.35), clamp((v - 0.9) / 0.1) * 0.25)


def tidal(h, s, v):
    return clamp(1 - abs(h - 0.53) / 0.09) * clamp((s - 0.15) / 0.2) * clamp((v - 0.6) / 0.3)


def emerald(h, s, v):
    return clamp(1 - abs(h - 0.42) / 0.1) * clamp((s - 0.25) / 0.25) * clamp((v - 0.3) / 0.3)


def widow(h, s, v):
    return clamp(1 - abs(h - 0.76) / 0.08) * clamp((v - 0.78) / 0.12) * clamp((s - 0.1) / 0.15)


def storm(h, s, v):
    lightning = clamp(1 - abs(h - 0.16) / 0.03) * clamp((s - 0.4) / 0.2) * clamp((v - 0.72) / 0.2)
    edge = clamp(1 - abs(h - 0.53) / 0.05) * clamp((s - 0.3) / 0.2) * clamp((v - 0.6) / 0.3)
    return max(lightning, edge)


def rift(h, s, v):
    return clamp(1 - abs(h - 0.75) / 0.1) * clamp((s - 0.4) / 0.15) * clamp((v - 0.6) / 0.2)


RULES = {
    "SunforgedBlade": sunforged,
    "VerdantBlade": verdant,
    "PrismBlade": prism,
    "MagmaHalberd": sunforged,
    "TidalTrident": tidal,
    "TitansLance": emerald,
    "WidowsReaper": widow,
    "StormReaper": storm,
    "RiftReaper": rift,
}


def by_colour(name, rule):
    image = Image.open(os.path.join(SOURCES, name, f"{name}_color.png")).convert("RGB")
    pixels = image.load()
    mask = Image.new("L", image.size)
    out = mask.load()
    for y in range(image.size[1]):
        for x in range(image.size[0]):
            r, g, b = pixels[x, y]
            h, s, v = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
            out[x, y] = int(255 * clamp(rule(h, s, v)))
    return mask


def forge_gems(name):
    folder = os.path.join(SOURCES, name)
    base = Image.open(os.path.join(folder, f"{name}_color.png")).convert("RGB")
    mask = Image.new("L", base.size, 0)
    for element in ("Ember", "Tide", "Bloom", "Volt", "Shade"):
        tinted = Image.open(os.path.join(folder, f"{name}_{element}_color.png")).convert("RGB")
        difference = ImageChops.difference(base, tinted).convert("L").point(lambda d: 255 if d > 24 else 0)
        mask = ImageChops.lighter(mask, difference)
    return mask


def main():
    os.makedirs(OUT, exist_ok=True)
    maps = {name: by_colour(name, rule) for name, rule in RULES.items()}
    maps["ForgeSword"] = forge_gems("ForgeSword")
    maps["ForgeSpear"] = forge_gems("ForgeSpear")
    maps["ForgeScythe"] = forge_gems("ForgeScythe")
    for name, mask in maps.items():
        mask.filter(ImageFilter.GaussianBlur(1)).save(os.path.join(OUT, f"{name}.png"))
        print("saved", name)


if __name__ == "__main__":
    main()
