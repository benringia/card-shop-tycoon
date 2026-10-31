"""Rigs the Puddle Crab, the meadow's wild crab (spec 2026-11-01-wild-monster-models-design, style B "wild-touched").
The user picked the "barnacle brute" concept; Meshy made it from that picture (image to 3D, job
meshy:i2m:01a192ef-e13e-752d-abe0-699d71b631ef, cut-out assets/blender/PuddleCrab/PuddleCrab_concept.png): a domed dark
blue shell crowded with barnacles that glow cyan inside, a grumpy face under the rim with cyan eyes, two grey stone
hammer claws resting in front and three walking legs a side, 0.3 m tall, facing -Y.

"PuddleCrab_Src" in assets/blender/PuddleCrab/PuddleCrab.blend is that mesh (appended from the raw file). Meshy also
added a leg standing at the back middle; it is cut off here (the column within 4.5 cm of the midline behind y 0.1,
below 11 cm, plus its top joint poking out behind the rim) and the hole closed. Collapse-decimating it turned the barnacles and legs to shards, so it goes through
rig_kit.remesh_bake (3 mm voxels for its 0.3 m size, 5,000 triangles, colours baked) into "PuddleCrab_Body", and the
raw mesh is deleted; the leg is cut from that remeshed surface (cut first, the filled hole made the remesh fall apart). The three leg pairs walk as two tripods (PetRig); the claws are role-less bones
on the body (Claw_<Side>_<n>), so they hold steady in front. The glow mask lights the bright cyan barnacle insides and
eyes. Writes PuddleCrab.fbx and PuddleCrab_glow.png next to the .blend.
"""
import importlib
import os
import sys

import bmesh
import bpy

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import rig_kit  # noqa: E402

importlib.reload(rig_kit)


def remove_extra_leg(mesh):
    """Deletes the stray leg at the back middle and fills the hole it leaves under the shell."""
    bm = bmesh.new()
    bm.from_mesh(mesh.data)
    # Meshy splits the surface at its UV seams: weld those first, so only the cut is left open to fill
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.0005)
    # The leg's column under the shell, and its top joint where it pokes out behind the shell's rim (y 0.166)
    stray = [v for v in bm.verts if (abs(v.co.x) < 0.045 and 0.1 < v.co.y < 0.2 and v.co.z < 0.11)
             or (abs(v.co.x) < 0.03 and v.co.y > 0.168 and v.co.z < 0.135)]
    bmesh.ops.delete(bm, geom=stray, context="VERTS")

    def near_cut(edge):
        return all(abs(v.co.x) < 0.06 and 0.08 < v.co.y < 0.22 and v.co.z < 0.15 for v in edge.verts)

    edges = [e for e in bm.edges if e.is_boundary and near_cut(e)]
    if edges:
        bmesh.ops.holes_fill(bm, edges=edges, sides=0)
    print("extra leg: filled", len(edges), "boundary edges at the cut")
    bm.to_mesh(mesh.data)
    bm.free()
    print("extra leg:", len(stray), "vertices removed")


BONES = [
    ("Root", None, (0, 0, 0), (0, 0, 0.1)),
    ("Pelvis", "Root", (0, 0.08, 0.17), (0, 0.0, 0.18)),
    ("Spine_0", "Pelvis", (0, 0.0, 0.18), (0, -0.08, 0.18)),
    ("Neck", "Spine_0", (0, -0.08, 0.18), (0, -0.11, 0.17)),
    ("Head_0", "Neck", (0, -0.11, 0.17), (0, -0.17, 0.15)),
]
# Leg tips (x, y) on the ground, front to back, read off the mesh
TIPS = [(0.166, -0.073), (0.175, 0.014), (0.137, 0.099)]
ROOTS = [(0.09, -0.05), (0.09, 0.01), (0.08, 0.06)]
for side, sx in (("Left", 1), ("Right", -1)):
    for pair, ((tx, ty), (rx, ry)) in enumerate(zip(TIPS, ROOTS)):
        knee = (sx * (rx + tx) / 2 + sx * 0.02, (ry + ty) / 2, 0.09)
        BONES += [
            (f"{pair}_{side}_Limb_0", "Spine_0", (sx * rx, ry, 0.11), knee),
            (f"{pair}_{side}_Limb_1", f"{pair}_{side}_Limb_0", knee, (sx * tx, ty, 0.0)),
        ]
    # The hammer claws: out from the body's front corners, down to the stone blocks
    BONES += [
        (f"Claw_{side}_0", "Spine_0", (sx * 0.1, -0.06, 0.1), (sx * 0.08, -0.12, 0.07)),
        (f"Claw_{side}_1", f"Claw_{side}_0", (sx * 0.08, -0.12, 0.07), (sx * 0.07, -0.17, 0.06)),
    ]

params = rig_kit.Params()
params.leg_top = 0.13
params.leg_full = 0.08
params.leg_core = 0.03
params.leg_radius = 0.05
params.belly_mid = 0.04
params.tail_from = 1.0  # no tail
params.head_from = -0.1
params.smooth_radius = 0.02

GLOW = [{"hue": (170, 200), "sat": (0.6, 1.0), "val": (0.8, 1.0)}]  # the cyan barnacle insides and eyes

source = bpy.data.objects.get("PuddleCrab_Src")
if source:
    low = rig_kit.remesh_bake(source, "PuddleCrab", voxel=0.003, target_tris=5000)
    bpy.data.objects.remove(source, do_unlink=True)
    low.name = "PuddleCrab_Body"
    low.data.name = "PuddleCrab_Body"
    # Cut on the clean remeshed surface: filling the cut on the raw mesh made a face the voxel remesh read inside out
    remove_extra_leg(low)
mesh = bpy.data.objects["PuddleCrab_Body"]
rig = rig_kit.build_rig("PuddleCrabRig", BONES)
rig_kit.skin(mesh, rig, BONES, params)
if os.environ.get("EXPORT", "1") == "1":
    rig_kit.export("PuddleCrab", rig, mesh)
rig_kit.glow_mask(mesh, "PuddleCrab", GLOW, grow=1)
bpy.ops.wm.save_mainfile()
