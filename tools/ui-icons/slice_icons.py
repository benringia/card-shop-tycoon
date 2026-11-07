"""Cuts the UI icon sheet (a 4x4 grid on a magenta background, made with Figma's image generator) into separate
transparent PNGs in assets/ui/icons, one per name below. Needs Pillow.

Usage: python tools/ui-icons/slice_icons.py <sheet.jpg> [sheet number 1-9, default 1]
       python tools/ui-icons/slice_icons.py <icon.png> single <Name>   (one icon on magenta, e.g. DashSkill)
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
    # The boss-fight HUD (white line icons for the slanted panels) and spares for heals and the Forge
    5: [
        "Attack", "Dodge", "SpinSkill", "Paw",
        "Sparkle", "Swap", "Run", "Shield",
        "Potion", "Food", "Heal", "Sword",
        "Forge", "Skull", "Target", "Bolt",
    ],
    # The Pet button moves and super moves (white glyphs, pet moves round 2026-11-05; Config/MoveFx SKILL_ICONS) and spares
    6: [
        "MoveFireball", "MoveRain", "MoveSnare", "MoveOvercharge",
        "MoveCurse", "MoveInferno", "MoveTidalShield", "MoveStampede",
        "MoveEclipse", "MoveSupernova", "MoveDevour", "Crown",
        "Crit", "Stunned", "Chain", "Cooldown",
    ],
    # Weapons round 1 (owner's pick A, 2026-11-06): the boss materials and Wild Ore (Config/Items), and spare Forge icons
    7: [
        "WardenHeartwood", "BroodSilk", "ColossusCore", "FrostHeart",
        "StormCrystal", "RiftShard", "PrismScale", "WildOre",
        "Anvil", "Hammer", "Upgrade", "Reforge",
        "Spear", "Scythe", "Elements", "Awakened",
    ],
    # The sword skill button per sword (white glyphs, owner's picks 2026-11-07; Config/CombatHud SKILLS): four takes of
    # each skill's icon, the used ones Thornline, Sunfall and PrismJudgment (Elemental Spin uses sheet 5's SpinSkill)
    8: [
        "Thornline", "ThornWrap", "ThornBurst", "ThornCrack",
        "Sunfall", "FireCrescent", "CrescentSparks", "SunCrescent",
        "SwordRain", "PrismJudgment", "SwordGem", "SwordCrown",
        "ThornlineBold", "CrescentBold", "SwordRing", "Tornado",
    ],
    # weapons round 2: the spear skill button (owner's pick C: afterimages) and spares for the next spear skills
    9: [
        "RushGhosts", "RushGhosts3", "RushSpeed", "RushBold",
        "HalberdFlames", "HalberdCrack", "Volcano", "HalberdSpin",
        "TridentWave", "TridentDrops", "TridentIcicles", "Whirlpool",
        "LanceBloom", "LanceLeaves", "GiantThorn", "LanceSun",
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


def single(path: str, name: str):
    os.makedirs(OUT_DIR, exist_ok=True)
    out = os.path.join(OUT_DIR, f"{name}.png")
    square(key_out(Image.open(path))).save(out)
    print(f"saved {os.path.abspath(out)}")


if __name__ == "__main__":
    if len(sys.argv) > 3 and sys.argv[2] == "single":
        single(sys.argv[1], sys.argv[3])
    else:
        main(sys.argv[1], int(sys.argv[2]) if len(sys.argv) > 2 else 1)
