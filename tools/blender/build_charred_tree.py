"""Builds the caldera's charred dead tree (caldera spec 2026-10-31): a burnt black trunk splitting into 3-5 crooked bare
branches, a few branch tips still glowing like embers. Replaces the canyon's cacti.

One object, Frame (palette texture). Blender: Z up, 1 unit = 1 stud, origin at the bottom centre, about 10 studs tall.
Run inside Blender (MCP execute: exec(open(path).read())); EXPORT=0 builds without saving.
Writes assets/blender/CharredTree/.
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

NAME = "CharredTree"
COLORS = {
    "char": (26, 22, 24),
    "char_light": (52, 44, 46),
    "ember": (255, 112, 34),
}
SEED = 5


def branch(b, rng, start, heading, length, radius, depth):
    """A crooked branch from start: 3 bends, then smaller branches off its end; ember-tipped at the last level."""
    points = [start]
    direction = heading.normalized()
    for _ in range(3):
        direction = (direction + Vector((rng.uniform(-0.45, 0.45), rng.uniform(-0.45, 0.45), rng.uniform(-0.15, 0.2)))).normalized()
        points.append(points[-1] + direction * length / 3)
    radii = [radius, radius * 0.85, radius * 0.7, radius * 0.55]
    portal_kit.tube(b, points, radii, "char" if depth == 0 else "char_light", sides=6)
    end = points[-1]
    if depth >= 2:
        b.blob(end, (0.32, 0.32, 0.32), "ember", portal_kit.BONE, segments=6, rings=4)
        return
    for _ in range(2 if depth == 0 else rng.choice((1, 2))):
        out = Vector((rng.uniform(-1, 1), rng.uniform(-1, 1), rng.uniform(0.3, 1.0)))
        branch(b, rng, end, direction * 0.4 + out.normalized(), length * 0.65, radius * 0.6, depth + 1)


def build_frame():
    rng = random.Random(SEED)
    b = voxel_kit.Builder(COLORS)
    # The trunk: leaning, thick at the foot, with a flared base of three root stubs
    trunk = [Vector((0, 0, -0.3)), Vector((0.3, 0.1, 2.2)), Vector((0.6, -0.1, 4.2))]
    portal_kit.tube(b, trunk, [1.1, 0.9, 0.75], "char", sides=7)
    for angle in (20, 140, 260):
        a = math.radians(angle)
        portal_kit.tube(b, [Vector((0, 0, 0.8)), Vector((math.cos(a) * 2.0, math.sin(a) * 2.0, -0.2))], [0.7, 0.3], "char", sides=5)
    for angle in (10, 130, 250):
        a = math.radians(angle + rng.uniform(-20, 20))
        branch(b, rng, trunk[-1], Vector((math.cos(a) * 1.1, math.sin(a) * 1.1, 1)), 4.2, 0.6, 0)
    return b.to_object("Frame")


def run():
    portal_kit.begin(NAME)
    return portal_kit.export(NAME, [build_frame()], COLORS)


run()
