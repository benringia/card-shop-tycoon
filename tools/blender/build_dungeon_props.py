"""Builds the Dungeon's props (spec docs/superpowers/specs/2026-11-11-dungeon-puzzles-design.md, the owner's look C
"crystal-grown temple ruins": an old element temple the Prism Hydra's rainbow crystals have taken over; concept
assets/blender/DungeonProps/concept_look.png): the ruins (pillars whole and broken, a broken arch, wall pieces, floor
slabs, steps, a rune brazier, the carved gate round every door, crystal clusters) and the puzzle pieces (the beam gem,
a crystal mirror on its stand, the door's prism, a stone plate, a pylon, an element crystal, the cracked wall). Same
smooth stylized look as build_frontier_props.py (voxel_kit, portal_kit).

All props go into ONE pack so the owner imports once: each prop is an Empty named <Name> holding its meshes
<Name>__Frame (palette texture) and, for glowing ones, <Name>__Glow (palette white; the game turns it Neon in the
spot's colour: rune lines and crystals). The props stand apart along X in
assets/blender/DungeonProps/DungeonProps.{blend,fbx}. Import the FBX in Studio with default settings, save the
imported model as assets/props-import/DungeonProps.rbxm, then
`lune run tools/props/split_pack assets/props-import/DungeonProps.rbxm` writes assets/props/<Name>.rbxm per prop.
Blender: Z up, 1 unit = 1 stud, each prop's origin at its bottom centre, its front facing -Y. Run in a background
Blender (it clears the scene):
  blender -b --factory-startup --python tools/blender/build_dungeon_props.py
PROPS="A,B" builds only those, EXPORT=0 builds without saving. Each prop stays under 2000 triangles. The ruins are
named Dungeon<Piece> (the Wild valley already has RuinPillar, RuinArch...).
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
GLOW = (255, 255, 255)  # the game recolours it
PACK = "DungeonProps"
SPACING = 30  # studs between props in the pack file

STONE = (96, 104, 136)  # cool indigo-grey temple stone
STONE_LIGHT = (124, 132, 164)
STONE_DARK = (66, 72, 100)
DARK = (34, 32, 48)
MOSS = (70, 110, 92)
GOLD = (214, 176, 92)


def tilt(degrees, axis="Y"):
    return Matrix.Rotation(math.radians(degrees), 3, axis)


def spin(radians):
    return Matrix.Rotation(radians, 3, "Z")


def palette(**extra):
    colors = {"stone": STONE, "stone_light": STONE_LIGHT, "stone_dark": STONE_DARK, "dark": DARK, "moss": MOSS, "gold": GOLD, "glow": GLOW}
    colors.update(extra)
    return colors


def shards(glow, centre, count, rng, size=1.0, spread=1.2):
    """A small burst of crystals pushing out of the ground or stone at `centre`."""
    for k in range(count):
        a = k / count * math.tau + rng.uniform(-0.4, 0.4)
        lean = rng.uniform(0.25, 0.55)
        base = Vector(centre) + Vector((math.cos(a) * spread * 0.3, math.sin(a) * spread * 0.3, 0))
        portal_kit.crystal(glow, base, (math.cos(a) * lean, math.sin(a) * lean, 1), 0.32 * size, rng.uniform(1.4, 2.6) * size, "glow", sides=5, tip=0.4)


# ---------------------------------------------------------------------------------------------------------- ruins

def ruin_pillar():
    """A carved temple pillar: a square plinth, a round shaft with two carved bands and a rune line up its front (Glow),
    a square capital, crystals pushing out at its foot. About 16 tall."""
    colors = palette()
    frame, glow = voxel_kit.Builder(colors), voxel_kit.Builder(colors)
    rng = random.Random(1)
    frame.round_box((0, 0, 0.7), (4.2, 4.2, 1.4), "stone_dark", BONE, bevel=0.3)
    portal_kit.tube(frame, [Vector((0, 0, 1.4)), Vector((0, 0, 13.6))], [1.55, 1.4], "stone", sides=10)
    for z in (4.0, 10.4):
        portal_kit.tube(frame, [Vector((0, 0, z)), Vector((0, 0, z + 0.6))], [1.68, 1.68], "stone_light", sides=10)
    frame.round_box((0, 0, 14.4), (3.8, 3.8, 1.6), "stone_dark", BONE, bevel=0.3)
    frame.round_box((0, 0, 15.5), (3.2, 3.2, 0.6), "stone", BONE, bevel=0.2)
    for (z0, z1) in ((2.0, 3.6), (5.0, 9.8), (11.4, 13.2)):
        portal_kit.ribbon(glow, (0, -1.47, z0), (0, -1.47, z1), 0.24, "glow", 0.05)
    shards(glow, (1.6, -1.6, 0.2), 4, rng, 0.9)
    return colors, [frame.to_object("Frame"), glow.to_object("Glow")]


def ruin_pillar_broken():
    """The same pillar snapped off at the top in a jagged break, its fallen drum lying beside it, crystals growing out
    of the break and the ground. About 8 tall."""
    colors = palette()
    frame, glow = voxel_kit.Builder(colors), voxel_kit.Builder(colors)
    rng = random.Random(2)
    frame.round_box((0, 0, 0.7), (4.2, 4.2, 1.4), "stone_dark", BONE, bevel=0.3)
    portal_kit.tube(frame, [Vector((0, 0, 1.4)), Vector((0, 0, 6.4))], [1.55, 1.48], "stone", sides=10)
    for k in range(5):
        a = k / 5 * math.tau
        frame.round_box((math.cos(a) * 1.0, math.sin(a) * 1.0, 6.6 + (k % 2) * 0.6), (1.0, 1.0, 1.2 + (k % 2) * 0.8), "stone", BONE, rot=spin(a), bevel=0.25, segments=1)
    portal_kit.tube(frame, [Vector((3.4, -1.2, 1.4)), Vector((6.2, -2.6, 1.4))], [1.4, 1.4], "stone", sides=10)
    portal_kit.ribbon(glow, (0, -1.5, 2.0), (0, -1.5, 5.6), 0.24, "glow", 0.05)
    shards(glow, (0, 0, 6.8), 3, rng, 1.0, 1.0)
    shards(glow, (-1.8, 1.8, 0.2), 3, rng, 0.8)
    return colors, [frame.to_object("Frame"), glow.to_object("Glow")]


def ruin_arch():
    """A broken temple gateway: two square columns, the lintel still on the left one and snapped off past the middle,
    its broken half fallen at the right column's foot, a rune disc on the lintel (Glow), moss. About 14 tall, 12 wide."""
    colors = palette()
    frame, glow = voxel_kit.Builder(colors), voxel_kit.Builder(colors)
    for side in (-1, 1):
        frame.round_box((side * 5.0, 0, 0.6), (3.6, 3.6, 1.2), "stone_dark", BONE, bevel=0.3)
        frame.round_box((side * 5.0, 0, 5.4), (2.8, 2.8, 8.6), "stone", BONE, bevel=0.3)
        frame.round_box((side * 5.0, 0, 10.1), (3.4, 3.4, 0.9), "stone_dark", BONE, bevel=0.25)
    # the lintel: still on the left column, snapped off past the middle in a jagged end
    frame.round_box((-2.2, 0, 11.7), (8.4, 3.2, 2.4), "stone_light", BONE, bevel=0.35)
    frame.round_box((2.3, 0.3, 11.4), (1.4, 2.6, 1.6), "stone", BONE, rot=tilt(-14), bevel=0.3, segments=1)
    frame.round_box((-2.2, 0, 13.3), (6.0, 2.6, 0.9), "stone_dark", BONE, bevel=0.25)
    portal_kit.disc(glow, (-2.2, -1.62, 11.7), 0.9, "glow", normal=(0, -1, 0), sides=10)
    portal_kit.disc(frame, (-2.2, -1.65, 11.7), 0.55, "stone_dark", normal=(0, -1, 0), sides=10)
    # its broken half, fallen across the right column's foot
    frame.round_box((4.4, -2.6, 1.2), (5.0, 3.0, 2.2), "stone_light", BONE, rot=spin(0.35) @ tilt(8, "X"), bevel=0.35)
    frame.round_box((6.6, -2.0, 0.6), (1.9, 2.0, 1.3), "stone", BONE, rot=spin(0.5), bevel=0.25, segments=1)
    frame.round_box((7.8, 0.4, 0.5), (1.6, 1.8, 1.1), "stone_light", BONE, rot=spin(-0.3), bevel=0.25, segments=1)
    frame.blob((-5.0, -1.2, 10.7), (1.6, 1.4, 0.45), "moss", BONE, segments=6, rings=3)
    return colors, [frame.to_object("Frame"), glow.to_object("Glow")]


