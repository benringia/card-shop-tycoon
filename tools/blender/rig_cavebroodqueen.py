"""Rigs the Cave Brood Queen, the Wild valley's second boss (spec 2026-11-01-wild-bosses-arenas-design, "Broodmother").
The user picked the bat-winged spider; Meshy made it from the approved sheet (image to 3D, job
meshy:i2m:01a19636-6aeb-77b9-8807-777f9e5dc0b5, picture assets/blender/CaveBroodQueen/CaveBroodQueen_sheet.png): a dark
violet spider with a cluster of glowing lilac eyes and two pale fangs, eight grey-green legs spread wide, a pair of
leathery bat wings raised on its back and a big glowing lavender egg sac behind, facing -Y. Meshy also gave it a
leg-like palp by the fangs on its right (+X is its left), resting on the ground.

"CaveBroodQueen_Src" in assets/blender/CaveBroodQueen/CaveBroodQueen.blend is that mesh (Meshy made it 10 cm tall); it
is scaled to 1 m (1.33 m across the legs) and renamed "CaveBroodQueen_Body". It walks on four pairs of two-segment legs
(0..3_<Side>_Limb_0..1, front to back, the eight-leg wave), its wings (Wing_<Side>_0..1) shifting at rest and spreading
for its roar. The body is Pelvis (the sac, from the waist back) and Spine_0 (the thorax); Head_0 carries the eyes and
Jaw_0 the fangs (the palp follows them). A zero-influence Fx_Sac at the sac's centre carries the game's heal flare
(Config/Bosses moments; left out of skinning). Up to 8,000 triangles. The glow mask lights the eyes and the egg sac (not the fangs, which are as lilac).
Writes CaveBroodQueen.fbx and CaveBroodQueen_glow.png next to the .blend.
"""
import importlib
import os
import sys

import bpy
from mathutils import Matrix

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import rig_kit  # noqa: E402

importlib.reload(rig_kit)

# Bone positions read off the 1 m mesh: the thorax from y 0 to -0.35 (z 0.32-0.65), the head's eyes and fangs in front
# of it (the fang tips at y -0.6, z 0.09), the sac from y 0 to 0.62 (z 0.28-0.81); each leg rises from the thorax to a
# knee at z 0.45 and drops to its foot (feet at x 0.51 y -0.44, x 0.65 y -0.05, x 0.56 y 0.35; the back pair runs under
# the sac to x 0.23, y 0.63); the wings rise from x 0.05, z 0.65 to tips at x 0.54, z 0.98
BONES = [
    ("Root", None, (0, 0, 0), (0, 0, 0.2)),
    # The sac, from the waist back
    ("Pelvis", "Root", (0, 0.0, 0.47), (0, 0.5, 0.56)),
    ("Spine_0", "Pelvis", (0, 0.0, 0.47), (0, -0.3, 0.5)),
    ("Head_0", "Spine_0", (0, -0.3, 0.5), (0, -0.5, 0.46)),
    # The fangs, hanging down in front
    ("Jaw_0", "Head_0", (0, -0.46, 0.36), (0, -0.6, 0.12)),
]
LEGS = [  # (parent, hip, knee, foot) on the left (+X)
    ("Spine_0", (0.2, -0.27, 0.42), (0.34, -0.34, 0.45), (0.51, -0.44, 0.01)),
    ("Spine_0", (0.21, -0.11, 0.4), (0.39, -0.09, 0.45), (0.65, -0.05, 0.01)),
    ("Pelvis", (0.21, 0.05, 0.41), (0.36, 0.17, 0.45), (0.56, 0.35, 0.01)),
    # The back pair is fused along the sac's underside, so it swings from where it comes out behind (the part under the
    # sac stays with the body)
    ("Pelvis", (0.19, 0.42, 0.33), (0.21, 0.52, 0.21), (0.23, 0.63, 0.01)),
]
for side, sx in (("Left", 1), ("Right", -1)):
    for pair, (parent, hip, knee, foot) in enumerate(LEGS):
        hip, knee, foot = ((sx * p[0], p[1], p[2]) for p in (hip, knee, foot))
        BONES += [
            (f"{pair}_{side}_Limb_0", parent, hip, knee),
            (f"{pair}_{side}_Limb_1", f"{pair}_{side}_Limb_0", knee, foot),
        ]
    BONES += [
        # The bat wing, root to tip along the middle of the membrane
        (f"Wing_{side}_0", "Spine_0", (sx * 0.05, -0.12, 0.66), (sx * 0.3, -0.17, 0.86)),
        (f"Wing_{side}_1", f"Wing_{side}_0", (sx * 0.3, -0.17, 0.86), (sx * 0.54, -0.3, 0.97)),
    ]
FX = [("Fx_Sac", "Pelvis", (0, 0.32, 0.55), (0, 0.32, 0.62))]

params = rig_kit.Params()
params.leg_top = 0.62  # the knees stand above the body's underside, so a leg is all leg up to z 0.5
params.leg_full = 0.5
params.leg_core = 0.05  # thin legs: the whole tube follows its bones, the body only near the hips
params.leg_radius = 0.09
params.belly_mid = 0.08  # the sac's underside between the back legs stays body
params.head_from = -0.3
params.tail_from = 1.0  # no tail

