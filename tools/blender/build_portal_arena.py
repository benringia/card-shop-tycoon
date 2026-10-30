"""Builds the Ember Canyon portal to the PvP Arena (spec 2026-10-30-town-portals-design, the user's pick A: grown from
its world): black-purple obsidian shards leaning into an irregular pointed arch, jagged spikes jutting out of it, lava
glowing in cracks down their faces and running in two streams down the right side into a molten pool at its foot.
Not a rectangular black frame (it must not read as a famous game's portal): an uneven pointed arch of shards.

Separate objects so the game can find and dress them (Server/Util/PortalBuild, Config/Town PORTAL_LOOKS.Arena):
  Frame              the obsidian (palette texture)
  Lava               the cracks, the streams' beds and the pools (the game makes them glowing lava)
  Opening            a flat disc filling the arch (hidden; the game's vortex fills it)
  Fx_DripA/Fx_DripB  where the two lava streams start; Fx_Pool  the pool's middle (hidden markers)

Blender: Z up, 1 unit = 1 stud, origin at the bottom centre, the front faces -Y. About 28 studs tall, the opening
16 wide. Run inside Blender (MCP execute: exec(open(path).read())). Writes assets/blender/PortalArena/.
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

NAME = "PortalArena"
BONE = portal_kit.BONE
COLORS = {
    "obsidian_dark": (18, 13, 24),
    "obsidian": (30, 22, 40),
    "obsidian_light": (50, 38, 64),  # dark: the town's bright sun turned the first, lighter purples bright purple
    "lava": (255, 106, 28),
    "lava_hot": (255, 186, 60),
    "marker": (255, 0, 255),
}
SEED = 11
APEX = Vector((0.6, 0, 25.5))  # a little off centre: an uneven arch, not a neat frame
FOOT_X = 10.5
OPENING = {"z": 11.0, "width": 16.0, "height": 18.0}
POOL = Vector((10.8, -4.2, 0.08))
POOL_RADIUS = (3.4, 2.4)
# The right leg's front shard (the first leg shard below): the two lava streams run down its front face
FRONT_LEG = {"base": Vector((FOOT_X, -1.3, -0.5)), "top": Vector((FOOT_X - 1.4, -1.04, 16.0)), "radius": 2.7}


def on_front_leg(t, across):
    """A point on the right leg's front shard's front face, t up its length, across studs outward (+X)."""
    leg = FRONT_LEG
    return leg["base"].lerp(leg["top"], t) + Vector((across, -leg["radius"] * 0.9, 0))


DRIP_A = on_front_leg(0.82, -0.5)
DRIP_B = on_front_leg(0.58, 0.8)


def arch_line(side, t):
    """The arch's centre line, t 0 at the foot to 1 at the apex: up the leg, then leaning in to the point."""
    foot = Vector((side * FOOT_X, 0, 0))
    knee = Vector((side * (FOOT_X - 0.8), 0, 11.0))
    if t < 0.45:
        return foot.lerp(knee, t / 0.45)
    return knee.lerp(APEX, (t - 0.45) / 0.55)


def shard(b, lava, base, target, radius, color, overshoot=0.0, crack=True):
    """An obsidian shard from base past target, a lava crack down its front face."""
    direction = target - base
    length = direction.length + overshoot
    portal_kit.crystal(b, base, direction, radius, length, color, sides=5, tip=0.25)
    if crack:
        along = direction.normalized()
        front = Vector((0, -radius * 0.86, 0))
        portal_kit.ribbon(lava, base + along * length * 0.12 + front, base + along * length * 0.55 + front, 0.3, "lava")


