"""Rigs Sparkrat, a cute electric mouse (a Common, so cute and small; replaces the bought LightingMouse): generated with
Meshy through the Blender MCP (pose_mode "t-pose") from this prompt (object "Sparkrat_Src", scaled x10 to 1 m tall:
Meshy made it 10 cm):

  very cute chubby cartoon electric mouse, mythical volt creature, happy cheeky grin with two small buck teeth, big
  shiny dark eyes set close together, pink nose, mauve pink fur, round cream belly, two big round ears with orange
  insides, a long thin tail ending in a glowing yellow lightning bolt. Standing upright on two short legs with small
  feet, T-pose, both arms straight out to the sides, body and head facing straight forward. Toy-like collectible,
  plump round body, smooth simple rounded shapes, flat clean colors, low poly, no fur detail. Perfectly symmetrical.
  Isolated single character only, nothing else: no base, no ground, no rocks, no props. Legs clearly separate. One
  solid shape.

Right first time (one piece, symmetric, two feet, a clean T-pose), but the tail came out a short plain stub with no
bolt, so the mythical part is added here by hand: a big yellow lightning bolt (rig_kit.bolt, coloured by paint_patch)
rising up and back from the stub, flat to the sides so it shows from the side. rig_kit.optimize took it to 7,000
triangles first. Saved as "Sparkrat_Mouse" in assets/blender/Sparkrat/Sparkrat.blend.

It waddles upright on two short legs, arms swinging (lowered from the T-pose by Party.ARM_POSE), ears flicking and the
bolt tail wagging. Bone positions are read off that mesh. Writes assets/blender/Sparkrat/Sparkrat.fbx.
"""
import os
import sys

import bpy

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import rig_kit  # noqa: E402

BOLT_YELLOW = (1.0, 0.85, 0.15)

BONES = [
    ("Root", None, (0, 0, 0), (0, 0, 0.2)),
    ("Pelvis", "Root", (0, 0.0, 0.18), (0, -0.02, 0.36)),
    ("Spine_0", "Pelvis", (0, -0.02, 0.36), (0, -0.03, 0.52)),
    # The big round head sits right on the round body (no room for a neck)
    ("Head_0", "Spine_0", (0, -0.03, 0.52), (0, -0.1, 0.95)),
    # The stubby tail, then on up through the lightning bolt
    ("Tail_0", "Pelvis", (0, 0.3, 0.18), (0, 0.42, 0.19)),
    ("Tail_1", "Tail_0", (0, 0.42, 0.19), (0, 0.56, 0.48)),
]
for side, sx in (("Left", 1), ("Right", -1)):
    BONES += [
        (f"Ear_{side}_0", "Head_0", (sx * 0.22, -0.08, 0.82), (sx * 0.28, -0.08, 0.97)),
        # T-posed arms: shoulder, elbow, little hand
        (f"Arm_{side}_0", "Spine_0", (sx * 0.27, -0.08, 0.52), (sx * 0.34, -0.09, 0.52)),
        (f"Arm_{side}_1", f"Arm_{side}_0", (sx * 0.34, -0.09, 0.52), (sx * 0.41, -0.12, 0.52)),
        (f"Arm_{side}_2", f"Arm_{side}_1", (sx * 0.41, -0.12, 0.52), (sx * 0.47, -0.15, 0.52)),
        # Short legs under the round body: hip, knee, ankle, toes
        (f"0_{side}_Limb_0", "Pelvis", (sx * 0.2, -0.04, 0.17), (sx * 0.22, -0.05, 0.08)),
        (f"0_{side}_Limb_1", f"0_{side}_Limb_0", (sx * 0.22, -0.05, 0.08), (sx * 0.24, -0.06, 0.04)),
        (f"0_{side}_Limb_2", f"0_{side}_Limb_1", (sx * 0.24, -0.06, 0.04), (sx * 0.25, -0.15, 0.01)),
    ]

params = rig_kit.Params()
params.leg_top = 0.22
params.leg_full = 0.12
params.leg_core = 0.04
params.leg_radius = 0.09
params.belly_mid = 0.03
params.arm_core = 0.03
params.arm_radius = 0.07
params.tail_from = 0.28
params.head_from = 0.4  # the head sits right over the body: split by height alone

mesh = bpy.data.objects["Sparkrat_Mouse"]
if "bolt" not in mesh:
    rig_kit.bolt(mesh, base=(0, 0.4, 0.2), up=(0, 0.45, 1), side=(0, 1, -0.45), size=0.42, thick=0.05,
                 uv=rig_kit.paint_patch(mesh, BOLT_YELLOW))
    mesh["bolt"] = True
rig = rig_kit.build_rig("SparkratRig", BONES)
rig_kit.skin(mesh, rig, BONES, params)
# Ear bones sit on the head's surface and would take much of the round head: only the ears (above EAR_BASE, out past
# EAR_SIDE) stay on them, the rest goes back to the head
EAR_BASE, EAR_SIDE = 0.8, 0.15
ears = {mesh.vertex_groups[f"Ear_{side}_0"].index: mesh.vertex_groups[f"Ear_{side}_0"] for side in ("Left", "Right")}
head = mesh.vertex_groups["Head_0"]
for v in mesh.data.vertices:
    if v.co.z > EAR_BASE and abs(v.co.x) > EAR_SIDE:
        continue
    moved = sum(g.weight for g in v.groups if g.group in ears)
    if moved <= 0:
        continue
    for index, group in ears.items():
        group.remove([v.index])
    own = next((g.weight for g in v.groups if g.group == head.index), 0.0)
    head.add([v.index], own + moved, "REPLACE")
# skin() left the upper arms on the body, so only the hands moved and the still upper arms read as a second pair of
# arms in game. The whole arm (out past the body's side, between ARM_LOW and ARM_HIGH) goes to the arm bones: the
# upper arm from |x| 0.28-0.32, the forearm from 0.35-0.38, the hand from 0.42-0.45
ARM_LOW, ARM_HIGH, ARM_BLEND = 0.42, 0.61, 0.03


def arm_band(p):
    return rig_kit._ramp(p.z, ARM_LOW - ARM_BLEND, ARM_LOW) * rig_kit._ramp(p.z, ARM_HIGH + ARM_BLEND, ARM_HIGH)


for side, sign in (("Left", 1), ("Right", -1)):
    for segment, start, full in ((0, 0.28, 0.32), (1, 0.35, 0.38), (2, 0.42, 0.45)):
        rig_kit.reweight(mesh, f"Arm_{side}_{segment}",
                         lambda p, sign=sign, start=start, full=full: arm_band(p) * rig_kit._ramp(p.x * sign, start, full))
if os.environ.get("EXPORT", "1") == "1":
    rig_kit.export("Sparkrat", rig, mesh)
