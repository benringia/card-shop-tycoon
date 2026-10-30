"""Builds the Frostpeak portal to the Frontier (spec 2026-10-30-town-portals-design, the user's pick A: grown from its
world): a ring of jagged ice crystals growing out of a snowdrift, icicles hanging inside its top, snow caps on the
upper crystals. Blues from deep to bright, never near-white (pale colours wash out in the town's sun); the snow is a
pale blue-grey for the same reason.

Separate objects so the game can find and dress them (Server/Util/PortalBuild, Config/Town PORTAL_LOOKS.Frontier):
  Frame    the crystals, icicles, snow caps and drift (palette texture)
  Opening  a flat disc filling the ring (hidden; the game's vortex fills it)
  Fx_Base  the drift's front middle, where the frosty mist rises (hidden marker)

Blender: Z up, 1 unit = 1 stud, origin at the bottom centre, the front faces -Y. About 28 studs tall, the opening
16 across. Run inside Blender (MCP execute: exec(open(path).read())). Writes assets/blender/PortalFrontier/.
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

NAME = "PortalFrontier"
BONE = portal_kit.BONE
COLORS = {
    "ice_deep": (28, 104, 196),
    "ice": (56, 152, 238),
    "ice_bright": (112, 198, 255),
    "ice_tip": (164, 222, 255),
    "snow": (190, 210, 232),
    "snow_shade": (150, 176, 208),
    "marker": (255, 0, 255),
}
RING = {"z": 12.5, "radius": 9.6}  # the crystals' bases sit round this circle (in the XZ plane)
OPENING = {"z": 12.5, "radius": 8.0}
SEED = 7
ICE = ["ice_deep", "ice", "ice_bright"]


def ring_point(angle_deg, out=0.0, depth=0.0):
    a = math.radians(angle_deg)
    r = RING["radius"] + out
    return Vector((r * math.cos(a), depth, RING["z"] + r * math.sin(a)))


def outward(angle_deg, lift=0.0, lean=0.0):
    """Pointing away from the ring's middle, tipped up by lift and toward the back (+Y) or front by lean."""
    a = math.radians(angle_deg)
    return Vector((math.cos(a), lean, math.sin(a) + lift)).normalized()


def build_frame():
    rng = random.Random(SEED)
    b = voxel_kit.Builder(COLORS)
    caps = []
    # The ring: crystals round the circle from the drift on one side, over the top, to the drift on the other
    for step in range(22):
        angle = -28 + step * (236 / 21) + rng.uniform(-4, 4)
        depth = rng.uniform(-1.6, 1.6)
        length = rng.uniform(4.0, 7.5) * (1.25 if 60 < angle < 120 else 1.0)
        radius = rng.uniform(1.1, 1.9)
        direction = outward(angle, lift=rng.uniform(-0.1, 0.35), lean=rng.uniform(-0.35, 0.35))
        base = ring_point(angle, out=-0.6, depth=depth)
        portal_kit.crystal(b, base, direction, radius, length, ICE[step % 3], sides=6, tip=0.35, tip_color="ice_tip")
        if 25 < angle < 155:
            caps.append((base + direction * length * 0.45 + Vector((0, 0, radius * 0.8)), radius))
    # The inner edge: shorter crystals pointing into the ring's middle, so the opening looks frozen round
    for step in range(10):
        angle = -10 + step * (200 / 9)
        base = ring_point(angle, out=-1.2, depth=rng.uniform(-1.0, 1.0))
        inward = -outward(angle, lean=rng.uniform(-0.3, 0.3))
        portal_kit.crystal(b, base, inward, rng.uniform(0.6, 0.9), rng.uniform(1.4, 2.4), "ice_bright", sides=5, tip=0.5)
    # Icicles hanging inside the top
    for x in (-5.0, -3.2, -1.4, 0.4, 2.2, 4.0, 5.6):
        top = Vector((x, rng.uniform(-0.8, 0.8), RING["z"] + math.sqrt(max(0.0, (RING["radius"] - 1.6) ** 2 - x * x))))
        portal_kit.crystal(b, top, (0, 0, -1), rng.uniform(0.3, 0.5), rng.uniform(1.6, 3.2), "ice_tip", sides=5, tip=0.6)
    # Big crystals rising out of the drift on both sides, leaning out
    for side in (-1, 1):
        for out, lean, length, radius in ((9.5, 0.25, 13.0, 2.3), (11.8, 0.45, 9.0, 1.8), (7.6, 0.1, 7.5, 1.5)):
            base = Vector((side * out, rng.uniform(-1.2, 1.2), 0.5))
            direction = Vector((side * lean, rng.uniform(-0.2, 0.2), 1)).normalized()
            portal_kit.crystal(b, base, direction, radius, length, "ice_deep" if out > 10 else "ice", sides=6, tip=0.3,
                               tip_color="ice_tip")
    # Snow caps on the upper crystals
    for centre, radius in caps:
        b.blob(centre, (radius * 1.2, radius * 1.1, radius * 0.45), "snow", BONE, segments=7, rings=4)
    # The drift the ring grows out of
    for centre, radii, color in (((0, 0, 0.6), (13.5, 5.5, 2.8), "snow"), ((-9.0, -1.0, 1.4), (5.0, 4.5, 2.6), "snow"),
                                 ((9.0, 0.8, 1.4), (5.0, 4.5, 2.6), "snow"), ((0, -3.2, 0.5), (8.0, 3.0, 1.4), "snow_shade"),
                                 ((-13.5, 1.5, 0.4), (3.5, 3.0, 1.2), "snow_shade"), ((13.5, -1.0, 0.4), (3.5, 3.0, 1.2), "snow_shade")):
        b.blob(centre, radii, color, BONE, segments=12, rings=6)
    return b.to_object("Frame")


def build_opening():
    b = voxel_kit.Builder(COLORS)
    portal_kit.disc(b, (0, 0, OPENING["z"]), OPENING["radius"], "ice", normal=(0, -1, 0), sides=12)
    return b.to_object("Opening")


def run():
    portal_kit.begin(NAME)
    objects = [
        build_frame(),
        build_opening(),
        portal_kit.marker("Fx_Base", (0, -4.5, 1.2), COLORS, "marker"),
    ]
    return portal_kit.export(NAME, objects, COLORS)


run()
