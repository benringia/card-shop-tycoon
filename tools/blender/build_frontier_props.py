"""Builds the Frontier valley's scenery props (spec docs/superpowers/specs/2026-11-10-frontier-valley-design.md, the
owner's pick C "Titans' Graveyard"): the camp, Frostwood's forts, ribcage and giant swords, Stormpeak's wrecked towers,
horned skull and storm stones, the Rift's floating rocks and the Dungeon gate's crystal arch, the dead giant's skull,
and the Frost Tyrant's throne hall pieces. Same smooth stylized look as build_valley_props.py (voxel_kit, portal_kit).

All props go into ONE pack so the owner imports once: each prop is an Empty named <Name> holding its meshes
<Name>__Frame (palette texture) and, for glowing ones, <Name>__Glow (palette white; the game turns it Neon in the
spot's colour). The props stand apart along X in assets/blender/FrontierProps/FrontierProps.{blend,fbx}. Import the FBX
in Studio with default settings, save the imported model as assets/props-import/FrontierProps.rbxm, then
`lune run tools/props/split_pack assets/props-import/FrontierProps.rbxm` writes assets/props/<Name>.rbxm per prop (parts
renamed Frame / Glow, pivot at the bottom centre). Blender: Z up, 1 unit = 1 stud, each prop's origin at its bottom
centre, its front facing -Y. Run in a background Blender (it clears the scene):
  blender -b --factory-startup --python tools/blender/build_frontier_props.py
PROPS="A,B" builds only those, EXPORT=0 builds without saving. Each prop stays under 2000 triangles (landmarks 4000).
"""
import math
import os
import random
import sys

import bpy
from mathutils import Matrix, Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)) if "__file__" in globals() else
                os.path.join(os.environ.get("CARD_SHOP_REPO", r"C:\Users\Ben\Documents\roblox-project\card-shop-tycoon"), "tools", "blender"))
import voxel_kit  # noqa: E402
import portal_kit  # noqa: E402

BONE = portal_kit.BONE
PROP_CAP = 2000
LANDMARK_CAP = 4000
GLOW = (255, 255, 255)  # the game recolours it
PACK = "FrontierProps"
SPACING = 40  # studs between props in the pack file

SNOW = (232, 238, 246)
STONE = (128, 130, 140)
STONE_DARK = (92, 94, 104)
BONE_C = (226, 214, 190)
BONE_DARK = (176, 162, 138)
WOOD = (122, 86, 56)
WOOD_DARK = (84, 58, 38)
RED = (178, 40, 44)
STEEL = (96, 104, 118)
RUST = (120, 76, 52)


def tilt(degrees, axis="Y"):
    return Matrix.Rotation(math.radians(degrees), 3, axis)


def snow_cap(b, centre, radii, color="snow"):
    """A soft snow lump on top of something."""
    b.blob(centre, radii, color, BONE, segments=8, rings=4)


# ---------------------------------------------------------------------------------------------------- the camp

def tent():
    """A canvas A-frame tent on two poles, its door flap open toward -Y, guy ropes pegged out. About 5 tall."""
    colors = {"canvas": (196, 150, 104), "canvas_dark": (150, 110, 74), "pole": WOOD_DARK, "dark": (40, 32, 28), "snow": SNOW}
    b = voxel_kit.Builder(colors)
    half, length, height = 2.6, 5.0, 3.6
    for side in (-1, 1):
        # each roof slope a thin slab from the ridge down to the ground
        a, c = Vector((0, 0, height)), Vector((side * half, 0, 0.05))
        mid = (a + c) / 2
        slope = (a - c)
        rot = Matrix.Rotation(math.atan2(slope.x, slope.z), 3, "Y")
        b.round_box(mid, (0.18, length, slope.length), "canvas" if side < 0 else "canvas_dark", BONE, rot=rot, bevel=0.2)
    b.box((0, length / 2 - 0.05, height * 0.45), (half * 1.7, 0.12, height * 0.9), "canvas_dark", BONE)  # back wall
    b.box((0, -length / 2 + 0.3, 1.05), (1.3, 0.1, 2.1), "dark", BONE)  # the open door
    for y in (-length / 2, length / 2):
        b.span((0, y, 0), (0, y, height + 0.5), 0.2, "pole", BONE)
    b.span((0, -length / 2, height), (0, length / 2, height), 0.16, "pole", BONE)
    for side in (-1, 1):
        b.span((side * half, -length / 2 - 0.4, 0), (0, -length / 2, height), 0.05, "pole", BONE)
    snow_cap(b, (0.8, 0.5, height * 0.62), (0.9, 1.6, 0.18))
    return colors, [b.to_object("Frame")]


