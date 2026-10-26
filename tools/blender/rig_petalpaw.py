"""Rigs Petalpaw, a very cute flower squirrel (a Common): generated with Meshy through the Blender MCP from this prompt
(object "Petalpaw_Src", scaled x4 to 1 m tall):

  very cute chubby cartoon squirrel, mythical flower creature, standing on all four short legs, toy-like collectible
  creature, round plump body, big round head, big shiny dark eyes set close together, small centred smile, soft pink
  blush, warm orange body with a cream belly, small rounded ears, a big smooth fluffy tail shaped like one giant soft
  pink flower petal curling up over its back, one simple pink five-petal flower with a yellow centre on top of its
  head. Perfectly symmetrical face. Smooth simple rounded shapes, big simple forms, flat clean colors, low poly, no fur
  detail, no leaves, no realistic textures. Isolated single character only, nothing else: no base, no ground, no
  grass, no rocks, no stand, no props. Legs clearly separate from each other. One solid closed shape.

Meshy made it upright with a furry orange tail (3.45M triangles of fur strands). It went through rig_kit.remesh_bake
(voxel 7 mm, 8,000 triangles, colours baked) into "Petalpaw_Squirrel" in assets/blender/Petalpaw/Petalpaw.blend,
which smooths the fur into one soft shape; then the tail was painted as a pink petal (faces behind y 0.115, or
behind y 0.07 facing the body, below z 0.7: rose 0.93, 0.52, 0.74 at the root fading to blush 1, 0.84, 0.92 along it).

It walks upright on short legs, arms held out a little; the big tail sways behind. Bone positions are read off that
mesh. Writes assets/blender/Petalpaw/Petalpaw.fbx.
"""
import os
import sys

import bpy

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import rig_kit  # noqa: E402

BONES = [
    ("Root", None, (0, 0, 0), (0, 0, 0.2)),
    ("Pelvis", "Root", (0, 0.0, 0.17), (0, 0.0, 0.32)),
    ("Spine_0", "Pelvis", (0, 0.0, 0.32), (0, -0.01, 0.44)),
    ("Spine_1", "Spine_0", (0, -0.01, 0.44), (0, -0.02, 0.55)),
    ("Neck", "Spine_1", (0, -0.02, 0.55), (0, -0.04, 0.62)),
    ("Head_0", "Neck", (0, -0.04, 0.62), (0, -0.12, 0.88)),
    # The petal tail rises up behind and curls back, leaning to its left
    ("Tail_0", "Pelvis", (0.01, 0.12, 0.12), (0.03, 0.24, 0.22)),
    ("Tail_1", "Tail_0", (0.03, 0.24, 0.22), (0.06, 0.28, 0.42)),
    ("Tail_2", "Tail_1", (0.06, 0.28, 0.42), (0.1, 0.3, 0.6)),
    ("Tail_3", "Tail_2", (0.1, 0.3, 0.6), (0.2, 0.41, 0.52)),
]
for side, sx in (("Left", 1), ("Right", -1)):
    BONES += [
        (f"Ear_{side}_0", "Head_0", (sx * 0.1, -0.14, 0.82), (sx * 0.14, -0.15, 0.96)),
        # Arms held out a little from the shoulders, in front of the body (measured at y -0.2..-0.25: placed further
        # back, they got no weight and stayed stuck out)
        (f"Arm_{side}_0", "Spine_1", (sx * 0.17, -0.16, 0.5), (sx * 0.21, -0.2, 0.44)),
        (f"Arm_{side}_1", f"Arm_{side}_0", (sx * 0.21, -0.2, 0.44), (sx * 0.24, -0.24, 0.35)),
        (f"Arm_{side}_2", f"Arm_{side}_1", (sx * 0.24, -0.24, 0.35), (sx * 0.27, -0.25, 0.29)),
        # Short legs: hip, knee, ankle, toes forward
        (f"0_{side}_Limb_0", "Pelvis", (sx * 0.1, -0.02, 0.17), (sx * 0.11, -0.05, 0.08)),
        (f"0_{side}_Limb_1", f"0_{side}_Limb_0", (sx * 0.11, -0.05, 0.08), (sx * 0.11, -0.06, 0.04)),
        (f"0_{side}_Limb_2", f"0_{side}_Limb_1", (sx * 0.11, -0.06, 0.04), (sx * 0.11, -0.22, 0.02)),
    ]

params = rig_kit.Params()
params.leg_top = 0.18
params.leg_full = 0.1
params.leg_core = 0.05
params.leg_radius = 0.1
params.belly_mid = 0.03
params.tail_from = 0.1
params.head_from = 0.12  # neck and head bones keep off the tail behind
params.arm_core = 0.04
params.arm_radius = 0.075

# Already remeshed and baked, so it skips rig_kit.run's optimize step
mesh = bpy.data.objects["Petalpaw_Squirrel"]
rig = rig_kit.build_rig("PetalpawRig", BONES)
rig_kit.skin(mesh, rig, BONES, params)
if os.environ.get("EXPORT", "1") == "1":
    rig_kit.export("Petalpaw", rig, mesh)
