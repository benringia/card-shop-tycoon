"""Builds the caldera's volcano (caldera spec 2026-10-31, concept A: quiet): a big chunky low-poly cone with jagged
faceted flanks and a broken crater rim, a glowing lava surface in the crater and two lava streaks down its front flank.
It stands far behind Ember Canyon's end wall and rises over the cliffs (about 120 studs tall).

Objects so the game can find and dress them (SceneryService, Config/Scenery VOLCANO):
  Body      the mountain (palette texture: dark basalt, lighter ash bands)
  Lava      the crater's lava and the streaks (the game makes them glowing lava)
  Fx_Smoke  the crater's middle, where the smoke rises (hidden marker)

Blender: Z up, 1 unit = 1 stud, origin at the bottom centre; the front (toward the canyon) faces -Y.
Run inside Blender (MCP execute: exec(open(path).read())); EXPORT=0 builds without saving. Writes assets/blender/Volcano/.
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

NAME = "Volcano"
COLORS = {
    "basalt_dark": (30, 27, 32),
    "basalt": (44, 40, 46),
    "ash": (62, 56, 60),
    "rim": (78, 52, 44),
    "lava": (255, 106, 28),
    "lava_hot": (255, 186, 60),
    "marker": (255, 0, 255),
}
SEED = 13
HEIGHT = 120.0
BASE = 90.0  # radius at the foot
TOP = 17.0  # radius at the crater rim
CRATER = 7.0  # how deep the crater dips
AROUND = 20  # facets round the cone
# A concave profile: a wide skirt, then steepening to a narrow top (a volcano, not a pile)
RINGS = [  # (height share, radius share of the foot, jitter, colour band)
    (0.0, 1.0, 0.08, "basalt_dark"),
    (0.08, 0.72, 0.10, "basalt"),
    (0.22, 0.50, 0.10, "basalt_dark"),
    (0.42, 0.36, 0.09, "basalt"),
    (0.64, 0.28, 0.07, "ash"),
    (0.84, 0.23, 0.06, "basalt"),
    (1.0, TOP / BASE, 0.05, "rim"),
]
RIDGE = 0.06  # every other facet column pushed out by this share: ridges running down the flanks


def build_body():
    rng = random.Random(SEED)
    b = voxel_kit.Builder(COLORS)
    rings = []
    for share, radius_share, jitter, _ in RINGS:
        ring = []
        for k in range(AROUND):
            a = k / AROUND * math.tau + rng.uniform(-0.08, 0.08)
            r = BASE * radius_share * (1 + rng.uniform(-jitter, jitter) + (RIDGE if k % 2 == 0 else -RIDGE / 2))
            z = HEIGHT * share + (rng.uniform(-2.5, 2.5) if 0 < share < 1 else (rng.uniform(-1.5, 1.5) if share == 1 else -2))
            ring.append(Vector((math.cos(a) * r, math.sin(a) * r, z)))
        rings.append(b._verts(ring, portal_kit.BONE))
    for index in range(len(rings) - 1):
        lower, upper = rings[index], rings[index + 1]
        color = RINGS[index + 1][3]
        for k in range(AROUND):
            k2 = (k + 1) % AROUND
            # two triangles per facet: jagged, never flat quads
            b._face([lower[k], lower[k2], upper[k2]], color)
            b._face([lower[k], upper[k2], upper[k]], color)
    # The crater: the rim falls inward to a dark floor
    floor = b._verts([Vector((math.cos(k / AROUND * math.tau) * TOP * 0.55, math.sin(k / AROUND * math.tau) * TOP * 0.55, HEIGHT - CRATER)) for k in range(AROUND)], portal_kit.BONE)
    top = rings[-1]
    for k in range(AROUND):
        k2 = (k + 1) % AROUND
        b._face([top[k], top[k2], floor[k2]], "basalt_dark")
        b._face([top[k], floor[k2], floor[k]], "basalt_dark")
    b._face(list(reversed(floor)), "basalt_dark")
    return b.to_object("Body")


def build_lava():
    b = voxel_kit.Builder(COLORS)
    portal_kit.disc(b, (0, 0, HEIGHT - CRATER + 0.6), TOP * 0.62, "lava_hot", sides=AROUND)
    # two streaks down the front (-Y) flank from the rim's lowest notch, following the slope
    def radius_at(share):
        """The profile's radius at a height share (between the RINGS), a little proud of the surface."""
        for (s0, r0, _, _), (s1, r1, _, _) in zip(RINGS, RINGS[1:]):
            if s0 <= share <= s1:
                t = (share - s0) / (s1 - s0)
                return BASE * (r0 + (r1 - r0) * t) * 1.06 + 0.8
        return BASE * RINGS[-1][1]

    for offset, length, width in ((-0.22, 0.62, 5.0), (0.14, 0.42, 4.0)):
        points = []
        for t in (0.0, 0.2, 0.4, 0.6, 0.8, 1.0):
            share = 1.0 - t * length
            a = -math.pi / 2 + offset + math.sin(t * 5.0) * 0.07
            r = radius_at(share)
            points.append(Vector((math.cos(a) * r, math.sin(a) * r, HEIGHT * share - 1.0)))
        for index, (p0, p1) in enumerate(zip(points, points[1:])):
            portal_kit.ribbon(b, p0, p1, width * (1 - index * 0.12), "lava_hot" if index == 0 else "lava", thickness=0.8)
    return b.to_object("Lava")


def run():
    portal_kit.begin(NAME)
    objects = [build_body(), build_lava(), portal_kit.marker("Fx_Smoke", (0, 0, HEIGHT - CRATER + 2), COLORS, "marker")]
    return portal_kit.export(NAME, objects, COLORS)


run()