def campfire():
    """A ring of stones round crossed logs and a glowing fire (Glow) in the middle. About 1.6 tall."""
    colors = {"stone": STONE, "log": WOOD_DARK, "ash": (70, 64, 62), "glow": GLOW}
    frame, glow = voxel_kit.Builder(colors), voxel_kit.Builder(colors)
    for i in range(8):
        a = i / 8 * math.tau
        frame.blob((math.cos(a) * 1.3, math.sin(a) * 1.3, 0.2), (0.38, 0.32, 0.26), "stone", BONE, segments=6, rings=4)
    frame.blob((0, 0, 0.05), (1.0, 1.0, 0.1), "ash", BONE, segments=8, rings=3)
    for angle in (20, 80, 140):
        a = math.radians(angle)
        frame.span((math.cos(a) * -0.9, math.sin(a) * -0.9, 0.15), (math.cos(a) * 0.9, math.sin(a) * 0.9, 0.55), 0.28, "log", BONE)
    portal_kit.crystal(glow, (0, 0, 0.3), (0, 0, 1), 0.55, 1.3, "glow", sides=6, tip=0.6)
    portal_kit.crystal(glow, (0.3, 0.15, 0.25), (0.25, 0.1, 1), 0.3, 0.9, "glow", sides=5, tip=0.6)
    portal_kit.crystal(glow, (-0.3, -0.1, 0.25), (-0.2, -0.15, 1), 0.3, 0.8, "glow", sides=5, tip=0.6)
    return colors, [frame.to_object("Frame"), glow.to_object("Glow")]


def watchtower():
    """The camp's wooden watchtower: four braced legs, a railed platform with a pointed roof, a ladder, a red pennant.
    About 16 tall."""
    colors = {"wood": WOOD, "dark": WOOD_DARK, "roof": (96, 70, 60), "red": RED, "snow": SNOW}
    b = voxel_kit.Builder(colors)
    deck = 9.5
    for x in (-1.8, 1.8):
        for y in (-1.8, 1.8):
            b.span((x * 1.15, y * 1.15, 0), (x, y, deck + 2.6), 0.42, "dark", BONE)
    for z in (3.0, 6.5):
        for (a, c) in (((-1.9, -1.9), (1.9, -1.9)), ((1.9, -1.9), (1.9, 1.9)), ((1.9, 1.9), (-1.9, 1.9)), ((-1.9, 1.9), (-1.9, -1.9))):
            b.span((a[0], a[1], z), (c[0], c[1], z + 1.2), 0.22, "wood", BONE)
    b.round_box((0, 0, deck), (4.6, 4.6, 0.4), "wood", BONE, bevel=0.2)
    for (a, c) in (((-2.2, -2.2), (2.2, -2.2)), ((2.2, -2.2), (2.2, 2.2)), ((2.2, 2.2), (-2.2, 2.2)), ((-2.2, 2.2), (-2.2, -2.2))):
        b.span((a[0], a[1], deck + 1.1), (c[0], c[1], deck + 1.1), 0.2, "wood", BONE)
    # the roof: a square pyramid
    b.spike((0, 0, deck + 2.6), (0, 0, 1), 6.2, 2.8, "roof", BONE)
    snow_cap(b, (0, 0, deck + 3.6), (1.6, 1.6, 0.5))
    # the ladder up the front
    for x in (-0.45, 0.45):
        b.span((x, -2.6, 0), (x, -2.1, deck), 0.14, "dark", BONE)
    for k in range(6):
        z = 1.2 + k * 1.4
        b.span((-0.45, -2.6 + 0.5 * z / deck, z), (0.45, -2.6 + 0.5 * z / deck, z), 0.1, "wood", BONE)
    b.span((1.9, -1.9, deck + 2.6), (1.9, -1.9, deck + 5.6), 0.12, "dark", BONE)
    portal_kit.ribbon(b, (1.95, -1.95, deck + 5.4), (3.6, -1.95, deck + 4.8), 0.8, "red", 0.06)
    return colors, [b.to_object("Frame")]


