"""Rigs Sprouthop, a cute tree sprite (a Common, so cute and small; replaces the older scripted voxel build,
tools/blender/build_sprouthop.py, keeping its card's look): generated with Meshy through the Blender MCP
(pose_mode "t-pose") from this prompt (object "Sprouthop_Src", scaled x0.5 to 1 m tall):

  very cute chubby cartoon tree sprite character, mythical bloom creature, happy smiling face, big shiny dark eyes
  close together, pink blush cheeks, round plump body of smooth brown bark, a big square wooden head wearing a wide
  round cap of bright green leaves like a bush, two small brown twig antlers sticking up from the leaves, two short
  chunky bark arms held straight out to the sides in a T-pose, two short stubby root legs, standing upright facing
  straight forward. Toy-like collectible, smooth simple rounded shapes, flat clean colors, low poly. Perfectly
  symmetrical. Isolated single character only, nothing else: no base, no ground, no grass, no props. Legs clearly
  separate. One solid shape.

(A first try came out with a sad face, a single sprout and one arm waving; regenerated.) Meshy made a smiling bark
sprite in a clean T-pose with a big cap of leaves (no twig antlers: the leaf tips at the sides are its Ear_ bones, so
they wiggle). rig_kit.optimize took it to 8,000 triangles (collapse decimate keeps the thin leaves). Saved as
"Sprouthop_Sprite" in assets/blender/Sprouthop/Sprouthop_meshy.blend.

It walks on two stubby legs, swinging its arms (lowered from the T-pose by Party.ARM_POSE), and holds up a hand for
its butterfly. Bone positions are read off that mesh. Writes assets/blender/Sprouthop/Sprouthop.fbx.
"""
import os
import sys

import bpy

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import rig_kit  # noqa: E402

BONES = [
    ("Root", None, (0, 0, 0), (0, 0, 0.2)),
    ("Pelvis", "Root", (0, -0.03, 0.2), (0, -0.04, 0.32)),
    ("Spine_0", "Pelvis", (0, -0.04, 0.32), (0, -0.04, 0.42)),
    ("Spine_1", "Spine_0", (0, -0.04, 0.42), (0, -0.04, 0.5)),
    ("Neck", "Spine_1", (0, -0.04, 0.5), (0, -0.04, 0.56)),
    # The big wooden head under its cap of leaves
    ("Head_0", "Neck", (0, -0.04, 0.56), (0, -0.02, 0.95)),
]
for side, sx in (("Left", 1), ("Right", -1)):
    BONES += [
        # The leaf tips at the sides of the cap
        (f"Ear_{side}_0", "Head_0", (sx * 0.15, 0.0, 0.82), (sx * 0.26, 0.0, 0.9)),
        # T-posed arms: shoulder, elbow, twig fingers
        (f"Arm_{side}_0", "Spine_1", (sx * 0.17, -0.04, 0.37), (sx * 0.3, -0.04, 0.37)),
        (f"Arm_{side}_1", f"Arm_{side}_0", (sx * 0.3, -0.04, 0.37), (sx * 0.4, -0.045, 0.37)),
        (f"Arm_{side}_2", f"Arm_{side}_1", (sx * 0.4, -0.045, 0.37), (sx * 0.47, -0.05, 0.36)),
        # Stubby legs: hip, knee, ankle, root toes
        (f"0_{side}_Limb_0", "Pelvis", (sx * 0.1, -0.04, 0.22), (sx * 0.1, -0.05, 0.12)),
        (f"0_{side}_Limb_1", f"0_{side}_Limb_0", (sx * 0.1, -0.05, 0.12), (sx * 0.1, -0.06, 0.05)),
        (f"0_{side}_Limb_2", f"0_{side}_Limb_1", (sx * 0.1, -0.06, 0.05), (sx * 0.1, -0.16, 0.01)),
    ]

params = rig_kit.Params()
params.leg_top = 0.24
params.leg_full = 0.14
params.leg_core = 0.04
params.leg_radius = 0.09
params.belly_mid = 0.02
params.arm_core = 0.03
params.arm_radius = 0.07
params.tail_from = 9  # no tail
params.head_from = 0.3  # the head sits right over the body: split by height alone

mesh = bpy.data.objects["Sprouthop_Sprite"]
rig = rig_kit.build_rig("SprouthopRig", BONES)
rig_kit.skin(mesh, rig, BONES, params)
if os.environ.get("EXPORT", "1") == "1":
    rig_kit.export("Sprouthop", rig, mesh)
