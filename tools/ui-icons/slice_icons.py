"""Cuts the UI icon sheet (a 4x4 grid on a magenta background, made with Figma's image generator) into separate
transparent PNGs in assets/ui/icons, one per name below. Needs Pillow.

Usage: python tools/ui-icons/slice_icons.py <sheet.jpg> [sheet number 1-4, default 1]
"""
import os
import sys

from PIL import Image

SHEETS = {
    1: [
        "Cash", "Shard", "Level", "Manage",
        "Cards", "Bag", "Build", "Prices",
        "Jobs", "Party", "Pack", "Box",
        "Info", "Angry", "Happy", "Thinking",
    ],
    2: [
        "Shop", "Shelves", "Cases", "Fixtures",
        "Decor", "Close", "Search", "Odds",
        "Flip", "Hourglass", "Ember", "Tide",
        "Bloom", "Volt", "Shade", "Coin",
    ],
    3: [
        "BoosterPack", "Sleeves", "DeckBox", "BoosterBox",
        "Register", "Condenser", "Order", "Customer",
        "Trophy", "Gift", "Lock", "Check",
        "Next", "Heart", "Star", "Gem",
    ],
    4: [
        "Power", "Hp", "Atk", "Spd",
        "Xp", "Copies", "Summon", "Remove",
        "Job", "KeyFragment", "XpTonic", "GradingSeal",
        "GoldSeal", "Travel", "Best", "Pvp",
    ],
}
GRID = 4
OUT_SIZE = 256
OUT_DIR = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "ui", "icons")


def magenta_amount(r: int, g: int, b: int) -> float:
    """0 = not background, 1 = clearly the magenta background (either shade of it)."""
    low = min(r, b)
    if low < 90:
        return 0.0
    # Magenta: red and blue both high, green far below them
    gap = low - g
    return max(0.0, min(1.0, (gap - 60) / 50))


def key_out(cell: Image.Image) -> Image.Image:
    """Clears the background by flooding in from the cell's edges, so magenta-ish colours inside an icon
    (a purple crystal) survive: the icon's white outline stops the flood."""
    rgba = cell.convert("RGBA")
    pixels = rgba.load()
    width, height = rgba.size
    seen = set()
    stack = [(x, y) for x in range(width) for y in (0, height - 1)] + [(x, y) for y in range(height) for x in (0, width - 1)]
    while stack:
        x, y = stack.pop()
        if (x, y) in seen or not (0 <= x < width and 0 <= y < height):
            continue
        seen.add((x, y))
        r, g, b, _ = pixels[x, y]
        amount = magenta_amount(r, g, b)
        if amount <= 0:
            continue
        pixels[x, y] = (r, g, b, int(255 * (1 - amount)))
        stack.extend(((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)))
    # Holes the flood can't reach (inside a gear or a ring): only strong, pure magenta is cleared there
    for y in range(height):
        for x in range(width):
            r, g, b, a = pixels[x, y]
            if a == 255 and r > 200 and b > 200 and g < 70:
                pixels[x, y] = (r, g, b, 0)
    return rgba


def square(icon: Image.Image) -> Image.Image:
    box = icon.getbbox()
    if box:
        icon = icon.crop(box)
    side = max(icon.size)
    canvas = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    canvas.paste(icon, ((side - icon.width) // 2, (side - icon.height) // 2), icon)
    return canvas.resize((OUT_SIZE, OUT_SIZE), Image.LANCZOS)


def main(path: str, sheet: int):
    names = SHEETS[sheet]
    sheet = Image.open(path)
    cell_w = sheet.width / GRID
    cell_h = sheet.height / GRID
    os.makedirs(OUT_DIR, exist_ok=True)
    for index, name in enumerate(names):
        col, row = index % GRID, index // GRID
        # A small inset skips the darker tile edges between cells
        inset = cell_w * 0.04
        cell = sheet.crop((
            int(col * cell_w + inset), int(row * cell_h + inset),
            int((col + 1) * cell_w - inset), int((row + 1) * cell_h - inset),
        ))
        square(key_out(cell)).save(os.path.join(OUT_DIR, f"{name}.png"))
    print(f"saved {len(names)} icons to {os.path.abspath(OUT_DIR)}")


if __name__ == "__main__":
    main(sys.argv[1], int(sys.argv[2]) if len(sys.argv) > 2 else 1)
