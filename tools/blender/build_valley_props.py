"""Builds the Wild valley's scenery props (spec 2026-11-04-valley-scenery-design, plan 2026-11-04-valley-scenery):
the Caves' glow mushroom hollow, the Meadow's ancient ruins and Ember Ridge's ember forest, in the arena props' smooth
stylized look (build_arena_props.py) on voxel_kit and portal_kit.

Each prop is its own .blend and FBX in assets/blender/<Name>/ (portal_kit.export): Frame (palette texture) and, for the
glowing ones, Glow (palette white; the game turns it Neon in each spot's colour, Config/WildValley GLOW). Blender: Z up,
1 unit = 1 stud, origin at the bottom centre, front facing -Y; the game scales each prop by its height, so only
proportions matter. Run in a background Blender (it clears the scene):
  blender -b --factory-startup --python tools/blender/build_valley_props.py
PROPS="A,B" builds only those, EXPORT=0 builds without saving. Each prop stays under 2000 triangles (the dragon
skeleton, a landmark, under 4000).
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
PROP_CAP = 2000
LANDMARK_CAP = 4000
GLOW = (255, 255, 255)  # the game recolours it


def tilt(degrees, axis="Y"):
    return Matrix.Rotation(math.radians(degrees), 3, axis)


# ---------------------------------------------------------------------------------------------------------- the Caves

def mushroom(frame, glow, base, height, cap, lean=(0.0, 0.0), spots=3, rng=None):
    """One mushroom from base: a curved pale stem, darker gills under a domed glowing cap, white spots on the cap."""
    base = Vector(base)
    top = base + Vector((lean[0] * height, lean[1] * height, height))
    middle = base.lerp(top, 0.5) + Vector((lean[0] * height * 0.15, lean[1] * height * 0.15, 0))
    portal_kit.tube(frame, [base - Vector((0, 0, 0.1)), middle, top], [cap * 0.36, cap * 0.28, cap * 0.24], "stem", sides=7)
    frame.blob(base + Vector((0, 0, 0.05)), (cap * 0.42, cap * 0.42, cap * 0.18), "stem_dark", BONE, segments=8, rings=4)
    frame.blob(top + Vector((0, 0, cap * 0.08)), (cap * 0.88, cap * 0.88, cap * 0.16), "gill", BONE, segments=10, rings=4)
    glow.blob(top + Vector((0, 0, cap * 0.22)), (cap, cap, cap * 0.55), "glow", BONE, segments=12, rings=6)
    rng = rng or random.Random(1)
    for i in range(spots):
        a = i / spots * math.tau + rng.uniform(-0.4, 0.4)
        r = cap * rng.uniform(0.35, 0.6)
        z = cap * 0.22 + cap * 0.55 * math.sqrt(max(0.0, 1 - (r / cap) ** 2)) - cap * 0.04
        frame.blob(top + Vector((math.cos(a) * r, math.sin(a) * r, z)), (cap * 0.13, cap * 0.13, cap * 0.06), "spot", BONE, segments=6, rings=3)


def mushroom_colors():
    return {"stem": (226, 230, 236), "stem_dark": (150, 170, 178), "gill": (70, 90, 120), "spot": (240, 250, 255),
            "moss": (70, 120, 90), "glow": GLOW}


def glow_mushroom_tall():
    """A tall single glowing mushroom, its stem curving a little, a broad domed cap."""
    colors = mushroom_colors()
    frame, glow = voxel_kit.Builder(colors), voxel_kit.Builder(colors)
    mushroom(frame, glow, (0, 0, 0), 3.0, 1.5, lean=(0.06, 0.02), spots=4, rng=random.Random(2))
    frame.blob((0, 0, 0.05), (0.9, 0.8, 0.22), "moss", BONE, segments=8, rings=4)
    return colors, [frame.to_object("Frame"), glow.to_object("Glow")]


def glow_mushroom_cluster():
    """Three glowing mushrooms of different sizes leaning out of one mossy mound."""
    colors = mushroom_colors()
    frame, glow = voxel_kit.Builder(colors), voxel_kit.Builder(colors)
    rng = random.Random(3)
    frame.blob((0, 0, 0.05), (1.3, 1.1, 0.35), "moss", BONE, segments=10, rings=5)
    mushroom(frame, glow, (0, 0, 0.1), 2.6, 1.1, lean=(-0.05, 0.03), spots=3, rng=rng)
    mushroom(frame, glow, (0.75, -0.35, 0.05), 1.7, 0.75, lean=(0.22, -0.1), spots=2, rng=rng)
    mushroom(frame, glow, (-0.6, -0.5, 0.05), 1.1, 0.55, lean=(-0.25, -0.15), spots=2, rng=rng)
    return colors, [frame.to_object("Frame"), glow.to_object("Glow")]


def glow_mushroom_small():
    """A short wide flat-capped mushroom with two tiny ones at its foot."""
    colors = mushroom_colors()
    frame, glow = voxel_kit.Builder(colors), voxel_kit.Builder(colors)
    rng = random.Random(4)
    mushroom(frame, glow, (0, 0, 0), 0.7, 0.9, spots=3, rng=rng)
    mushroom(frame, glow, (0.75, 0.2, 0), 0.35, 0.3, lean=(0.2, 0), spots=1, rng=rng)
    mushroom(frame, glow, (-0.55, -0.45, 0), 0.25, 0.22, lean=(-0.2, -0.1), spots=1, rng=rng)
    return colors, [frame.to_object("Frame"), glow.to_object("Glow")]


def glow_tuft():
    """A leafy cave plant: curled leaves fanning out of a clump, each tip a small glowing bulb."""
    colors = {"leaf": (40, 96, 104), "leaf_light": (64, 132, 140), "glow": GLOW}
    frame, glow = voxel_kit.Builder(colors), voxel_kit.Builder(colors)
    rng = random.Random(5)
    frame.blob((0, 0, 0.08), (0.3, 0.3, 0.12), "leaf", BONE, segments=8, rings=4)
    leaves = 7
    for i in range(leaves):
        a = i / leaves * math.tau + rng.uniform(-0.3, 0.3)
        reach = rng.uniform(0.5, 0.85)
        rise = rng.uniform(0.7, 1.2)
        out = Vector((math.cos(a), math.sin(a), 0))
        points = [Vector((0, 0, 0.1)), out * reach * 0.4 + Vector((0, 0, rise * 0.7)), out * reach + Vector((0, 0, rise))]
        portal_kit.tube(frame, points, [0.07, 0.06, 0.03], "leaf" if i % 2 else "leaf_light", sides=4)
        glow.blob(points[-1] + Vector((0, 0, 0.05)), (0.09, 0.09, 0.11), "glow", BONE, segments=6, rings=4)
    return colors, [frame.to_object("Frame"), glow.to_object("Glow")]


def glow_flowers():
    """A tuft of thin stems, each bending over into a glowing bell flower."""
    colors = {"stem": (56, 112, 80), "leaf": (44, 92, 70), "glow": GLOW}
    frame, glow = voxel_kit.Builder(colors), voxel_kit.Builder(colors)
    rng = random.Random(6)
    for i in range(3):
        a = i / 3 * math.tau
        frame.blob((math.cos(a) * 0.18, math.sin(a) * 0.18, 0.06), (0.22, 0.1, 0.06), "leaf", BONE, rot=tilt(math.degrees(a), "Z"), segments=6, rings=3)
    stems = 5
    for i in range(stems):
        a = i / stems * math.tau + rng.uniform(-0.4, 0.4)
        out = Vector((math.cos(a), math.sin(a), 0))
        height = rng.uniform(0.7, 1.05)
        tip = out * 0.35 + Vector((0, 0, height))
        hang = tip + out * 0.12 - Vector((0, 0, 0.1))
        portal_kit.tube(frame, [Vector((0, 0, 0)), out * 0.12 + Vector((0, 0, height * 0.6)), tip], [0.035, 0.03, 0.025], "stem", sides=4)
        glow.blob(hang, (0.12, 0.12, 0.14), "glow", BONE, segments=7, rings=4)
    return colors, [frame.to_object("Frame"), glow.to_object("Glow")]


def moss_rock(seed, lumps):
    """A rounded limestone rock (one or two lumps), lightly dented, with a thick moss cap and a moss drip or two."""
    colors = {"rock": (150, 146, 140), "rock_dark": (118, 114, 110), "moss": (86, 140, 72), "moss_light": (120, 170, 90)}
    rng = random.Random(seed)
    b = voxel_kit.Builder(colors)
    before = len(b.bm.verts)
    for i, (x, size) in enumerate(lumps):
        b.blob((x, 0, size * 0.45), (size, size * 0.85, size * 0.62), "rock" if i == 0 else "rock_dark", BONE, segments=10, rings=7)
    for vert in list(b.bm.verts)[before:]:
        push = 1 + rng.uniform(-0.07, 0.07)
        vert.co.x *= push
        vert.co.y *= push
    for i, (x, size) in enumerate(lumps):
        b.blob((x, 0, size * 0.86), (size * 0.66, size * 0.58, size * 0.26), "moss" if i == 0 else "moss_light", BONE, segments=10, rings=5)
        for a in (-0.9, 0.4, 2.3):
            b.blob((x + math.cos(a) * size * 0.62, math.sin(a) * size * 0.52, size * 0.62), (size * 0.2, size * 0.2, size * 0.24), "moss", BONE, segments=6, rings=4)
    return colors, [b.to_object("Frame")]


def moss_rock_a():
    return moss_rock(7, [(0, 1.0)])


def moss_rock_b():
    return moss_rock(8, [(-0.35, 0.9), (0.75, 0.6)])


# --------------------------------------------------------------------------------------------------------- the Meadow

def ruin_colors():
    return {"stone": (196, 188, 170), "stone_dark": (152, 146, 132), "moss": (98, 150, 70), "vine": (70, 124, 56),
            "leaf": (92, 160, 72), "pink": (238, 140, 170), "yellow": (246, 214, 96), "white": (244, 240, 230)}


def vine(b, rng, top, length, sway=0.25):
    """A vine hanging from top, a few leaves and a flower or two along it."""
    points = [top]
    for i in range(3):
        points.append(points[-1] + Vector((rng.uniform(-sway, sway), rng.uniform(-0.05, 0.05), -length / 3)))
    portal_kit.tube(b, points, [0.07, 0.06, 0.05, 0.03], "vine", sides=4)
    for p in points[1:]:
        b.blob(p + Vector((0.08, -0.06, 0)), (0.14, 0.06, 0.1), "leaf", BONE, segments=5, rings=3)
    flower = rng.choice(("pink", "yellow", "white"))
    b.blob(points[1] + Vector((0, -0.1, 0)), (0.1, 0.06, 0.1), flower, BONE, segments=6, rings=3)


def flower_clump(b, rng, centre, count=3):
    for _ in range(count):
        p = Vector(centre) + Vector((rng.uniform(-0.3, 0.3), rng.uniform(-0.3, 0.3), 0))
        b.blob(p + Vector((0, 0, 0.12)), (0.11, 0.11, 0.08), rng.choice(("pink", "yellow", "white")), BONE, segments=6, rings=3)
        b.blob(p + Vector((0, 0, 0.04)), (0.16, 0.16, 0.05), "leaf", BONE, segments=6, rings=3)


def pillar(b, rng, base, height, radius=0.55, broken=False):
    """A round column on a square base, slightly tapered, a capital on top (or a broken jagged top), moss on its crown."""
    base = Vector(base)
    b.round_box(base + Vector((0, 0, 0.25)), (radius * 2.6, radius * 2.6, 0.5), "stone_dark", BONE, bevel=0.35)
    top = base + Vector((0, 0, height - (0 if broken else 0.5)))
    portal_kit.tube(b, [base + Vector((0, 0, 0.45)), top], [radius, radius * 0.9], "stone", sides=8)
    if broken:
        for i in range(3):
            a = i / 3 * math.tau + rng.uniform(-0.3, 0.3)
            b.blob(top + Vector((math.cos(a) * radius * 0.4, math.sin(a) * radius * 0.4, rng.uniform(0.0, 0.3))),
                   (radius * 0.5, radius * 0.45, radius * 0.5), "stone", BONE, segments=6, rings=4)
        b.blob(top + Vector((0, 0, 0.1)), (radius * 0.85, radius * 0.85, 0.2), "moss", BONE, segments=8, rings=4)
    else:
        b.round_box(top + Vector((0, 0, 0.25)), (radius * 2.4, radius * 2.4, 0.5), "stone_dark", BONE, bevel=0.35)
        b.blob(top + Vector((0.1, 0, 0.55)), (radius * 0.95, radius * 0.9, 0.18), "moss", BONE, segments=8, rings=4)
    return top


def ruin_arch():
    """A broken stone arch: two legs, the arch's stones running over from the taller leg and stopping short of the
    other, vines and flowers hanging off it, rubble at its feet. About 6 wide and 6 tall; legs at x = +-2.3."""
    colors = ruin_colors()
    b = voxel_kit.Builder(colors)
    rng = random.Random(9)
    left = pillar(b, rng, (-2.3, 0, 0), 4.2, radius=0.72)
    pillar(b, rng, (2.3, 0, 0), 3.4, radius=0.72, broken=True)
    # voussoirs: wedge-ish blocks along a half circle from the left capital, stopping two-thirds of the way over
    centre = Vector((0, 0, left.z + 0.5))
    stones = 7
    for i in range(stones):
        if i >= 5:
            break
        a = math.pi - (i + 0.5) / stones * math.pi
        p = centre + Vector((math.cos(a) * 2.3, 0, math.sin(a) * 1.7))
        b.round_box(p, (1.25, 1.3, 0.8), "stone" if i % 2 == 0 else "stone_dark", BONE, rot=tilt(-math.degrees(a) + 90), bevel=0.3)
    for x in (-1.9, -0.9, 0.1):
        vine(b, rng, Vector((x, -0.65, centre.z + 1.3)), rng.uniform(1.4, 2.2))
    for p in ((1.4, -0.6, 0), (-1.2, 0.8, 0), (3.0, 0.4, 0)):
        b.blob(Vector(p) + Vector((0, 0, 0.2)), (0.45, 0.35, 0.3), "stone_dark", BONE, segments=6, rings=4)
    flower_clump(b, rng, (-2.9, -0.6, 0))
    flower_clump(b, rng, (2.0, -0.9, 0))
    return colors, [b.to_object("Frame")]


def ruin_pillar():
    """A whole column with a capital, moss on top and a vine wound down it."""
    colors = ruin_colors()
    b = voxel_kit.Builder(colors)
    rng = random.Random(10)
    top = pillar(b, rng, (0, 0, 0), 5.0)
    vine(b, rng, top + Vector((0.3, -0.55, 0.3)), 2.6, sway=0.15)
    flower_clump(b, rng, (0.7, -0.6, 0))
    return colors, [b.to_object("Frame")]


def ruin_pillar_broken():
    """A column snapped half way up, its jagged stump mossy, its top lying in pieces beside it."""
    colors = ruin_colors()
    b = voxel_kit.Builder(colors)
    rng = random.Random(11)
    pillar(b, rng, (0, 0, 0), 2.4, broken=True)
    b.blob((1.2, 0.4, 0.3), (0.5, 0.45, 0.32), "stone", BONE, segments=7, rings=4)
    b.blob((-0.9, -0.7, 0.22), (0.35, 0.3, 0.22), "stone_dark", BONE, segments=6, rings=4)
    flower_clump(b, rng, (-0.8, 0.6, 0))
    return colors, [b.to_object("Frame")]


def ruin_pillar_fallen():
    """A column lying in the grass in two pieces, its base block still standing at one end."""
    colors = ruin_colors()
    b = voxel_kit.Builder(colors)
    rng = random.Random(12)
    b.round_box((-3.0, 0, 0.35), (1.4, 1.4, 0.7), "stone_dark", BONE, bevel=0.35)
    portal_kit.tube(b, [Vector((-2.4, 0, 0.5)), Vector((0.2, 0.15, 0.5))], [0.55, 0.53], "stone", sides=8)
    portal_kit.tube(b, [Vector((0.6, 0.25, 0.45)), Vector((3.0, 0.7, 0.45))], [0.52, 0.5], "stone", sides=8)
    b.round_box((3.4, 0.8, 0.45), (0.6, 1.3, 1.2), "stone_dark", BONE, rot=tilt(10, "Z"), bevel=0.3)
    b.blob((-0.6, 0.05, 0.95), (0.7, 0.45, 0.14), "moss", BONE, segments=8, rings=4)
    b.blob((1.8, 0.5, 0.92), (0.6, 0.4, 0.12), "moss", BONE, segments=8, rings=4)
    flower_clump(b, rng, (0.4, -0.8, 0))
    flower_clump(b, rng, (-1.6, 0.8, 0), count=2)
    return colors, [b.to_object("Frame")]


def ruin_wall():
    """A crumbled low wall about 5 long: two rows of rounded blocks, the top row broken off at one end, moss and
    flowers along it."""
    colors = ruin_colors()
    b = voxel_kit.Builder(colors)
    rng = random.Random(13)
    for row, (z, count) in enumerate(((0.45, 5), (1.3, 4), (2.1, 2))):
        offset = 0.5 * row
        for i in range(count):
            x = -2.2 + offset + i * 1.0 + rng.uniform(-0.06, 0.06)
            shade = "stone" if (i + row) % 2 == 0 else "stone_dark"
            b.round_box((x, rng.uniform(-0.05, 0.05), z), (0.92, 0.9, 0.82), shade, BONE, rot=tilt(rng.uniform(-4, 4), "Z"), bevel=0.3)
    b.blob((-1.4, 0, 2.55), (0.7, 0.5, 0.14), "moss", BONE, segments=8, rings=4)
    b.blob((1.2, 0, 1.75), (0.8, 0.5, 0.14), "moss", BONE, segments=8, rings=4)
    vine(b, rng, Vector((-0.6, -0.5, 2.4)), 1.6, sway=0.1)
    b.blob((2.4, -0.4, 0.25), (0.4, 0.35, 0.25), "stone_dark", BONE, segments=6, rings=4)
    flower_clump(b, rng, (0.3, -0.75, 0))
    flower_clump(b, rng, (-2.0, -0.7, 0), count=2)
    return colors, [b.to_object("Frame")]


def toadstool():
    """A little red-and-white toadstool for the Meadow's fairy rings."""
    colors = {"stem": (246, 240, 228), "cap": (220, 58, 52), "spot": (255, 250, 244), "gill": (230, 214, 196)}
    b = voxel_kit.Builder(colors)
    portal_kit.tube(b, [Vector((0, 0, 0)), Vector((0.03, 0, 0.55))], [0.16, 0.13], "stem", sides=6)
    b.blob((0.03, 0, 0.58), (0.36, 0.36, 0.06), "gill", BONE, segments=8, rings=3)
    b.blob((0.03, 0, 0.62), (0.4, 0.4, 0.28), "cap", BONE, segments=10, rings=5)
    for i, (a, r) in enumerate(((0.3, 0.2), (2.2, 0.24), (4.1, 0.18), (1.2, 0.05))):
        z = 0.62 + 0.28 * math.sqrt(max(0.0, 1 - (r / 0.4) ** 2))
        b.blob((0.03 + math.cos(a) * r, math.sin(a) * r, z), (0.07, 0.07, 0.03), "spot", BONE, segments=5, rings=3)
    return colors, [b.to_object("Frame")]


