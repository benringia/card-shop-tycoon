"""Rigs Magmaw, a chunky lava salamander (a Rare, slightly fierce; replaces the tinted bought Salamander, keeping its
card's look): generated with Meshy through the Blender MCP from this prompt (object "Magmaw_Src", 1 m tall as
generated):

  chunky cartoon lava salamander, mythical ember creature, slightly fierce, long heavy plump body, exactly four short
  thick legs placed straight down under its body, standing still in a neutral pose, all four feet planted square, head
  and body facing straight forward, thick tail straight back. Bright red-orange skin with glowing yellow belly and jaw,
  wide toothy grin with small white teeth, fierce dark eyes, a row of big chunky orange flame-shaped spikes along its
  back and tail. Toy-like collectible, smooth simple rounded shapes, flat clean colors, low poly. Perfectly symmetrical.
  Isolated single character only, nothing else: no base, no ground, no rocks, no props. Legs clearly separate. One
  solid closed shape.

Right first time: one piece, four square feet (counted at ground level), a wide toothy open mouth, flame spikes along
its back and tail. rig_kit.optimize took it to 9,000 triangles. Saved as "Magmaw_Salamander" in
assets/blender/Magmaw/Magmaw.blend.

It crawls on four short legs, its long tail swaying; its lower jaw is on Jaw_0 for its fire breath (shared with
Infernox). Bone positions are read off that mesh. Writes assets/blender/Magmaw/Magmaw.fbx.
"""
import os
import sys

import bpy
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import rig_kit  # noqa: E402

BONES = [
    ("Root", None, (0, 0, 0), (0, 0, 0.2)),
    ("Pelvis", "Root", (0, 0.12, 0.38), (0, -0.1, 0.4)),
    ("Spine_0", "Pelvis", (0, -0.1, 0.4), (0, -0.35, 0.44)),
    ("Spine_1", "Spine_0", (0, -0.35, 0.44), (0, -0.6, 0.5)),
    ("Neck", "Spine_1", (0, -0.6, 0.5), (0, -0.78, 0.6)),
    ("Head_0", "Neck", (0, -0.78, 0.6), (0, -1.18, 0.62)),
    # The long tail, sweeping back and up to its spiky tip
    ("Tail_0", "Pelvis", (0, 0.25, 0.32), (0, 0.48, 0.28)),
    ("Tail_1", "Tail_0", (0, 0.48, 0.28), (0, 0.72, 0.33)),
    ("Tail_2", "Tail_1", (0, 0.72, 0.33), (0, 0.95, 0.46)),
    ("Tail_3", "Tail_2", (0, 0.95, 0.46), (0, 1.18, 0.68)),
]
for side, sx in (("Left", 1), ("Right", -1)):
    BONES += [
        # Front legs: shoulder, elbow, clawed foot
        (f"0_{side}_Limb_0", "Spine_1", (sx * 0.24, -0.56, 0.4), (sx * 0.3, -0.55, 0.22)),
        (f"0_{side}_Limb_1", f"0_{side}_Limb_0", (sx * 0.3, -0.55, 0.22), (sx * 0.36, -0.6, 0.07)),
        (f"0_{side}_Limb_2", f"0_{side}_Limb_1", (sx * 0.36, -0.6, 0.07), (sx * 0.42, -0.74, 0.01)),
        # Hind legs: hip, knee, clawed foot
        (f"1_{side}_Limb_0", "Pelvis", (sx * 0.18, 0.04, 0.38), (sx * 0.21, 0.02, 0.22)),
        (f"1_{side}_Limb_1", f"1_{side}_Limb_0", (sx * 0.21, 0.02, 0.22), (sx * 0.24, 0.04, 0.07)),
        (f"1_{side}_Limb_2", f"1_{side}_Limb_1", (sx * 0.24, 0.04, 0.07), (sx * 0.27, -0.06, 0.01)),
    ]

params = rig_kit.Params()
params.leg_top = 0.36
params.leg_full = 0.24
params.leg_core = 0.06
params.leg_radius = 0.13
params.belly_mid = 0.08
params.tail_from = 0.22
params.head_from = -0.72

# The lower jaw hinges under the back of the head and drops for its fire breath: its vertices (in front of JAW_FRONT,
# under JAW_TOP) go to Jaw_0, blending over JAW_BLEND into the head's weights
BONES.append(("Jaw_0", "Head_0", (0, -0.82, 0.48), (0, -1.15, 0.44)))
JAW_FRONT, JAW_TOP, JAW_BLEND, JAW_BOTTOM = -0.84, 0.54, 0.03, 0.3  # the front claws reach under the snout


def jaw_share(p):
    if p.y > JAW_FRONT + JAW_BLEND or p.z > JAW_TOP + JAW_BLEND or p.z < JAW_BOTTOM:
        return 0.0
    along = min(1.0, (JAW_FRONT + JAW_BLEND - p.y) / JAW_BLEND)
    below = min(1.0, (JAW_TOP + JAW_BLEND - p.z) / JAW_BLEND)
    return along * below


mesh = bpy.data.objects["Magmaw_Salamander"]
rig = rig_kit.build_rig("MagmawRig", BONES)
rig_kit.skin(mesh, rig, BONES, params)
rig_kit.reweight(mesh, "Jaw_0", jaw_share)
# Claw tips reach past the legs' radius, so skin() gave some to the spine, pelvis and jaw and they'd stay behind as the
# foot stepped: every vertex near the ground within FOOT_REACH of a foot goes wholly to that foot (as for Coalbit)
FOOT_TOP, FOOT_FULL, FOOT_REACH = 0.12, 0.06, 0.25
LEGS = ("0_Left_", "0_Right_", "1_Left_", "1_Right_")
SEGMENTS = {leg: [(Vector(h), Vector(t)) for n, _, h, t in BONES if n in (leg + "Limb_1", leg + "Limb_2")] for leg in LEGS}


def nearest_leg(p):
    best, best_distance = None, FOOT_REACH
    for leg, segments in SEGMENTS.items():
        distance = min(rig_kit._segment_distance(p, a, b) for a, b in segments)
        if distance < best_distance:
            best, best_distance = leg, distance
    return best


for leg in LEGS:
    rig_kit.reweight(mesh, leg + "Limb_2",
                     lambda p, leg=leg: rig_kit._ramp(p.z, FOOT_TOP, FOOT_FULL) if nearest_leg(p) == leg else 0.0)
if os.environ.get("EXPORT", "1") == "1":
    rig_kit.export("Magmaw", rig, mesh)
