"""Builds the Stormjack creature (a cute baby storm hydra: a chunky electric-blue body on stubby legs, three short
necks with big-eyed heads, little horn nubs and lightning-bolt tufts, a curly tail) in Blender. It's a Rare card,
so it looks friendly, not fierce: no fangs, no claws, round toe beans and blushing cheeks.

One skinned mesh with a palette texture, rigidly weighted to an armature whose bones carry the names
src/shared/Util/PetRig.luau reads: four legs (front 0_Left_Limb_0..2, hind 1_Left_Limb_0..2), its body level
(Pelvis, Spine_0/1), a five-bone tail curling up (Tail_0..4) and three necks rising from its chest (Hydra_<head>_0..2,
Hydra_<head>_3 the head) each with a little jaw (Jaw_<head>), so it trots, every neck bobs on its own and its
mouths open for its storm roar.

Blender: Z up, the creature faces -Y, its left is +X.
Run inside Blender (MCP execute or Text Editor; tools/blender/voxel_kit.py does the file, palette and export).
Writes assets/blender/Stormjack/{Stormjack.blend,.fbx,palette png}.
"""
import math
import os
import sys

from mathutils import Matrix, Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import voxel_kit  # noqa: E402

NAME = "Stormjack"

COLORS = {
    "blue": (84, 184, 240),
    "blue_dark": (52, 136, 210),
    "blue_light": (150, 220, 255),
    "belly": (250, 240, 170),
    "belly_dark": (228, 210, 130),
    "bolt": (255, 224, 60),
    "bolt_light": (255, 246, 160),
    "eye_white": (250, 250, 250),
    "eye": (30, 40, 70),
    "blush": (255, 160, 180),
    "mouth": (70, 50, 90),
    "bean": (255, 196, 210),
}

# A round little body close to the ground, on short legs
HIPS = Vector((0, 0.42, 0.78))
WAIST = Vector((0, 0.02, 0.82))
CHEST = Vector((0, -0.32, 0.88))
CHEST_FRONT = Vector((0, -0.56, 0.98))
NECK_ROOT_Z = 1.2
HIND_LEG = [(0.36, 0.42, 0.66), (0.4, 0.4, 0.36), (0.4, 0.46, 0.14), (0.4, 0.3, 0.04)]
FRONT_LEG = [(0.36, -0.34, 0.7), (0.4, -0.34, 0.38), (0.4, -0.38, 0.14), (0.4, -0.54, 0.04)]
TAIL = [(0, 0.74, 0.8), (0, 1.04, 0.66), (0.08, 1.3, 0.7), (0.16, 1.44, 0.92), (0.12, 1.38, 1.14), (0.02, 1.24, 1.18)]
FAN = [0, 46, -46]
NECK_BONES = 3
HEAD_SCALE = 1.5  # big round heads, like a baby animal
HEAD_LENGTH = 0.5 * HEAD_SCALE


def neck_points(head):
    """Short necks rising out of the chest, the middle one a little taller, the side ones leaning out."""
    a = math.radians(FAN[head])
    base = Vector((math.sin(a) * 0.26, CHEST_FRONT.y + 0.1, NECK_ROOT_Z))
    top = Vector((math.sin(a) * 1.2, -0.78, NECK_ROOT_Z + 0.55 + 0.3 * math.cos(a) ** 3))
    control = Vector((math.sin(a) * 0.6, -0.5, (base.z + top.z) / 2 + 0.1))
    points = []
    for i in range(NECK_BONES + 1):
        t = i / NECK_BONES
        points.append(base * (1 - t) ** 2 + control * 2 * t * (1 - t) + top * t * t)
    forward = Vector((math.sin(a) * 0.45, -1.0, -0.05)).normalized()
    return points, forward


def mirror(p, sx):
    return (p[0] * sx, p[1], p[2])