# ------------------------------------------------------------------------------------------------------ Frostwood

def ribcage():
    """A dead giant's ribcage the trail walks through (along Y): six huge ribs arching over from the right (+X, where a
    half-buried spine runs) to the left, the front and back ones broken short, snow on top. About 16 long, 12 wide,
    10 tall; its feet stand at x -6 and +6 (Config COLLIDERS spread)."""
    colors = {"bone": BONE_C, "bone_dark": BONE_DARK, "snow": SNOW}
    b = voxel_kit.Builder(colors)
    portal_kit.tube(b, [Vector((6.2, -8.5, 0.2)), Vector((6.6, -3, 0.9)), Vector((6.5, 3, 1.0)), Vector((6.0, 8.5, 0.3))], [0.7, 0.95, 0.95, 0.6], "bone_dark", sides=8)
    for i in range(6):
        y = -6.5 + i * 2.6
        broken = i in (0, 5)
        top = 9.6 - abs(i - 2.5) * 0.6
        arc = [Vector((6.0, y, 0.8)), Vector((5.2, y, top * 0.75)), Vector((2.0, y, top)), Vector((-2.4, y, top * 0.95)), Vector((-5.4, y, top * 0.55)), Vector((-6.0, y, -0.1))]
        if broken:
            arc = arc[:4]
        portal_kit.tube(b, arc, [0.85, 0.78, 0.7, 0.62, 0.66, 0.78][:len(arc)], "bone", sides=7)
        snow_cap(b, arc[2] + Vector((0, 0, 0.35)), (1.4, 0.45, 0.2))
    for k in range(4):
        b.blob((6.4, -6 + k * 4, 1.6), (0.6, 0.5, 0.5), "bone", BONE, segments=6, rings=4)
    snow_cap(b, (6.4, 0, 0.5), (1.6, 8.0, 0.5))
    snow_cap(b, (-6.0, 0, 0.1), (1.2, 7.0, 0.35))
    return colors, [b.to_object("Frame")]


def giant_sword():
    """A titan's sword driven point-down into the snow, leaning a little: a broad notched blade, a heavy crossguard,
    a red-wrapped grip and a round pommel; a snow drift round its foot. About 12 tall."""
    colors = {"steel": STEEL, "steel_dark": (70, 76, 90), "guard": RUST, "grip": RED, "snow": SNOW}
    b = voxel_kit.Builder(colors)
    lean = tilt(8, "Y") @ tilt(-4, "X")
    def at(p):
        return lean @ Vector(p)
    b.round_box(at((0, 0, 3.6)), (1.6, 0.32, 7.4), "steel", BONE, rot=lean, bevel=0.25)
    b.round_box(at((0, 0, 3.6)), (0.3, 0.38, 7.2), "steel_dark", BONE, rot=lean, bevel=0.2)  # the fuller
    b.box(at((0.82, 0, 4.5)), (0.3, 0.36, 0.5), "steel_dark", BONE, rot=lean @ tilt(40, "Y"))  # a notch's shadow
    b.round_box(at((0, 0, 7.5)), (4.0, 0.7, 0.6), "guard", BONE, rot=lean, bevel=0.35)
    b.round_box(at((0, 0, 9.0)), (0.5, 0.5, 2.6), "grip", BONE, rot=lean, bevel=0.3)
    b.blob(at((0, 0, 10.6)), (0.6, 0.6, 0.6), "guard", BONE, segments=8, rings=5)
    snow_cap(b, (0.2, 0, 0.1), (2.2, 1.6, 0.6))
    return colors, [b.to_object("Frame")]


