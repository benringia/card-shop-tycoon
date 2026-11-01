"""Rigs the Meadow Warden, the Wild valley's first boss (spec 2026-11-01-wild-bosses-arenas-design, "Elder Warden"). The
user picked the tree-trunk-and-boulder giant; Meshy made it from the approved sheet (image to 3D, no pose mode: the
T-pose run gave it four arms; job meshy:i2m:01a1968f-cd10-774f-8e59-8426691c74a2, picture
assets/blender/MeadowWarden/MeadowWarden_sheet.png): a hunched giant of mossy grey boulders over a hollow tree-stump
belly, a stone mask face with two glowing green eyes and a moss beard, blossoming antler boughs, long root-wrapped arms
with bark fists near the ground and short stump legs, facing -Y.

"MeadowWarden_Src" in assets/blender/MeadowWarden/MeadowWarden.blend is that mesh (Meshy made it 3 m tall); it is scaled
to 1 m like rig_magmagolem.py, whose biped layout it follows. Its 1.76M triangles collapse-decimated into shards, so it
goes through rig_kit.remesh_bake (voxel 4 mm, colours baked) into "MeadowWarden_Body" and the source is deleted (the
script then rigs the body it finds). It lumbers on two legs
(pair 0) swinging its arms (Arm_<Side>_0..2: shoulder x 0.29 at z 0.6, fists at x 0.4 down to z 0.03); the antlers ride
Head_0 and there is no jaw (a stone mask). Up to 8,000 triangles. The glow mask lights the eyes only (the moss is as
green, so a region keeps it to the face). Writes MeadowWarden.fbx and MeadowWarden_glow.png next to the .blend.
"""
import importlib
import os
import sys

import bpy
from mathutils import Matrix

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import rig_kit  # noqa: E402

importlib.reload(rig_kit)

# Bone positions read off the 1 m mesh: legs at x 0.15 (the body's underside at z 0.18), arms hanging at x 0.39 from
# shoulders at z 0.6, the stone face at the front (y -0.26) between z 0.6 and 0.8 with the eyes at x 0.05, z 0.655,
# the antlers above it up to z 1
BONES = [
    ("Root", None, (0, 0, 0), (0, 0, 0.2)),
    ("Pelvis", "Root", (0, 0.03, 0.2), (0, 0.03, 0.36)),
    ("Spine_0", "Pelvis", (0, 0.03, 0.36), (0, 0.02, 0.5)),
    ("Spine_1", "Spine_0", (0, 0.02, 0.5), (0, 0.0, 0.6)),
    ("Neck", "Spine_1", (0, 0.0, 0.6), (0, -0.08, 0.63)),
    # The stone face at the front of the upper body, the antler boughs above it
    ("Head_0", "Neck", (0, -0.08, 0.63), (0, -0.11, 0.92)),
]
for side, sx in (("Left", 1), ("Right", -1)):
    BONES += [
        # Long arms: shoulder, elbow, wrist, the bark fist resting by the ground
        (f"Arm_{side}_0", "Spine_1", (sx * 0.29, 0.02, 0.6), (sx * 0.38, 0.05, 0.38)),
        (f"Arm_{side}_1", f"Arm_{side}_0", (sx * 0.38, 0.05, 0.38), (sx * 0.39, -0.02, 0.18)),
        (f"Arm_{side}_2", f"Arm_{side}_1", (sx * 0.39, -0.02, 0.18), (sx * 0.4, -0.04, 0.03)),
        # Short stump legs: hip, knee, ankle, foot forward
        (f"0_{side}_Limb_0", "Pelvis", (sx * 0.13, 0.03, 0.22), (sx * 0.15, 0.03, 0.12)),
        (f"0_{side}_Limb_1", f"0_{side}_Limb_0", (sx * 0.15, 0.03, 0.12), (sx * 0.16, 0.03, 0.04)),
        (f"0_{side}_Limb_2", f"0_{side}_Limb_1", (sx * 0.16, 0.03, 0.04), (sx * 0.16, -0.07, 0.01)),
    ]

params = rig_kit.Params()
params.leg_top = 0.24
params.leg_full = 0.14
params.leg_core = 0.06
params.leg_radius = 0.11
params.belly_mid = 0.04
params.head_from = 0.4  # the face sits on the upper body; neck and head bones may reach everything
params.arm_core = 0.07
params.arm_radius = 0.12
params.tail_from = 1.0  # no tail

GLOW = [{"hue": (70, 170), "sat": (0.3, 1.0), "val": (0.65, 1.0)}]  # the eyes' green irises (not the pale stone round them)


def on_face(point):
    """The eyes' part of the stone mask (the shoulders' moss is the same green)."""
    return abs(point.x) < 0.1 and 0.61 < point.z < 0.7 and point.y < -0.17


def scale_to_metre(mesh):
    """Bakes the object's transform into the mesh, then scales it so it stands 1 m tall on the ground."""
    mesh.data.transform(mesh.matrix_world)
    mesh.matrix_world = Matrix.Identity(4)
    height = max(v.co.z for v in mesh.data.vertices)
    mesh.data.transform(Matrix.Scale(1 / height, 4))
    mesh.data.update()
    print("scaled to 1 m from", round(height, 3))


source = bpy.data.objects.get("MeadowWarden_Src")
if source:
    scale_to_metre(source)
    body = rig_kit.remesh_bake(source, "MeadowWarden", voxel=0.004, target_tris=7600)
    bpy.data.objects.remove(source, do_unlink=True)
    bpy.ops.outliner.orphans_purge(do_recursive=True)
    body.name = "MeadowWarden_Body"
    body.data.name = "MeadowWarden_Body"
mesh = bpy.data.objects["MeadowWarden_Body"]
rig = rig_kit.build_rig("MeadowWardenRig", BONES)
rig_kit.skin(mesh, rig, BONES, params)
if os.environ.get("EXPORT", "1") == "1":
    rig_kit.export("MeadowWarden", rig, mesh)
rig_kit.glow_mask(mesh, "MeadowWarden", GLOW, grow=1, region=on_face)
bpy.ops.wm.save_mainfile()