# -------------------------------------------------------------------------------------------------------- Ember Ridge

def ember_branch(frame, glow, rng, start, heading, length, radius, depth):
    """A crooked charred branch; its last level ends in a glowing ember cluster (the Glow object)."""
    points = [start]
    direction = heading.normalized()
    for _ in range(2):
        direction = (direction + Vector((rng.uniform(-0.4, 0.4), rng.uniform(-0.4, 0.4), rng.uniform(-0.1, 0.25)))).normalized()
        points.append(points[-1] + direction * length / 2)
    portal_kit.tube(frame, points, [radius, radius * 0.8, radius * 0.6], "char" if depth == 0 else "char_light", sides=5)
    end = points[-1]
    if depth >= 1:
        # a burning clump of ember leaves round the branch's end, and one part way along
        for _ in range(3):
            offset = Vector((rng.uniform(-0.5, 0.5), rng.uniform(-0.5, 0.5), rng.uniform(-0.15, 0.4)))
            glow.blob(end + offset, (rng.uniform(0.55, 0.8), rng.uniform(0.55, 0.8), rng.uniform(0.4, 0.55)), "glow", BONE, segments=7, rings=4)
        glow.blob(points[1] + Vector((0, 0, 0.15)), (0.4, 0.4, 0.3), "glow", BONE, segments=6, rings=4)
        return
    for _ in range(3):
        out = Vector((rng.uniform(-1, 1), rng.uniform(-1, 1), rng.uniform(0.3, 0.9)))
        ember_branch(frame, glow, rng, end, direction * 0.4 + out.normalized(), length * 0.6, radius * 0.6, depth + 1)


