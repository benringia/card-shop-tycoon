"""Builds the Wild bosses' arena props (spec 2026-11-01-wild-bosses-arenas-design, Config/WildValley ARENA_DRESSING):
StandingStone, Stalagmite, Web, Cocoon, Bones, CaveDome and LavaCliff, in the caldera props' smooth stylized look
(build_charred_tree.py, build_obsidian_shards.py) on voxel_kit and portal_kit.

Each prop is its own .blend and FBX in assets/blender/<Name>/ (portal_kit.export): Frame (palette texture) and, for the
lava cliff, Lava (cracks the game turns into glowing lava). Blender: Z up, 1 unit = 1 stud, origin at the bottom centre;
the game scales each prop by its height, so only proportions matter. Run inside Blender (MCP execute:
exec(open(path).read())); PROPS="A,B" builds only those, EXPORT=0 builds without saving.
"""
import math
import os
import random
import sys

import bmesh
from mathutils import Matrix, Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)) if "__file__" in globals() else
                os.path.join(os.environ.get("CARD_SHOP_REPO", r"C:\Users\Ben\Documents\roblox-project\card-shop-tycoon"), "tools", "blender"))
import voxel_kit  # noqa: E402
import portal_kit  # noqa: E402

BONE = portal_kit.BONE


def standing_stone():
    """A tall rough menhir leaning a little, a mossy cap with drips and three faint carved rune lines."""
    colors = {"stone": (128, 126, 118), "stone_dark": (96, 94, 90), "moss": (88, 138, 60), "rune": (150, 205, 185)}
    b = voxel_kit.Builder(colors)
    # One tall faceted lump leaning a little (a raw standing stone, not a cut slab), its foot sunk in a rubble mound
    lean = Matrix.Rotation(math.radians(7), 3, "Y") @ Matrix.Rotation(math.radians(-4), 3, "X")
    b.blob((0, 0, 0.25), (1.2, 0.95, 0.45), "stone_dark", BONE, segments=7, rings=3)
    b.blob((0.12, 0, 2.0), (0.88, 0.62, 2.1), "stone", BONE, rot=lean, segments=6, rings=6)
    b.blob((0.36, 0, 3.85), (0.55, 0.45, 0.3), "moss", BONE, rot=lean, segments=7, rings=4)
    for x in (0.12, 0.38, 0.6):
        portal_kit.tube(b, [Vector((x, -0.28, 3.85)), Vector((x - 0.02, -0.48, 3.25))], [0.11, 0.04], "moss", sides=4)
    for z in (1.4, 2.0, 2.6):
        portal_kit.ribbon(b, Vector((-0.2, -0.6, z)), Vector((0.42, -0.58, z + 0.12)), 0.07, "rune", thickness=0.05)
    return colors, [b.to_object("Frame")]


def stalagmite():
    """A crooked cave spike tapering to a point, a smaller one leaning off its foot, drips down its side."""
    colors = {"rock": (96, 88, 108), "rock_light": (130, 122, 142)}
    b = voxel_kit.Builder(colors)
    spine = [Vector((0, 0, -0.2)), Vector((0.1, 0.05, 1.4)), Vector((0.05, -0.05, 2.8)), Vector((0.2, 0, 4.2))]
    portal_kit.tube(b, spine, [0.9, 0.6, 0.32, 0.03], "rock", sides=7)
    portal_kit.tube(b, [Vector((0.6, 0.3, -0.1)), Vector((0.95, 0.5, 1.2)), Vector((1.2, 0.6, 2.0))], [0.45, 0.22, 0.02], "rock_light", sides=6)
    b.blob((0, 0, 0.0), (1.0, 0.9, 0.18), "rock", BONE, segments=8, rings=3)
    return colors, [b.to_object("Frame")]


