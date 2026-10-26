"""Rigs Stormking, a colossal storm titan beetle (a Legendary, so godlike and very dangerous): generated with Meshy
through the Blender MCP from this prompt (object "Stormking_Src", scaled x0.556 to 1 m tall):

  colossal godlike storm titan rhinoceros beetle, legendary lightning creature, very dangerous, massive heavy armoured
  body, broad thick shell plates of deep sapphire blue with jagged glowing blue crystal ridges, one huge forward horn
  tipped with glowing yellow lightning crystals, fierce glowing blue eyes, six thick sturdy armoured legs with big
  claws, low wide stance, glowing yellow lightning crack lines on its shell. Stylized cartoon game model, smooth simple
  rounded shapes, big simple forms, flat clean colors, low poly, no realistic textures. Perfectly symmetrical. Isolated
  single character only, nothing else: no base, no ground, no rocks, no props. Legs clearly separate. One solid closed
  shape.

Meshy made it an armoured beetle-tank on four thick legs (not six: just right for the four-legged walk), with crystal
spikes on its sapphire shell, a gold horn and a long tail spike. It went through rig_kit.remesh_bake (voxel 6 mm,
12,000 triangles, colours baked) into "Stormking_Beetle" in assets/blender/Stormking/Stormking.blend. The lightning is
the game's effects.

It plods on four armoured legs, the horned head low in front. Bone positions are read off that mesh. Writes
assets/blender/Stormking/Stormking.fbx.
"""
import os
import sys

import bpy

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import rig_kit  # noqa: E402

BONES = [
    ("Root", None, (0, 0, 0), (0, 0, 0.2)),
    ("Pelvis", "Root", (0, 0.25, 0.5), (0, 0.0, 0.52)),
    ("Spine_0", "Pelvis", (0, 0.0, 0.52), (0, -0.25, 0.55)),
    ("Spine_1", "Spine_0", (0, -0.25, 0.55), (0, -0.45, 0.55)),
    ("Neck", "Spine_1", (0, -0.45, 0.55), (0, -0.58, 0.55)),
    ("Head_0", "Neck", (0, -0.58, 0.55), (0, -0.85, 0.6)),
    # The long tail spike
    ("Tail_0", "Pelvis", (0, 0.4, 0.48), (0, 0.6, 0.45)),
    ("Tail_1", "Tail_0", (0, 0.6, 0.45), (0, 0.8, 0.43)),
    ("Tail_2", "Tail_1", (0, 0.8, 0.43), (0, 0.96, 0.43)),
]
for side, sx in (("Left", 1), ("Right", -1)):
    BONES += [
        # Front legs: shoulder under the shell, elbow, wrist, claws
        (f"0_{side}_Limb_0", "Spine_1", (sx * 0.24, -0.26, 0.48), (sx * 0.3, -0.27, 0.3)),
        (f"0_{side}_Limb_1", f"0_{side}_Limb_0", (sx * 0.3, -0.27, 0.3), (sx * 0.36, -0.29, 0.1)),
        (f"0_{side}_Limb_2", f"0_{side}_Limb_1", (sx * 0.36, -0.29, 0.1), (sx * 0.4, -0.38, 0.02)),
        # Hind legs: hip, knee, ankle, claws
        (f"1_{side}_Limb_0", "Pelvis", (sx * 0.19, 0.17, 0.46), (sx * 0.23, 0.17, 0.3)),
        (f"1_{side}_Limb_1", f"1_{side}_Limb_0", (sx * 0.23, 0.17, 0.3), (sx * 0.25, 0.24, 0.1)),
        (f"1_{side}_Limb_2", f"1_{side}_Limb_1", (sx * 0.25, 0.24, 0.1), (sx * 0.27, 0.2, 0.02)),
    ]

params = rig_kit.Params()
params.leg_top = 0.42
params.leg_full = 0.26
params.leg_core = 0.07
params.leg_radius = 0.14
params.belly_mid = 0.06
params.tail_from = 0.38
params.head_from = -0.5

# Already remeshed and baked, so it skips rig_kit.run's optimize step
mesh = bpy.data.objects["Stormking_Beetle"]
rig = rig_kit.build_rig("StormkingRig", BONES)
rig_kit.skin(mesh, rig, BONES, params)
if os.environ.get("EXPORT", "1") == "1":
    rig_kit.export("Stormking", rig, mesh)
