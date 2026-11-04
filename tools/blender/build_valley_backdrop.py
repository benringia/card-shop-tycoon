"""Builds the Wild valley's backdrop models (round 2, spec 2026-11-05-valley-natural-design, plan
2026-11-05-valley-natural): three giant ancient trees (green, autumn, pink blossom) for the Meadow's edges and two far
mountain range pieces (snowy for the Meadow and the Caves, dark jagged for Ember Ridge), in the valley props' smooth
stylized look (build_valley_props.py) on voxel_kit and portal_kit.

Each model is its own .blend and FBX in assets/blender/<Name>/ (portal_kit.export): one `Frame` object with the palette
texture. Blender: Z up, 1 unit = 1 stud, origin at the bottom centre, front facing -Y; the game scales each by its
height, so only proportions matter. Run in a background Blender (it clears the scene):
  blender -b --factory-startup --python tools/blender/build_valley_backdrop.py
PROPS="A,B" builds only those, EXPORT=0 builds without saving. Each stays under 4000 triangles (landmarks).
"""
import math
import os
import random
import sys

from mathutils import Matrix, Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)) if "__file__" in globals() else
                os.path.join(os.environ.get("CARD_SHOP_REPO", r"C:\Users\Ben\Documents\roblox-project\card-shop-tycoon"), "tools", "blender"))
import voxel_kit  # noqa: E402
import portal_kit  # noqa: E402

BONE = portal_kit.BONE
CAP = 4000

LEAVES = {
    "GiantTreeA": ((88, 166, 70), (128, 198, 88), (62, 128, 58)),  # green
    "GiantTreeB": ((236, 160, 52), (250, 202, 92), (204, 112, 42)),  # autumn yellow-orange
    "GiantTreeC": ((238, 156, 196), (250, 198, 222), (212, 116, 166)),  # pink blossom
}


def giant_tree(name, seed):
    """A giant ancient tree: a thick flared trunk on five roots, four big branches, and a broad dome canopy of rounded
    leaf clumps in three shades, about as wide as tall (11 by 11)."""
    leaf, leaf_light, leaf_dark = LEAVES[name]
    colors = {"bark": (112, 80, 54), "bark_dark": (84, 58, 40), "moss": (96, 140, 70),
              "leaf": leaf, "leaf_light": leaf_light, "leaf_dark": leaf_dark}
    rng = random.Random(seed)
    b = voxel_kit.Builder(colors)
    trunk = [Vector((0, 0, -0.3)), Vector((0.25, 0.1, 2.4)), Vector((0.1, -0.05, 4.6)), Vector((0.3, 0, 5.6))]
    portal_kit.tube(b, trunk, [1.7, 1.25, 1.05, 0.95], "bark", sides=9)
    for i in range(5):
        a = i / 5 * math.tau + rng.uniform(-0.25, 0.25)
        out = Vector((math.cos(a), math.sin(a), 0))
        portal_kit.tube(b, [Vector((0, 0, 1.4)), out * 1.9 + Vector((0, 0, 0.35)), out * 3.3 + Vector((0, 0, -0.3))], [0.85, 0.55, 0.22], "bark_dark", sides=6)
    b.blob((0, 0, 0.05), (2.4, 2.2, 0.3), "moss", BONE, segments=10, rings=4)
    top = trunk[-1]
    tips = []
    for i in range(4):
        a = i / 4 * math.tau + rng.uniform(-0.3, 0.3)
        tip = top + Vector((math.cos(a) * 3.2, math.sin(a) * 3.2, rng.uniform(1.6, 2.4)))
        portal_kit.tube(b, [top, top.lerp(tip, 0.5) + Vector((0, 0, 0.4)), tip], [0.7, 0.5, 0.32], "bark", sides=6)
        tips.append(tip)
    # the canopy: a big dome over the trunk, a ring of clumps round it at the branch tips and between, a few on top
    b.blob(top + Vector((0, 0, 3.0)), (3.8, 3.8, 2.4), "leaf", BONE, segments=12, rings=7)
    ring = 8
    for i in range(ring):
        a = i / ring * math.tau + rng.uniform(-0.15, 0.15)
        reach = rng.uniform(3.6, 4.4)
        centre = top + Vector((math.cos(a) * reach, math.sin(a) * reach, rng.uniform(1.6, 2.6)))
        size = rng.uniform(2.0, 2.6)
        b.blob(centre, (size, size, size * 0.72), ("leaf", "leaf_dark", "leaf_light")[i % 3], BONE, segments=10, rings=6)
    for i in range(4):
        a = i / 4 * math.tau + 0.4
        centre = top + Vector((math.cos(a) * 1.8, math.sin(a) * 1.8, rng.uniform(4.3, 5.0)))
        b.blob(centre, (2.0, 2.0, 1.4), "leaf_light", BONE, segments=10, rings=6)
    return colors, [b.to_object("Frame")]


