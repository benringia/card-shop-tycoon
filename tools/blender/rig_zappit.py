"""Rigs Zappit, a very cute lavender electric bunny (a Common): generated with Meshy through the Blender MCP from this
prompt (object "Zappit_Bunny" in assets/blender/Zappit/Zappit.blend, scaled x2.5 to about 1 m tall), then optimized
by rig_kit.optimize to about 10,000 triangles and one 1024-pixel colour map:

  very cute chubby cartoon bunny, mythical electric creature, sitting on its big flat hind feet with small front paws,
  side view game model, toy-like collectible creature, round plump body, big round head, two big round shiny dark eyes
  set close together near the middle of the face, a tiny pink nose and a small simple smile centred under it, soft
  pink blush, soft lavender-violet body, white zigzag lightning stripes on its back and sides, a small white diamond
  mark on its forehead, two long upright ears, a round fluffy tail. Perfectly symmetrical face. Smooth simple rounded
  shapes, flat clean colors, low poly, no fur detail, no realistic textures, one solid closed shape

(The first Zappit was yellow with red cheeks and a bolt tail, too close to Pikachu, and its face was lopsided: one eye
a smear, eyes wide apart; patching it caused more problems than it solved, so it was regenerated.)

Meshy stood it upright, very pale lilac, without the stripes. By hand: vertices within 4 mm merged and small holes
filled; the body colour deepened to lavender (pixels of hue 250..345 and saturation 0.08..0.38 set to hue 265,
saturation +0.22, value x0.95; the white belly, pink ears, eyes and nose untouched); the forehead diamond painted gold
(1, 0.86, 0.25) as a gem; the white tail cut off and replaced by a round ball of lightning (icosphere, radius 0.075,
at 0, 0.2, 0.185) and a small bolt added on each ear tip (rig_kit.bolt), both electric yellow (1, 0.9, 0.2) from
rig_kit.paint_patch.

It walks upright on short legs with big feet, arms hanging at its sides. Bone positions are read off that mesh.
Writes assets/blender/Zappit/Zappit.fbx.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import rig_kit  # noqa: E402

BONES = [
    ("Root", None, (0, 0, 0), (0, 0, 0.2)),
    ("Pelvis", "Root", (0, 0.02, 0.14), (0, 0.0, 0.3)),
    ("Spine_0", "Pelvis", (0, 0.0, 0.3), (0, 0.0, 0.38)),
    ("Spine_1", "Spine_0", (0, 0.0, 0.38), (0, -0.01, 0.46)),
    ("Neck", "Spine_1", (0, -0.01, 0.46), (0, -0.02, 0.52)),
    ("Head_0", "Neck", (0, -0.02, 0.52), (0, -0.05, 0.8)),
    # The ball-of-lightning tail
    ("Tail_0", "Pelvis", (0, 0.15, 0.18), (0, 0.21, 0.19)),
    ("Tail_1", "Tail_0", (0, 0.21, 0.19), (0, 0.27, 0.2)),
    # Long ears leaning back, two bones each so they flop; the right one leans further
    ("Ear_Left_0", "Head_0", (0.09, 0.0, 0.8), (0.11, 0.03, 0.9)),
    ("Ear_Left_1", "Ear_Left_0", (0.11, 0.03, 0.9), (0.125, 0.07, 1.0)),
    ("Ear_Right_0", "Head_0", (-0.09, 0.01, 0.8), (-0.115, 0.06, 0.9)),
    ("Ear_Right_1", "Ear_Right_0", (-0.115, 0.06, 0.9), (-0.131, 0.125, 0.99)),
]
for side, sx in (("Left", 1), ("Right", -1)):
    BONES += [
        # Arms hanging at its sides, paws a little forward
        (f"Arm_{side}_0", "Spine_1", (sx * 0.16, -0.04, 0.46), (sx * 0.19, -0.07, 0.38)),
        (f"Arm_{side}_1", f"Arm_{side}_0", (sx * 0.19, -0.07, 0.38), (sx * 0.2, -0.1, 0.3)),
        (f"Arm_{side}_2", f"Arm_{side}_1", (sx * 0.2, -0.1, 0.3), (sx * 0.19, -0.12, 0.24)),
        # Short legs, big feet pointing forward
        (f"0_{side}_Limb_0", "Pelvis", (sx * 0.09, 0.0, 0.2), (sx * 0.1, 0.0, 0.08)),
        (f"0_{side}_Limb_1", f"0_{side}_Limb_0", (sx * 0.1, 0.0, 0.08), (sx * 0.09, 0.0, 0.04)),
        (f"0_{side}_Limb_2", f"0_{side}_Limb_1", (sx * 0.09, 0.0, 0.04), (sx * 0.09, -0.14, 0.02)),
    ]

params = rig_kit.Params()
params.leg_top = 0.22
params.leg_full = 0.12
params.leg_core = 0.06
params.leg_radius = 0.11
params.belly_mid = 0.03
params.tail_from = 0.14
params.head_from = 0.2  # the head sits on top of the body: only the tail behind is kept from it
params.arm_core = 0.035
params.arm_radius = 0.065

rig_kit.run("Zappit", "Zappit_Bunny", BONES, params)
