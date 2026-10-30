"""Builds the caldera's obsidian shard cluster (caldera spec 2026-10-31): 6 black-purple crystals leaning out of a low
mound, thin lava cracks on their faces, in the Ember Canyon portal's obsidian (build_portal_arena.py's palette).

Objects: Frame (the crystals and mound, palette texture) and Lava (the cracks; the game makes them glowing lava).
Blender: Z up, 1 unit = 1 stud, origin at the bottom centre, about 4 studs tall. Run inside Blender (MCP execute:
exec(open(path).read())); EXPORT=0 builds without saving. Writes assets/blender/ObsidianShards/.
"""
import math
import os
import random
import sys

from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)) if "__file__" in globals() else
                os.path.join(os.environ.get("CARD_SHOP_REPO", r"C:\Users\Ben\Documents\roblox-project\card-shop-tycoon"), "tools", "blender"))
import voxel_kit  # noqa: E402
import portal_kit  # noqa: E402

NAME = "ObsidianShards"
COLORS = {
    "obsidian_dark": (18, 13, 24),
    "obsidian": (30, 22, 40),
    "obsidian_light": (50, 38, 64),
    "rock": (40, 34, 40),
    "lava": (255, 106, 28),
}
SEED = 9
SHARDS = ("obsidian_dark", "obsidian", "obsidian_light")


def run():
    portal_kit.begin(NAME)
    rng = random.Random(SEED)
    frame = voxel_kit.Builder(COLORS)
    lava = voxel_kit.Builder(COLORS)
    frame.blob((0, 0, 0.1), (1.8, 1.6, 0.55), "rock", portal_kit.BONE, segments=8, rings=4)
    for index in range(6):
        a = index / 6 * math.tau + rng.uniform(-0.3, 0.3)
        lean = 0.15 if index == 0 else rng.uniform(0.35, 0.7)
        out = 0.0 if index == 0 else rng.uniform(0.4, 1.1)
        base = Vector((math.cos(a) * out, math.sin(a) * out, -0.2))
        direction = Vector((math.cos(a) * lean, math.sin(a) * lean, 1)).normalized()
        radius = 0.55 if index == 0 else rng.uniform(0.3, 0.45)
        length = 4.0 if index == 0 else rng.uniform(1.8, 3.0)
        portal_kit.crystal(frame, base, direction, radius, length, SHARDS[index % 3], sides=5, tip=0.35)
        # a lava crack up the crystal's outward face
        side = Vector((math.cos(a), math.sin(a), 0)) if index else Vector((0, -1, 0))
        crack_from = base + direction * length * 0.12 + side * radius * 0.92
        crack_to = base + direction * length * 0.5 + side * radius * 0.9
        portal_kit.ribbon(lava, crack_from, crack_to, 0.16, "lava", thickness=0.12)
    return portal_kit.export(NAME, [frame.to_object("Frame"), lava.to_object("Lava")], COLORS)


run()
