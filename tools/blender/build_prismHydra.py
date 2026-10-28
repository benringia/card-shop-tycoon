"""Builds the Prism Hydra, the final boss (Config/Bosses prismHydra, spec 2026-10-29-dungeon-final-boss-design.md),
in a faceted low-poly "studded" style (the look the user showed as references, our own creature): chunky chamfered
shapes, small raised square studs scattered over the hide, a bold base colour with cream and gold accents, glowing
eyes and crystals. A heavy brute on thick legs with five big horned heads, a gold collar where the necks meet, prism
crystal shards down its back and a crystal gem on every forehead. All five heads share one colour (so it doesn't read
as the famous five-coloured dragon); in game only the active phase's head glows its element colour (MonsterController).

One skinned mesh with a palette texture, rigidly weighted to an armature whose bones carry the names
src/shared/Util/PetRig.luau reads: four legs (front 0_<side>_Limb_0..2, hind 1_<side>_Limb_0..2), Pelvis and
Spine_0/1 level, Tail_0..4, five necks Hydra_<head>_0..2 with the head Hydra_<head>_3 and a jaw Jaw_<head>.
Heads: 0 in the middle, then 1/2 and 3/4 outwards (left, right); their elements are Config/Bosses prismHydra.heads.

Blender: Z up, the creature faces -Y, its left is +X.
Run inside Blender (MCP execute or Text Editor; tools/blender/voxel_kit.py does the file, palette and export).
Writes assets/blender/PrismHydra/{PrismHydra.blend,.fbx,palette png}.
"""
import math
import os
import random
import sys

from mathutils import Matrix, Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import voxel_kit  # noqa: E402

NAME = "PrismHydra"

COLORS = {
    "hide": (58, 50, 104),
    "hide_dark": (40, 34, 76),
    "hide_stud": (86, 76, 144),
    "bone": (238, 226, 198),
    "bone_stud": (212, 198, 166),
    "gold": (255, 190, 60),
    "gold_dark": (212, 138, 32),
    "crystal": (120, 230, 255),
    "crystal_pink": (255, 120, 220),
    "eye": (255, 196, 54),
    "eye_core": (255, 248, 206),
    "mouth": (72, 24, 62),
    "teeth": (250, 246, 236),
}
STUD = {"hide": "hide_stud", "hide_dark": "hide_stud", "bone": "bone_stud"}
RNG = random.Random(4242)

# A heavy brute: hips at the back (+Y), a big chest at the front (-Y); the necks leave the top of the chest
HIPS = Vector((0, 0.75, 1.1))
WAIST = Vector((0, 0.1, 1.2))
CHEST = Vector((0, -0.45, 1.3))
CHEST_FRONT = Vector((0, -0.95, 1.42))
NECK_ROOT_Z = 1.8
# Thick legs (one side, +X): hip/shoulder, knee/elbow, ankle, toes
FRONT_LEG = [(0.86, -0.55, 1.0), (0.92, -0.6, 0.55), (0.92, -0.62, 0.2), (0.92, -0.86, 0.05)]
HIND_LEG = [(0.82, 0.78, 0.92), (0.88, 0.86, 0.52), (0.88, 0.78, 0.2), (0.88, 0.54, 0.05)]
TAIL = [(0, 1.25, 1.02), (0, 1.85, 0.84), (0, 2.42, 0.68), (0, 2.95, 0.56), (0, 3.4, 0.5), (0, 3.78, 0.48)]
# Heads: 0 in the middle and tallest, then outwards alternating sides (fan angle in degrees, + is the left)
FAN = [0, 34, -34, 64, -64]
NECK_BONES = 3
HEAD_SCALE = 1.3  # heads are built at size 1 and scaled up about the top of their neck
HEAD_LENGTH = 1.1 * HEAD_SCALE


