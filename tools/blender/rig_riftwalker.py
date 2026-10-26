"""Rigs Riftwalker, a massive void dragon (an Epic, so very dangerous and big): generated with Meshy through the
Blender MCP from this prompt (object "Riftwalker_Dragon" in assets/blender/Riftwalker/Riftwalker.blend, scaled x0.333
to 1 m tall), then optimized by rig_kit.optimize to about 10,000 triangles:

  massive menacing void dragon, mythical shadow creature, very dangerous, huge heavy bulky armoured body, thick
  powerful legs with big claws, broad chest, low wide stance on four legs, black obsidian armour scales with glowing
  violet rift cracks, fierce glowing violet eyes, a jaw with sharp fangs, two big swept-back horns, a row of jagged
  spikes down its back, two large thick folded dragon wings with dark purple membranes, a thick spiked tail. Stylized
  cartoon game model, smooth simple rounded shapes, big simple forms, flat clean colors, low poly, no realistic
  textures. Perfectly symmetrical. Isolated single character only, nothing else: no base, no ground, no rocks, no
  props. Legs clearly separate. One solid closed shape.

Right first time: a low, roaring void dragon with folded wings and a long spiked tail curling to its right. Vertices
within 1 mm merged and small holes filled. It prowls on four legs (it doesn't fly); its wings ride on Wing_ bones
(they shift as it breathes and spread for a roar) and its lower jaw on Jaw_0 (rig_kit.reweight).
Bone positions are read off that mesh. Writes assets/blender/Riftwalker/Riftwalker.fbx.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import rig_kit  # noqa: E402

BONES = [
    ("Root", None, (0, 0, 0), (0, 0, 0.2)),
    ("Pelvis", "Root", (0, 0.15, 0.42), (0, -0.1, 0.42)),
    ("Spine_0", "Pelvis", (0, -0.1, 0.42), (0, -0.35, 0.44)),
    ("Spine_1", "Spine_0", (0, -0.35, 0.44), (0, -0.55, 0.5)),
    ("Neck", "Spine_1", (0, -0.55, 0.5), (0, -0.75, 0.6)),
    ("Head_0", "Neck", (0, -0.75, 0.6), (0, -1.03, 0.45)),
    # The long spiked tail runs low behind and curls up to its right at the tip
    ("Tail_0", "Pelvis", (0, 0.3, 0.4), (0, 0.5, 0.22)),
    ("Tail_1", "Tail_0", (0, 0.5, 0.22), (0.03, 0.7, 0.15)),
    ("Tail_2", "Tail_1", (0.03, 0.7, 0.15), (0.0, 0.88, 0.22)),
    ("Tail_3", "Tail_2", (0.0, 0.88, 0.22), (-0.2, 1.03, 0.35)),
]
for side, sx in (("Left", 1), ("Right", -1)):
    BONES += [
        # Folded wings, from the shoulders up and out
        (f"Wing_{side}_0", "Spine_0", (sx * 0.15, -0.2, 0.6), (sx * 0.35, -0.15, 0.82)),
        (f"Wing_{side}_1", f"Wing_{side}_0", (sx * 0.35, -0.15, 0.82), (sx * 0.55, -0.1, 0.95)),
        # Front legs: shoulder, elbow, wrist, claws
        (f"0_{side}_Limb_0", "Spine_1", (sx * 0.15, -0.48, 0.4), (sx * 0.2, -0.48, 0.2)),
        (f"0_{side}_Limb_1", f"0_{side}_Limb_0", (sx * 0.2, -0.48, 0.2), (sx * 0.21, -0.48, 0.06)),
        (f"0_{side}_Limb_2", f"0_{side}_Limb_1", (sx * 0.21, -0.48, 0.06), (sx * 0.22, -0.58, 0.01)),
        # Hind legs from mid-haunch: knee, hock, claws
        (f"1_{side}_Limb_0", "Pelvis", (sx * 0.15, -0.05, 0.4), (sx * 0.22, 0.0, 0.22)),
        (f"1_{side}_Limb_1", f"1_{side}_Limb_0", (sx * 0.22, 0.0, 0.22), (sx * 0.22, -0.1, 0.07)),
        (f"1_{side}_Limb_2", f"1_{side}_Limb_1", (sx * 0.22, -0.1, 0.07), (sx * 0.23, -0.2, 0.01)),
    ]

params = rig_kit.Params()
params.leg_top = 0.36
params.leg_full = 0.2
params.leg_core = 0.06
params.leg_radius = 0.12
params.belly_mid = 0.04
params.tail_from = 0.28
params.head_from = -0.6

# The lower jaw hinges just in front of the neck and drops for roars and yawns. Its vertices (the open mouth's bottom
# half: in front of y -0.76, under z 0.335) go to Jaw_0, blending over 3 cm into the head's weights
BONES.append(("Jaw_0", "Head_0", (0, -0.75, 0.4), (0, -0.92, 0.24)))
JAW_FRONT, JAW_TOP, JAW_BLEND = -0.76, 0.335, 0.03


def jaw_share(p):
    if p.y > JAW_FRONT + JAW_BLEND or p.z > JAW_TOP + JAW_BLEND:
        return 0.0
    along = min(1.0, (JAW_FRONT + JAW_BLEND - p.y) / JAW_BLEND)
    below = min(1.0, (JAW_TOP + JAW_BLEND - p.z) / JAW_BLEND)
    return along * below


rig, mesh = rig_kit.run("Riftwalker", "Riftwalker_Dragon", BONES, params, target_tris=10000, export_now=False)
rig_kit.reweight(mesh, "Jaw_0", jaw_share)
if os.environ.get("EXPORT", "1") == "1":
    rig_kit.export("Riftwalker", rig, mesh)
