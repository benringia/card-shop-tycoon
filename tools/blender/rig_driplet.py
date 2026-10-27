"""Rigs Driplet, a cute water dove (a Common, so cute and small; replaces the bought FrostDove, keeping its card's look):
generated with Meshy through the Blender MCP from this prompt (object "Driplet_Src", scaled x6.667 to 1 m tall: Meshy
made it 15 cm):

  very cute chubby cartoon water dove, mythical tide creature, round plump white body, big round head, big shiny dark
  eyes, small grey beak, soft blue wing tips and tail tips, wings folded neatly at its sides, a small blue feather
  crest on its head with a big glowing clear blue water droplet sitting on top, short pink legs with small feet.
  Standing still in a neutral pose on two legs, feet planted, body and head facing straight forward. Toy-like
  collectible, smooth simple rounded shapes, flat clean colors, low poly, no feather detail. Perfectly symmetrical.
  Isolated single character only, nothing else: no base, no ground, no rocks, no water, no props. Legs clearly
  separate. One solid closed shape.

Right first time apart from the droplet, which came out as a small mark on its chest: kept, and the big water drop on
its head is added here by hand (rig_kit.droplet, a teardrop coloured by paint_patch, beside the crest like the card).
Collapse decimate flattened its round body into facets, so it went through rig_kit.remesh_bake (voxel 5 mm, 9,000
triangles, colours baked) into "Driplet_Dove" in assets/blender/Driplet/Driplet.blend.

It waddles on two short legs, folded wings fluttering a little (Arm_ bones, held as modelled by Party.ARM_POSE), its
tail swishing; the crest and the water drop bob on their own Ear_ bones. Bone positions are read off that mesh (the
legs stand a little off centre, so each side has its own numbers). Writes assets/blender/Driplet/Driplet.fbx.
"""
import os
import sys

import bpy

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import rig_kit  # noqa: E402

DROP_BODY, DROP_TIP = (0.35, 0.75, 1.0), (0.8, 0.95, 1.0)

BONES = [
    ("Root", None, (0, 0, 0), (0, 0, 0.2)),
    ("Pelvis", "Root", (0, 0.0, 0.15), (0, -0.03, 0.3)),
    ("Spine_0", "Pelvis", (0, -0.03, 0.3), (0, -0.06, 0.45)),
    ("Neck", "Spine_0", (0, -0.06, 0.45), (0, -0.1, 0.6)),
    ("Head_0", "Neck", (0, -0.1, 0.6), (0, -0.2, 0.88)),
    # The feather crest (its right) and the water drop (its left) on top of its head
    ("Ear_Right_0", "Head_0", (-0.05, -0.12, 0.9), (-0.07, -0.1, 1.0)),
    ("Ear_Left_0", "Head_0", (0.05, -0.16, 0.92), (0.05, -0.16, 1.06)),
    # The tail sweeps back and a little to its left
    ("Tail_0", "Pelvis", (0.03, 0.18, 0.18), (0.09, 0.26, 0.14)),
    ("Tail_1", "Tail_0", (0.09, 0.26, 0.14), (0.18, 0.4, 0.11)),
    # Short legs: hip, knee, ankle, toes
    ("0_Left_Limb_0", "Pelvis", (0.09, -0.06, 0.2), (0.085, -0.08, 0.1)),
    ("0_Left_Limb_1", "0_Left_Limb_0", (0.085, -0.08, 0.1), (0.085, -0.085, 0.04)),
    ("0_Left_Limb_2", "0_Left_Limb_1", (0.085, -0.085, 0.04), (0.11, -0.18, 0.01)),
    ("0_Right_Limb_0", "Pelvis", (-0.12, -0.06, 0.2), (-0.12, -0.08, 0.1)),
    ("0_Right_Limb_1", "0_Right_Limb_0", (-0.12, -0.08, 0.1), (-0.122, -0.086, 0.04)),
    ("0_Right_Limb_2", "0_Right_Limb_1", (-0.122, -0.086, 0.04), (-0.15, -0.18, 0.01)),
]
for side, sx in (("Left", 1), ("Right", -1)):
    BONES += [
        # Folded wings along its sides, shoulder to tip
        (f"Arm_{side}_0", "Spine_0", (sx * 0.22, -0.17, 0.48), (sx * 0.25, -0.12, 0.4)),
        (f"Arm_{side}_1", f"Arm_{side}_0", (sx * 0.25, -0.12, 0.4), (sx * 0.26, -0.04, 0.32)),
        (f"Arm_{side}_2", f"Arm_{side}_1", (sx * 0.26, -0.04, 0.32), (sx * 0.24, 0.06, 0.27)),
    ]

params = rig_kit.Params()
params.mid_x = -0.02
params.leg_top = 0.16
params.leg_full = 0.1
params.leg_core = 0.03
params.leg_radius = 0.07
params.belly_mid = 0.02
params.arm_core = 0.04
params.arm_radius = 0.08
params.tail_from = 0.2  # the round rump stays on the body
params.head_from = 0.05  # the whole head is in front of this

mesh = bpy.data.objects["Driplet_Dove"]
if "droplet" not in mesh:
    rig_kit.droplet(mesh, base=(0.05, -0.16, 0.9), radius=0.065, height=0.17,
                    uv_body=rig_kit.paint_patch(mesh, DROP_BODY), uv_tip=rig_kit.paint_patch(mesh, DROP_TIP))
    mesh["droplet"] = True
rig = rig_kit.build_rig("DripletRig", BONES)
rig_kit.skin(mesh, rig, BONES, params)
# The Ear_ bones sit on top of the head and would take much of it: only the crest and the drop (above TOP) stay on
# them, the rest goes back to the head
TOP = 0.89
ears = {mesh.vertex_groups[n].index: mesh.vertex_groups[n] for n in ("Ear_Left_0", "Ear_Right_0")}
head = mesh.vertex_groups["Head_0"]
for v in mesh.data.vertices:
    if v.co.z > TOP:
        continue
    moved = sum(g.weight for g in v.groups if g.group in ears)
    if moved <= 0:
        continue
    for group in ears.values():
        group.remove([v.index])
    own = next((g.weight for g in v.groups if g.group == head.index), 0.0)
    head.add([v.index], own + moved, "REPLACE")
if os.environ.get("EXPORT", "1") == "1":
    rig_kit.export("Driplet", rig, mesh)