def fort_ruin():
    """A ruined round fort tower: a thick stone drum broken off at the top on one side, a dark doorway at the front, a
    torn red banner on a pole, snow on its broken top. About 14 tall."""
    colors = {"stone": STONE, "stone_dark": STONE_DARK, "dark": (36, 34, 40), "red": RED, "pole": WOOD_DARK, "snow": SNOW}
    b = voxel_kit.Builder(colors)
    rng = random.Random(31)
    # the drum: a solid ten-sided tower with two darker stone bands, then the upper storey standing only on its -X half
    portal_kit.tube(b, [Vector((0, 0, 0)), Vector((0, 0, 8.0))], [3.3, 3.0], "stone", sides=10)
    for z in (2.6, 5.6):
        portal_kit.tube(b, [Vector((0, 0, z)), Vector((0, 0, z + 0.5))], [3.12, 3.08], "stone_dark", sides=10)
    for k in range(10):
        a = k / 10 * math.tau
        if math.cos(a) > 0.2:
            continue  # broken off on the +X side
        height = 3.6 if math.cos(a) < -0.6 else 2.0
        c = Vector((math.cos(a) * 2.7, math.sin(a) * 2.7, 8.0 + height / 2))
        b.round_box(c, (1.9, 1.2, height), "stone" if k % 2 else "stone_dark", BONE, rot=Matrix.Rotation(a, 3, "Z"), bevel=0.3, segments=1)
        b.round_box(c + Vector((0, 0, height / 2 + 0.45)), (1.1, 1.3, 0.9), "stone_dark", BONE, rot=Matrix.Rotation(a, 3, "Z"), bevel=0.3, segments=1)
    b.box((0, -2.8, 1.6), (1.8, 1.0, 3.2), "dark", BONE)
    for _ in range(4):
        a = rng.uniform(0, math.tau)
        b.round_box((math.cos(a) * 4.4, math.sin(a) * 4.4, 0.4), (1.4, 1.0, 0.8), "stone_dark", BONE, rot=Matrix.Rotation(a, 3, "Z"), bevel=0.3, segments=1)
    b.span((-2.4, -1.4, 9.0), (-2.4, -1.4, 14.4), 0.18, "pole", BONE)
    portal_kit.ribbon(b, (-2.4, -1.5, 14.2), (-2.4, -1.5, 11.0), 1.4, "red", 0.06)
    snow_cap(b, (-1.2, 0, 12.6), (2.4, 2.6, 0.5))
    return colors, [b.to_object("Frame")]


def fort_wall():
    """A stretch of fort wall with crenellations, broken off at its right end, a red banner hanging on its face and
    snow along its top. About 16 long and 6 tall (Config COLLIDERS spread along X)."""
    colors = {"stone": STONE, "stone_dark": STONE_DARK, "red": RED, "gold": (210, 170, 80), "snow": SNOW}
    b = voxel_kit.Builder(colors)
    for k in range(7):
        x = -7 + k * 2.2
        height = 5.0 if k < 5 else (3.4 if k == 5 else 1.8)
        b.round_box((x, 0, height / 2), (2.15, 1.6, height), "stone" if k % 2 else "stone_dark", BONE, bevel=0.15)
        if k < 5:
            b.round_box((x - 0.5, 0, height + 0.5), (0.9, 1.6, 1.0), "stone", BONE, bevel=0.2)
            snow_cap(b, (x, 0, height + 0.05), (1.1, 0.9, 0.18))
    b.box((-2.6, -0.85, 3.0), (1.6, 0.08, 2.6), "red", BONE)
    b.box((-2.6, -0.9, 3.0), (0.5, 0.06, 0.5), "gold", BONE)
    for x in (4.4, 6.6):
        b.round_box((x + 0.6, -1.4, 0.35), (1.3, 0.9, 0.7), "stone_dark", BONE, rot=Matrix.Rotation(0.5, 3, "Z"), bevel=0.3)
    return colors, [b.to_object("Frame")]


def snow_pine():
    """A dark pine heavy with snow: four stacked tiers on a short trunk, each tier's top snowy. About 10 tall."""
    colors = {"needles": (40, 70, 64), "needles_dark": (30, 52, 50), "trunk": WOOD_DARK, "snow": SNOW}
    b = voxel_kit.Builder(colors)
    b.span((0, 0, 0), (0, 0, 2.0), 0.7, "trunk", BONE)
    tiers = [(1.6, 3.2, 2.6), (3.6, 2.6, 2.4), (5.4, 2.0, 2.2), (7.0, 1.3, 2.4)]
    for i, (z, radius, height) in enumerate(tiers):
        b.spike((0, 0, z - 0.4), (0, 0, 1), radius * 2, height, "needles" if i % 2 == 0 else "needles_dark", BONE)
        snow_cap(b, (0, 0, z + height * 0.45), (radius * 0.6, radius * 0.6, 0.25))
    return colors, [b.to_object("Frame")]


