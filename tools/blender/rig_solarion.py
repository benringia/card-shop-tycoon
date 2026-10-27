"""Rigs Solarion, a sun fire god titan (a Legendary, so godlike and big; replaces the older scripted voxel three-headed
cerberus, tools/blender/build_solarion.py): generated with Meshy through the Blender MCP in a T-pose (pose_mode
"t-pose") from this firm prompt (object "Solarion_Src", scaled x0.5 to 1 m tall):

  colossal mythical sun fire god titan, legendary creature, godlike, majestic and very powerful. Humanoid standing
  upright in a T-pose: arms straight out to the sides, legs straight, feet apart, head and body facing straight
  forward. Huge broad heavy muscular build, thick strong arms and legs, big chest. Smooth simple solid body. Skin of
  glowing white-hot gold and orange fire, polished golden armour on chest, shoulders, forearms and shins. Fierce
  glowing white eyes, a stern regal face. Main feature: a big crown of blazing golden sun rays around its head like a
  sun halo, and a glowing sun disc emblem on its chest. Flat clean colors, low poly, toy-like collectible. Perfectly
  symmetrical. Isolated single character only: no base, no ground, no weapons, no props. One solid shape.

A regal bearded fire god in golden armour with flame-orange skin, its arms hanging at its sides (not T-posed) and the
sun crown grown into a huge spiky sun disc behind its whole body, three times its width. Shrunk by hand on the user's
call: everything behind the body (y > 0.035, fading in to y 0.06) scaled x0.68 across and up and down about a centre
moved from z 0.51 up to z 0.66, so the disc frames its head and shoulders. rig_kit.remesh_bake (voxel 4 mm, 12,000
triangles, colours baked) into "Solarion_God" in assets/blender/Solarion/Solarion_meshy.blend. Its polished gold
armour is metallic in Meshy's material, so the bake left it a dull khaki; those texels (hue 0.07-0.2, saturation under
0.8) were turned gold in the colour map: hue 0.115, saturation x0.95 (at most 0.75), brightness x2.2.

It strides on two legs, arms swinging at its sides as modelled (ARM_POSE hang 0); the sun disc rides its upper spine,
rigid. Bone positions are read off that mesh. Writes assets/blender/Solarion/Solarion.fbx.
"""
import os
import sys

import bpy

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import rig_kit  # noqa: E402

BONES = [
    ("Root", None, (0, 0, 0), (0, 0, 0.2)),
    ("Pelvis", "Root", (0, -0.05, 0.36), (0, -0.05, 0.5)),
    ("Spine_0", "Pelvis", (0, -0.05, 0.5), (0, -0.05, 0.62)),
    ("Spine_1", "Spine_0", (0, -0.05, 0.62), (0, -0.05, 0.74)),
    ("Neck", "Spine_1", (0, -0.05, 0.74), (0, -0.06, 0.78)),
    ("Head_0", "Neck", (0, -0.06, 0.78), (0, -0.07, 0.94)),
]
for side, sx in (("Left", 1), ("Right", -1)):
    BONES += [
        # Arms hanging at its sides: shoulder, elbow, wrist, fist
        (f"Arm_{side}_0", "Spine_1", (sx * 0.17, -0.05, 0.71), (sx * 0.2, -0.07, 0.55)),
        (f"Arm_{side}_1", f"Arm_{side}_0", (sx * 0.2, -0.07, 0.55), (sx * 0.215, -0.11, 0.42)),
        (f"Arm_{side}_2", f"Arm_{side}_1", (sx * 0.215, -0.11, 0.42), (sx * 0.215, -0.13, 0.32)),
        # Legs: hip, knee, ankle, toes
        (f"0_{side}_Limb_0", "Pelvis", (sx * 0.09, -0.06, 0.36), (sx * 0.11, -0.08, 0.2)),
        (f"0_{side}_Limb_1", f"0_{side}_Limb_0", (sx * 0.11, -0.08, 0.2), (sx * 0.13, -0.06, 0.06)),
        (f"0_{side}_Limb_2", f"0_{side}_Limb_1", (sx * 0.13, -0.06, 0.06), (sx * 0.14, -0.17, 0.01)),
    ]

params = rig_kit.Params()
params.leg_top = 0.38
params.leg_full = 0.3
params.leg_core = 0.04
params.leg_radius = 0.08
params.belly_mid = 0.03
params.arm_core = 0.03
params.arm_radius = 0.065
params.head_from = 0.4  # the head sits right over the body: split by height alone

mesh = bpy.data.objects["Solarion_God"]
rig = rig_kit.build_rig("SolarionRig", BONES)
rig_kit.skin(mesh, rig, BONES, params)
# The sun disc behind it (y > DISC_FROM) moves as one piece with the upper spine, so it never bends with the head or arms
DISC_FROM, DISC_FULL = 0.04, 0.06
rig_kit.reweight(mesh, "Spine_1", lambda p: rig_kit._ramp(p.y, DISC_FROM, DISC_FULL))
if os.environ.get("EXPORT", "1") == "1":
    rig_kit.export("Solarion", rig, mesh)
