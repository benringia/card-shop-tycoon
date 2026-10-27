"""Rigs Puffpuddle, a cute baby sea otter (a Common, so cute and small; replaces the older scripted voxel build,
tools/blender/build_puffpuddle.py, keeping its card's look): generated with Meshy through the Blender MCP from this
prompt (object "Puffpuddle_Src", scaled x1.25 to 1 m tall):

  very cute chubby cartoon baby sea otter, mythical tide creature, exactly four short thick legs straight down under
  its plump body, standing still on all fours in a neutral pose, feet planted square, head and body facing straight
  forward, thick tail straight back. Round head, big shiny dark eyes, black button nose, pink blush cheeks, small happy
  smile, small round ears, warm brown body, cream face and chest, a small glowing aqua pearl on its forehead, glowing
  aqua swirl markings on its tail. Toy-like collectible, smooth simple rounded shapes, flat clean colors, low poly, no
  fur detail. Perfectly symmetrical. Isolated single character only, nothing else: no base, no ground, no rocks, no
  water, no props. Legs clearly separate. One solid closed shape.

Meshy made it standing up on two legs with its paws on its cream belly (kept, the user's call: sea otters stand like
this), a glowing aqua pearl on its forehead, no tail swirls, and a rusty red coat: warmed to the card's chocolate
brown by hand (red-orange pixels: hue +0.025, saturation x0.62, value x0.72; reload the saved PNG into the material
before exporting, or the FBX embeds the old red one). rig_kit.optimize took it to 8,000 triangles. Its left foot came
out a big shapeless lump (it showed in game as a bump), so the left foot (x > 0.015, z < 0.15, y < 0.06) was replaced
by a mirror of the right one, merged at the ankle, the gaps filled and stretched seam faces given the colour beside
them. Saved as "Puffpuddle_Otter" in assets/blender/Puffpuddle/Puffpuddle_meshy.blend.

It waddles upright on two short legs, paws on its belly, its flat tail swishing and ears flicking; for its shell
crack it brings its paws up and taps them together. Bone positions are read off that mesh. Writes
assets/blender/Puffpuddle/Puffpuddle.fbx.
"""
import os
import sys

import bpy
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import rig_kit  # noqa: E402

BONES = [
    ("Root", None, (0, 0, 0), (0, 0, 0.2)),
    ("Pelvis", "Root", (0, -0.03, 0.2), (0, -0.04, 0.36)),
    ("Spine_0", "Pelvis", (0, -0.04, 0.36), (0, -0.06, 0.5)),
    ("Neck", "Spine_0", (0, -0.06, 0.5), (0, -0.09, 0.6)),
    ("Head_0", "Neck", (0, -0.09, 0.6), (0, -0.2, 0.95)),
    # The flat tail lying out behind
    ("Tail_0", "Pelvis", (0, 0.16, 0.2), (0, 0.29, 0.17)),
    ("Tail_1", "Tail_0", (0, 0.29, 0.17), (0, 0.42, 0.15)),
]
for side, sx in (("Left", 1), ("Right", -1)):
    BONES += [
        (f"Ear_{side}_0", "Head_0", (sx * 0.18, -0.12, 0.86), (sx * 0.22, -0.12, 0.94)),
        # Arms from the shoulders, paws resting on the belly
        (f"Arm_{side}_0", "Spine_0", (sx * 0.2, -0.13, 0.52), (sx * 0.23, -0.19, 0.41)),
        (f"Arm_{side}_1", f"Arm_{side}_0", (sx * 0.23, -0.19, 0.41), (sx * 0.2, -0.25, 0.3)),
        (f"Arm_{side}_2", f"Arm_{side}_1", (sx * 0.2, -0.25, 0.3), (sx * 0.16, -0.29, 0.26)),
        # Short legs: hip, knee, ankle, toes
        (f"0_{side}_Limb_0", "Pelvis", (sx * 0.1, -0.06, 0.22), (sx * 0.11, -0.1, 0.12)),
        (f"0_{side}_Limb_1", f"0_{side}_Limb_0", (sx * 0.11, -0.1, 0.12), (sx * 0.11, -0.11, 0.05)),
        (f"0_{side}_Limb_2", f"0_{side}_Limb_1", (sx * 0.11, -0.11, 0.05), (sx * 0.12, -0.2, 0.01)),
    ]

params = rig_kit.Params()
params.leg_top = 0.22
params.leg_full = 0.13
params.leg_core = 0.04
params.leg_radius = 0.09
params.belly_mid = 0.03
params.arm_core = 0.035
params.arm_radius = 0.065
params.tail_from = 0.15
params.head_from = 0.3  # the head sits right over the body: split by height alone

mesh = bpy.data.objects["Puffpuddle_Otter"]
rig = rig_kit.build_rig("PuffpuddleRig", BONES)
rig_kit.skin(mesh, rig, BONES, params)
# The ear bones sit on the head's surface: only the ears (above EAR_BASE, out past EAR_SIDE) stay on them
EAR_BASE, EAR_SIDE = 0.86, 0.15
ears = {mesh.vertex_groups[f"Ear_{side}_0"].index: mesh.vertex_groups[f"Ear_{side}_0"] for side in ("Left", "Right")}
head = mesh.vertex_groups["Head_0"]
for v in mesh.data.vertices:
    if v.co.z > EAR_BASE and abs(v.co.x) > EAR_SIDE:
        continue
    moved = sum(g.weight for g in v.groups if g.group in ears)
    if moved <= 0:
        continue
    for group in ears.values():
        group.remove([v.index])
    own = next((g.weight for g in v.groups if g.group == head.index), 0.0)
    head.add([v.index], own + moved, "REPLACE")
# skin() left the upper arms on the body (12 vertices each), so the paws would move and the upper arms stay: every
# vertex close to an arm (within ARM_FULL of its bones wholly, fading out by ARM_REACH) goes to its nearest arm bone
ARM_FULL, ARM_REACH = 0.05, 0.075
arm_segments = {n: (Vector(h), Vector(t)) for n, _, h, t in BONES if n.startswith("Arm_")}


def arm_share(p, name):
    side = name.split("_")[1]
    if (p.x > 0) != (side == "Left"):
        return 0.0
    mine = rig_kit._segment_distance(p, *arm_segments[name])
    nearest = min(rig_kit._segment_distance(p, *seg) for n, seg in arm_segments.items() if n.split("_")[1] == side)
    if mine > nearest + 1e-9:
        return 0.0
    return rig_kit._ramp(mine, ARM_REACH, ARM_FULL)


for name in arm_segments:
    rig_kit.reweight(mesh, name, lambda p, name=name: arm_share(p, name))
if os.environ.get("EXPORT", "1") == "1":
    rig_kit.export("Puffpuddle", rig, mesh)
