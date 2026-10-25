"""Builds the Voidmaw creature (seven-headed obsidian hydra dragon with violet crystals, card art
assets/ui/card-art/Voidmaw.jpg) in Blender.

One skinned mesh with a palette texture, rigidly weighted to an armature whose bones carry the names
src/shared/Util/PetRig.luau reads: a dragon on four legs (front 0_Left_Limb_0..2, hind 1_Left_Limb_0..2), its body
level (Pelvis at the hips, Spine_0/1 forward to the chest), a six-bone tail (Tail_0..5) straight out behind and
seven necks rising from the chest (Hydra_<head>_0..2, Hydra_<head>_3 the head) each with a jaw (Jaw_<head>), so it
trots like a beast, every neck sways on its own and every jaw snaps.

Blender: Z up, the creature faces -Y, its left is +X.
Run inside Blender (MCP execute or Text Editor; tools/blender/voxel_kit.py does the file, palette and export).
Writes assets/blender/Voidmaw/{Voidmaw.blend,.fbx,palette png}.
"""
import math
import os
import sys

from mathutils import Matrix, Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import voxel_kit  # noqa: E402

NAME = "Voidmaw"

COLORS = {
    "obsidian": (36, 30, 46),
    "obsidian_mid": (54, 44, 70),
    "obsidian_light": (78, 64, 100),
    "belly": (92, 64, 132),
    "crystal": (152, 84, 234),
    "crystal_light": (206, 162, 255),
    "crystal_dark": (100, 46, 178),
    "mouth": (204, 104, 255),
    "teeth": (236, 228, 246),
    "claw": (22, 18, 30),
    "eye": (248, 218, 255),
}
CRYSTALS = ("crystal", "crystal_light", "crystal_dark")

# Body: level, hips at the back (+Y), chest at the front (-Y); the necks leave the top of the chest
HIPS = Vector((0, 0.7, 1.3))
WAIST = Vector((0, 0.15, 1.36))
CHEST = Vector((0, -0.35, 1.44))
CHEST_FRONT = Vector((0, -0.78, 1.58))
NECK_ROOT_Z = 1.82
# Legs (one side, +X): hip/shoulder, knee/elbow, ankle/wrist, toes
HIND_LEG = [(0.52, 0.68, 1.2), (0.6, 0.42, 0.72), (0.6, 0.78, 0.3), (0.6, 0.42, 0.06)]
FRONT_LEG = [(0.56, -0.5, 1.28), (0.62, -0.34, 0.76), (0.62, -0.58, 0.3), (0.62, -0.92, 0.06)]
TAIL = [(0, 0.98, 1.3), (0, 1.45, 1.14), (0.06, 1.92, 0.94), (0.2, 2.36, 0.74), (0.45, 2.72, 0.58), (0.8, 2.94, 0.5), (1.18, 2.96, 0.5)]
# Heads: 0 in the middle and tallest, then outwards alternating sides (fan angle in degrees, + is the left)
FAN = [0, 26, -26, 52, -52, 76, -76]
NECK_BONES = 3
HEAD_SCALE = 1.3  # heads are built at size 1 and scaled about the top of their neck
HEAD_LENGTH = 0.62 * HEAD_SCALE


def neck_points(head):
    """Points along one neck, base to head: up out of the chest and forward in a curve, the head looking ahead."""
    a = math.radians(FAN[head])
    reach = 0.25 if head % 2 == 1 else 0.0  # every other head reaches further forward, so they don't stand in a row
    base = Vector((math.sin(a) * 0.42, CHEST_FRONT.y + 0.12, NECK_ROOT_Z))
    top = Vector((math.sin(a) * 1.6, -1.35 - reach, NECK_ROOT_Z + 0.75 + 1.25 * math.cos(a) ** 2.2))
    control = Vector((math.sin(a) * 1.25, -0.55, (base.z + top.z) / 2 + 0.35))
    points = []
    for i in range(NECK_BONES + 1):
        t = i / NECK_BONES
        points.append(base * (1 - t) ** 2 + control * 2 * t * (1 - t) + top * t * t)
    forward = Vector((math.sin(a) * 0.35, -1.0, -0.12)).normalized()
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
        hinge = top + (forward * 0.08 + Vector((0, 0, -0.06))) * HEAD_SCALE
        bones.append((f"Jaw_{head}", f"Hydra_{head}_3", tuple(hinge), tuple(hinge + (forward * 0.45 + Vector((0, 0, -0.08))) * HEAD_SCALE)))
    return bones