def ruin_wall():
    """A temple wall piece: a stone block wall with a carved panel (a rune circle, Glow) and a crack running up it,
    its top edge broken. About 10 tall and 12 wide, 2 thick."""
    colors = palette()
    frame, glow = voxel_kit.Builder(colors), voxel_kit.Builder(colors)
    for row in range(4):
        z = 1.2 + row * 2.3
        for col in range(3):
            if row == 3 and col == 2:
                continue  # broken corner
            x = -4.0 + col * 4.0 + (1.0 if row % 2 else 0)
            frame.round_box((x, 0, z), (3.9, 2.0, 2.2), "stone" if (row + col) % 2 else "stone_light", BONE, bevel=0.2, segments=1)
    frame.round_box((0.4, -1.0, 4.6), (4.2, 0.4, 4.2), "stone_dark", BONE, bevel=0.2)
    portal_kit.disc(glow, (0.4, -1.24, 4.6), 1.5, "glow", normal=(0, -1, 0), sides=12)
    portal_kit.disc(frame, (0.4, -1.27, 4.6), 1.1, "stone_dark", normal=(0, -1, 0), sides=12)
    return colors, [frame.to_object("Frame"), glow.to_object("Glow")]


def floor_slab():
    """A cracked temple floor slab with a rune ring inlaid (Glow) and a crystal poking through a crack. 6 x 6, low."""
    colors = palette()
    frame, glow = voxel_kit.Builder(colors), voxel_kit.Builder(colors)
    rng = random.Random(5)
    frame.round_box((-1.5, -1.5, 0.3), (2.9, 2.9, 0.6), "stone", BONE, bevel=0.15, segments=1)
    frame.round_box((1.5, -1.5, 0.3), (2.9, 2.9, 0.6), "stone_light", BONE, bevel=0.15, segments=1)
    frame.round_box((-1.5, 1.5, 0.3), (2.9, 2.9, 0.6), "stone_light", BONE, bevel=0.15, segments=1)
    frame.round_box((1.5, 1.5, 0.25), (2.9, 2.9, 0.5), "stone", BONE, rot=tilt(4, "X"), bevel=0.15, segments=1)
    for k in range(8):
        a = k / 8 * math.tau
        portal_kit.ribbon(glow, (math.cos(a) * 1.6, math.sin(a) * 1.6, 0.62), (math.cos(a + 0.6) * 1.6, math.sin(a + 0.6) * 1.6, 0.62), 0.18, "glow", 0.03)
    shards(glow, (2.2, 2.0, 0.3), 2, rng, 0.6, 0.6)
    return colors, [frame.to_object("Frame"), glow.to_object("Glow")]


