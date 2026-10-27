"""Rigs Nightowl, a mythical shadow owl (a Rare, so slightly dangerous and medium size; a redesign chosen by the user to
match its name, replacing the bought heron demon): generated with Meshy through the Blender MCP from this prompt
(object "Nightowl_Src", scaled x2.5 to 1 m tall):

  mythical shadow owl, rare shade creature, slightly dangerous, plump stocky round body, big round head, large fierce
  glowing violet eyes, small sharp hooked beak, dark violet and deep purple feathers with a pale lilac face disc,
  ghostly purple smoke-tipped wing and tail feathers, a glowing silver crescent moon mark on its forehead, short thick
  legs with dark talons. Standing upright, facing straight forward, both wings spread straight out to the sides, level
  and symmetric. Stylized cartoon game model, smooth simple rounded shapes, flat clean colors, low poly, no feather
  detail. Perfectly symmetrical. Isolated single character only, nothing else: no base, no ground, no branch, no
  rocks, no props. One solid closed shape.

Right first time, standing straight with its wings raised up and back. 1.2M triangles of feathers shattered under
collapse decimate, so it went through rig_kit.remesh_bake (voxel 4 mm, fine enough to keep the feathered wings; 10,000
triangles, colours baked) into "Nightowl_Owl" in assets/blender/Nightowl/Nightowl.blend.

It flies, wings beating; on the ground its folded wings breathe. Bone positions are read off that mesh. Writes
assets/blender/Nightowl/Nightowl.fbx.
"""
import os
import sys

import bpy

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import rig_kit  # noqa: E402

BONES = [
    ("Root", None, (0, 0, 0), (0, 0, 0.2)),
    ("Pelvis", "Root", (0, -0.02, 0.25), (0, -0.04, 0.38)),
    ("Spine_0", "Pelvis", (0, -0.04, 0.38), (0, -0.05, 0.48)),
    ("Spine_1", "Spine_0", (0, -0.05, 0.48), (0, -0.06, 0.55)),
    ("Neck", "Spine_1", (0, -0.06, 0.55), (0, -0.07, 0.6)),
    # The big round head, looking forward
    ("Head_0", "Neck", (0, -0.07, 0.6), (0, -0.3, 0.66)),
    # The tail feather hangs down behind the legs
    ("Tail_0", "Pelvis", (0, 0.03, 0.3), (0, 0.06, 0.18)),
    ("Tail_1", "Tail_0", (0, 0.06, 0.18), (0, 0.08, 0.06)),
]
for side, sx in (("Left", 1), ("Right", -1)):
    BONES += [
        # Wings from the shoulder, sweeping up and back to the smoky tips
        (f"Wing_{side}_0", "Spine_1", (sx * 0.17, 0.0, 0.6), (sx * 0.3, 0.12, 0.7)),
        (f"Wing_{side}_1", f"Wing_{side}_0", (sx * 0.3, 0.12, 0.7), (sx * 0.42, 0.23, 0.8)),
        (f"Wing_{side}_2", f"Wing_{side}_1", (sx * 0.42, 0.23, 0.8), (sx * 0.56, 0.34, 0.92)),
        # Short legs to taloned feet
        (f"0_{side}_Limb_0", "Pelvis", (sx * 0.08, -0.02, 0.3), (sx * 0.075, 0.0, 0.15)),
        (f"0_{side}_Limb_1", f"0_{side}_Limb_0", (sx * 0.075, 0.0, 0.15), (sx * 0.08, 0.0, 0.05)),
        (f"0_{side}_Limb_2", f"0_{side}_Limb_1", (sx * 0.08, 0.0, 0.05), (sx * 0.09, -0.15, 0.01)),
    ]

params = rig_kit.Params()
params.leg_top = 0.26
params.leg_full = 0.18
params.leg_core = 0.03
params.leg_radius = 0.07
params.belly_mid = 0.02
params.tail_from = 0.0
params.head_from = 0.2  # the head fills the top of the owl front to back

mesh = bpy.data.objects["Nightowl_Owl"]
rig = rig_kit.build_rig("NightowlRig", BONES)
rig_kit.skin(mesh, rig, BONES, params)
if os.environ.get("EXPORT", "1") == "1":
    rig_kit.export("Nightowl", rig, mesh)
