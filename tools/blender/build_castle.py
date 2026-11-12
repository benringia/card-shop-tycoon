"""Builds the Hydra's castle at the end of the Crystal Abyss (owner 2026-11-12: "this doesn't look like a castle, use
Blender to draw a proper castle", then "a broken/abandoned castle instead of a proper castle"; concept
assets/blender/DungeonWorld/concept_castle.png): a ruined, long-abandoned dark-violet fortress round the hydra gate:
towers broken off to jagged stumps (two spires left, leaning), walls breached in several places with most of their
crenels gone, the keep's roof fallen in, moss over the stones, heaps of rubble, crystals overgrowing it all. A crenellated front wall either side of the gate's gap, two gatehouse towers flanking
it and a battlement bridge over it with the hydra's sigil, side walls (one breached, rubble at its foot), a back wall,
four corner towers with spire roofs, a keep with a tall spire tower, glowing slit windows and rune lines, crystals
growing through the stones.

ONE prop in its own pack, like DungeonWorld: an Empty DungeonCastle over DungeonCastle__Frame (palette texture) and
DungeonCastle__Glow (palette white; the game turns it Neon violet). Writes assets/blender/DungeonCastle/
DungeonCastle.{blend,fbx}. Import the FBX in Studio with default settings, save the imported model as
assets/props-import/DungeonCastle.rbxm, then `lune run tools/props/split_pack assets/props-import/DungeonCastle.rbxm`
writes assets/props/DungeonCastle.rbxm.
Blender: Z up, 1 unit = 1 stud, the origin at the middle of the gate's gap on the ground, the front facing -Y (the
side you come from), the castle reaching +Y behind. Run in a background Blender (it clears the scene):
  blender -b --factory-startup --python tools/blender/build_castle.py

Sizes the game relies on (Server/Util/DungeonBuilder castle, Config/Dungeon ABYSS.CASTLE): the gate's gap 30 wide
(the Frontier's Dungeon portal model at 1.3x stands in it), the front wall on y 0, the castle within x -44..44 and
y 0..62 (the castle plateau's square from its front wall back), walls 5 thick; the game gives the walls their
collision with invisible blocks (a big mesh's collision can't be set from a script). split_pack pivots the model at
the bottom centre of its bounds: the run prints that pivot from the gate (`pivot = {...}`) for ABYSS.CASTLE.model.pivot.
"""
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)) if "__file__" in globals() else
                os.path.join(os.environ.get("CARD_SHOP_REPO", r"C:\Users\Ben\Documents\roblox-project\card-shop-tycoon"), "tools", "blender"))
import voxel_kit  # noqa: E402
import portal_kit  # noqa: E402
import build_dungeon_props as stone  # noqa: E402  (its pack's build/export)

BONE = portal_kit.BONE
PACK = "DungeonCastle"
CAP = 12000  # Roblox takes 20000 a mesh

GAP = 15.0  # half the gate's gap
WIDE = 44.0  # half the castle's width
DEEP = 62.0  # front wall to back wall
WALL = 5.0  # thickness
WALL_TALL = 22.0


def colors():
    return stone.palette(
        castle=(84, 70, 116),
        castle_light=(104, 90, 140),
        castle_dark=(54, 46, 78),
        roof=(42, 34, 64),
    )