def neck_points(head):
    """Points along one thick neck, base to head: up out of the chest and out to its own place in the fan."""
    a = math.radians(FAN[head])
    reach = 0.25 if head % 2 == 1 else 0.0
    base = Vector((math.sin(a) * 0.5, CHEST_FRONT.y + 0.25, NECK_ROOT_Z))
    top = Vector((math.sin(a) * 3.0, -1.5 - reach, NECK_ROOT_Z + 0.8 + 1.05 * math.cos(a) ** 2))
    control = Vector((math.sin(a) * 1.6, -0.8, (base.z + top.z) / 2 + 0.25))
    points = []
    for i in range(NECK_BONES + 1):
        t = i / NECK_BONES
        points.append(base * (1 - t) ** 2 + control * 2 * t * (1 - t) + top * t * t)
    forward = Vector((math.sin(a) * 0.3, -1.0, -0.08)).normalized()
    return points, forward


def mirror(p, sx):
    return (p[0] * sx, p[1], p[2])


def rig_bones():
    bones = [
        ("Root", None, (0, 0, 0), (0, 0, 0.4)),
        ("Pelvis", "Root", tuple(HIPS), tuple(WAIST)),
        ("Spine_0", "Pelvis", tuple(WAIST), tuple(CHEST)),
        ("Spine_1", "Spine_0", tuple(CHEST), tuple(CHEST_FRONT)),
    ]
    for i in range(len(TAIL) - 1):
        bones.append((f"Tail_{i}", "Pelvis" if i == 0 else f"Tail_{i - 1}", TAIL[i], TAIL[i + 1]))
    for side, sx in (("Left", 1), ("Right", -1)):
        for pair, leg, parent in ((0, FRONT_LEG, "Spine_1"), (1, HIND_LEG, "Pelvis")):
            for i in range(3):
                bone_parent = parent if i == 0 else f"{pair}_{side}_Limb_{i - 1}"
                bones.append((f"{pair}_{side}_Limb_{i}", bone_parent, mirror(leg[i], sx), mirror(leg[i + 1], sx)))
    for head in range(len(FAN)):
        points, forward = neck_points(head)
        for i in range(NECK_BONES):
            parent = "Spine_1" if i == 0 else f"Hydra_{head}_{i - 1}"
            bones.append((f"Hydra_{head}_{i}", parent, tuple(points[i]), tuple(points[i + 1])))
        top = points[-1]
        bones.append((f"Hydra_{head}_3", f"Hydra_{head}_{NECK_BONES - 1}", tuple(top), tuple(top + forward * HEAD_LENGTH)))
        hinge = top + (forward * 0.2 + Vector((0, 0, -0.18))) * HEAD_SCALE
        bones.append((f"Jaw_{head}", f"Hydra_{head}_3", tuple(hinge), tuple(hinge + (forward * 0.75 + Vector((0, 0, -0.08))) * HEAD_SCALE)))
    return bones


def chunk(b, center, size, color, bone, rot=None, bevel=0.3, studs=3.0, skip=("-z",)):
    """The faceted look: a box with chamfered edges (one flat bevel), and small square studs scattered over its faces
    (`studs` per square metre, never on the faces in `skip`)."""
    b.round_box(center, size, color, bone, rot, bevel=bevel, segments=1)
    stud_color = STUD.get(color)
    if not stud_color or studs <= 0:
        return
    c, r = Vector(center), rot if rot is not None else Matrix.Identity(3)
    half = [size[0] / 2, size[1] / 2, size[2] / 2]
    inset = min(size) * bevel * 0.5  # the chamfer eats this much of every face's edge
    s, h = 0.14, 0.05
    for axis in range(3):
        for sign in (1, -1):
            if ("+" if sign > 0 else "-") + "xyz"[axis] in skip:
                continue
            u, v = (i for i in range(3) if i != axis)
            room_u, room_v = half[u] - inset - s, half[v] - inset - s
            if room_u <= 0 or room_v <= 0:
                continue
            for _ in range(int(size[u] * size[v] * studs)):
                p = [0.0, 0.0, 0.0]
                p[axis] = sign * (half[axis] + h / 2 - 0.01)
                p[u] = RNG.uniform(-room_u, room_u)
                p[v] = RNG.uniform(-room_v, room_v)
                dims = [s, s, s]
                dims[axis] = h
                b.box(c + r @ Vector(p), dims, stud_color, bone, r)