def web():
    """An upright round web: eight spokes and four rings of thin strands, slightly saggy."""
    colors = {"silk": (222, 222, 228)}
    b = voxel_kit.Builder(colors)
    centre = Vector((0, 0, 1.2))
    spokes = 8
    for i in range(spokes):
        a = i / spokes * math.tau
        tip = centre + Vector((math.cos(a) * 1.15, 0, math.sin(a) * 1.15))
        portal_kit.ribbon(b, centre, tip, 0.035, "silk", thickness=0.02)
    for ring in (0.3, 0.55, 0.8, 1.05):
        for i in range(spokes):
            a0, a1 = i / spokes * math.tau, (i + 1) / spokes * math.tau
            sag = 0.06 * ring
            p0 = centre + Vector((math.cos(a0) * ring, 0, math.sin(a0) * ring))
            p1 = centre + Vector((math.cos(a1) * ring, 0, math.sin(a1) * ring))
            mid = (p0 + p1) / 2 * 0.97 + centre * 0.03 - Vector((0, 0, sag))
            portal_kit.ribbon(b, p0, mid, 0.03, "silk", thickness=0.02)
            portal_kit.ribbon(b, mid, p1, 0.03, "silk", thickness=0.02)
    return colors, [b.to_object("Frame")]


def cocoon():
    """A wrapped shape hanging from a strand: a lumpy pod with silk bands round it."""
    colors = {"silk": (214, 210, 200), "silk_dark": (168, 160, 150)}
    b = voxel_kit.Builder(colors)
    b.blob((0, 0, 1.0), (0.42, 0.4, 0.85), "silk", BONE, segments=10, rings=7)
    b.blob((0.1, 0.05, 0.55), (0.3, 0.3, 0.32), "silk_dark", BONE, segments=8, rings=5)
    for z, tilt in ((0.6, 0.1), (1.0, -0.12), (1.4, 0.08)):
        ring = [Vector((math.cos(a) * 0.44, math.sin(a) * 0.42, z + math.sin(a) * tilt)) for a in (i / 8 * math.tau for i in range(9))]
        portal_kit.tube(b, ring, [0.05] * len(ring), "silk_dark", sides=4)
    portal_kit.tube(b, [Vector((0, 0, 1.8)), Vector((0, 0, 3.4))], [0.035, 0.025], "silk", sides=4)
    return colors, [b.to_object("Frame")]


def bones():
    """A half-sunk ribcage on its spine, a horned skull at its end and a few loose bones."""
    colors = {"bone": (226, 214, 188), "bone_dark": (176, 162, 138), "socket": (48, 40, 36)}
    rng = random.Random(4)
    b = voxel_kit.Builder(colors)
    portal_kit.tube(b, [Vector((-1.6, 0, 0.15)), Vector((0, 0, 0.3)), Vector((1.5, 0, 0.2))], [0.14, 0.16, 0.12], "bone_dark", sides=6)
    for i in range(6):
        x = -1.3 + i * 0.5
        height = 1.1 - abs(i - 2.5) * 0.12
        for side in (-1, 1):
            # each rib arches up off the spine and curls down and out, like a cage half sunk in the ground
            arc = [Vector((x, side * 0.1, 0.35)), Vector((x + 0.03, side * 0.35, 0.35 + height * 0.8)),
                   Vector((x + 0.06, side * 0.7, 0.35 + height * 0.7)), Vector((x + 0.1, side * 0.9, height * 0.2))]
            portal_kit.tube(b, arc, [0.08, 0.075, 0.065, 0.05], "bone", sides=5)
    b.blob((2.0, 0, 0.45), (0.5, 0.42, 0.4), "bone", BONE, segments=10, rings=6)
    b.blob((2.4, 0, 0.32), (0.32, 0.26, 0.2), "bone", BONE, segments=8, rings=5)
    for side in (-1, 1):
        b.blob((2.25, side * 0.2, 0.55), (0.1, 0.08, 0.1), "socket", BONE, segments=6, rings=4)
        portal_kit.tube(b, [Vector((1.9, side * 0.32, 0.75)), Vector((1.75, side * 0.6, 1.15)), Vector((1.95, side * 0.7, 1.45))], [0.09, 0.06, 0.02], "bone_dark", sides=5)
    for _ in range(3):
        a = rng.uniform(0, math.tau)
        start = Vector((rng.uniform(-1.5, 1.5), rng.uniform(-1.4, 1.4), 0.08))
        end = start + Vector((math.cos(a) * 0.7, math.sin(a) * 0.7, 0))
        portal_kit.tube(b, [start, end], [0.06, 0.06], "bone", sides=5)
        b.blob(start, (0.1, 0.1, 0.08), "bone", BONE, segments=6, rings=4)
        b.blob(end, (0.1, 0.1, 0.08), "bone", BONE, segments=6, rings=4)
    return colors, [b.to_object("Frame")]