def ruin_steps():
    """Three wide temple steps, worn at the edges, crystals at one end. About 3 tall and 8 wide."""
    colors = palette()
    frame, glow = voxel_kit.Builder(colors), voxel_kit.Builder(colors)
    rng = random.Random(6)
    for k in range(3):
        frame.round_box((0, k * 0.7, (k + 1) * 0.5), (8.0, 4.2 - k * 1.4, (k + 1) * 1.0), "stone" if k % 2 else "stone_light", BONE, bevel=0.2, segments=1)
    shards(glow, (3.6, 0.0, 0.4), 3, rng, 0.8)
    return colors, [frame.to_object("Frame"), glow.to_object("Glow")]


def rune_brazier():
    """A stone bowl on a carved stand with a crystal flame rising out of it (Glow). About 6 tall."""
    colors = palette()
    frame, glow = voxel_kit.Builder(colors), voxel_kit.Builder(colors)
    frame.round_box((0, 0, 0.4), (2.6, 2.6, 0.8), "stone_dark", BONE, bevel=0.25)
    portal_kit.tube(frame, [Vector((0, 0, 0.8)), Vector((0, 0, 3.6))], [0.7, 0.55], "stone", sides=8)
    portal_kit.tube(frame, [Vector((0, 0, 3.6)), Vector((0, 0, 4.6))], [1.0, 1.8], "stone_light", sides=10)
    portal_kit.crystal(glow, (0, 0, 4.3), (0, 0, 1), 0.7, 2.0, "glow", sides=6, tip=0.35)
    for a in (0.6, 2.7, 4.6):
        portal_kit.crystal(glow, (math.cos(a) * 0.6, math.sin(a) * 0.6, 4.3), (math.cos(a) * 0.4, math.sin(a) * 0.4, 1), 0.35, 1.2, "glow", sides=5, tip=0.4)
    return colors, [frame.to_object("Frame"), glow.to_object("Glow")]


