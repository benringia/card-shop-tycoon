"""Rigs Blazehound, a cute flame dachshund puppy (a Rare, kept friendly; replaces the older scripted voxel build,
tools/blender/build_blazehound.py, keeping its card's look): generated with Meshy through the Blender MCP from this
prompt (object "Blazehound_Src", scaled x4 to 1 m tall: Meshy made it 25 cm):

  cute chubby cartoon dachshund puppy, mythical ember creature, slightly cheeky, long low plump body on four short
  thick legs, standing still in a neutral pose, all four feet planted square, head and body facing straight forward,
  glossy black coat with warm tan-orange muzzle, eyebrows, chest, belly and paws, long droopy black ears, big kind
  shiny dark eyes, black nose, small friendly smile, two small orange flame tufts on top of its head, a thin tail held
  up ending in a small orange flame. Toy-like collectible, smooth simple rounded shapes, flat clean colors, low poly,
  no fur detail. Perfectly symmetrical. Isolated single character only, nothing else: no base, no ground, no rug, no
  props. Legs clearly separate. One solid closed shape.

Right first time: four square feet, two flame tufts, droopy ears, a thin tail (no flame on its tip: the game's sneeze
and sparks carry the fire). The two side tufts didn't match (a big curl
out on its left, none on its right), so by hand on the full mesh, before reducing: the curl's yellow faces (z > 0.78,
x > 0.15) copied mirrored onto its right side. Nothing else changed (the middle tuft, eyebrows and crown are Meshy's).
The front right paw is a separate piece sitting against the leg (kept: it skins to that
leg by position). rig_kit.optimize took it to 8,500 triangles. Saved as "Blazehound_Pup" in
assets/blender/Blazehound/Blazehound_meshy.blend.

It trots on four stubby legs, ears flopping (Ear_ bones) and tail wagging; the flame tufts ride on the head. Bone
positions are read off that mesh. Writes assets/blender/Blazehound/Blazehound.fbx.
"""
import os
import sys

import bpy

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import rig_kit  # noqa: E402

BONES = [
    ("Root", None, (0, 0, 0), (0, 0, 0.2)),
    ("Pelvis", "Root", (0, 0.35, 0.3), (0, 0.1, 0.32)),
    ("Spine_0", "Pelvis", (0, 0.1, 0.32), (0, -0.15, 0.36)),
    ("Spine_1", "Spine_0", (0, -0.15, 0.36), (0, -0.3, 0.48)),
    ("Neck", "Spine_1", (0, -0.3, 0.48), (0, -0.38, 0.6)),
    # The head, its long snout reaching forward
    ("Head_0", "Neck", (0, -0.38, 0.6), (0, -0.75, 0.6)),
    # The thin tail curling up behind
    ("Tail_0", "Pelvis", (0, 0.48, 0.2), (0.03, 0.6, 0.14)),
    ("Tail_1", "Tail_0", (0.03, 0.6, 0.14), (0.07, 0.75, 0.09)),
]
for side, sx in (("Left", 1), ("Right", -1)):
    BONES += [
        # Droopy ears hanging from the sides of the head
        (f"Ear_{side}_0", "Head_0", (sx * 0.17, -0.25, 0.64), (sx * 0.34, -0.25, 0.5)),
        # Front legs: shoulder, knee, paw
        (f"0_{side}_Limb_0", "Spine_1", (sx * 0.13, -0.13, 0.3), (sx * 0.135, -0.11, 0.16)),
        (f"0_{side}_Limb_1", f"0_{side}_Limb_0", (sx * 0.135, -0.11, 0.16), (sx * 0.14, -0.1, 0.06)),
        (f"0_{side}_Limb_2", f"0_{side}_Limb_1", (sx * 0.14, -0.1, 0.06), (sx * 0.15, -0.22, 0.01)),
        # Hind legs: hip, knee, paw
        (f"1_{side}_Limb_0", "Pelvis", (sx * 0.12, 0.36, 0.3), (sx * 0.125, 0.35, 0.16)),
        (f"1_{side}_Limb_1", f"1_{side}_Limb_0", (sx * 0.125, 0.35, 0.16), (sx * 0.14, 0.32, 0.06)),
        (f"1_{side}_Limb_2", f"1_{side}_Limb_1", (sx * 0.14, 0.32, 0.06), (sx * 0.16, 0.25, 0.01)),
    ]

params = rig_kit.Params()
params.leg_top = 0.28
params.leg_full = 0.18
params.leg_core = 0.04
params.leg_radius = 0.1
params.belly_mid = 0.03
params.tail_from = 0.46
params.head_from = -0.3

mesh = bpy.data.objects["Blazehound_Pup"]
rig = rig_kit.build_rig("BlazehoundRig", BONES)
rig_kit.skin(mesh, rig, BONES, params)
# The ears are flaps out beside the head: only the ear flaps (out past EAR_SIDE, in front of EAR_BACK, under EAR_TOP)
# stay on the Ear_ bones, the rest goes back to the head
EAR_SIDE, EAR_BACK, EAR_TOP = 0.16, -0.1, 0.74
ears = {mesh.vertex_groups[f"Ear_{side}_0"].index: mesh.vertex_groups[f"Ear_{side}_0"] for side in ("Left", "Right")}
head = mesh.vertex_groups["Head_0"]
for side in ("Left", "Right"):
    rig_kit.reweight(mesh, f"Ear_{side}_0", lambda p, side=side: 1.0 if (p.x > 0) == (side == "Left")
                     and abs(p.x) > EAR_SIDE and p.y < EAR_BACK and p.z < EAR_TOP and p.z > 0.4 else 0.0)
for v in mesh.data.vertices:
    if abs(v.co.x) > EAR_SIDE and v.co.y < EAR_BACK and v.co.z < EAR_TOP and v.co.z > 0.4:
        continue
    moved = sum(g.weight for g in v.groups if g.group in ears)
    if moved <= 0:
        continue
    for group in ears.values():
        group.remove([v.index])
    own = next((g.weight for g in v.groups if g.group == head.index), 0.0)
    head.add([v.index], own + moved, "REPLACE")
if os.environ.get("EXPORT", "1") == "1":
    rig_kit.export("Blazehound", rig, mesh)