# ------------------------------------------------------------------------------------------------------ Stormpeak

def wrecked_tower():
    """A wrecked stone watchtower on the plateau: a square tower snapped off and leaning, its top lying in rubble beside
    it, a broken wooden beam sticking out. About 14 tall."""
    colors = {"stone": (110, 112, 124), "stone_dark": (78, 80, 92), "wood": WOOD_DARK, "dark": (34, 34, 40)}
    b = voxel_kit.Builder(colors)
    lean = tilt(-9, "X")
    for k in range(6):
        z = 1.1 + k * 2.1
        width = 4.6 - k * 0.15
        if k == 5:
            b.round_box(lean @ Vector((-0.8, 0, z)), (width * 0.6, width, 2.0), "stone_dark", BONE, rot=lean, bevel=0.15)
        else:
            b.round_box(lean @ Vector((0, 0, z)), (width, width, 2.0), "stone" if k % 2 else "stone_dark", BONE, rot=lean, bevel=0.12)
    b.box(lean @ Vector((0, -2.2, 6.0)), (1.0, 0.5, 1.6), "dark", BONE, rot=lean)
    b.span(lean @ Vector((1.0, 0, 10.4)), lean @ Vector((3.8, -0.6, 12.4)), 0.4, "wood", BONE)
    b.round_box((4.6, 2.4, 1.2), (3.6, 3.4, 2.4), "stone_dark", BONE, rot=Matrix.Rotation(0.6, 3, "Z") @ tilt(25, "X"), bevel=0.15)
    rng = random.Random(41)
    for _ in range(6):
        a = rng.uniform(0, math.tau)
        d = rng.uniform(3.2, 5.4)
        b.round_box((math.cos(a) * d, math.sin(a) * d, 0.4), (1.2, 1.0, 0.8), "stone", BONE, rot=Matrix.Rotation(a, 3, "Z"), bevel=0.3)
    return colors, [b.to_object("Frame")]


def horned_skull():
    """A giant horned beast's skull half sunk in the rock: a broad brow, deep eye sockets that glow faintly (Glow), a
    long snout with big fangs, and two great horns sweeping up and back. About 8 wide and 7 tall (a landmark)."""
    colors = {"bone": BONE_C, "bone_dark": BONE_DARK, "socket": (40, 32, 30), "horn": (70, 62, 58), "glow": GLOW}
    frame, glow = voxel_kit.Builder(colors), voxel_kit.Builder(colors)
    skull = Vector((0, 0, 2.4))
    frame.blob(skull, (2.6, 2.4, 2.1), "bone", BONE, segments=14, rings=9)
    frame.blob(skull + Vector((0, -2.6, -0.8)), (1.7, 1.9, 1.2), "bone", BONE, segments=12, rings=7)
    frame.blob(skull + Vector((0, -4.0, -1.1)), (1.1, 0.9, 0.8), "bone_dark", BONE, segments=10, rings=6)
    for side in (-1, 1):
        frame.blob(skull + Vector((side * 1.2, -1.7, 0.6)), (0.8, 0.5, 0.65), "socket", BONE, segments=8, rings=5)
        glow.blob(skull + Vector((side * 1.2, -2.0, 0.6)), (0.35, 0.12, 0.3), "glow", BONE, segments=6, rings=4)
        horn = [skull + Vector((side * 2.0, 0.2, 1.3)), skull + Vector((side * 3.6, 0.6, 2.6)), skull + Vector((side * 4.0, 1.8, 4.4)), skull + Vector((side * 3.2, 3.0, 5.4))]
        portal_kit.tube(frame, horn, [0.8, 0.6, 0.38, 0.06], "horn", sides=8)
        for t in range(3):
            frame.spike(skull + Vector((side * (0.5 + t * 0.35), -3.3 - t * 0.3, -1.7)), (0, 0, -1), 0.3, 0.9 - t * 0.15, "bone", BONE)
    frame.blob((0, 0, 0.2), (3.6, 3.4, 0.6), "bone_dark", BONE, segments=10, rings=4)
    return colors, [frame.to_object("Frame"), glow.to_object("Glow")]


