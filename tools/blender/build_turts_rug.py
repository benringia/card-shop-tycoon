"""Builds Turts' rug and things (spec 2026-11-13-turts-shop-design; owner: "his rug should have stuff on them too not
just him"): a round woven rug with a medallion and tassels, his cushion with gold tassels, two wooden crates behind
him, a lantern on a post on the left crate with a stack of booster packs beside it, a chalkboard sign on the right
crate and a little pile of coins by the cushion.

Three objects: Frame (palette texture), Glow (the lantern's glass: the game makes it glow and puts a light in it) and
Sign (the board: the game writes TURTS on its front). Blender: Z up, 1 unit = 1 stud, origin where Turts sits, his
customers toward -Y (it imports facing -Z, the props' front). The offers' stands are drawn by the game in front of him.
Run in a background Blender:

  blender -b --factory-startup --python tools/blender/build_turts_rug.py

EXPORT=0 builds without saving; writes assets/blender/TurtsRug/TurtsRug.{blend,fbx}. Import the FBX in Studio (default
settings) and save it as assets/props/TurtsRug.rbxm (docs/props.md).
"""
import math
import os
import sys

from mathutils import Euler, Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)) if "__file__" in globals() else
                os.path.join(os.environ.get("CARD_SHOP_REPO", r"C:\Users\Ben\Documents\roblox-project\card-shop-tycoon"), "tools", "blender"))
import voxel_kit  # noqa: E402
import portal_kit  # noqa: E402

NAME = "TurtsRug"
BONE = portal_kit.BONE
COLORS = {
    "rug_red": (196, 64, 52),
    "rug_cream": (244, 226, 190),
    "rug_orange": (236, 150, 58),
    "rug_gold": (250, 200, 80),
    "rug_teal": (40, 128, 132),
    "cushion": (128, 88, 182),
    "tassel": (250, 204, 96),
    "wood": (156, 104, 62),
    "wood_dark": (104, 66, 38),
    "metal": (52, 50, 58),
    "glass": (255, 214, 140),
    "slate": (44, 52, 56),
    "pack_pink": (255, 110, 170),
    "pack_blue": (80, 170, 255),
    "pack_gold": (255, 196, 60),
    "coin": (255, 206, 72),
}
RUG_Y = -1.6  # the rug's middle, in front of him


def turn(x, y, z):
    """A rotation (radians about X, Y, Z) as voxel_kit's 3x3 matrix"""
    return Euler((x, y, z)).to_matrix()
CRATE_X, CRATE_Y = 2.9, 0.6


def rug(b):
    """Stacked woven rings, each a hair higher so they never flicker, and tassels round the edge"""
    rings = [(4.0, "rug_red"), (3.65, "rug_cream"), (3.35, "rug_teal"), (3.0, "rug_orange"), (2.0, "rug_red"),
             (1.5, "rug_cream"), (0.9, "rug_gold")]
    for index, (radius, color) in enumerate(rings):
        portal_kit.disc(b, (0, RUG_Y, 0.02 + index * 0.012), radius, color, sides=28)
    # a ring of diamonds on the orange band
    for k in range(12):
        a = 2 * math.pi * k / 12
        centre = Vector((math.cos(a) * 2.5, RUG_Y + math.sin(a) * 2.5, 0.12))
        portal_kit.disc(b, centre, 0.28, "rug_gold", sides=4)
    for k in range(20):
        a = 2 * math.pi * (k + 0.5) / 20
        b.box((math.cos(a) * 4.12, RUG_Y + math.sin(a) * 4.12, 0.03), (0.16, 0.16, 0.06), "rug_cream", BONE,
              rot=turn(0, 0, a))


def cushion(b):
    b.blob((0, 0.2, 0.2), (1.35, 1.25, 0.2), "cushion", BONE, segments=12, rings=6)
    for x in (-1.15, 1.15):
        for y in (-0.85, 1.25):
            b.blob((x, y, 0.16), (0.14, 0.14, 0.14), "tassel", BONE, segments=6, rings=4)