def giant_tree_a():
    return giant_tree("GiantTreeA", 41)


def giant_tree_b():
    return giant_tree("GiantTreeB", 42)


def giant_tree_c():
    return giant_tree("GiantTreeC", 43)


def peak(b, base, radius, height, color, cap_color=None, cap_share=0.36, sides=8, lean=(0.0, 0.0)):
    """A cone-like peak: a tube narrowing to a point (leaning a little), with an optional cap over its top share."""
    tip = base + Vector((lean[0] * height, lean[1] * height, height))
    middle = base.lerp(tip, 0.55) + Vector((lean[0] * height * 0.1, 0, 0))
    portal_kit.tube(b, [base, middle, tip], [radius, radius * 0.5, 0.05], color, sides=sides)
    if cap_color:
        start = base.lerp(tip, 1 - cap_share)
        portal_kit.tube(b, [start, tip + Vector((0, 0, 0.05))], [radius * 0.5 * (cap_share / 0.45) + 0.05, 0.08], cap_color, sides=sides)


def mountain_snow():
    """A far mountain range piece: four rounded peaks of different heights with snow caps, rocky shoulders and green
    foothills at their feet; about 30 wide and 10 tall."""
    colors = {"rock": (112, 120, 142), "rock_dark": (88, 96, 120), "snow": (242, 246, 252), "foot": (98, 132, 112)}
    b = voxel_kit.Builder(colors)
    for x, radius, height, shade in ((-9.5, 6.0, 7.0, "rock_dark"), (-3.0, 7.0, 10.0, "rock"), (4.5, 6.5, 8.4, "rock"), (10.5, 5.0, 5.8, "rock_dark")):
        peak(b, Vector((x, 0, -0.5)), radius, height, shade, cap_color="snow", sides=9, lean=(0.02, 0))
    for x, size in ((-12.0, 3.4), (-5.5, 4.0), (1.5, 4.4), (8.0, 3.8), (13.5, 3.0)):
        b.blob((x, -1.2, 0.2), (size, size * 0.8, size * 0.42), "foot", BONE, segments=9, rings=5)
    return colors, [b.to_object("Frame")]


def mountain_dark():
    """A far jagged range piece for Ember Ridge: crooked dark basalt spires of mixed heights, leaning, on a rough
    shoulder; about 30 wide and 10 tall."""
    colors = {"basalt": (56, 48, 58), "basalt_dark": (38, 32, 42), "basalt_light": (78, 68, 78)}
    rng = random.Random(51)
    b = voxel_kit.Builder(colors)
    b.blob((0, 0, 0.6), (15.0, 4.2, 2.2), "basalt_dark", BONE, segments=14, rings=6)
    spires = ((-11.0, 3.6, 6.2), (-6.5, 4.4, 9.0), (-2.0, 3.0, 6.8), (2.5, 4.8, 10.0), (7.5, 3.8, 7.4), (11.5, 3.2, 5.6))
    for i, (x, radius, height) in enumerate(spires):
        lean = (rng.uniform(-0.12, 0.12), rng.uniform(-0.05, 0.05))
        peak(b, Vector((x, rng.uniform(-0.6, 0.6), 0.2)), radius, height, ("basalt", "basalt_light", "basalt_dark")[i % 3], sides=6, lean=lean)
        side = Vector((x + rng.uniform(-1.5, 1.5), rng.uniform(-1.0, 1.0), 0.6))
        peak(b, side, radius * 0.45, height * 0.45, "basalt_light", sides=5, lean=(rng.uniform(-0.25, 0.25), 0))
    return colors, [b.to_object("Frame")]


PROPS = {
    "GiantTreeA": giant_tree_a,
    "GiantTreeB": giant_tree_b,
    "GiantTreeC": giant_tree_c,
    "MountainSnow": mountain_snow,
    "MountainDark": mountain_dark,
}


def run():
    wanted = [name for name in os.environ.get("PROPS", ",".join(PROPS)).split(",") if name]
    for name in wanted:
        portal_kit.begin(name)
        colors, objects = PROPS[name]()
        total = sum(portal_kit.triangles(o) for o in objects)
        assert total <= CAP, f"{name} has {total} triangles (cap {CAP})"
        portal_kit.export(name, objects, colors)
        print(f"OK {name} {total} tris")


if __name__ == "__main__":  # render_valley_props.py imports the builders without running them (MODULE=build_valley_backdrop)
    run()