def rock_spire():
    """A jagged slate spire: stacked, tapering, slightly twisted rock blocks with a split top. About 14 tall."""
    colors = {"rock": (98, 100, 112), "rock_dark": (72, 74, 86)}
    b = voxel_kit.Builder(colors)
    rng = random.Random(43)
    z = 0
    width = 4.4
    for k in range(6):
        h = 2.6 - k * 0.15
        rot = Matrix.Rotation(rng.uniform(-0.4, 0.4), 3, "Z") @ tilt(rng.uniform(-6, 6), "X")
        b.round_box((rng.uniform(-0.3, 0.3), rng.uniform(-0.3, 0.3), z + h / 2), (width, width * 0.85, h), "rock" if k % 2 else "rock_dark", BONE, rot=rot, bevel=0.2)
        z += h * 0.92
        width *= 0.8
    portal_kit.crystal(b, (0.3, 0, z - 0.4), (0.15, 0.1, 1), 0.7, 2.6, "rock_dark", sides=5, tip=0.5)
    portal_kit.crystal(b, (-0.4, 0.2, z - 0.6), (-0.25, -0.1, 1), 0.5, 1.8, "rock", sides=5, tip=0.5)
    return colors, [b.to_object("Frame")]


def storm_stone():
    """A tall standing stone carved with a zigzag rune that glows (Glow), the Storm Sovereign's summit ring's pieces
    and Stormpeak's markers. About 8 tall."""
    colors = {"stone": (96, 98, 112), "stone_dark": (70, 72, 84), "glow": GLOW}
    frame, glow = voxel_kit.Builder(colors), voxel_kit.Builder(colors)
    frame.round_box((0, 0, 3.8), (2.4, 1.3, 7.6), "stone", BONE, rot=tilt(4, "Y"), bevel=0.35)
    frame.round_box((0.3, 0, 7.4), (1.8, 1.1, 1.2), "stone_dark", BONE, rot=tilt(14, "Y"), bevel=0.35)
    bolt = [(0.4, 6.4), (-0.4, 5.0), (0.3, 4.6), (-0.5, 2.8), (0.2, 3.3), (-0.2, 1.6)]
    for (x0, z0), (x1, z1) in zip(bolt, bolt[1:]):
        portal_kit.ribbon(glow, (x0, -0.68, z0), (x1, -0.68, z1), 0.22, "glow", 0.06)
    frame.blob((0, 0, 0.1), (1.8, 1.2, 0.3), "stone_dark", BONE, segments=8, rings=3)
    return colors, [frame.to_object("Frame"), glow.to_object("Glow")]


# --------------------------------------------------------------------------------------------------------- the Rift

def floating_rock():
    """A chunk of the Rift's floor torn loose and floating: a flat rocky top, a pointed underside with violet crystals
    growing down out of it (Glow). The game hangs it in the air (the spot's y). About 6 tall."""
    colors = {"rock": (54, 44, 66), "rock_dark": (38, 30, 48), "glow": GLOW}
    frame, glow = voxel_kit.Builder(colors), voxel_kit.Builder(colors)
    frame.blob((0, 0, 4.6), (3.2, 2.8, 1.0), "rock", BONE, segments=10, rings=5)
    portal_kit.crystal(frame, (0, 0, 4.4), (0, 0, -1), 2.4, 4.2, "rock_dark", sides=7, tip=0.7)
    for a, length in ((0.4, 2.2), (2.5, 1.6), (4.4, 1.9)):
        base = Vector((math.cos(a) * 1.3, math.sin(a) * 1.1, 3.4))
        portal_kit.crystal(glow, base, (math.cos(a) * 0.3, math.sin(a) * 0.3, -1), 0.35, length, "glow", sides=5, tip=0.4)
    return colors, [frame.to_object("Frame"), glow.to_object("Glow")]


