"""Builds the Blazehound creature (a long little dachshund, black with tan points, droopy ears, two flame tufts on its
head and a flame on its tail tip, card art assets/ui/card-art/Blazehound.jpg) in Blender. A Rare card, so friendly:
big kind eyes, a soft snout, no fangs.

One skinned mesh with a palette texture, rigidly weighted to an armature whose bones carry the names
src/shared/Util/PetRig.luau reads: four short legs (front 0_Left_Limb_0..2, hind 1_Left_Limb_0..2), a long level body
(Pelvis, Spine_0/1), Neck, Head_0, Jaw_0 (for its sneeze), droopy ears (Ear_Left_0, Ear_Right_0, which flop) and a
thin tail curling up to a flame (Tail_0..2), so it trots on its stubby legs, its ears flop and its tail wags.

Blender: Z up, the creature faces -Y, its left is +X.
Run inside Blender (MCP execute or Text Editor; tools/blender/voxel_kit.py does the file, palette and export).
Writes assets/blender/Blazehound/{Blazehound.blend,.fbx,palette png}.
"""
import os
import sys

from mathutils import Matrix, Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import voxel_kit  # noqa: E402

NAME = "Blazehound"

COLORS = {
    "black": (36, 33, 38),
    "black_light": (62, 58, 66),
    "tan": (210, 130, 60),
    "tan_light": (234, 164, 92),
    "nose": (18, 16, 18),
    "eye": (30, 22, 18),
    "shine": (250, 250, 250),
    "mouth": (160, 60, 70),
    "flame": (255, 150, 30),
    "flame_light": (255, 225, 90),
    "flame_red": (240, 80, 30),
}

HIPS = Vector((0, 0.55, 0.64))
WAIST = Vector((0, 0.14, 0.66))
CHEST = Vector((0, -0.3, 0.68))
CHEST_FRONT = Vector((0, -0.62, 0.72))
NECK_TOP = Vector((0, -0.8, 1.0))
HEAD_TIP = Vector((0, -1.42, 0.95))
JAW_HINGE = Vector((0, -0.96, 0.86))
# The head is held up and drawn big, like the card art: built at size 1, lifted and scaled about the top of the neck
HEAD_SCALE = 1.3
HEAD_LIFT = Vector((0, 0.04, 0.14))
HEAD_XFORM = Matrix.Translation(NECK_TOP + HEAD_LIFT) @ Matrix.Scale(HEAD_SCALE, 4) @ Matrix.Translation(-NECK_TOP)


def head_point(p):
    return tuple(HEAD_XFORM @ Vector(p))
FRONT_LEG = [(0.24, -0.52, 0.52), (0.25, -0.52, 0.3), (0.25, -0.56, 0.12), (0.25, -0.72, 0.04)]
HIND_LEG = [(0.24, 0.52, 0.52), (0.25, 0.48, 0.32), (0.25, 0.56, 0.12), (0.25, 0.42, 0.04)]
TAIL = [(0, 0.86, 0.74), (0, 1.06, 0.94), (0, 1.16, 1.18), (0, 1.18, 1.4)]


def mirror(p, sx):
    return (p[0] * sx, p[1], p[2])


def side_name(sx):
    return "Left" if sx > 0 else "Right"


def rig_bones():
    bones = [
        ("Root", None, (0, 0, 0), (0, 0, 0.3)),
        ("Pelvis", "Root", tuple(HIPS), tuple(WAIST)),
        ("Spine_0", "Pelvis", tuple(WAIST), tuple(CHEST)),
        ("Spine_1", "Spine_0", tuple(CHEST), tuple(CHEST_FRONT)),
        ("Neck", "Spine_1", tuple(CHEST_FRONT), head_point(NECK_TOP)),
        ("Head_0", "Neck", head_point(NECK_TOP), head_point(HEAD_TIP)),
        ("Jaw_0", "Head_0", head_point(JAW_HINGE), head_point((0, -1.36, 0.82))),
    ]
    for i in range(len(TAIL) - 1):
        bones.append((f"Tail_{i}", "Pelvis" if i == 0 else f"Tail_{i - 1}", TAIL[i], TAIL[i + 1]))
    for sx in (1, -1):
        side = side_name(sx)
        # Droopy ears hang down from the top of the head
        bones.append((f"Ear_{side}_0", "Head_0", head_point((sx * 0.24, -0.86, 1.18)), head_point((sx * 0.3, -0.86, 0.86))))
        for pair, leg, parent in ((0, FRONT_LEG, "Spine_1"), (1, HIND_LEG, "Pelvis")):
            for i in range(3):
                bone_parent = parent if i == 0 else f"{pair}_{side}_Limb_{i - 1}"
                bones.append((f"{pair}_{side}_Limb_{i}", bone_parent, mirror(leg[i], sx), mirror(leg[i + 1], sx)))
    return bones


