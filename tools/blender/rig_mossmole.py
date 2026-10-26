"""Rigs Mossmole, a very cute forest mole (a Common): generated with Meshy through the Blender MCP from this prompt
(object "Mossmole_Src" in assets/blender/Mossmole/Mossmole.blend, scaled x6.67 to 1 m tall):

  very cute chubby cartoon mole, mythical forest creature, standing on all four short legs, toy-like collectible
  creature, round plump body, big round head, big shiny dark eyes set close together, small centred smile, round pink
  nose, soft brown body with a cream face, big pink digging paws, a smooth rounded patch of bright green moss on its
  back with three small glowing teal mushroom caps sitting flat on the moss, a tiny two-leaf sprout on top of its head.
  Perfectly symmetrical face. Smooth simple rounded shapes, flat clean colors, low poly, no fur detail, no realistic
  textures. Isolated single character only, nothing else: no base, no ground, no grass, no rocks, no stand, no props.
  Legs clearly separate from each other. One solid closed shape.

(The first try, without the "isolated single character" clause, came with a grass patch round its feet and couldn't
be used.) Meshy made it upright and egg-shaped, hugging a little moss garden with glowing teal mushrooms to its
chest: kept. Its 610,000 triangles of fine moss collapse-decimate into shards, so it went through
rig_kit.remesh_bake (voxel 6 mm, 10,000 triangles, colours baked) instead of rig_kit.optimize; the result is
"Mossmole_Mole".

It waddles on tiny feet, hugging its garden (the garden follows the chest; the arms hardly swing). No tail or ears.
Bone positions are read off that mesh. Writes assets/blender/Mossmole/Mossmole.fbx.
"""
import os
import sys

import bpy

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import rig_kit  # noqa: E402

BONES = [
    ("Root", None, (0, 0, 0), (0, 0, 0.2)),
    ("Pelvis", "Root", (0, 0.02, 0.15), (0, 0.0, 0.32)),
    ("Spine_0", "Pelvis", (0, 0.0, 0.32), (0, 0.0, 0.46)),
    ("Spine_1", "Spine_0", (0, 0.0, 0.46), (0, -0.01, 0.6)),
    ("Neck", "Spine_1", (0, -0.01, 0.6), (0, -0.02, 0.66)),
    ("Head_0", "Neck", (0, -0.02, 0.66), (0, -0.06, 0.95)),
]
for side, sx in (("Left", 1), ("Right", -1)):
    BONES += [
        # Arms wrapped round the garden at its chest
        (f"Arm_{side}_0", "Spine_1", (sx * 0.27, -0.12, 0.5), (sx * 0.27, -0.22, 0.42)),
        (f"Arm_{side}_1", f"Arm_{side}_0", (sx * 0.27, -0.22, 0.42), (sx * 0.22, -0.3, 0.38)),
        (f"Arm_{side}_2", f"Arm_{side}_1", (sx * 0.22, -0.3, 0.38), (sx * 0.16, -0.34, 0.38)),
        # Tiny legs: hip, knee, ankle, toes poking forward
        (f"0_{side}_Limb_0", "Pelvis", (sx * 0.14, -0.06, 0.16), (sx * 0.15, -0.14, 0.08)),
        (f"0_{side}_Limb_1", f"0_{side}_Limb_0", (sx * 0.15, -0.14, 0.08), (sx * 0.15, -0.18, 0.04)),
        (f"0_{side}_Limb_2", f"0_{side}_Limb_1", (sx * 0.15, -0.18, 0.04), (sx * 0.15, -0.31, 0.02)),
    ]

params = rig_kit.Params()
params.leg_top = 0.16
params.leg_full = 0.09
params.leg_core = 0.05
params.leg_radius = 0.1
params.belly_mid = 0.04
params.head_from = 0.4  # the head sits right on the body; split from it by height alone
params.arm_core = 0.04
params.arm_radius = 0.075

# Already remeshed and baked, so it skips rig_kit.run's optimize step
mesh = bpy.data.objects["Mossmole_Mole"]
rig = rig_kit.build_rig("MossmoleRig", BONES)
rig_kit.skin(mesh, rig, BONES, params)
if os.environ.get("EXPORT", "1") == "1":
    rig_kit.export("Mossmole", rig, mesh)
