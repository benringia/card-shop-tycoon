"""Rigs Frostfang, a mythical ice fox (a Rare, slightly fierce; replaces the tinted bought PurpleFox): generated with
Meshy through the Blender MCP from this prompt (object "Frostfang_Src", scaled x2.5 to 1 m tall), described fresh,
not from the old card:

  chunky cartoon mythical ice fox, rare creature, slightly fierce. Standing on all four legs like a dog, exactly four
  short thick legs straight down under its sturdy plump body, all four feet planted square, head and body facing
  straight forward, not sitting, not turned. Smooth simple solid body, no fur spikes, no fur strands. Pale icy blue
  body with a white chest, a simple smooth rounded white mane on its neck, big pointed ears, fierce glowing ice-blue
  eyes. Main feature: large glowing bright blue ice crystal spikes along its back, a big ice crystal on the tip of its
  thick tail, a glowing blue crystal gem on its forehead. Flat clean colors, low poly, toy-like collectible. Perfectly
  symmetrical. Isolated single character only: no base, no ground, no snow, no props. One solid shape.

(The first, looser prompt gave a plain spiky-furred fox sitting turned to one side; regenerated with this firm one.)
One piece, four feet, teal crystals on its back and forehead, a white mane, a big pale ice blade rising over its rump
and a fluffy tail. rig_kit.optimize took it to 9,000 triangles. Saved as "Frostfang_Fox" in
assets/blender/Frostfang/Frostfang.blend.

It trots on four legs, ears flicking, its tail and ice blade swaying. Bone positions are read off that mesh. Writes
assets/blender/Frostfang/Frostfang.fbx.
"""
import os
import sys

import bpy
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import rig_kit  # noqa: E402

BONES = [
    ("Root", None, (0, 0, 0), (0, 0, 0.2)),
    ("Pelvis", "Root", (0, 0.18, 0.42), (0, -0.02, 0.44)),
    ("Spine_0", "Pelvis", (0, -0.02, 0.44), (0, -0.2, 0.46)),
    ("Spine_1", "Spine_0", (0, -0.2, 0.46), (0, -0.32, 0.5)),
    ("Neck", "Spine_1", (0, -0.32, 0.5), (0, -0.4, 0.62)),
    ("Head_0", "Neck", (0, -0.4, 0.62), (0, -0.64, 0.56)),
    # The fluffy tail sweeps back low; the ice blade over the rump rides its base
    ("Tail_0", "Pelvis", (0, 0.24, 0.42), (0, 0.38, 0.38)),
    ("Tail_1", "Tail_0", (0, 0.38, 0.38), (0, 0.52, 0.32)),
    ("Tail_2", "Tail_1", (0, 0.52, 0.32), (0, 0.65, 0.24)),
]
for side, sx in (("Left", 1), ("Right", -1)):
    front_y = -0.4 if side == "Left" else -0.42  # its right forefoot stands a little ahead
    hind_y = 0.12 if side == "Left" else 0.07
    BONES += [
        (f"Ear_{side}_0", "Head_0", (sx * 0.1, -0.4, 0.8), (sx * 0.21, -0.42, 0.94)),
        # Front legs: shoulder, knee, paw
        (f"0_{side}_Limb_0", "Spine_1", (sx * 0.09, -0.3, 0.42), (sx * 0.09, -0.3, 0.22)),
        (f"0_{side}_Limb_1", f"0_{side}_Limb_0", (sx * 0.09, -0.3, 0.22), (sx * 0.1, front_y + 0.04, 0.06)),
        (f"0_{side}_Limb_2", f"0_{side}_Limb_1", (sx * 0.1, front_y + 0.04, 0.06), (sx * 0.11, front_y - 0.03, 0.01)),
        # Hind legs: hip, hock, paw
        (f"1_{side}_Limb_0", "Pelvis", (sx * 0.1, 0.14, 0.42), (sx * 0.1, 0.2, 0.22)),
        (f"1_{side}_Limb_1", f"1_{side}_Limb_0", (sx * 0.1, 0.2, 0.22), (sx * 0.11, hind_y + 0.03, 0.06)),
        (f"1_{side}_Limb_2", f"1_{side}_Limb_1", (sx * 0.11, hind_y + 0.03, 0.06), (sx * 0.12, hind_y - 0.05, 0.01)),
    ]

params = rig_kit.Params()
params.leg_top = 0.36
params.leg_full = 0.26
params.leg_core = 0.04
params.leg_radius = 0.09
params.belly_mid = 0.03
params.tail_from = 0.22
params.head_from = -0.3

mesh = bpy.data.objects["Frostfang_Fox"]
rig = rig_kit.build_rig("FrostfangRig", BONES)
rig_kit.skin(mesh, rig, BONES, params)
# Ear bones sit on top of the head: only the ears (above EAR_BASE, out past EAR_SIDE) stay on them
EAR_BASE, EAR_SIDE = 0.78, 0.06
for side in ("Left", "Right"):
    rig_kit.reweight(mesh, f"Ear_{side}_0", lambda p, side=side: rig_kit._ramp(p.z, EAR_BASE, EAR_BASE + 0.04)
                     if (p.x > EAR_SIDE if side == "Left" else p.x < -EAR_SIDE) and p.y < -0.3 else 0.0)
# Paws and toes reach past the legs' radius: near the ground every vertex within FOOT_REACH of a foot goes to it
FOOT_TOP, FOOT_FULL, FOOT_REACH = 0.08, 0.04, 0.15
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
    rig_kit.export("Frostfang", rig, mesh)
