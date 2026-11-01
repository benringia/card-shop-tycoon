"""Rigs the Ember Colossus, the Wild valley's third boss (spec 2026-11-01-wild-bosses-arenas-design, "Magma Behemoth").
The user picked the lava rhino; Meshy made it from the approved sheet (image to 3D, job
meshy:i2m:01a19636-d6a3-72ba-a656-b7158ac06d7a, picture assets/blender/EmberColossus/EmberColossus_sheet.png): a heavy
armoured rhino of dark basalt plates split by glowing orange lava seams, a big nose horn, glowing eyes and mouth, dark
spikes along its domed back, standing square on four thick legs, facing -Y.

"EmberColossus_Src" in assets/blender/EmberColossus/EmberColossus.blend is that mesh (Meshy made it 1.7 m tall); it is
scaled to 1 m (1.64 m long) and renamed "EmberColossus_Body". A quadruped with three-segment legs (0_/1_<Side>_Limb_0..2),
a neck and head with the horn, and Jaw_0 for the lower jaw under the mouth's glowing slit (its vertices handed over after
skinning, like rig_infernox.py). Zero-influence Fx_Vent_0..2 along the back ridge carry the game's enrage burst and
smoke (Config/Bosses moments; left out of skinning). Up to 8,000 triangles. The glow mask lights the lava seams, the
eyes and the mouth (not the horns). Writes EmberColossus.fbx and EmberColossus_glow.png next to the .blend.
"""
import importlib
import os
import sys

import bpy
from mathutils import Matrix

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import rig_kit  # noqa: E402

importlib.reload(rig_kit)

# Bone positions read off the 1 m mesh: front legs at x 0.3, y -0.06 (straight columns, 0.2 thick), hind legs at x 0.24,
# y 0.62; the belly at z 0.2-0.3; the back rising to z 1 over the shoulders; the head from y -0.45 to the horn at -0.82,
# the eyes at z 0.5 and the mouth's slit at z 0.32 under the snout (y -0.58 to -0.7)
BONES = [
    ("Root", None, (0, 0, 0), (0, 0, 0.2)),
    ("Pelvis", "Root", (0, 0.62, 0.6), (0, 0.3, 0.62)),
    ("Spine_0", "Pelvis", (0, 0.3, 0.62), (0, 0.0, 0.66)),
    ("Spine_1", "Spine_0", (0, 0.0, 0.66), (0, -0.3, 0.64)),
    ("Neck", "Spine_1", (0, -0.3, 0.64), (0, -0.45, 0.6)),
    # The head out to the nose horn
    ("Head_0", "Neck", (0, -0.45, 0.6), (0, -0.8, 0.55)),
    # The lower jaw, hinged under the back of the snout
    ("Jaw_0", "Head_0", (0, -0.48, 0.33), (0, -0.7, 0.28)),
]
for side, sx in (("Left", 1), ("Right", -1)):
    BONES += [
        # Front legs: elbow at the belly (the stubby leg swings from there, so the belly round it hardly moves), knee,
        # wrist, the broad foot
        (f"0_{side}_Limb_0", "Spine_1", (sx * 0.29, -0.05, 0.36), (sx * 0.3, -0.05, 0.22)),
        (f"0_{side}_Limb_1", f"0_{side}_Limb_0", (sx * 0.3, -0.05, 0.22), (sx * 0.3, -0.07, 0.12)),
        (f"0_{side}_Limb_2", f"0_{side}_Limb_1", (sx * 0.3, -0.07, 0.12), (sx * 0.31, -0.15, 0.02)),
        # Hind legs the same way: from the belly, knee, hock, the broad foot
        (f"1_{side}_Limb_0", "Pelvis", (sx * 0.23, 0.63, 0.36), (sx * 0.24, 0.64, 0.22)),
        (f"1_{side}_Limb_1", f"1_{side}_Limb_0", (sx * 0.24, 0.64, 0.22), (sx * 0.25, 0.66, 0.12)),
        (f"1_{side}_Limb_2", f"1_{side}_Limb_1", (sx * 0.25, 0.66, 0.12), (sx * 0.25, 0.58, 0.02)),
    ]
# The three vents along the back ridge, between its spikes
FX = [
    ("Fx_Vent_0", "Spine_1", (0, -0.05, 0.96), (0, -0.05, 1.02)),
    ("Fx_Vent_1", "Spine_0", (0, 0.22, 0.92), (0, 0.22, 0.98)),
    ("Fx_Vent_2", "Pelvis", (0, 0.48, 0.87), (0, 0.48, 0.93)),
]

params = rig_kit.Params()
# Stubby legs under a low flat belly (z 0.2-0.3): the leg is all leg only below the belly, and the weights blend wide,
# so the belly round each leg gives a little with the stride instead of tearing at the join
params.leg_top = 0.45
params.leg_full = 0.18
params.smooth_radius = 0.08
params.smooth_passes = 6
params.leg_core = 0.13  # thick legs (0.2 wide, up to 0.28 deep): all of the column follows its bones
params.leg_radius = 0.2
params.belly_mid = 0.1  # the chest and belly between the legs stay body (the hind legs stand 0.13 off the midline)
params.head_from = -0.35
params.tail_from = 1.0  # no tail

GLOW = [{"hue": (12, 48), "sat": (0.5, 1.0), "val": (0.65, 1.0)}]  # the lava seams, eyes, mouth and ears' insides


def glows_here(point):
    """Not the two horns on the snout, whose tan is as orange (the eyes sit further out, x 0.11-0.15)."""
    return not (abs(point.x) < 0.07 and point.y < -0.54 and point.z > 0.52)

# The lower jaw: under the mouth's slit (z 0.31) and in front of y -0.5, blending over 3 cm into the head's weights
JAW_BACK, JAW_TOP, JAW_BLEND = -0.5, 0.31, 0.03


def jaw_share(p):
    if p.y > JAW_BACK + JAW_BLEND or p.z > JAW_TOP + JAW_BLEND:
        return 0.0
    along = min(1.0, (JAW_BACK + JAW_BLEND - p.y) / JAW_BLEND)
    below = min(1.0, (JAW_TOP + JAW_BLEND - p.z) / JAW_BLEND)
    return along * below


def scale_to_metre(mesh):
    """Bakes the object's transform into the mesh, then scales it so it stands 1 m tall on the ground."""
    mesh.data.transform(mesh.matrix_world)
    mesh.matrix_world = Matrix.Identity(4)
    height = max(v.co.z for v in mesh.data.vertices)
    mesh.data.transform(Matrix.Scale(1 / height, 4))
    mesh.data.update()
    print("scaled to 1 m from", round(height, 3))


source = bpy.data.objects.get("EmberColossus_Src")
if source:
    scale_to_metre(source)
    source.name = "EmberColossus_Body"
    source.data.name = "EmberColossus_Body"
mesh = bpy.data.objects["EmberColossus_Body"]
mesh.parent = None
for mod in [m for m in mesh.modifiers if m.type == "ARMATURE"]:
    mesh.modifiers.remove(mod)
rig_kit.optimize(mesh, "EmberColossus", 7600)
rig = rig_kit.build_rig("EmberColossusRig", BONES + FX)
rig_kit.skin(mesh, rig, BONES, params)
rig_kit.reweight(mesh, "Jaw_0", jaw_share)
if os.environ.get("EXPORT", "1") == "1":
    rig_kit.export("EmberColossus", rig, mesh)
rig_kit.glow_mask(mesh, "EmberColossus", GLOW, grow=1, region=glows_here)
bpy.ops.wm.save_mainfile()
