"""Rigs Ashbeak, a very cute ember chick (a Common): generated with Meshy through the Blender MCP from this prompt
(object "Ashbeak_Chick" in assets/blender/Ashbeak/Ashbeak.blend, scaled x3.33 to 1 m tall), then optimized by
rig_kit.optimize to about 7,000 triangles:

  very cute chubby cartoon baby bird chick, mythical ember creature, round plump ball-shaped body, big round head, big
  shiny dark eyes set close together, small centred smile, small rounded orange beak, soft ash-grey body with a pale
  grey belly, glowing orange ember crack markings on its body, a small flame-shaped crest of orange and yellow fire on
  top of its head, two thick chunky rounded wings spread straight out to the sides, a short flame-shaped tail, short
  stubby orange feet tucked under. Perfectly symmetrical face. Smooth simple rounded shapes, big simple forms, flat
  clean colors, low poly, no feather detail, no realistic textures. Isolated single character only, nothing else: no
  base, no ground, no grass, no rocks, no stand, no props. One solid closed shape.

Meshy folded the wings at its sides and left out the ember cracks, so it walks like a chick instead of flying, and the
colour map was painted by hand (no second generation): two glowing ember zigzag lines (1, 0.55, 0.15) round its back
and sides (z 0.24 and 0.36, wobbling 3.5 cm), and the tail feathers turned to flame (orange 1, 0.45, 0.1 at the root
to yellow 1, 0.85, 0.3 at the tips). Vertices within 1 mm merged and small holes filled.

It waddles on two orange feet, its folded wings (Arm_ bones) fluttering at its sides. Bone positions are read off that
mesh. Writes assets/blender/Ashbeak/Ashbeak.fbx.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import rig_kit  # noqa: E402

BONES = [
    ("Root", None, (0, 0, 0), (0, 0, 0.2)),
    ("Pelvis", "Root", (0, 0.02, 0.15), (0, 0.0, 0.32)),
    ("Spine_0", "Pelvis", (0, 0.0, 0.32), (0, -0.02, 0.42)),
    ("Spine_1", "Spine_0", (0, -0.02, 0.42), (0, -0.04, 0.5)),
    ("Neck", "Spine_1", (0, -0.04, 0.5), (0, -0.08, 0.55)),
    ("Head_0", "Neck", (0, -0.08, 0.55), (0, -0.2, 0.86)),
    # The flame crest on its head wags like an ear
    ("Ear_Left_0", "Head_0", (0, -0.2, 0.86), (0, -0.21, 1.0)),
    # The flame tail fans out behind, low
    ("Tail_0", "Pelvis", (0.05, 0.25, 0.15), (0.12, 0.35, 0.12)),
    ("Tail_1", "Tail_0", (0.12, 0.35, 0.12), (0.2, 0.46, 0.1)),
]
for side, sx in (("Left", 1), ("Right", -1)):
    BONES += [
        # Folded wings at its sides, shoulder to tip
        (f"Arm_{side}_0", "Spine_1", (sx * 0.24, -0.04, 0.4), (sx * 0.29, 0.0, 0.3)),
        (f"Arm_{side}_1", f"Arm_{side}_0", (sx * 0.29, 0.0, 0.3), (sx * 0.3, 0.04, 0.2)),
        (f"Arm_{side}_2", f"Arm_{side}_1", (sx * 0.3, 0.04, 0.2), (sx * 0.29, 0.06, 0.12)),
        # Little legs and big orange toes pointing forward
        (f"0_{side}_Limb_0", "Pelvis", (sx * 0.12, -0.05, 0.14), (sx * 0.13, -0.08, 0.07)),
        (f"0_{side}_Limb_1", f"0_{side}_Limb_0", (sx * 0.13, -0.08, 0.07), (sx * 0.13, -0.1, 0.03)),
        (f"0_{side}_Limb_2", f"0_{side}_Limb_1", (sx * 0.13, -0.1, 0.03), (sx * 0.14, -0.26, 0.02)),
    ]

params = rig_kit.Params()
params.leg_top = 0.12
params.leg_full = 0.07
params.leg_core = 0.05
params.leg_radius = 0.1
params.belly_mid = 0.03
params.tail_from = 0.22
params.head_from = 0.2
params.arm_core = 0.04
params.arm_radius = 0.075

rig_kit.run("Ashbeak", "Ashbeak_Chick", BONES, params, target_tris=8000)
