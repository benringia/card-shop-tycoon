"""Rigs the Spark Beetle, the caves' wild beetle (spec 2026-11-01-wild-monster-models-design, style B "wild-touched").
The user picked the "stag spark" concept; Meshy made it from that picture (image to 3D, job
meshy:i2m:01a192fc-d8da-7270-b789-c57e645f19ae, cut-out assets/blender/SparkBeetle/SparkBeetle_concept.png, the
lightning arcs erased first): a rust-copper stag beetle with big jagged pincers marked with yellow cracks, yellow
crystals along its domed back, pale yellow eyes and six thick legs, facing -Y.

"SparkBeetle_Src" in assets/blender/SparkBeetle/SparkBeetle.blend is that mesh, scaled x10 (Meshy made it 6 cm tall) to
0.6 m so rig_kit's metre defaults fit. Six legs as pairs 0..2 (feet at x 0.205/0.248/0.222, y -0.153/0.057/0.244) walk
as two tripods (PetRig). The pincers rise from the head to tips at x 0.086, y -0.37, z 0.6; each rides a role-less bone
on the head (Pincer_<Side>_0), so they move with it in one piece. Zero-influence bones Fx_PincerLeft / Fx_PincerRight
at the tips carry the game's sparks (Config/Wild fx; skipped when skinning). The glow mask lights the yellow crystals,
cracks and eyes. Writes SparkBeetle.fbx and SparkBeetle_glow.png next to the .blend.
"""
import importlib
import os
import sys

import bpy

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import rig_kit  # noqa: E402

importlib.reload(rig_kit)

BONES = [
    ("Root", None, (0, 0, 0), (0, 0, 0.1)),
    ("Pelvis", "Root", (0, 0.2, 0.25), (0, 0.0, 0.26)),
    ("Spine_0", "Pelvis", (0, 0.0, 0.26), (0, -0.14, 0.27)),
    ("Neck", "Spine_0", (0, -0.14, 0.27), (0, -0.19, 0.28)),
    ("Head_0", "Neck", (0, -0.19, 0.28), (0, -0.3, 0.32)),
]
TIPS = [(0.205, -0.153), (0.248, 0.057), (0.222, 0.244)]
ROOTS = [(0.1, -0.11), (0.1, 0.05), (0.1, 0.18)]
for side, sx in (("Left", 1), ("Right", -1)):
    for pair, ((tx, ty), (rx, ry)) in enumerate(zip(TIPS, ROOTS)):
        knee = (sx * (rx + tx) / 2 + sx * 0.02, (ry + ty) / 2, 0.18)
        BONES += [
            (f"{pair}_{side}_Limb_0", "Spine_0" if pair == 0 else "Pelvis", (sx * rx, ry, 0.16), knee),
            (f"{pair}_{side}_Limb_1", f"{pair}_{side}_Limb_0", knee, (sx * tx, ty, 0.0)),
        ]
    BONES += [(f"Pincer_{side}_0", "Head_0", (sx * 0.08, -0.26, 0.36), (sx * 0.086, -0.37, 0.6))]
FX = [(f"Fx_Pincer{side}", "Head_0", (sx * 0.086, -0.37, 0.6), (sx * 0.086, -0.37, 0.63)) for side, sx in (("Left", 1), ("Right", -1))]

params = rig_kit.Params()
params.leg_top = 0.2
params.leg_full = 0.12
params.leg_core = 0.035
params.leg_radius = 0.07
params.belly_mid = 0.05
params.head_from = -0.17
params.tail_from = 1.0  # no tail

GLOW = [{"hue": (40, 65), "sat": (0.45, 1.0), "val": (0.7, 1.0)}]  # the yellow crystals, pincer cracks and eyes

source = bpy.data.objects.get("SparkBeetle_Src")
if source:
    source.name = "SparkBeetle_Body"
    source.data.name = "SparkBeetle_Body"
mesh = bpy.data.objects["SparkBeetle_Body"]
mesh.parent = None
for mod in [m for m in mesh.modifiers if m.type == "ARMATURE"]:
    mesh.modifiers.remove(mod)
rig_kit.optimize(mesh, "SparkBeetle", 5000)
rig = rig_kit.build_rig("SparkBeetleRig", BONES + FX)
rig_kit.skin(mesh, rig, BONES, params)
if os.environ.get("EXPORT", "1") == "1":
    rig_kit.export("SparkBeetle", rig, mesh)
rig_kit.glow_mask(mesh, "SparkBeetle", GLOW, grow=1)
bpy.ops.wm.save_mainfile()