def ember_tree():
    """A big charred tree (the caldera tree's shape, taller and fuller) whose crown still burns in clusters of glowing
    embers. About 8 tall."""
    colors = {"char": (30, 25, 28), "char_light": (56, 46, 48), "ash": (88, 80, 78), "glow": GLOW}
    frame, glow = voxel_kit.Builder(colors), voxel_kit.Builder(colors)
    rng = random.Random(14)
    trunk = [Vector((0, 0, -0.3)), Vector((0.25, 0.1, 2.0)), Vector((0.45, -0.05, 3.8))]
    portal_kit.tube(frame, trunk, [0.9, 0.75, 0.6], "char", sides=7)
    for angle in (30, 150, 270):
        a = math.radians(angle)
        portal_kit.tube(frame, [Vector((0, 0, 0.6)), Vector((math.cos(a) * 1.5, math.sin(a) * 1.5, -0.2))], [0.5, 0.2], "char", sides=5)
    frame.blob((0, 0, 0.0), (1.1, 1.0, 0.18), "ash", BONE, segments=8, rings=4)
    for angle in (0, 120, 240):
        a = math.radians(angle + rng.uniform(-25, 25))
        ember_branch(frame, glow, rng, trunk[-1], Vector((math.cos(a) * 0.9, math.sin(a) * 0.9, 1)), 2.6, 0.42, 0)
    return colors, [frame.to_object("Frame"), glow.to_object("Glow")]