def build_frame_and_lava():
    rng = random.Random(SEED)
    b = voxel_kit.Builder(COLORS)
    lava = voxel_kit.Builder(COLORS)
    shards = ("obsidian_dark", "obsidian", "obsidian_light")
    for side in (-1, 1):
        # The legs: big shards rising from the ground, a little splayed
        for depth, x, height, radius, color in ((-1.3, 0.0, 16.0, 2.7, "obsidian"), (1.3, 0.6, 14.0, 2.5, "obsidian_dark"),
                                                (0.1, 1.6, 11.0, 2.2, "obsidian_light"), (-0.6, -1.0, 12.5, 2.0, "obsidian_dark")):
            base = Vector((side * (FOOT_X + x), depth, -0.5))
            target = Vector((side * (FOOT_X + x - 1.4), depth * 0.8, height))
            shard(b, lava, base, target, radius, color, crack=depth < 0.5)
        # The crown: shards from high on the leg leaning in past the apex, crossing the other side's
        for depth, z, radius, overshoot, color in ((-0.9, 10.5, 2.1, 3.0, "obsidian"), (0.9, 12.5, 1.9, 2.0, "obsidian_light"),
                                                   (0.0, 14.5, 1.7, 3.5, "obsidian_dark")):
            base = Vector((side * (FOOT_X - 1.0), depth, z))
            target = APEX + Vector((-side * 1.5, depth * 0.6, 0.5))
            shard(b, lava, base, target, radius, color, overshoot=overshoot, crack=depth < 0)
        # Jagged spikes jutting out of the arch's outer edge
        for step in range(6):
            t = 0.12 + step * 0.15 + rng.uniform(-0.04, 0.04)
            here = arch_line(side, t)
            along = (arch_line(side, min(1.0, t + 0.05)) - here).normalized()
            out = Vector((side * abs(along.z), 0, abs(along.x))).normalized()
            direction = (out + Vector((0, rng.uniform(-0.4, 0.4), 0.3))).normalized()
            portal_kit.crystal(b, here + out * 1.8 + Vector((0, rng.uniform(-1.2, 1.2), 0)), direction,
                               rng.uniform(0.9, 1.4), rng.uniform(3.5, 6.5), shards[step % 3], sides=5, tip=0.45)
        # Shards round the feet, half sunk
        for step in range(5):
            angle = rng.uniform(0, math.tau)
            base = Vector((side * (FOOT_X + rng.uniform(-1.0, 4.0)), rng.uniform(-3.5, 3.0), -0.6))
            direction = Vector((math.cos(angle) * 0.6, math.sin(angle) * 0.6, 1)).normalized()
            portal_kit.crystal(b, base, direction, rng.uniform(0.8, 1.5), rng.uniform(2.5, 5.0), shards[step % 3], sides=5, tip=0.4)
    # Two lava streams down the right leg's front into the pool, and a little puddle at the left foot
    for top, across in ((DRIP_A, -0.5), (DRIP_B, 0.8)):
        low = on_front_leg(0.05, across)
        portal_kit.ribbon(lava, top, low, 0.85, "lava_hot")
        portal_kit.ribbon(lava, low, POOL + Vector((across * 0.5, 0.8, 0.1)), 0.85, "lava")
    portal_kit.disc(lava, POOL + Vector((0, 0, 0.06)), POOL_RADIUS[0], "lava_hot", sides=12, radius_y=POOL_RADIUS[1])
    portal_kit.disc(lava, Vector((-11.2, -3.6, 0.14)), 1.8, "lava", sides=10, radius_y=1.3)
    return b.to_object("Frame"), lava.to_object("Lava")


def build_opening():
    b = voxel_kit.Builder(COLORS)
    portal_kit.disc(b, (0, 0, OPENING["z"]), OPENING["width"] / 2, "lava", normal=(0, -1, 0), sides=12,
                    radius_y=OPENING["height"] / 2)
    return b.to_object("Opening")


def run():
    portal_kit.begin(NAME)
    frame, lava = build_frame_and_lava()
    objects = [
        frame,
        lava,
        build_opening(),
        # just in front of the lava ribbons, so the dripping beams show over them
        portal_kit.marker("Fx_DripA", DRIP_A + Vector((0, -0.6, 0)), COLORS, "marker"),
        portal_kit.marker("Fx_DripB", DRIP_B + Vector((0, -0.6, 0)), COLORS, "marker"),
        portal_kit.marker("Fx_Pool", POOL + Vector((0, -0.6, 0.3)), COLORS, "marker"),
    ]
    return portal_kit.export(NAME, objects, COLORS)


run()