def rig_bones():
    bones = [
        ("Root", None, (0, 0, 0), (0, 0, 0.3)),
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
        hinge = top + (forward * 0.12 + Vector((0, 0, -0.08))) * HEAD_SCALE
        bones.append((f"Jaw_{head}", f"Hydra_{head}_3", tuple(hinge), tuple(hinge + (forward * 0.28 + Vector((0, 0, -0.04))) * HEAD_SCALE)))
    return bones


def build_body(b):
    # A chunky, rounded body: a big middle block with bevel blocks round it, a cream tummy
    for bone, centre, size in (("Pelvis", (0, 0.4, 0.8), (0.86, 0.6, 0.62)),
                               ("Spine_0", (0, 0.02, 0.84), (0.96, 0.56, 0.7)),
                               ("Spine_1", (0, -0.34, 0.9), (0.9, 0.5, 0.68))):
        c = Vector(centre)
        b.box(c, size, "blue", bone)
        b.box(c, (size[0] - 0.12, size[1] + 0.08, size[2] - 0.12), "blue", bone)  # rounds the corners
        b.box(c + Vector((0, 0, -size[2] / 2 - 0.02)), (size[0] * 0.7, size[1] * 0.9, 0.04), "belly", bone)
        b.box(c + Vector((0, 0, size[2] / 2 + 0.03)), (0.12, 0.12, 0.08), "blue_light", bone)  # soft bumps down the back
    b.box((0, -0.62, 0.92), (0.62, 0.06, 0.5), "belly", "Spine_1")  # tummy
    b.box((0, -0.64, 0.82), (0.44, 0.04, 0.12), "belly_dark", "Spine_1")


def build_legs(b):
    for side, sx in (("Left", 1), ("Right", -1)):
        for pair, leg in ((0, FRONT_LEG), (1, HIND_LEG)):
            p = [Vector(mirror(q, sx)) for q in leg]
            upper, lower, foot = (f"{pair}_{side}_Limb_{i}" for i in range(3))
            b.span(p[0], p[1], 0.34, "blue", upper, 0.08)
            b.span(p[1], p[2], 0.3, "blue", lower, 0.04)
            # A round paw with pink toe beans
            paw = p[2] + Vector((0, -0.06, -0.08))
            b.box(paw, (0.34, 0.36, 0.14), "blue_dark", foot)
            for toe in (-0.09, 0, 0.09):
                b.box(paw + Vector((toe, -0.18, -0.02)), (0.07, 0.03, 0.06), "bean", foot)


def build_tail(b):
    widths = (0.3, 0.24, 0.2, 0.17, 0.14)
    for i in range(len(TAIL) - 1):
        b.span(TAIL[i], TAIL[i + 1], widths[i], "blue", f"Tail_{i}", 0.04)
    # A little lightning bolt at the tip
    tip = Vector(TAIL[-1])
    for offset, size in (((0.0, -0.02, 0.1), (0.16, 0.06, 0.14)), ((-0.06, -0.02, 0.0), (0.16, 0.06, 0.08)), ((0.0, -0.02, -0.1), (0.16, 0.06, 0.14))):
        b.box(tip + Vector(offset), size, "bolt", "Tail_4")


def build_necks(b):
    for head in range(len(FAN)):
        points, forward = neck_points(head)
        for i in range(NECK_BONES):
            bone = f"Hydra_{head}_{i}"
            b.span(points[i], points[i + 1], 0.3, "blue", bone, 0.06)
            along = (points[i + 1] - points[i]).normalized()
            back = along.cross(Vector((1, 0, 0))).normalized()
            if back.y < 0:
                back = -back
            b.span(points[i] - back * 0.12, points[i + 1] - back * 0.12, 0.2, "belly", bone)
        build_head(b, head, points[-1], forward)


def build_head(b, head, origin, forward):
    """A round baby-dragon head: big shiny eyes, blush, a little smile, horn nubs and a lightning tuft."""
    skull, jaw = f"Hydra_{head}_3", f"Jaw_{head}"
    m = voxel_kit.frame(forward)
    b.xform = Matrix.Translation(origin) @ Matrix.Scale(HEAD_SCALE, 4) @ Matrix.Translation(-origin)

    def at(x, y, z):
        return origin + m @ Vector((x, y, z))

    b.box(at(0, 0.1, 0.06), (0.4, 0.36, 0.34), "blue", skull, m)
    b.box(at(0, 0.1, 0.06), (0.34, 0.42, 0.28), "blue", skull, m)  # rounds the corners
    b.box(at(0, 0.32, 0.0), (0.26, 0.16, 0.16), "blue_light", skull, m)  # short snout
    b.box(at(0, 0.405, 0.02), (0.08, 0.02, 0.04), "mouth", skull, m)  # nose
    for sx in (1, -1):
        b.box(at(sx * 0.11, 0.29, 0.12), (0.15, 0.02, 0.17), "eye_white", skull, m)
        b.box(at(sx * 0.1, 0.3, 0.11), (0.11, 0.02, 0.13), "eye", skull, m)
        b.box(at(sx * 0.08, 0.31, 0.15), (0.04, 0.02, 0.04), "eye_white", skull, m)  # shine
        b.box(at(sx * 0.165, 0.29, -0.01), (0.06, 0.02, 0.03), "blush", skull, m)
        b.box(at(sx * 0.1, 0.0, 0.26), (0.07, 0.07, 0.08), "bolt", skull, m)  # horn nubs
    # A lightning-bolt tuft on top
    for offset, size in (((0.0, 0.04, 0.3), (0.04, 0.06, 0.08)), ((0.03, 0.04, 0.36), (0.04, 0.06, 0.06)), ((0.0, 0.04, 0.41), (0.04, 0.06, 0.06))):
        b.box(at(*offset), size, "bolt_light", skull, m)
    # A small lower jaw with a pink mouth, opening for the storm roar
    b.box(at(0, 0.27, -0.1), (0.22, 0.2, 0.06), "belly", jaw, m)
    b.box(at(0, 0.27, -0.065), (0.16, 0.16, 0.02), "mouth", jaw, m)
    b.xform = None


def parts(b):
    build_body(b)
    build_legs(b)
    build_tail(b)
    build_necks(b)


voxel_kit.run(NAME, COLORS, rig_bones(), parts)
