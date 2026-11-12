"""Builds the Crystal Abyss's world props (spec docs/superpowers/specs/2026-11-12-dungeon-world-design.md, the owner's
concept A; concepts assets/blender/DungeonWorld/concept_*.png): the gate across each island's bridge out, the Hydra's
round door, a bridge segment, a hanging chain and the hydra sigil in the fight rings' floors. Same smooth stylized
look and stone palette as build_dungeon_props.py (voxel_kit, portal_kit), cool indigo with gold.

ONE pack, like DungeonProps: each prop an Empty <Name> over <Name>__Frame (palette texture) and <Name>__Glow (palette
white; the game turns it Neon in the spot's colour). The props stand apart along X in
assets/blender/DungeonWorld/DungeonWorld.{blend,fbx}. Import the FBX in Studio with default settings, save the
imported model as assets/props-import/DungeonWorld.rbxm, then
`lune run tools/props/split_pack assets/props-import/DungeonWorld.rbxm` writes assets/props/<Name>.rbxm per prop.
Blender: Z up, 1 unit = 1 stud, each prop's origin at its bottom centre, its front facing -Y (the side you come from).
Run in a background Blender (it clears the scene):
  blender -b --factory-startup --python tools/blender/build_dungeon_world.py
PROPS="A,B" builds only those, EXPORT=0 builds without saving. Caps: 2000 triangles, the Hydra's door 4000.

Sizes the game relies on (Server/Util/DungeonBuilder): the gate's opening 12 wide and 14 tall (its barrier is the
game's); the Hydra's door a disc of radius 13 standing on the ground, 2.4 thick, its five eyes the game's lock sockets
on an arc of radius 7.15 round a point 2 below its middle (-60 to 60 degrees), 1.4 in front of its middle; the bridge
segment 8 wide and 12 long, its walking top 1.4 over its bottom; the chain 60 long, hung by its top; the sigil flat.
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
import build_dungeon_props as stone  # noqa: E402  (its palette, shards and the pack's build/export)

BONE = portal_kit.BONE
PACK = "DungeonWorld"
CAPS = {"DungeonHydraDoor": 4000}

DOOR_RADIUS = 13.0
EYE_ARC = DOOR_RADIUS * 0.55
DECK = 1.4
CHAIN_LENGTH = 60.0


def island_gate():
    """The gate across the start of an island's bridge out: two cracked posts with rune lines (Glow), a heavy lintel
    snapped at one end, a carved hydra eye over the middle (Glow), crystals at the posts' feet. The opening 12 wide and
    14 tall; about 20 wide and 19 tall in all, 3 deep."""
    colors = stone.palette()
    frame, glow = voxel_kit.Builder(colors), voxel_kit.Builder(colors)
    rng = random.Random(21)
    for side in (-1, 1):
        x = side * 7.6
        frame.round_box((x, 0, 0.8), (3.8, 3.8, 1.6), "stone_dark", BONE, bevel=0.3)
        frame.round_box((x, 0, 8.4), (3.0, 3.0, 13.6), "stone" if side < 0 else "stone_light", BONE, bevel=0.35)
        portal_kit.ribbon(glow, (x, -1.52, 2.6), (x, -1.52, 13.0), 0.3, "glow", 0.05)
        stone.shards(glow, (x + side * 1.6, -1.4, 0.2), 3, rng, 0.8)
    frame.round_box((-1.0, 0, 16.4), (18.0, 3.4, 2.8), "stone_light", BONE, bevel=0.35)
    frame.round_box((8.4, 0.2, 15.9), (2.4, 3.0, 1.8), "stone", BONE, rot=stone.tilt(-18), bevel=0.3, segments=1)
    frame.round_box((-1.0, 0, 18.3), (12.0, 2.8, 1.0), "stone_dark", BONE, bevel=0.25)
    # the hydra eye: an almond of gold round a glowing slit
    portal_kit.disc(frame, (0, -1.74, 16.4), 1.8, "gold", normal=(0, -1, 0), sides=12, radius_y=1.0)
    portal_kit.disc(glow, (0, -1.80, 16.4), 1.2, "glow", normal=(0, -1, 0), sides=10, radius_y=0.45)
    return colors, [frame.to_object("Frame"), glow.to_object("Glow")]


def hydra_door():
    """The Hydra's round door: a thick stone disc in a gold-trimmed rim, a five-headed hydra in relief on its face (five
    necks rising from a coiled body at its foot to five heads round the game's eye sockets), glowing cracks between the
    stones (Glow). Radius 13, standing on the ground, 2.4 thick."""
    colors = stone.palette()
    frame, glow = voxel_kit.Builder(colors), voxel_kit.Builder(colors)
    centre = Vector((0, 0, DOOR_RADIUS))
    portal_kit.tube(frame, [Vector((0, -1.2, DOOR_RADIUS)), Vector((0, 1.2, DOOR_RADIUS))], [DOOR_RADIUS, DOOR_RADIUS], "stone", sides=24)
    # the gold rim: a band just round the stone's edge (behind its face, so only the band shows)
    portal_kit.tube(frame, [Vector((0, -0.9, DOOR_RADIUS)), Vector((0, 0.9, DOOR_RADIUS))], [DOOR_RADIUS + 0.5, DOOR_RADIUS + 0.5], "gold", sides=24)
    portal_kit.disc(frame, (0, -1.25, DOOR_RADIUS), DOOR_RADIUS - 1.2, "stone_dark", normal=(0, -1, 0), sides=24)
    # the coiled body at the foot, heavy
    frame.blob((0, -1.7, 3.6), (6.4, 1.4, 3.0), "stone_light", BONE, segments=10, rings=5)
    for k in range(5):
        a = math.radians(-60 + k * 30)
        head = Vector((math.sin(a) * EYE_ARC, -1.7, DOOR_RADIUS + math.cos(a) * EYE_ARC - 2))
        base = Vector((math.sin(a) * 3.2, -1.7, 5.0))
        bend = Vector((math.sin(a) * (EYE_ARC + 2.6), -1.8, (base.z + head.z) / 2))  # an S: out, then back in
        portal_kit.tube(frame, [base, bend, head - Vector((0, 0, 1.2))], [1.7, 1.35, 1.15], "stone_light", sides=7)
        # the head: a broad skull round the eye socket, a snout out and down, two horns back
        frame.blob(tuple(head + Vector((0, -0.2, 0.2))), (2.3, 1.1, 1.7), "stone_light", BONE, segments=8, rings=4)
        snout = head + Vector((math.sin(a) * 1.6, -0.5, -1.4))
        frame.round_box(tuple(snout), (1.4, 0.9, 1.0), "stone", BONE, rot=stone.spin(a), bevel=0.3, segments=1)
        for side in (-1, 1):
            portal_kit.crystal(frame, tuple(head + Vector((side * 0.9, 0.1, 1.2))), (side * 0.5 + math.sin(a) * 0.4, 0.3, 1), 0.3, 1.6, "gold", sides=5, tip=0.3)
    # glowing cracks between the stones, out from the middle
    for k in range(8):
        a = k / 8 * math.tau + 0.2
        p0 = centre + Vector((math.cos(a) * 3.0, -1.3, math.sin(a) * 3.0))
        p1 = centre + Vector((math.cos(a) * (DOOR_RADIUS - 1.6), -1.3, math.sin(a) * (DOOR_RADIUS - 1.6)))
        portal_kit.ribbon(glow, tuple(p0), tuple(p1), 0.22, "glow", 0.04)
    return colors, [frame.to_object("Frame"), glow.to_object("Glow")]


def bridge_segment():
    """A stone bridge segment: big worn planks of stone, a rough underside, low broken railing posts along both edges
    (some missing, some snapped short), a few crystal chips (Glow). 8 wide, 12 long; its walking top 1.4 up."""
    colors = stone.palette()
    frame, glow = voxel_kit.Builder(colors), voxel_kit.Builder(colors)
    rng = random.Random(23)
    for k in range(4):
        y = -4.5 + k * 3.0
        frame.round_box((0, y, DECK - 0.4), (8.0, 2.9, 0.8), "stone" if k % 2 else "stone_light", BONE, rot=stone.tilt(rng.uniform(-1.5, 1.5), "Y"), bevel=0.2, segments=1)
    frame.round_box((0, 0, 0.5), (6.6, 12.0, 1.0), "stone_dark", BONE, bevel=0.3, segments=1)
    for side in (-1, 1):
        for k in range(5):
            if rng.random() < 0.3:
                continue
            tall = rng.uniform(0.6, 1.5)
            frame.round_box((side * 3.6, -4.8 + k * 2.4, DECK + tall / 2), (0.7, 0.7, tall), "stone_dark", BONE, bevel=0.15, segments=1)
    stone.shards(glow, (2.8, 3.6, DECK - 0.1), 2, rng, 0.45, 0.6)
    return colors, [frame.to_object("Frame"), glow.to_object("Glow")]


def hanging_chain():
    """A rusted iron chain hanging from the cave's ceiling, its last links broken open, a small crystal grown on one link
    (Glow). 60 long, its origin at its bottom."""
    colors = stone.palette(iron=(58, 54, 66), rust=(104, 70, 54))
    frame, glow = voxel_kit.Builder(colors), voxel_kit.Builder(colors)
    links = int(CHAIN_LENGTH / 2.2)
    for k in range(links):
        z = 1.1 + k * 2.2
        flat = k % 2 == 0
        size = (1.4, 0.45, 2.4) if flat else (0.45, 1.4, 2.4)
        frame.round_box((0, 0, z), size, "iron" if k % 5 else "rust", BONE, bevel=0.2, segments=1)
    portal_kit.crystal(glow, (0.4, -0.3, 22.0), (0.6, -0.4, 0.4), 0.3, 1.4, "glow", sides=5, tip=0.4)
    return colors, [frame.to_object("Frame"), glow.to_object("Glow")]


def hydra_sigil():
    """The hydra sigil inlaid in each fight ring's floor (Glow): a ring, a centre circle and five curving heads reaching
    out from it. 16 across, flat."""
    colors = stone.palette()
    frame, glow = voxel_kit.Builder(colors), voxel_kit.Builder(colors)
    portal_kit.disc(frame, (0, 0, 0.04), 8.4, "stone_dark", sides=24)
    for k in range(24):
        a = k / 24 * math.tau
        portal_kit.ribbon(glow, (math.cos(a) * 7.6, math.sin(a) * 7.6, 0.1), (math.cos(a + 0.27) * 7.6, math.sin(a + 0.27) * 7.6, 0.1), 0.3, "glow", 0.03)
    portal_kit.disc(glow, (0, 0, 0.1), 1.6, "glow", sides=12)
    for k in range(5):
        a = k / 5 * math.tau + math.pi / 2
        points = [(math.cos(a + t * 0.35) * (1.8 + t * 4.4), math.sin(a + t * 0.35) * (1.8 + t * 4.4)) for t in (0.0, 0.4, 0.8, 1.0)]
        for (x0, y0), (x1, y1) in zip(points, points[1:]):
            portal_kit.ribbon(glow, (x0, y0, 0.1), (x1, y1, 0.1), 0.45, "glow", 0.03)
        hx, hy = points[-1]
        portal_kit.disc(glow, (hx, hy, 0.1), 0.7, "glow", sides=8)
    return colors, [frame.to_object("Frame"), glow.to_object("Glow")]


PROPS = {
    "DungeonIslandGate": island_gate,
    "DungeonHydraDoor": hydra_door,
    "DungeonBridge": bridge_segment,
    "DungeonChain": hanging_chain,
    "DungeonSigil": hydra_sigil,
}


def build(name):
    """One prop's meshes with its palette material, under its own cap (2000, the Hydra's door 4000)."""
    colors, objects = PROPS[name]()
    material = voxel_kit.make_material(name, voxel_kit.make_palette(name, colors))
    scene = stone.bpy.context.scene
    for obj in objects:
        scene.collection.objects.link(obj)
        obj.data.materials.append(material)
        obj.vertex_groups.clear()
        obj.name = f"{name}__{obj.name}"
        obj.data.name = obj.name
    total = sum(portal_kit.triangles(o) for o in objects)
    cap = CAPS.get(name, stone.PROP_CAP)
    assert total <= cap, f"{name} has {total} triangles (cap {cap})"
    return objects, total


def run():
    # build_dungeon_props' pack run (layout, save, FBX export) with this pack's props, name and build
    stone.PROPS = PROPS
    stone.PACK = PACK
    stone.build = build
    stone.run()


if __name__ == "__main__":
    run()