def build_body(b):
    # A long, low sausage body: black on top, a tan chest and belly
    for bone, centre, size in (("Pelvis", (0, 0.52, 0.66), (0.56, 0.62, 0.46)),
                               ("Spine_0", (0, 0.1, 0.67), (0.58, 0.56, 0.48)),
                               ("Spine_1", (0, -0.38, 0.69), (0.6, 0.56, 0.5))):
        c = Vector(centre)
        b.box(c, size, "black", bone)
        b.box(c, (size[0] - 0.08, size[1] + 0.06, size[2] - 0.08), "black", bone)  # rounds the corners
        b.box(c + Vector((0, 0, -size[2] / 2 - 0.01)), (size[0] * 0.6, size[1] * 0.8, 0.03), "tan", bone)
        b.box(c + Vector((0, 0, size[2] / 2 + 0.01)), (size[0] * 0.3, size[1] * 0.9, 0.02), "black_light", bone)
    b.box((0, -0.67, 0.64), (0.4, 0.04, 0.3), "tan", "Spine_1")  # tan chest
    b.box((0, -0.76, 0.92), (0.36, 0.32, 0.42), "black", "Neck")


def build_head(b):
    h, jaw = "Head_0", "Jaw_0"
    b.xform = HEAD_XFORM
    b.box((0, -0.98, 1.06), (0.46, 0.46, 0.4), "black", h)
    b.box((0, -0.98, 1.06), (0.4, 0.52, 0.34), "black", h)  # rounds the corners
    b.box((0, -1.32, 0.98), (0.28, 0.4, 0.2), "black", h)  # long snout
    b.box((0, -1.32, 0.9), (0.3, 0.38, 0.06), "tan", h)  # tan under the snout
    b.box((0, -1.53, 1.02), (0.12, 0.04, 0.09), "nose", h)
    for sx in (1, -1):
        b.box((sx * 0.13, -1.252, 1.13), (0.14, 0.02, 0.13), "shine", h)  # eye whites, so the eyes show on black
        b.box((sx * 0.12, -1.262, 1.12), (0.09, 0.02, 0.1), "eye", h)
        b.box((sx * 0.1, -1.272, 1.15), (0.035, 0.02, 0.035), "shine", h)
        b.box((sx * 0.13, -1.252, 1.22), (0.07, 0.02, 0.04), "tan_light", h)  # tan eyebrow dots
        b.box((sx * 0.16, -1.15, 0.94), (0.06, 0.2, 0.06), "tan", h)  # tan cheeks
    # Little lower jaw, for the sneeze
    b.box((0, -1.24, 0.84), (0.24, 0.3, 0.06), "tan", jaw)
    b.box((0, -1.24, 0.875), (0.18, 0.24, 0.02), "mouth", jaw)
    # Two flame tufts on top of the head
    for sx in (1, -1):
        base = Vector((sx * 0.1, -0.96, 1.26))
        b.box(base, (0.1, 0.1, 0.06), "flame_red", h)
        b.spike(base + Vector((0, 0, 0.02)), (sx * 0.15, 0.1, 1), 0.12, 0.26, "flame", h)
        b.spike(base + Vector((0, -0.01, 0.06)), (0, 0, 1), 0.06, 0.16, "flame_light", h)
    for sx in (1, -1):
        ear = f"Ear_{side_name(sx)}_0"
        b.box((sx * 0.27, -0.88, 1.04), (0.06, 0.24, 0.34), "black", ear)
        b.box((sx * 0.27, -0.88, 0.86), (0.06, 0.2, 0.06), "black_light", ear)
    b.xform = None


def build_legs(b):
    for sx in (1, -1):
        side = side_name(sx)
        for pair, leg in ((0, FRONT_LEG), (1, HIND_LEG)):
            p = [Vector(mirror(q, sx)) for q in leg]
            upper, lower, foot = (f"{pair}_{side}_Limb_{i}" for i in range(3))
            b.span(p[0], p[1], 0.2, "black", upper, 0.05)
            b.span(p[1], p[2], 0.17, "tan", lower, 0.03)
            b.box(p[2] + Vector((0, -0.05, -0.06)), (0.2, 0.26, 0.1), "tan", foot)
            for toe in (-0.05, 0.05):
                b.box(p[2] + Vector((toe, -0.18, -0.07)), (0.04, 0.02, 0.05), "tan_light", foot)


def build_tail(b):
    widths = (0.1, 0.08, 0.07)
    for i in range(len(TAIL) - 1):
        b.span(TAIL[i], TAIL[i + 1], widths[i], "black", f"Tail_{i}", 0.02)
    tip = Vector(TAIL[-1])
    b.box(tip, (0.12, 0.12, 0.08), "flame_red", "Tail_2")
    b.spike(tip + Vector((0, 0, 0.02)), (0, 0.1, 1), 0.16, 0.32, "flame", "Tail_2")
    b.spike(tip + Vector((0, -0.02, 0.06)), (0, 0, 1), 0.08, 0.2, "flame_light", "Tail_2")


def parts(b):
    build_body(b)
    build_head(b)
    build_legs(b)
    build_tail(b)


voxel_kit.run(NAME, COLORS, rig_bones(), parts)