def cave_dome():
    """One closed rock shell over the Broodmother's hollow: a rough dome about 132 wide and 46 high, faces turned inward,
    its rim below the floor, stalactites hanging from the roof."""
    colors = {"rock": (64, 58, 76), "rock_dark": (44, 40, 54), "drip": (88, 82, 104)}
    rng = random.Random(11)
    b = voxel_kit.Builder(colors)
    b.blob((0, 0, -4), (66, 66, 50), "rock", BONE, segments=28, rings=16)
    for vert in list(b.bm.verts):
        if vert.co.z < -6:
            b.bm.verts.remove(vert)
    for vert in b.bm.verts:
        push = 1 + rng.uniform(-0.1, 0.06)
        vert.co.x *= push
        vert.co.y *= push
        vert.co.z = max(vert.co.z * (1 + rng.uniform(-0.08, 0.05)), -6)
    bmesh.ops.reverse_faces(b.bm, faces=list(b.bm.faces))
    for _ in range(24):
        a = rng.uniform(0, math.tau)
        out = rng.uniform(8, 50)
        top = Vector((math.cos(a) * out, math.sin(a) * out, 0))
        top.z = 46 * math.sqrt(max(0.0, 1 - (out / 66) ** 2)) - 4 + 1
        length = rng.uniform(4, 9)
        portal_kit.tube(b, [top, top - Vector((0, 0, length * 0.6)), top - Vector((0, 0, length))], [rng.uniform(1.0, 1.6), 0.5, 0.05], "drip", sides=6)
    return colors, [b.to_object("Frame")]


def lava_cliff():
    """A basalt cliff piece about 16 wide: a row of tall columns of varied heights on a rocky foot, glowing lava cracks
    down its face (the Lava object)."""
    colors = {"basalt": (42, 37, 44), "basalt_light": (58, 52, 60), "basalt_dark": (30, 27, 32), "lava": (255, 106, 28)}
    rng = random.Random(6)
    frame = voxel_kit.Builder(colors)
    lava = voxel_kit.Builder(colors)
    # a solid rock back (no see-through gaps), a rubble foot, and tight basalt columns in front of it
    frame.round_box((0, 0.3, 1.5), (2.0, 0.55, 3.0), "basalt_dark", BONE, bevel=0.4)
    frame.round_box((0, -0.1, 0.25), (2.1, 0.9, 0.5), "basalt_dark", BONE, bevel=0.5)
    columns = 8
    for i in range(columns):
        x = -0.84 + i * (1.68 / (columns - 1))
        height = rng.uniform(2.5, 3.5)
        shade = ("basalt", "basalt_light", "basalt_dark")[i % 3]
        portal_kit.tube(frame, [Vector((x, rng.uniform(-0.05, 0.05), 0)), Vector((x, 0, height))], [0.14, 0.13], shade, sides=6)
    for x in (-0.55, 0.05, 0.5):
        top = rng.uniform(1.8, 2.8)
        bend = x + rng.uniform(-0.08, 0.08)
        portal_kit.ribbon(lava, Vector((x, -0.15, top)), Vector((bend, -0.15, top * 0.5)), 0.05, "lava", thickness=0.04)
        portal_kit.ribbon(lava, Vector((bend, -0.15, top * 0.5)), Vector((x + rng.uniform(-0.1, 0.1), -0.15, 0.5)), 0.045, "lava", thickness=0.04)
    return colors, [frame.to_object("Frame"), lava.to_object("Lava")]


PROPS = {
    "StandingStone": standing_stone,
    "Stalagmite": stalagmite,
    "Web": web,
    "Cocoon": cocoon,
    "Bones": bones,
    "CaveDome": cave_dome,
    "LavaCliff": lava_cliff,
}


def run():
    wanted = [name for name in os.environ.get("PROPS", ",".join(PROPS)).split(",") if name]
    for name in wanted:
        portal_kit.begin(name)
        colors, objects = PROPS[name]()
        portal_kit.export(name, objects, colors)


run()