GLOW = [{"hue": (250, 330), "sat": (0.1, 1.0), "val": (0.7, 1.0)}]  # the lilac eyes and the lavender egg sac


def glows_here(point):
    """Not the fangs under the eyes or the wings' pale highlights, which are as lilac."""
    fangs = point.y < -0.35 and point.z < 0.42
    wings = point.z > 0.6 and abs(point.x) > 0.1 and point.y < 0
    return not (fangs or wings)


def _ramp(value, zero, one):
    t = max(0.0, min(1.0, (value - zero) / (one - zero)))
    return t * t * (3 - 2 * t)


def _segment_distance(p, a, b):
    ab = b - a
    t = max(0.0, min(1.0, (p - a).dot(ab) / max(ab.length_squared, 1e-9)))
    return (p - (a + ab * t)).length


def sac_stays(mesh):
    """The back legs run along the sac's underside, so skin() gave them the sac's surface too and a stride pulled it into
    a point: on the sac (an ellipsoid round its centre), weight more than 3.5 cm from a back leg's bones goes to Pelvis,
    fading out by 6 cm."""
    from mathutils import Vector

    centre, radii = Vector((0, 0.31, 0.545)), Vector((0.27, 0.31, 0.265))
    bones = {n: (Vector(h), Vector(t)) for n, _, h, t in BONES if n.startswith("3_")}
    pelvis = mesh.vertex_groups["Pelvis"]
    for v in mesh.data.vertices:
        offset = v.co - centre
        shell = Vector((offset.x / radii.x, offset.y / radii.y, offset.z / radii.z)).length
        if v.co.y < 0.1 or not 0.85 < shell < 1.15:
            continue
        moved = 0.0
        for g in list(v.groups):
            name = mesh.vertex_groups[g.group].name
            if name in bones:
                keep = _ramp(_segment_distance(v.co, *bones[name]), 0.06, 0.035)
                moved += g.weight * (1 - keep)
                mesh.vertex_groups[g.group].add([v.index], g.weight * keep, "REPLACE")
        if moved > 0:
            current = next((g.weight for g in v.groups if g.group == pelvis.index), 0.0)
            pelvis.add([v.index], current + moved, "REPLACE")
            kept = sorted(((g.group, g.weight) for g in v.groups if g.weight > 0), key=lambda gw: -gw[1])
            total = sum(w for _, w in kept[:rig_kit.MAX_BONES])
            for i, (group, w) in enumerate(kept):
                if i < rig_kit.MAX_BONES:
                    mesh.vertex_groups[group].add([v.index], w / total, "REPLACE")
                else:
                    mesh.vertex_groups[group].remove([v.index])
            for g in list(v.groups):
                if g.weight <= 0:
                    mesh.vertex_groups[g.group].remove([v.index])


def wings_on_wings(mesh):
    """skin() lets the wing bones reach anything near them, so the knees and hips would lift with a spread wing and each
    wing's root (5 cm off the midline) would drag the other side's: fades their weights out below the wing roots (the
    knees stand at z 0.45), behind the waist (the sac) and across the midline, smoothly so the wing roots don't tear."""
    sides = {g.index: (1 if "_Left_" in g.name else -1) for g in mesh.vertex_groups if g.name.startswith("Wing_")}
    for v in mesh.data.vertices:
        keep = _ramp(v.co.z, 0.38, 0.6) * _ramp(v.co.y, 0.1, 0.0)
        weights = [(g.group, g.weight * (keep * _ramp(sides[g.group] * v.co.x, 0.0, 0.06) if g.group in sides else 1))
                   for g in v.groups]
        if all(abs(w - g.weight) < 1e-6 for (_, w), g in zip(weights, v.groups)):
            continue
        total = sum(w for _, w in weights)
        if total <= 0:
            continue
        for group, w in weights:
            if w > 0:
                mesh.vertex_groups[group].add([v.index], w / total, "REPLACE")
            else:
                mesh.vertex_groups[group].remove([v.index])


def scale_to_metre(mesh):
    """Bakes the object's transform into the mesh, then scales it so it stands 1 m tall on the ground."""
    mesh.data.transform(mesh.matrix_world)
    mesh.matrix_world = Matrix.Identity(4)
    height = max(v.co.z for v in mesh.data.vertices)
    mesh.data.transform(Matrix.Scale(1 / height, 4))
    mesh.data.update()
    print("scaled to 1 m from", round(height, 3))


source = bpy.data.objects.get("CaveBroodQueen_Src")
if source:
    scale_to_metre(source)
    source.name = "CaveBroodQueen_Body"
    source.data.name = "CaveBroodQueen_Body"
mesh = bpy.data.objects["CaveBroodQueen_Body"]
mesh.parent = None
for mod in [m for m in mesh.modifiers if m.type == "ARMATURE"]:
    mesh.modifiers.remove(mod)
rig_kit.optimize(mesh, "CaveBroodQueen", 7600)
rig = rig_kit.build_rig("CaveBroodQueenRig", BONES + FX)
rig_kit.skin(mesh, rig, BONES, params)
sac_stays(mesh)
wings_on_wings(mesh)
if os.environ.get("EXPORT", "1") == "1":
    rig_kit.export("CaveBroodQueen", rig, mesh)
rig_kit.glow_mask(mesh, "CaveBroodQueen", GLOW, grow=1, region=glows_here)
bpy.ops.wm.save_mainfile()