def build_body(b):
    # A big chest and shoulders, a lower back, the cream belly underneath
    chunk(b, (0, 0.72, 1.1), (1.9, 1.1, 1.3), "hide", "Pelvis")
    chunk(b, (0, 0.08, 1.2), (2.2, 1.0, 1.5), "hide", "Spine_0")
    chunk(b, (0, -0.55, 1.36), (2.3, 1.0, 1.65), "hide", "Spine_1")
    chunk(b, (0, 0.05, 0.56), (1.6, 2.0, 0.36), "bone", "Spine_0", studs=1.8, skip=("-z", "+z"))
    chunk(b, (0, -1.06, 1.28), (1.4, 0.2, 1.0), "bone", "Spine_1", studs=2.2, skip=("-z", "-y"))
    # The gold collar where the necks meet, a crystal gem at its front
    b.round_box((0, -0.98, 1.94), (1.9, 0.5, 0.26), "gold", "Spine_1", bevel=0.4, segments=1)
    b.spike((0, -1.24, 1.9), (0, -1, 0.15), 0.34, 0.3, "crystal", "Spine_1")
    b.spike((0, -1.2, 1.9), (0, -1, -0.6), 0.26, 0.32, "crystal", "Spine_1")


def build_crown(b):
    """Prism crystal shards down the back, biggest over the shoulders"""
    for y, z, size, bone in ((-0.4, 2.16, 1.0, "Spine_1"), (0.1, 1.96, 0.85, "Spine_0"), (0.62, 1.76, 0.7, "Pelvis"), (1.0, 1.7, 0.5, "Pelvis")):
        b.spike((0, y, z), (0, 0.25, 1), size * 0.55, size, "crystal_pink", bone)
        for sx in (1, -1):
            b.spike((sx * 0.42, y + 0.08, z - 0.12), (sx * 0.55, 0.25, 1), size * 0.36, size * 0.62, "crystal", bone)


def build_legs(b):
    for side, sx in (("Left", 1), ("Right", -1)):
        for pair, leg in ((0, FRONT_LEG), (1, HIND_LEG)):
            p = [Vector(mirror(q, sx)) for q in leg]
            upper, lower, foot = (f"{pair}_{side}_Limb_{i}" for i in range(3))
            chunk(b, p[0].lerp(p[1], 0.45), (0.86, 0.86, 0.72), "hide", upper, studs=2.2)
            chunk(b, p[1].lerp(p[2], 0.5), (0.72, 0.72, 0.5), "hide_dark", lower, studs=2.2)
            paw = p[2] + Vector((0, (p[3] - p[2]).y * 0.35, -0.08))
            chunk(b, paw, (0.86, 0.9, 0.3), "bone", foot, studs=1.8, skip=("-z", "+z"))
            for toe in (-0.26, 0, 0.26):  # gold claws
                b.spike(paw + Vector((toe, -0.45, -0.04)), (0, -1, -0.3), 0.16, 0.24, "gold", foot)


def build_tail(b):
    sizes = (0.8, 0.66, 0.54, 0.44, 0.34)
    for i in range(len(TAIL) - 1):
        a, c = Vector(TAIL[i]), Vector(TAIL[i + 1])
        rot = (c - a).to_track_quat("Z", "Y").to_matrix()
        chunk(b, a.lerp(c, 0.5), (sizes[i], sizes[i], (c - a).length + 0.14), "hide" if i % 2 == 0 else "hide_dark", f"Tail_{i}", rot, studs=2.2, skip=())
    b.spike(Vector(TAIL[-1]), (0, 1, 0.2), 0.42, 0.7, "crystal_pink", "Tail_4")