def crystal_arch():
    """The Dungeon gate: two jagged violet crystal pillars leaning together into an arch over the portal, rocks at their
    feet. Its crystals glow (Glow). About 16 tall and 14 wide; the portal ring stands in its opening."""
    colors = {"rock": (54, 44, 66), "rock_dark": (38, 30, 48), "glow": GLOW}
    frame, glow = voxel_kit.Builder(colors), voxel_kit.Builder(colors)
    for side in (-1, 1):
        frame.blob((side * 6.0, 0, 0.6), (2.0, 1.8, 1.2), "rock", BONE, segments=8, rings=5)
        portal_kit.crystal(glow, (side * 6.0, 0, 0.8), (-side * 0.42, 0, 1), 1.3, 15.0, "glow", sides=6, tip=0.25)
        portal_kit.crystal(glow, (side * 6.8, 0.6, 0.6), (side * 0.2, 0.1, 1), 0.7, 5.0, "glow", sides=5, tip=0.4)
        portal_kit.crystal(glow, (side * 5.4, -0.8, 0.5), (-side * 0.1, -0.2, 1), 0.6, 3.6, "glow", sides=5, tip=0.4)
        frame.blob((side * 7.6, -1.0, 0.3), (1.0, 0.9, 0.6), "rock_dark", BONE, segments=6, rings=4)
    frame.blob((0, 0, 13.6), (2.8, 1.8, 1.6), "rock_dark", BONE, segments=8, rings=5)
    return colors, [frame.to_object("Frame"), glow.to_object("Glow")]


# --------------------------------------------------------------------------------------------- the dead giant

def titan_skull():
    """The dead giant's skull lying on its side at the end of its body: a huge cracked dome, a dark eye socket and nose,
    a jaw with big square teeth, moss-dark stains and snow on top. About 14 wide and 10 tall (a landmark)."""
    colors = {"bone": (214, 204, 182), "bone_dark": (160, 148, 126), "socket": (40, 34, 34), "snow": SNOW}
    b = voxel_kit.Builder(colors)
    b.blob((0, 0, 5.0), (7.0, 6.0, 5.4), "bone", BONE, segments=16, rings=10)
    b.blob((0, -5.2, 2.6), (4.6, 2.8, 2.6), "bone", BONE, segments=12, rings=7)
    for side in (-1, 1):
        b.blob((side * 2.6, -5.0, 5.0), (1.6, 1.2, 1.4), "socket", BONE, segments=8, rings=5)
    b.blob((0, -6.6, 3.4), (0.7, 0.6, 1.0), "socket", BONE, segments=6, rings=4)
    for k in range(6):
        x = -2.5 + k
        b.round_box((x, -7.3, 1.2), (0.85, 0.7, 1.1), "bone", BONE, bevel=0.3)
    b.round_box((0, -6.4, 0.5), (6.8, 2.6, 0.9), "bone_dark", BONE, bevel=0.3)
    for (a, c) in (((-1.5, -5.6, 8.6), (0.6, -3.4, 9.8)), ((0.6, -3.4, 9.8), (2.6, -1.6, 9.0))):
        portal_kit.ribbon(b, a, c, 0.3, "socket", 0.2)
    snow_cap(b, (0, 1.0, 10.0), (4.6, 4.0, 0.6))
    return colors, [b.to_object("Frame")]


# ------------------------------------------------------------------------------------- the Frost Tyrant's hall

def ice_pillar():
    """A tall pillar of clear blue ice: a cluster of three upright crystals on a snowy base (Glow, faint). About 14
    tall."""
    colors = {"snow": SNOW, "ice": (150, 200, 236), "glow": GLOW}
    frame, glow = voxel_kit.Builder(colors), voxel_kit.Builder(colors)
    frame.blob((0, 0, 0.3), (2.4, 2.2, 0.8), "snow", BONE, segments=8, rings=4)
    portal_kit.crystal(frame, (0, 0, 0.5), (0.05, 0, 1), 1.4, 13.5, "ice", sides=6, tip=0.15)
    portal_kit.crystal(glow, (1.2, 0.4, 0.4), (0.25, 0.1, 1), 0.7, 7.0, "glow", sides=6, tip=0.25)
    portal_kit.crystal(glow, (-1.1, -0.5, 0.4), (-0.2, -0.15, 1), 0.6, 5.5, "glow", sides=6, tip=0.25)
    return colors, [frame.to_object("Frame"), glow.to_object("Glow")]


