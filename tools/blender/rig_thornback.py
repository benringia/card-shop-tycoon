"""Rigs Thornback, a chunky thorn boar (a Rare, slightly fierce; a redesign chosen by the user after a Meshy kung-fu
mantis looked wrong, replacing the older scripted voxel mantis, tools/blender/build_thornback.py): generated with
Meshy through the Blender MCP from this prompt (object "Thornback_Src", scaled x1.25 to 1 m tall):

  chunky cartoon thorn boar, mythical bloom creature, slightly fierce, stocky heavy round body on four short thick
  legs with dark hooves, standing still in a neutral pose, all four feet planted square, head and body facing straight
  forward, moss green body with a cream snout and belly, big round snout, two small white tusks, fierce amber eyes,
  small pointed ears, a thick ridge of dark green thorny vines with small pink blossoms running down its back, a short
  curly tail. Toy-like collectible, smooth simple rounded shapes, flat clean colors, low poly, no fur detail. Perfectly
  symmetrical. Isolated single character only, nothing else: no base, no ground, no grass, no props. Legs clearly
  separate. One solid closed shape.

Right first time: one piece, four square hooves, a pink snout, white tusks, pink-lined ears and the thorny vines with
blossoms as a crest on its head (not down the back: kept). 838k triangles, so rig_kit.remesh_bake (voxel 5 mm,
10,000 triangles, colours baked) into "Thornback_Boar" in assets/blender/Thornback/Thornback_meshy.blend. (The mantis
it replaces is in Thornback_mantis.blend.)

It trots on four short legs, its curly tail swishing and ears flicking; for its signature it paws the ground and
charges a short way as thorny vines burst up (the thorncharge, shared with Briarhorn). Bone positions are read off that
mesh. Writes assets/blender/Thornback/Thornback.fbx.
"""
import os
import sys

import bpy

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import rig_kit  # noqa: E402

BONES = [
    ("Root", None, (0, 0, 0), (0, 0, 0.2)),
    ("Pelvis", "Root", (0, 0.32, 0.4), (0, 0.05, 0.42)),
    ("Spine_0", "Pelvis", (0, 0.05, 0.42), (0, -0.15, 0.45)),
    ("Spine_1", "Spine_0", (0, -0.15, 0.45), (0, -0.28, 0.5)),
    ("Neck", "Spine_1", (0, -0.28, 0.5), (0, -0.38, 0.56)),
    # The big head and snout
    ("Head_0", "Neck", (0, -0.38, 0.56), (0, -0.68, 0.5)),
    # The short curly tail, up behind
    ("Tail_0", "Pelvis", (0, 0.56, 0.48), (0, 0.64, 0.56)),
    ("Tail_1", "Tail_0", (0, 0.64, 0.56), (0, 0.66, 0.67)),
]
for side, sx in (("Left", 1), ("Right", -1)):
    BONES += [
        (f"Ear_{side}_0", "Head_0", (sx * 0.16, -0.2, 0.83), (sx * 0.23, -0.2, 0.96)),
        # Front legs: shoulder, knee, hoof
        (f"0_{side}_Limb_0", "Spine_1", (sx * 0.19, -0.17, 0.32), (sx * 0.2, -0.14, 0.16)),
        (f"0_{side}_Limb_1", f"0_{side}_Limb_0", (sx * 0.2, -0.14, 0.16), (sx * 0.21, -0.12, 0.06)),
        (f"0_{side}_Limb_2", f"0_{side}_Limb_1", (sx * 0.21, -0.12, 0.06), (sx * 0.22, -0.24, 0.01)),
        # Hind legs: hip, hock, hoof
        (f"1_{side}_Limb_0", "Pelvis", (sx * 0.18, 0.36, 0.32), (sx * 0.19, 0.38, 0.16)),
        (f"1_{side}_Limb_1", f"1_{side}_Limb_0", (sx * 0.19, 0.38, 0.16), (sx * 0.2, 0.4, 0.06)),
        (f"1_{side}_Limb_2", f"1_{side}_Limb_1", (sx * 0.2, 0.4, 0.06), (sx * 0.21, 0.3, 0.01)),
    ]

params = rig_kit.Params()
params.leg_top = 0.3
params.leg_full = 0.18
params.leg_core = 0.05
params.leg_radius = 0.11
params.belly_mid = 0.06
params.tail_from = 0.55
params.head_from = -0.32

mesh = bpy.data.objects["Thornback_Boar"]
rig = rig_kit.build_rig("ThornbackRig", BONES)
rig_kit.skin(mesh, rig, BONES, params)
# Ear bones sit on top of the head beside the crest: only the ears (above EAR_BASE, out past EAR_SIDE) stay on them
EAR_BASE, EAR_SIDE = 0.82, 0.13
for side in ("Left", "Right"):
    rig_kit.reweight(mesh, f"Ear_{side}_0", lambda p, side=side: rig_kit._ramp(abs(p.x), EAR_SIDE, EAR_SIDE + 0.03)
                     * rig_kit._ramp(p.z, EAR_BASE, EAR_BASE + 0.03) if (p.x > 0) == (side == "Left") else 0.0)
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
if os.environ.get("EXPORT", "1") == "1":
    rig_kit.export("Thornback", rig, mesh)