def crenels(frame, a, b, top, rng, skip=0.55):
    """Merlons along a wall's top from a to b (x, y), some knocked off."""
    ax, ay = a
    bx, by = b
    length = math.hypot(bx - ax, by - ay)
    count = max(1, int(length // 4.5))
    for k in range(count):
        if rng.random() < skip:
            continue
        t = (k + 0.5) / count
        x, y = ax + (bx - ax) * t, ay + (by - ay) * t
        size = (2.6, WALL + 0.4, 2.6) if abs(bx - ax) > abs(by - ay) else (WALL + 0.4, 2.6, 2.6)
        frame.round_box((x, y, top + 1.3), size, "castle_light", BONE, bevel=0.15, segments=1)


def wall(frame, a, b, tall, rng, color="castle", breach=None):
    """A ruined wall from a to b (x, y) in 8-stud pieces of uneven height, a few crenels left; `breach` (a list of 0-1
    spots along it) knocks those pieces down to jagged stumps with rubble at their foot; moss patches on its face."""
    breaches = breach if isinstance(breach, (list, tuple)) else ([breach] if breach is not None else [])
    ax, ay = a
    bx, by = b
    length = math.hypot(bx - ax, by - ay)
    pieces = max(1, int(length // 8))
    along_x = abs(bx - ax) > abs(by - ay)
    for k in range(pieces):
        t = (k + 0.5) / pieces
        x, y = ax + (bx - ax) * t, ay + (by - ay) * t
        piece_tall = tall * rng.uniform(0.78, 1.0)
        if any(abs(t - spot) < 0.5 / pieces for spot in breaches):
            piece_tall = tall * rng.uniform(0.35, 0.5)
            for _ in range(5):
                frame.round_box((x + rng.uniform(-4, 4), y + rng.uniform(-6, 6), rng.uniform(0.6, 1.6)),
                                (rng.uniform(1.6, 3.2), rng.uniform(1.6, 3.2), rng.uniform(1.2, 2.4)), "castle_dark", BONE, bevel=0.3, segments=1)
        size = (length / pieces + 0.2, WALL, piece_tall) if along_x else (WALL, length / pieces + 0.2, piece_tall)
        frame.round_box((x, y, piece_tall / 2), size, color if k % 3 else "castle_light", BONE, bevel=0.06, segments=1)
        if piece_tall > tall * 0.7:
            sub_a = (x - size[0] / 2, y) if along_x else (x, y - size[1] / 2)
            sub_b = (x + size[0] / 2, y) if along_x else (x, y + size[1] / 2)
            crenels(frame, sub_a, sub_b, piece_tall, rng)
        else:
            # the broken top: a few jagged blocks
            for _ in range(3):
                jx = rng.uniform(-2.5, 2.5) if along_x else 0
                jy = 0 if along_x else rng.uniform(-2.5, 2.5)
                frame.round_box((x + jx, y + jy, piece_tall + rng.uniform(0.2, 1.6)), (rng.uniform(1.2, 2.6), WALL * 0.8, rng.uniform(1.0, 2.6)),
                                "castle_dark", BONE, rot=stone.tilt(rng.uniform(-20, 20)), bevel=0.2, segments=1)
        if rng.random() < 0.45:
            # moss creeping up its face
            if along_x:
                frame.blob((x, y - WALL / 2 - 0.15, rng.uniform(1.5, piece_tall * 0.6)), (rng.uniform(1.4, 2.6), 0.4, rng.uniform(1.0, 2.2)), "moss", BONE, segments=6, rings=4)
            else:
                frame.blob((x - WALL / 2 - 0.15, y, rng.uniform(1.5, piece_tall * 0.6)), (0.4, rng.uniform(1.4, 2.6), rng.uniform(1.0, 2.2)), "moss", BONE, segments=6, rings=4)


def tower(frame, glow, x, y, radius, tall, rng, spire=True, broken=False, lean=0.0):
    """A round tower: a battered foot, its shaft, a corbelled ring and crenels at its top, a spire roof (tipped `lean`
    degrees), slit windows facing the front. `broken`: cut off at a jagged height, no ring or roof, its fallen stones
    round its foot, moss on it, its windows dark."""
    if broken:
        stump = tall * rng.uniform(0.45, 0.65)
        portal_kit.tube(frame, [(x, y, 0), (x, y, 3)], [radius * 1.18, radius * 1.05], "castle_dark", sides=10)
        portal_kit.tube(frame, [(x, y, 3), (x, y, stump)], [radius, radius * 0.96], "castle", sides=10)
        for k in range(7):
            a = k / 7 * math.tau + rng.uniform(-0.2, 0.2)
            frame.round_box((x + math.cos(a) * radius * 0.82, y + math.sin(a) * radius * 0.82, stump + rng.uniform(0.4, 3.2)),
                            (2.2, 2.2, rng.uniform(1.2, 4.0)), "castle_dark", BONE, rot=stone.tilt(rng.uniform(-15, 15)), bevel=0.2, segments=1)
        for _ in range(4):
            a = rng.uniform(0, math.tau)
            d = radius + rng.uniform(1.5, 5)
            frame.round_box((x + math.cos(a) * d, y + math.sin(a) * d, rng.uniform(0.6, 1.4)), (rng.uniform(1.8, 3.4), rng.uniform(1.6, 3.0), rng.uniform(1.2, 2.4)),
                            "castle_dark", BONE, rot=stone.tilt(rng.uniform(-25, 25)), bevel=0.3, segments=1)
        frame.blob((x, y - radius * 0.98, stump * 0.4), (radius * 0.45, 0.4, stump * 0.2), "moss", BONE, segments=6, rings=4)
        return
    portal_kit.tube(frame, [(x, y, 0), (x, y, 3)], [radius * 1.18, radius * 1.05], "castle_dark", sides=10)
    portal_kit.tube(frame, [(x, y, 3), (x, y, tall)], [radius, radius * 0.94], "castle", sides=10)
    portal_kit.tube(frame, [(x, y, tall), (x, y, tall + 1.6)], [radius * 1.18, radius * 1.18], "castle_light", sides=10)
    for k in range(8):
        a = k / 8 * math.tau
        if rng.random() < 0.15:
            continue
        frame.round_box((x + math.cos(a) * radius * 1.05, y + math.sin(a) * radius * 1.05, tall + 2.6), (2.0, 2.0, 2.2), "castle_light", BONE, bevel=0.15, segments=1)
    if spire:
        tip_x = x + math.sin(math.radians(lean)) * radius * 2.4
        tip_z = tall + 1.6 + math.cos(math.radians(lean)) * radius * 2.4
        portal_kit.tube(frame, [(x, y, tall + 1.6), (tip_x, y, tip_z)], [radius * 1.05, 0.15], "roof", sides=10)
    for level in (0.45, 0.72):
        glow.box((x, y - radius * 0.97, tall * level), (0.7, 0.3, 2.6), "glow", BONE)


def castle():
    rng = random.Random(1977)
    pal = colors()
    frame, glow = voxel_kit.Builder(pal), voxel_kit.Builder(pal)
    # the front wall either side of the gate's gap, the gatehouse towers flanking it, a battlement over the gate
    wall(frame, (-WIDE, 0), (-GAP - 3, 0), WALL_TALL, rng, breach=[0.3])
    wall(frame, (GAP + 3, 0), (WIDE, 0), WALL_TALL, rng, breach=[0.55, 0.85])
    tower(frame, glow, -(GAP + 3), 0.5, 6.0, 32.0, rng, spire=True, lean=18)
    tower(frame, glow, GAP + 3, 0.5, 6.0, 32.0, rng, broken=True)
    frame.round_box((0, 0, 36.5), (2 * GAP + 4, WALL + 1, 5.0), "castle", BONE, bevel=0.08, segments=1)
    crenels(frame, (-GAP - 2, 0), (GAP + 2, 0), 39.0, rng, skip=0.0)
    # the hydra's sigil over the gate: a ring with five heads (glow)
    portal_kit.disc(glow, (0, -3.6, 36.5), 3.2, "glow", normal=(0, -1, 0), sides=14)
    portal_kit.disc(frame, (0, -3.55, 36.5), 3.9, "gold", normal=(0, -1, 0), sides=14)
    for k in range(5):
        a = math.pi * (0.15 + k * 0.175)
        portal_kit.ribbon(glow, (math.cos(a) * 1.0, -3.7, 36.5 + math.sin(a) * 1.0), (math.cos(a) * 3.0, -3.7, 36.5 + math.sin(a) * 3.0), 0.35, "glow", 0.05)
    # side walls (the left breached) and the back wall
    wall(frame, (-WIDE, 0), (-WIDE, DEEP), WALL_TALL - 2, rng, breach=[0.4, 0.75])
    wall(frame, (WIDE, 0), (WIDE, DEEP), WALL_TALL - 2, rng, breach=[0.6])
    wall(frame, (-WIDE, DEEP), (WIDE, DEEP), WALL_TALL, rng, color="castle_dark", breach=[0.25])
    # corner towers: three broken off, one still with its spire, leaning
    for x, y, tall, broken, lean in ((-WIDE, 0, 34.0, True, 0), (WIDE, 0, 30.0, True, 0), (-WIDE, DEEP, 42.0, False, -12), (WIDE, DEEP, 46.0, True, 0)):
        tower(frame, glow, x, y, 7.0, tall, rng, spire=not broken, broken=broken, lean=lean)
    # the keep: a tall block with crenels and windows, its spire tower at one corner, a fallen corner
    kx, ky = 4.0, DEEP - 20.0
    frame.round_box((kx, ky, 15.0), (28.0, 22.0, 30.0), "castle", BONE, bevel=0.04, segments=1)
    crenels(frame, (kx - 14, ky - 11), (kx + 14, ky - 11), 30.0, rng)
    crenels(frame, (kx - 14, ky + 11), (kx + 14, ky + 11), 30.0, rng)
    glow.box((kx + 8, ky - 11.1, 20.0), (1.0, 0.3, 4.0), "glow", BONE)  # one window still lit; the rest dark
    tower(frame, glow, kx + 12, ky + 9, 5.0, 52.0, rng, broken=True)
    # its roof fallen in: a slanted slab sunk into the top, a corner collapsed in a heap at its foot
    frame.round_box((kx - 4, ky, 28.5), (16.0, 18.0, 2.0), "castle_dark", BONE, rot=stone.tilt(-14), bevel=0.1, segments=1)
    frame.round_box((kx - 13, ky - 9, 31.0), (6.0, 6.0, 4.0), "castle_dark", BONE, rot=stone.tilt(25), bevel=0.3, segments=1)
    for _ in range(6):
        frame.round_box((kx - 16 + rng.uniform(-3, 3), ky - 13 + rng.uniform(-3, 3), rng.uniform(0.6, 2.0)), (rng.uniform(2, 4), rng.uniform(2, 4), rng.uniform(1.4, 3)),
                        "castle_dark", BONE, rot=stone.tilt(rng.uniform(-30, 30)), bevel=0.3, segments=1)
    # rune lines along the front wall, crystals growing through the stones
    for side in (-1, 1):
        portal_kit.ribbon(glow, (side * (GAP + 10), -2.6, 3.0), (side * (WIDE - 6), -2.6, 3.0), 0.4, "glow", 0.05)
    for _ in range(20):
        x = rng.uniform(-WIDE + 4, WIDE - 4)
        y = rng.choice((rng.uniform(-3.5, -2.0), rng.uniform(4, DEEP - 4)))
        if abs(x) < GAP + 6 and y < 2:
            continue
        stone.shards(glow, (x, y, 0.2), rng.randint(3, 5), rng, rng.uniform(1.2, 2.4), 2.0)
    return pal, [frame.to_object("Frame"), glow.to_object("Glow")]


PROPS = {"DungeonCastle": castle}


def build(name):
    """The castle's meshes with its palette material, under its own cap."""
    pal, objects = PROPS[name]()
    material = voxel_kit.make_material(name, voxel_kit.make_palette(name, pal))
    scene = stone.bpy.context.scene
    for obj in objects:
        scene.collection.objects.link(obj)
        obj.data.materials.append(material)
        obj.vertex_groups.clear()
        obj.name = f"{name}__{obj.name}"
        obj.data.name = obj.name
    total = sum(portal_kit.triangles(o) for o in objects)
    assert total <= CAP, f"{name} has {total} triangles (cap {CAP})"
    # split_pack pivots the imported model at the bottom centre of its bounds; the game needs where that is from the
    # gate (this origin) in the model's axes (Blender x flips, y is behind, z is up): Config/Dungeon ABYSS.CASTLE.model.pivot
    corners = [o.matrix_world @ stone.Vector(c) for o in objects for c in o.bound_box]
    lo = [min(c[i] for c in corners) for i in range(3)]
    hi = [max(c[i] for c in corners) for i in range(3)]
    print(f"pivot = {{ x = {-(lo[0] + hi[0]) / 2:.2f}, y = {lo[2]:.2f}, z = {(lo[1] + hi[1]) / 2:.2f} }}")
    return objects, total


def run():
    # build_dungeon_props' pack run (layout, save, FBX export) with this pack's prop, name and build
    stone.PROPS = PROPS
    stone.PACK = PACK
    stone.build = build
    stone.run()


if __name__ == "__main__":
    run()