def ice_throne():
    """The Frost Tyrant's broken throne of ice: a wide seat on a stepped dais, a tall cracked back with jagged spikes, one
    arm snapped off. About 12 tall."""
    colors = {"ice": (150, 200, 236), "ice_dark": (110, 160, 206), "snow": SNOW, "glow": GLOW}
    frame, glow = voxel_kit.Builder(colors), voxel_kit.Builder(colors)
    frame.round_box((0, 0, 0.5), (9.0, 7.0, 1.0), "snow", BONE, bevel=0.3)
    frame.round_box((0, 0.6, 1.5), (7.0, 5.0, 1.0), "ice_dark", BONE, bevel=0.3)
    frame.round_box((0, 0.6, 2.9), (5.0, 3.8, 1.8), "ice", BONE, bevel=0.25)
    frame.round_box((0, 2.4, 6.6), (5.4, 1.0, 8.4), "ice", BONE, rot=tilt(-6, "X"), bevel=0.2)
    for x, length in ((-2.2, 3.2), (-0.8, 4.6), (0.8, 4.2), (2.2, 2.8)):
        portal_kit.crystal(glow, (x, 2.6, 10.2), (x * 0.08, 0.15, 1), 0.55, length, "glow", sides=5, tip=0.5)
    frame.round_box((-2.6, -0.2, 4.4), (0.8, 3.6, 1.0), "ice_dark", BONE, bevel=0.3)
    frame.round_box((2.6, 0.6, 4.4), (0.8, 1.6, 1.0), "ice_dark", BONE, bevel=0.3)
    frame.round_box((3.6, -2.8, 1.4), (1.0, 1.8, 0.8), "ice_dark", BONE, rot=Matrix.Rotation(0.7, 3, "Z"), bevel=0.3)
    return colors, [frame.to_object("Frame"), glow.to_object("Glow")]


PROPS = {
    "Tent": tent,
    "Campfire": campfire,
    "Watchtower": watchtower,
    "Ribcage": ribcage,
    "GiantSword": giant_sword,
    "FortRuin": fort_ruin,
    "FortWall": fort_wall,
    "SnowPine": snow_pine,
    "WreckedTower": wrecked_tower,
    "HornedSkull": horned_skull,
    "RockSpire": rock_spire,
    "StormStone": storm_stone,
    "FloatingRock": floating_rock,
    "CrystalArch": crystal_arch,
    "TitanSkull": titan_skull,
    "IcePillar": ice_pillar,
    "IceThrone": ice_throne,
}
CAPS = {"Ribcage": LANDMARK_CAP, "HornedSkull": LANDMARK_CAP, "TitanSkull": LANDMARK_CAP}


def build(name):
    """One prop's meshes, named <Name>__<part>, with its palette material; returns them and its triangle count."""
    colors, objects = PROPS[name]()
    material = voxel_kit.make_material(name, voxel_kit.make_palette(name, colors))
    scene = bpy.context.scene
    for obj in objects:
        scene.collection.objects.link(obj)
        obj.data.materials.append(material)
        obj.vertex_groups.clear()
        obj.name = f"{name}__{obj.name}"
        obj.data.name = obj.name
    total = sum(portal_kit.triangles(o) for o in objects)
    cap = CAPS.get(name, PROP_CAP)
    assert total <= cap, f"{name} has {total} triangles (cap {cap})"
    return objects, total


def run():
    wanted = [name for name in os.environ.get("PROPS", ",".join(PROPS)).split(",") if name]
    portal_kit.begin(PACK)
    scene = bpy.context.scene
    everything = []
    for index, name in enumerate(wanted):
        objects, total = build(name)
        holder = bpy.data.objects.new(name, None)  # an Empty: the prop's own Model in the import
        scene.collection.objects.link(holder)
        holder.location = (index * SPACING, 0, 0)
        for obj in objects:
            obj.parent = holder
        everything += [holder] + objects
        print(f"OK {name} {total} tris")
    if os.environ.get("EXPORT", "1") == "1":
        bpy.ops.object.select_all(action="DESELECT")
        for obj in everything:
            obj.select_set(True)
        bpy.context.view_layer.objects.active = everything[0]
        folder = voxel_kit.out_dir(PACK)
        bpy.ops.wm.save_as_mainfile(filepath=os.path.join(folder, f"{PACK}.blend"))
        bpy.ops.export_scene.fbx(
            filepath=os.path.join(folder, f"{PACK}.fbx"),
            use_selection=True,
            object_types={"EMPTY", "MESH"},
            path_mode="COPY",
            embed_textures=True,
            mesh_smooth_type="FACE",
            apply_scale_options="FBX_SCALE_ALL",
        )
        print("exported to", folder)


if __name__ == "__main__":  # render_frontier_props.py imports the builders without running them
    run()