def dragon_skeleton():
    """A giant dragon's bones half buried in the ash: a long spine curving along X with tall ribs arching out of the
    ground, a great horned skull at its +X end with a dropped jaw, a folded wing bone and a trailing tail. Its eye
    sockets glow faintly (Glow). About 12 long and 4 tall."""
    colors = {"bone": (232, 220, 196), "bone_dark": (186, 170, 146), "socket": (40, 32, 30), "ash": (70, 64, 62), "glow": GLOW}
    frame, glow = voxel_kit.Builder(colors), voxel_kit.Builder(colors)
    rng = random.Random(15)
    # an ash mound the spine sinks into
    frame.blob((-0.5, 0, -0.05), (5.4, 2.2, 0.35), "ash", BONE, segments=12, rings=5)
    spine = [Vector((-6.0, 0.6, 0.0)), Vector((-4.0, 0.2, 0.35)), Vector((-1.5, 0, 0.55)), Vector((1.2, 0, 0.6)), Vector((3.3, -0.1, 0.9)), Vector((4.4, 0, 1.6))]
    portal_kit.tube(frame, spine, [0.18, 0.28, 0.36, 0.36, 0.3, 0.26], "bone_dark", sides=7)
    for p in spine[1:5]:
        frame.blob(p + Vector((0, 0, 0.3)), (0.22, 0.2, 0.3), "bone", BONE, segments=6, rings=4)
    ribs = 5
    for i in range(ribs):
        x = -2.4 + i * 1.05
        height = 3.6 - abs(i - 2) * 0.45
        for side in (-1, 1):
            # out of the ground beside the spine, up and out, then curling back in over it like a cage
            arc = [Vector((x, side * 1.3, -0.1)), Vector((x + 0.05, side * 1.7, height * 0.5)),
                   Vector((x + 0.1, side * 1.45, height * 0.92)), Vector((x + 0.15, side * 0.65, height * 1.05))]
            portal_kit.tube(frame, arc, [0.26, 0.23, 0.19, 0.11], "bone", sides=6)
    # the skull: a long snout, a broad brow, two swept horns, a dropped lower jaw lying in front
    skull = Vector((5.4, 0, 1.8))
    frame.blob(skull, (1.35, 1.05, 0.95), "bone", BONE, segments=12, rings=7)
    frame.blob(skull + Vector((1.5, 0, -0.3)), (1.2, 0.65, 0.52), "bone", BONE, segments=10, rings=6)
    frame.blob(skull + Vector((2.5, 0, -0.42)), (0.42, 0.44, 0.36), "bone_dark", BONE, segments=8, rings=5)
    portal_kit.tube(frame, [skull + Vector((0.3, 0, -1.2)), skull + Vector((1.4, 0.1, -1.55)), skull + Vector((2.2, 0.15, -1.6))], [0.22, 0.18, 0.12], "bone_dark", sides=6)
    for side in (-1, 1):
        frame.blob(skull + Vector((0.6, side * 0.72, 0.3)), (0.38, 0.2, 0.3), "socket", BONE, segments=8, rings=5)
        glow.blob(skull + Vector((0.66, side * 0.82, 0.3)), (0.18, 0.08, 0.15), "glow", BONE, segments=6, rings=4)
        portal_kit.tube(frame, [skull + Vector((-0.5, side * 0.65, 0.7)), skull + Vector((-1.6, side * 1.15, 1.6)), skull + Vector((-2.6, side * 1.0, 1.85))], [0.3, 0.18, 0.04], "bone_dark", sides=6)
        for t in range(3):
            frame.spike(skull + Vector((1.0 + t * 0.35, side * 0.35, -0.6)), (0, 0, -1), 0.1, 0.35, "bone", BONE)
    # a folded wing: an arm bone out of the shoulders, three long finger bones fanning along the ground
    shoulder = Vector((1.0, -1.6, 2.6))
    elbow = Vector((-0.5, -3.4, 1.4))
    portal_kit.tube(frame, [Vector((1.2, -0.6, 2.4)), shoulder, elbow], [0.2, 0.18, 0.16], "bone", sides=6)
    for k in range(3):
        a = math.radians(200 + k * 25)
        tip = elbow + Vector((math.cos(a) * (3.2 - k * 0.5), math.sin(a) * 1.2 - 0.6, -1.3))
        portal_kit.tube(frame, [elbow, elbow.lerp(tip, 0.5) + Vector((0, 0, 0.3)), tip], [0.12, 0.09, 0.04], "bone_dark", sides=5)
    # loose bones in the ash
    for _ in range(3):
        a = rng.uniform(0, math.tau)
        start = Vector((rng.uniform(-4, 3), rng.uniform(1.4, 2.4) * rng.choice((-1, 1)), 0.1))
        end = start + Vector((math.cos(a) * 0.9, math.sin(a) * 0.9, 0))
        portal_kit.tube(frame, [start, end], [0.08, 0.08], "bone", sides=5)
        frame.blob(start, (0.13, 0.13, 0.1), "bone", BONE, segments=6, rings=4)
        frame.blob(end, (0.13, 0.13, 0.1), "bone", BONE, segments=6, rings=4)
    return colors, [frame.to_object("Frame"), glow.to_object("Glow")]


