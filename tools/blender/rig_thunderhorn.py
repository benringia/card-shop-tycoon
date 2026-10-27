"""Rigs Thunderhorn, a majestic thunder stag (an Epic, so very dangerous and big; remade on the user's call because the
first, heavy-set one read as a bull): generated with Meshy through the Blender MCP from this prompt (object
"Thunderhorn_Src", scaled x0.5 to 1 m tall):

  majestic mythical thunder stag deer, epic lightning creature, fierce and powerful, strong athletic deer body with a
  deep broad chest and muscular shoulders, long strong legs with gold hooves, long proud neck with a thick cream chest
  ruff, elegant deer head with a slim muzzle and big deer ears, fierce glowing yellow eyes, cream-white coat, small gold
  forehead plate and gold shoulder guards, enormous wide golden antlers with many big branching tines, glowing yellow
  lightning tips, short deer tail. Standing proudly on four legs. Stylized cartoon game model, smooth simple rounded
  shapes, flat clean colors, low poly, no fur detail. Perfectly symmetrical. Isolated single character only, nothing
  else: no base, no ground, no rocks, no props. Legs clearly separate. One solid closed shape.

Meshy made a real stag with huge golden antlers, slim deer legs (approved by the user) and its head turned to its
right; the gold armour came out as a strap over its back (kept). rig_kit.optimize took it to 9,000 triangles (collapse
decimate keeps the thin tines); it stood turned 16.5 degrees, so the mesh was turned back (-16.5 degrees about Z) and
centred so its body runs along Y. The turned head looked awkward in game, so it was straightened by hand: head and
antlers (z > 0.68, or y < -0.2 and z > 0.47) turned 38.1 degrees about a vertical axis at (-0.05, -0.18) and moved 5 cm
to the middle, the neck blending in (weight smoothstep(z, 0.44, 0.56) x smoothstep(-y, 0.1, 0.2)). Saved as
"Thunderhorn_Stag" in assets/blender/Thunderhorn/Thunderhorn.blend.

It walks on four long legs, antlers swaying. Bone positions are read off that mesh (the front legs are off-centre, so
each side has its own numbers). Writes assets/blender/Thunderhorn/Thunderhorn.fbx.
"""
import os
import sys

import bpy

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import rig_kit  # noqa: E402

BONES = [
    ("Root", None, (0, 0, 0), (0, 0, 0.2)),
    ("Pelvis", "Root", (0, 0.25, 0.44), (0, 0.05, 0.45)),
    ("Spine_0", "Pelvis", (0, 0.05, 0.45), (0, -0.1, 0.46)),
    ("Spine_1", "Spine_0", (0, -0.1, 0.46), (0, -0.16, 0.5)),
    # The neck rises and the head hangs forward, a little low
    ("Neck", "Spine_1", (0, -0.16, 0.5), (0, -0.21, 0.63)),
    ("Head_0", "Neck", (0, -0.21, 0.63), (0, -0.36, 0.53)),
    ("Tail_0", "Pelvis", (0, 0.33, 0.46), (0.01, 0.36, 0.44)),
    ("Tail_1", "Tail_0", (0.01, 0.36, 0.44), (0.02, 0.39, 0.4)),
    # The golden antlers sway like ears
    ("Ear_Left_0", "Head_0", (0.04, -0.23, 0.69), (0.15, -0.15, 0.88)),
    ("Ear_Right_0", "Head_0", (-0.05, -0.21, 0.69), (-0.18, -0.12, 0.87)),
    # Front legs (the right one stands near the middle): shoulder, knee, fetlock, hoof
    ("0_Left_Limb_0", "Spine_1", (0.08, -0.09, 0.42), (0.1, -0.085, 0.23)),
    ("0_Left_Limb_1", "0_Left_Limb_0", (0.1, -0.085, 0.23), (0.106, -0.08, 0.13)),
    ("0_Left_Limb_2", "0_Left_Limb_1", (0.106, -0.08, 0.13), (0.13, -0.12, 0.01)),
    ("0_Right_Limb_0", "Spine_1", (-0.03, -0.08, 0.42), (-0.044, -0.076, 0.23)),
    ("0_Right_Limb_1", "0_Right_Limb_0", (-0.044, -0.076, 0.23), (-0.036, -0.082, 0.13)),
    ("0_Right_Limb_2", "0_Right_Limb_1", (-0.036, -0.082, 0.13), (-0.053, -0.13, 0.01)),
    # Hind legs from the haunch: knee, hock, hoof
    ("1_Left_Limb_0", "Pelvis", (0.07, 0.16, 0.44), (0.065, 0.22, 0.3)),
    ("1_Left_Limb_1", "1_Left_Limb_0", (0.065, 0.22, 0.3), (0.094, 0.29, 0.13)),
    ("1_Left_Limb_2", "1_Left_Limb_1", (0.094, 0.29, 0.13), (0.127, 0.24, 0.01)),
    ("1_Right_Limb_0", "Pelvis", (-0.07, 0.16, 0.44), (-0.063, 0.2, 0.3)),
    ("1_Right_Limb_1", "1_Right_Limb_0", (-0.063, 0.2, 0.3), (-0.101, 0.292, 0.13)),
    ("1_Right_Limb_2", "1_Right_Limb_1", (-0.101, 0.292, 0.13), (-0.114, 0.25, 0.01)),
]

params = rig_kit.Params()
params.mid_x = 0.03  # between the front legs (the right one stands near the middle)
params.leg_top = 0.38
params.leg_full = 0.28
params.leg_core = 0.025
params.leg_radius = 0.06
params.belly_mid = 0.0
params.tail_from = 0.33
params.head_from = -0.15

mesh = bpy.data.objects["Thunderhorn_Stag"]
rig = rig_kit.build_rig("ThunderhornRig", BONES)
rig_kit.skin(mesh, rig, BONES, params)
# The right antler sweeps back past head_from: each antler, from its base up, belongs wholly to its own bone
for side, sign in (("Left", 1), ("Right", -1)):
    rig_kit.reweight(mesh, f"Ear_{side}_0",
                     lambda p, sign=sign: rig_kit._ramp(p.z, 0.69, 0.73) if p.x * sign > 0 else 0.0)
if os.environ.get("EXPORT", "1") == "1":
    rig_kit.export("Thunderhorn", rig, mesh)