def build_necks(b):
    for head in range(len(FAN)):
        points, forward = neck_points(head)
        for i in range(NECK_BONES):
            a, c = points[i], points[i + 1]
            rot = (c - a).to_track_quat("Z", "Y").to_matrix()
            width = 0.74 - 0.06 * i
            chunk(b, a.lerp(c, 0.5), (width, width, (c - a).length + 0.22), "hide", f"Hydra_{head}_{i}", rot, studs=2.2, skip=())
        build_head(b, head, points[-1], forward)


def build_head(b, head, origin, forward):
    """A big faceted horned head: a studded skull, a cream muzzle, glowing slanted eyes, cream horns with gold tips, a
    crystal gem on the forehead, and an open lower jaw with teeth on its own bone"""
    skull, jaw = f"Hydra_{head}_3", f"Jaw_{head}"
    m = voxel_kit.frame(forward)
    b.xform = Matrix.Translation(origin) @ Matrix.Scale(HEAD_SCALE, 4) @ Matrix.Translation(-origin)

    def at(x, y, z):
        return origin + m @ Vector((x, y, z))

    chunk(b, at(0, 0.3, 0.12), (0.96, 0.9, 0.74), "hide", skull, m, studs=2.2, skip=("-z", "+y"))
    chunk(b, at(0, 0.64, 0.02), (0.78, 0.36, 0.5), "hide", skull, m, studs=2.2, skip=("-z", "+y"))  # bridge
    chunk(b, at(0, 1.0, -0.04), (0.6, 0.6, 0.4), "bone", skull, m, studs=3.0, skip=("-z", "+y"))  # a long muzzle
    for sx in (1, -1):
        b.box(at(sx * 0.14, 1.31, 0.06), (0.1, 0.03, 0.08), "hide_dark", skull, m)  # nostril
        # Slanted glowing eyes under a heavy brow
        tilt = m @ Matrix.Rotation(math.radians(-18 * sx), 3, "Y")
        b.box(at(sx * 0.27, 0.76, 0.27), (0.3, 0.06, 0.13), "eye", skull, tilt)
        b.box(at(sx * 0.27, 0.78, 0.27), (0.12, 0.04, 0.07), "eye_core", skull, tilt)
        b.box(at(sx * 0.27, 0.75, 0.39), (0.38, 0.12, 0.09), "hide_dark", skull, tilt)
        # A cream horn sweeping out and up, gold at the tip
        root = at(sx * 0.34, 0.2, 0.42)
        bend = at(sx * 0.62, 0.08, 0.66)
        b.span(root, bend, 0.18, "bone", skull, 0.04)
        b.spike(bend, m @ Vector((sx * 0.3, -0.35, 1)), 0.16, 0.3, "gold", skull)
    b.spike(at(0, 0.66, 0.5), m @ Vector((0, 0.35, 1)), 0.2, 0.22, "crystal", skull)  # forehead gem
    b.spike(at(0, 0.66, 0.5), m @ Vector((0, -0.35, -1)), 0.2, 0.12, "crystal", skull)
    # The lower jaw, open a little, a row of teeth along the upper lip
    chunk(b, at(0, 0.82, -0.34), (0.56, 0.95, 0.18), "bone", jaw, m, studs=0)
    b.box(at(0, 0.86, -0.23), (0.42, 0.8, 0.04), "mouth", jaw, m)
    for x in (-0.2, -0.07, 0.07, 0.2):
        b.spike(at(x, 1.24, -0.22), m @ Vector((0, 0.1, -1)), 0.07, 0.13, "teeth", skull)
    for sx in (1, -1):  # fangs along the sides
        b.spike(at(sx * 0.24, 0.9, -0.22), m @ Vector((0, 0.1, -1)), 0.08, 0.17, "teeth", skull)
    b.xform = None


def parts(b):
    build_body(b)
    build_crown(b)
    build_legs(b)
    build_tail(b)
    build_necks(b)


voxel_kit.run(NAME, COLORS, rig_bones(), parts)