def crystal_row(b, a, c, bone, count, up, size, seed=0):
    """Crystals along the line from a to c, pointing `up` (and a little back), sized `size`, alternating colours."""
    a, c, up = Vector(a), Vector(c), Vector(up)
    for i in range(count):
        t = (i + 0.5) / count
        grow = 0.75 + 0.5 * math.sin(t * math.pi)
        b.spike(a.lerp(c, t), up + Vector((0, 0.35, 0)), size * 0.5 * grow, size * grow, CRYSTALS[(i + seed) % 3], bone)


def build_body(b):
    # Level body: hips, waist and a deep chest, with pale belly plates underneath and ridges across the back
    for bone, centre, size in (("Pelvis", (0, 0.66, 1.3), (1.04, 0.78, 0.7)),
                               ("Spine_0", (0, 0.12, 1.36), (1.08, 0.66, 0.7)),
                               ("Spine_1", (0, -0.48, 1.46), (1.2, 0.72, 0.84))):
        c = Vector(centre)
        b.box(c, size, "obsidian", bone)
        b.box(c + Vector((0, 0, -size[2] / 2 - 0.02)), (size[0] * 0.6, size[1] * 0.85, 0.04), "belly", bone)
        b.box(c + Vector((0, 0, size[2] / 2 + 0.02)), (size[0] * 0.9, size[1] * 0.25, 0.04), "obsidian_light", bone)
    b.box((0, -0.9, 1.6), (1.0, 0.2, 0.56), "obsidian_mid", "Spine_1")  # breast, where the necks join
    b.box((0, -0.97, 1.5), (0.56, 0.06, 0.38), "belly", "Spine_1")
    # Big crystals down the back, smaller ones over the shoulders and hips
    crystal_row(b, (0, -0.65, 1.84), (0, -0.2, 1.84), "Spine_1", 2, (0, 0.2, 1), 0.62)
    crystal_row(b, (0, -0.15, 1.68), (0, 0.4, 1.68), "Spine_0", 2, (0, 0.2, 1), 0.66, 1)
    crystal_row(b, (0, 0.42, 1.62), (0, 1.0, 1.62), "Pelvis", 2, (0, 0.3, 1), 0.52, 2)
    for sx in (1, -1):
        b.spike((sx * 0.4, -0.45, 1.8), (sx * 0.8, 0.2, 1), 0.22, 0.46, "crystal_light", "Spine_1")
        b.spike((sx * 0.44, 0.12, 1.64), (sx * 0.9, 0.3, 0.8), 0.2, 0.4, "crystal_dark", "Spine_0")
        b.spike((sx * 0.42, 0.7, 1.58), (sx * 0.8, 0.5, 0.8), 0.2, 0.38, "crystal", "Pelvis")


def build_legs(b):
    for side, sx in (("Left", 1), ("Right", -1)):
        for pair, leg, widths in ((0, FRONT_LEG, (0.42, 0.33, 0.3)), (1, HIND_LEG, (0.52, 0.38, 0.32))):
            p = [Vector(mirror(q, sx)) for q in leg]
            upper, lower, foot = (f"{pair}_{side}_Limb_{i}" for i in range(3))
            b.span(p[0], p[1], widths[0], "obsidian", upper, 0.08)
            b.span(p[1], p[2], widths[1], "obsidian_mid", lower, 0.05)
            b.box(p[2] + Vector((0, -0.12, -0.18)), (widths[2] + 0.1, 0.46, 0.18), "obsidian", foot)
            b.spike(p[0].lerp(p[1], 0.35) + Vector((sx * widths[0] * 0.5, 0.05, 0)), (sx * 1, 0.4, 0.5), 0.16, 0.3,
                    "crystal" if pair else "crystal_light", upper)
            # Three hooked claws forward
            for toe in (-0.1, 0, 0.1):
                b.spike(p[2] + Vector((toe, -0.34, -0.22)), (toe * 2, -1, -0.45), 0.09, 0.22, "claw", foot)