def crate(b, x):
    """A wooden crate with darker plank seams and corner posts"""
    size = 1.4
    centre = (x, CRATE_Y, size / 2)
    b.box(centre, (size, size, size), "wood", BONE, rot=turn(0, 0, math.radians(8 if x > 0 else -8)))
    for z in (0.35, 0.7, 1.05):
        b.box((x, CRATE_Y - size / 2 - 0.01, z), (size * 0.98, 0.04, 0.05), "wood_dark", BONE)
    for dx in (-size / 2, size / 2):
        b.box((x + dx, CRATE_Y - size / 2, size / 2), (0.12, 0.08, size), "wood_dark", BONE)


def lantern_post(b):
    """A metal post on the left crate with a little roof; the glass is its own object (Glow)"""
    x, top = -CRATE_X, 1.4
    b.box((x, CRATE_Y, top + 0.5), (0.1, 0.1, 1.0), "metal", BONE)
    b.box((x, CRATE_Y, top + 1.0), (0.6, 0.6, 0.06), "metal", BONE)
    b.box((x, CRATE_Y, top + 1.75), (0.66, 0.66, 0.08), "metal", BONE)
    b.box((x, CRATE_Y, top + 1.88), (0.4, 0.4, 0.16), "metal", BONE)
    for dx, dy in ((-0.27, -0.27), (0.27, -0.27), (-0.27, 0.27), (0.27, 0.27)):
        b.box((x + dx, CRATE_Y + dy, top + 1.38), (0.05, 0.05, 0.72), "metal", BONE)


def glass():
    g = voxel_kit.Builder(COLORS)
    g.box((-CRATE_X, CRATE_Y, 1.4 + 1.38), (0.48, 0.48, 0.66), "glass", BONE)
    return g.to_object("Glow")


def packs(b):
    """A little stack of booster packs leaning on the left crate's top, beside the lantern"""
    x, top = -CRATE_X + 0.42, 1.4
    for index, color in enumerate(("pack_pink", "pack_blue", "pack_gold")):
        b.box((x, CRATE_Y - 0.25 + index * 0.02, top + 0.05 + index * 0.09), (0.42, 0.6, 0.08), color, BONE,
              rot=turn(0, 0, math.radians(-10 + index * 12)))


def sign_frame(b):
    """The sign's wooden frame and its two legs, standing on the right crate"""
    x, top = CRATE_X, 1.4
    tilt = math.radians(-12)
    for dx in (-1.0, 1.0):
        b.box((x + dx, CRATE_Y + 0.1, top + 0.55), (0.1, 0.1, 1.1), "wood_dark", BONE, rot=turn(tilt, 0, 0))
    b.box((x, CRATE_Y - 0.02, top + 1.15), (2.3, 0.08, 0.1), "wood_dark", BONE, rot=turn(tilt, 0, 0))
    b.box((x, CRATE_Y + 0.12, top + 0.05), (2.3, 0.08, 0.1), "wood_dark", BONE, rot=turn(tilt, 0, 0))


def sign():
    s = voxel_kit.Builder(COLORS)
    s.box((CRATE_X, CRATE_Y + 0.05, 1.4 + 0.6), (2.1, 0.06, 1.05), "slate", BONE, rot=turn(math.radians(-12), 0, 0))
    return s.to_object("Sign")


def coins(b):
    """A small pile of gold coins by the cushion, his takings"""
    for index, (x, y) in enumerate(((1.6, -0.5), (1.75, -0.35), (1.5, -0.3), (1.65, -0.48))):
        for layer in range(3 - index % 2):
            portal_kit.disc(b, (x, y, 0.13 + layer * 0.05), 0.16, "coin", sides=10)


def run():
    portal_kit.begin(NAME)
    b = voxel_kit.Builder(COLORS)
    rug(b)
    cushion(b)
    crate(b, -CRATE_X)
    crate(b, CRATE_X)
    lantern_post(b)
    packs(b)
    sign_frame(b)
    coins(b)
    return portal_kit.export(NAME, [b.to_object("Frame"), glass(), sign()], COLORS)


run()