PROPS = {
    "GlowMushroomTall": glow_mushroom_tall,
    "GlowMushroomCluster": glow_mushroom_cluster,
    "GlowMushroomSmall": glow_mushroom_small,
    "GlowTuft": glow_tuft,
    "GlowFlowers": glow_flowers,
    "MossRockA": moss_rock_a,
    "MossRockB": moss_rock_b,
    "RuinArch": ruin_arch,
    "RuinPillar": ruin_pillar,
    "RuinPillarBroken": ruin_pillar_broken,
    "RuinPillarFallen": ruin_pillar_fallen,
    "RuinWall": ruin_wall,
    "Toadstool": toadstool,
    "EmberTree": ember_tree,
    "DragonSkeleton": dragon_skeleton,
}
CAPS = {"DragonSkeleton": LANDMARK_CAP}


def run():
    wanted = [name for name in os.environ.get("PROPS", ",".join(PROPS)).split(",") if name]
    for name in wanted:
        portal_kit.begin(name)
        colors, objects = PROPS[name]()
        total = sum(portal_kit.triangles(o) for o in objects)
        cap = CAPS.get(name, PROP_CAP)
        assert total <= cap, f"{name} has {total} triangles (cap {cap})"
        portal_kit.export(name, objects, colors)
        print(f"OK {name} {total} tris")


if __name__ == "__main__":  # render_valley_props.py imports the builders without running them
    run()