def build_tail(b):
    widths = (0.44, 0.38, 0.32, 0.26, 0.2, 0.15)
    for i in range(len(TAIL) - 1):
        bone = f"Tail_{i}"
        b.span(TAIL[i], TAIL[i + 1], widths[i], "obsidian" if i % 2 == 0 else "obsidian_mid", bone, 0.04)
        top = Vector((0, 0, widths[i] / 2))
        crystal_row(b, Vector(TAIL[i]) + top, Vector(TAIL[i + 1]) + top, bone, 2, (0, 0.2, 1), 0.36 - i * 0.04, i)
    tip = Vector(TAIL[-1])
    for direction, color in (((0.5, 0.2, 0.8), "crystal_light"), ((1, 0, 0.1), "crystal"), ((0.6, 0.4, -0.4), "crystal_dark")):
        b.spike(tip, direction, 0.14, 0.34, color, "Tail_5")


def build_necks(b):
    for head, angle in enumerate(FAN):
        points, forward = neck_points(head)
        for i in range(NECK_BONES):
            bone = f"Hydra_{head}_{i}"
            width = 0.44 - 0.04 * i
            b.span(points[i], points[i + 1], width, "obsidian" if i % 2 == 0 else "obsidian_mid", bone, 0.05)
            along = (points[i + 1] - points[i]).normalized()
            back = along.cross(Vector((1, 0, 0))).normalized()
            if back.y < 0:
                back = -back
            mid = points[i].lerp(points[i + 1], 0.5)
            b.spike(mid + back * width * 0.4, back + along * 0.4, width * 0.55, 0.3, CRYSTALS[(head + i) % 3], bone)
            # Scales down the front of the neck
            b.span(points[i] - back * width * 0.42, points[i + 1] - back * width * 0.42, width * 0.4, "obsidian_light", bone)
        build_head(b, head, points[-1], forward)


def build_head(b, head, origin, forward):
    """A blocky dragon head along `forward`, the lower jaw on its own bone."""
    skull, jaw = f"Hydra_{head}_3", f"Jaw_{head}"
    m = voxel_kit.frame(forward)
    b.xform = Matrix.Translation(origin) @ Matrix.Scale(HEAD_SCALE, 4) @ Matrix.Translation(-origin)

    def at(x, y, z):
        return origin + m @ Vector((x, y, z))

    b.box(at(0, 0.1, 0.08), (0.42, 0.38, 0.32), "obsidian_mid", skull, m)
    b.box(at(0, 0.42, 0.04), (0.32, 0.34, 0.18), "obsidian_mid", skull, m)
    b.box(at(0, 0.5, 0.135), (0.22, 0.2, 0.04), "obsidian_light", skull, m)  # snout ridge
    b.box(at(0, 0.38, -0.06), (0.26, 0.4, 0.04), "mouth", skull, m)  # glowing roof of the mouth
    for sx in (1, -1):
        b.box(at(sx * 0.13, 0.24, 0.255), (0.14, 0.16, 0.06), "obsidian_light", skull, m)  # brow
        b.box(at(sx * 0.21, 0.24, 0.16), (0.03, 0.12, 0.06), "eye", skull, m)
        for y in (0.3, 0.42, 0.54):
            b.spike(at(sx * 0.12, y, -0.07), m @ Vector((0, 0.15, -1)), 0.05, 0.1, "teeth", skull)
        # Crystal crown sweeping back off the skull, and cheek spikes
        b.spike(at(sx * 0.14, -0.04, 0.22), m @ Vector((sx * 0.4, -1, 0.9)), 0.11, 0.34, "crystal_light", skull)
        b.spike(at(sx * 0.2, 0.02, 0.0), m @ Vector((sx * 1, -0.8, 0.1)), 0.09, 0.24, "crystal_dark", skull)
    b.spike(at(0, -0.05, 0.25), m @ Vector((0, -1, 1.2)), 0.14, 0.42, "crystal", skull)
    b.spike(at(0, 0.18, 0.25), m @ Vector((0, -0.6, 1)), 0.1, 0.26, "crystal_dark", skull)
    # Lower jaw: hinged at the back of the mouth
    b.box(at(0, 0.33, -0.15), (0.28, 0.42, 0.1), "obsidian", jaw, m)
    b.box(at(0, 0.33, -0.095), (0.22, 0.36, 0.02), "mouth", jaw, m)
    for sx in (1, -1):
        for y in (0.36, 0.48):
            b.spike(at(sx * 0.1, y, -0.09), m @ Vector((0, 0.1, 1)), 0.045, 0.08, "teeth", jaw)
    b.xform = None


def parts(b):
    build_body(b)
    build_legs(b)
    build_tail(b)
    build_necks(b)


voxel_kit.run(NAME, COLORS, rig_bones(), parts)
