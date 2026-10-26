"""Rigs Wispurr, a very cute ghost kitten (a Common): generated with Meshy through the Blender MCP from this prompt
(object "Wispurr_Kitten" in assets/blender/Wispurr/Wispurr.blend, scaled x4 to 1 m tall), then optimized by
rig_kit.optimize to about 6,800 triangles:

  very cute chubby cartoon ghost kitten, mythical shadow creature, standing on all four short stubby legs with its
  body horizontal, toy-like collectible creature, round plump body, big round head, big shiny teal eyes set close
  together, small centred smile, soft pink blush, pale lavender body with a white chest, small pointed ears with lilac
  insides, a thick short tail that curls up and ends in a big rounded glowing violet wisp flame, a small glowing
  violet star mark on its forehead. Perfectly symmetrical face. Smooth simple rounded shapes, big simple forms, flat
  clean colors, low poly, no fur detail, no realistic textures. Isolated single character only, nothing else: no
  base, no ground, no grass, no rocks, no props. Legs clearly separate from each other. One solid closed shape.

Meshy stood it upright, white, with the tail swinging out to its left; kept. By hand: the white tinted pale lavender
(every pale colourless pixel times 0.86, 0.8, 0.98) and the mesh moved 10.3 cm along +X so the body is centred (the
tail had pulled the generated shape off the middle). Vertices within 1 mm merged and small holes filled.

It waddles upright, paws held up in front, the wisp tail swaying. Bone positions are read off that mesh. Writes
assets/blender/Wispurr/Wispurr.fbx.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import rig_kit  # noqa: E402

MID = -0.02  # the body's midline after centring

BONES = [
    ("Root", None, (MID, 0, 0), (MID, 0, 0.2)),
    ("Pelvis", "Root", (MID, 0.02, 0.15), (MID, 0.0, 0.32)),
    ("Spine_0", "Pelvis", (MID, 0.0, 0.32), (MID, -0.02, 0.46)),
    ("Spine_1", "Spine_0", (MID, -0.02, 0.46), (MID, -0.04, 0.56)),
    ("Neck", "Spine_1", (MID, -0.04, 0.56), (MID, -0.05, 0.62)),
    ("Head_0", "Neck", (MID, -0.05, 0.62), (MID, -0.12, 0.9)),
    # The tail runs out to its left and curls up into the wisp
    ("Tail_0", "Pelvis", (0.15, 0.2, 0.17), (0.32, 0.27, 0.19)),
    ("Tail_1", "Tail_0", (0.32, 0.27, 0.19), (0.46, 0.29, 0.24)),
    ("Tail_2", "Tail_1", (0.46, 0.29, 0.24), (0.55, 0.28, 0.36)),
    ("Tail_3", "Tail_2", (0.55, 0.28, 0.36), (0.59, 0.27, 0.55)),
]
for side, sx in (("Left", 1), ("Right", -1)):
    BONES += [
        (f"Ear_{side}_0", "Head_0", (MID + sx * 0.16, -0.02, 0.86), (MID + sx * 0.32, 0.0, 1.0)),
        # Paws held up in front of the tummy
        (f"Arm_{side}_0", "Spine_1", (MID + sx * 0.2, -0.16, 0.52), (MID + sx * 0.18, -0.25, 0.44)),
        (f"Arm_{side}_1", f"Arm_{side}_0", (MID + sx * 0.18, -0.25, 0.44), (MID + sx * 0.16, -0.3, 0.37)),
        # Short legs, feet a little forward
        (f"0_{side}_Limb_0", "Pelvis", (MID + sx * 0.12, -0.02, 0.17), (MID + sx * 0.12, -0.04, 0.08)),
        (f"0_{side}_Limb_1", f"0_{side}_Limb_0", (MID + sx * 0.12, -0.04, 0.08), (MID + sx * 0.12, -0.1, 0.02)),
    ]

params = rig_kit.Params()
params.mid_x = MID
params.leg_top = 0.16
params.leg_full = 0.09
params.leg_core = 0.05
params.leg_radius = 0.1
params.belly_mid = 0.03
params.tail_from = 0.15
params.head_from = 0.2
params.arm_core = 0.04
params.arm_radius = 0.08

rig_kit.run("Wispurr", "Wispurr_Kitten", BONES, params, target_tris=7000)