def ruin_gate():
    """The carved stone gate round every door of the run (the game's glowing door fills its opening, 14 wide): two
    thick posts with rune lines (Glow), a lintel with a crystal keystone. About 22 tall and 22 wide, 4 deep."""
    colors = palette()
    frame, glow = voxel_kit.Builder(colors), voxel_kit.Builder(colors)
    for side in (-1, 1):
        frame.round_box((side * 9.0, 0, 0.8), (4.6, 4.6, 1.6), "stone_dark", BONE, bevel=0.3)
        frame.round_box((side * 9.0, 0, 9.6), (3.6, 3.6, 16.4), "stone", BONE, bevel=0.35)
        portal_kit.ribbon(glow, (side * 9.0, -1.82, 3.0), (side * 9.0, -1.82, 16.0), 0.3, "glow", 0.05)
    frame.round_box((0, 0, 19.2), (22.0, 4.0, 3.0), "stone_light", BONE, bevel=0.35)
    frame.round_box((0, 0, 21.2), (16.0, 3.4, 1.2), "stone_dark", BONE, bevel=0.3)
    portal_kit.crystal(glow, (0, -1.4, 18.4), (0, -0.3, 1), 1.0, 4.2, "glow", sides=6, tip=0.3)
    return colors, [frame.to_object("Frame"), glow.to_object("Glow")]


def crystal_cluster():
    """A cluster of big prism crystals bursting out of a rock (Glow; the game colours each cluster in an element's
    colour). About 9 tall."""
    colors = palette()
    frame, glow = voxel_kit.Builder(colors), voxel_kit.Builder(colors)
    frame.blob((0, 0, 0.5), (2.6, 2.2, 1.0), "stone_dark", BONE, segments=8, rings=4)
    for (a, lean, radius, length) in ((0.0, 0.05, 1.0, 8.6), (1.3, 0.45, 0.7, 5.6), (2.6, 0.5, 0.6, 4.4), (3.9, 0.4, 0.75, 6.0), (5.1, 0.55, 0.5, 3.6)):
        base = Vector((math.cos(a) * 0.7, math.sin(a) * 0.6, 0.6))
        portal_kit.crystal(glow, base, (math.cos(a) * lean, math.sin(a) * lean, 1), radius, length, "glow", sides=6, tip=0.3)
    return colors, [frame.to_object("Frame"), glow.to_object("Glow")]


# --------------------------------------------------------------------------------------------- the puzzle pieces

def beam_gem():
    """The beam's source: a carved pedestal holding a big round gem in gold claws (Glow). About 4.5 tall."""
    colors = palette()
    frame, glow = voxel_kit.Builder(colors), voxel_kit.Builder(colors)
    frame.round_box((0, 0, 0.4), (2.8, 2.8, 0.8), "stone_dark", BONE, bevel=0.25)
    portal_kit.tube(frame, [Vector((0, 0, 0.8)), Vector((0, 0, 2.6))], [0.8, 0.6], "stone", sides=8)
    portal_kit.tube(frame, [Vector((0, 0, 2.6)), Vector((0, 0, 3.0))], [0.7, 1.1], "gold", sides=8)
    glow.blob((0, 0, 3.7), (0.9, 0.9, 0.9), "glow", BONE, segments=10, rings=7)
    for a in (0.0, 2.1, 4.2):
        frame.span((math.cos(a) * 0.9, math.sin(a) * 0.9, 2.9), (math.cos(a) * 0.75, math.sin(a) * 0.75, 4.2), 0.18, "gold", BONE)
    return colors, [frame.to_object("Frame"), glow.to_object("Glow")]


def crystal_mirror():
    """A crystal mirror on a round stand: a gold frame holding a flat crystal pane (Glow), its face to -Y. The game
    turns the whole piece a quarter at a time. About 6 tall."""
    colors = palette()
    frame, glow = voxel_kit.Builder(colors), voxel_kit.Builder(colors)
    portal_kit.tube(frame, [Vector((0, 0, 0)), Vector((0, 0, 0.8))], [1.5, 1.4], "stone_dark", sides=12)
    portal_kit.tube(frame, [Vector((0, 0, 0.8)), Vector((0, 0, 1.6))], [0.45, 0.4], "stone", sides=8)
    frame.round_box((0, 0, 3.8), (4.4, 0.6, 4.4), "gold", BONE, bevel=0.2)
    glow.round_box((0, -0.2, 3.8), (3.6, 0.4, 3.6), "glow", BONE, bevel=0.1, segments=1)
    return colors, [frame.to_object("Frame"), glow.to_object("Glow")]


def door_prism():
    """The prism the beam must reach: a tall six-sided crystal on a small carved plinth (Glow). About 7 tall."""
    colors = palette()
    frame, glow = voxel_kit.Builder(colors), voxel_kit.Builder(colors)
    frame.round_box((0, 0, 0.5), (2.6, 2.6, 1.0), "stone_dark", BONE, bevel=0.25)
    frame.round_box((0, 0, 1.3), (2.0, 2.0, 0.6), "gold", BONE, bevel=0.15)
    portal_kit.crystal(glow, (0, 0, 1.5), (0, 0, 1), 0.9, 5.4, "glow", sides=6, tip=0.3)
    return colors, [frame.to_object("Frame"), glow.to_object("Glow")]


def stone_plate():
    """A pressure plate: a square carved stone slab set in a rim, a rune ring on its face (Glow; lights when pressed).
    8 x 8, low."""
    colors = palette()
    frame, glow = voxel_kit.Builder(colors), voxel_kit.Builder(colors)
    frame.round_box((0, 0, 0.2), (8.4, 8.4, 0.4), "stone_dark", BONE, bevel=0.15)
    frame.round_box((0, 0, 0.45), (7.2, 7.2, 0.5), "stone_light", BONE, bevel=0.2)
    for k in range(12):
        a = k / 12 * math.tau
        portal_kit.ribbon(glow, (math.cos(a) * 2.6, math.sin(a) * 2.6, 0.72), (math.cos(a + 0.45) * 2.6, math.sin(a + 0.45) * 2.6, 0.72), 0.26, "glow", 0.03)
    portal_kit.disc(glow, (0, 0, 0.72), 0.8, "glow", sides=10)
    return colors, [frame.to_object("Frame"), glow.to_object("Glow")]


def crystal_pylon():
    """A shield pylon: a carved stone base with a tall floating crystal above it (Glow), small shards round its foot.
    About 10 tall."""
    colors = palette()
    frame, glow = voxel_kit.Builder(colors), voxel_kit.Builder(colors)
    rng = random.Random(13)
    frame.round_box((0, 0, 0.6), (3.0, 3.0, 1.2), "stone_dark", BONE, bevel=0.3)
    portal_kit.tube(frame, [Vector((0, 0, 1.2)), Vector((0, 0, 2.6))], [1.1, 0.8], "stone", sides=8)
    portal_kit.crystal(glow, (0, 0, 3.0), (0, 0, 1), 0.85, 6.6, "glow", sides=6, tip=0.3)
    portal_kit.crystal(glow, (0, 0, 3.2), (0, 0, -1), 0.6, 0.6, "glow", sides=6, tip=0.6)
    shards(glow, (0, 0, 0.3), 3, rng, 0.6, 2.2)
    return colors, [frame.to_object("Frame"), glow.to_object("Glow")]


def element_crystal():
    """One of the lock's five crystals: a crystal on a low carved stand with a socket ring (Glow; the game colours it in
    its element's colour). About 7 tall."""
    colors = palette()
    frame, glow = voxel_kit.Builder(colors), voxel_kit.Builder(colors)
    frame.round_box((0, 0, 0.5), (2.8, 2.8, 1.0), "stone_dark", BONE, bevel=0.3)
    portal_kit.tube(frame, [Vector((0, 0, 1.0)), Vector((0, 0, 1.6))], [1.2, 1.0], "gold", sides=10)
    portal_kit.crystal(glow, (0, 0, 1.6), (0, 0, 1), 0.85, 5.0, "glow", sides=6, tip=0.3)
    return colors, [frame.to_object("Frame"), glow.to_object("Glow")]


def cracked_wall():
    """The secret wall: a stone block wall like ruin_wall but with a big glowing crack (Glow) running across it, a few
    chips on the floor before it. 14 wide, 14 tall, 2 thick."""
    colors = palette()
    frame, glow = voxel_kit.Builder(colors), voxel_kit.Builder(colors)
    for row in range(6):
        z = 1.15 + row * 2.3
        for col in range(4):
            x = -5.3 + col * 3.6 + (0.9 if row % 2 else 0)
            frame.round_box((x, 0, z), (3.5, 2.0, 2.2), "stone" if (row + col) % 2 else "stone_light", BONE, bevel=0.2, segments=1)
    crack = [(-3.6, 1.0), (-2.2, 3.6), (-0.4, 4.6), (0.2, 7.4), (1.8, 8.2), (2.4, 11.4), (4.0, 12.6)]
    for (x0, z0), (x1, z1) in zip(crack, crack[1:]):
        portal_kit.ribbon(glow, (x0, -1.08, z0), (x1, -1.08, z1), 0.3, "glow", 0.05)
    portal_kit.ribbon(glow, (-0.4, -1.08, 4.6), (-2.6, -1.08, 6.2), 0.2, "glow", 0.05)
    portal_kit.ribbon(glow, (1.8, -1.08, 8.2), (3.8, -1.08, 7.2), 0.2, "glow", 0.05)
    for x, y in ((-1.6, -2.0), (1.4, -1.6), (3.0, -2.4)):
        frame.round_box((x, y, 0.25), (0.8, 0.7, 0.5), "stone", BONE, rot=spin(x), bevel=0.15, segments=1)
    return colors, [frame.to_object("Frame"), glow.to_object("Glow")]


PROPS = {
    "DungeonPillar": ruin_pillar,
    "DungeonPillarBroken": ruin_pillar_broken,
    "DungeonArch": ruin_arch,
    "DungeonWall": ruin_wall,
    "DungeonSlab": floor_slab,
    "DungeonSteps": ruin_steps,
    "DungeonBrazier": rune_brazier,
    "DungeonGate": ruin_gate,
    "DungeonCrystals": crystal_cluster,
    "BeamGem": beam_gem,
    "CrystalMirror": crystal_mirror,
    "DoorPrism": door_prism,
    "StonePlate": stone_plate,
    "CrystalPylon": crystal_pylon,
    "ElementCrystal": element_crystal,
    "CrackedWall": cracked_wall,
}


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
    assert total <= PROP_CAP, f"{name} has {total} triangles (cap {PROP_CAP})"
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


if __name__ == "__main__":
    run()
