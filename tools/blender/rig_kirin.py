"""Rigs the celestial sea kirin (the Tide Legendary that replaces Aurora Drake; godlike and big): generated with Meshy
through the Blender MCP from this prompt (object "Kirin_Src", scaled x0.333 to 1 m tall):

  majestic divine celestial sea kirin, godlike legendary creature, powerful sturdy body, thick muscular legs with
  glowing aqua hooves, broad chest, standing proudly on four legs, dragon-like head with fierce glowing aqua eyes, two
  curved golden horns, pearl-white scales with soft aqua shading, a simple smooth flowing aqua mane along its neck, a
  long flowing aqua tail like a wave, a glowing golden halo ring behind its head, small golden armour plates on its
  chest and shoulders. Stylized cartoon game model, smooth simple rounded shapes, flat clean colors, low poly, no fur
  detail, no realistic textures. Perfectly symmetrical. Isolated single character only, nothing else: no base, no
  ground, no clouds, no water, no props. Legs clearly separate. One solid closed shape.

Meshy made it prancing with the right front leg folded up and a gentler face than asked; kept (the divine power is
sold by size and effects). By hand: rig_kit.remesh_bake (voxel 5 mm, 14,000 triangles) into "Kirin_Stage1"; the
raised right front leg (faces with x < -0.055, y < -0.24, z < 0.41) cut away and replaced by a mirror of the planted
left front leg, the openings filled; the result is "Kirin_Body" in assets/blender/Kirin/Kirin.blend. (A second voxel
remesh of the cut mesh fell apart into fragments: a remesh needs a closed surface.)

It walks on four legs, golden horns flicking. Bone positions are read off that mesh. Writes
assets/blender/Kirin/Kirin.fbx.
"""
import os
import sys

import bpy

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import rig_kit  # noqa: E402

BONES = [
    ("Root", None, (0, 0, 0), (0, 0, 0.2)),
    ("Pelvis", "Root", (0, 0.12, 0.33), (0, -0.05, 0.36)),
    ("Spine_0", "Pelvis", (0, -0.05, 0.36), (0, -0.22, 0.42)),
    ("Spine_1", "Spine_0", (0, -0.22, 0.42), (0, -0.32, 0.52)),
    ("Neck", "Spine_1", (0, -0.32, 0.52), (0, -0.38, 0.68)),
    ("Head_0", "Neck", (0, -0.38, 0.68), (0, -0.52, 0.72)),
    # The wave tail runs back and sweeps up to its fin
    ("Tail_0", "Pelvis", (0, 0.15, 0.3), (0, 0.28, 0.24)),
    ("Tail_1", "Tail_0", (0, 0.28, 0.24), (0, 0.4, 0.33)),
    ("Tail_2", "Tail_1", (0, 0.4, 0.33), (0, 0.5, 0.43)),
    ("Tail_3", "Tail_2", (0, 0.5, 0.43), (0, 0.56, 0.52)),
]
for side, sx in (("Left", 1), ("Right", -1)):
    hind = (0.0, 0.0) if side == "Left" else (-0.1, -0.13)  # the right hind leg is a step ahead
    BONES += [
        (f"Ear_{side}_0", "Head_0", (sx * 0.05, -0.33, 0.85), (sx * 0.15, -0.25, 0.99)),
        # Front legs: shoulder, knee, fetlock, hoof
        (f"0_{side}_Limb_0", "Spine_1", (sx * 0.11, -0.33, 0.45), (sx * 0.11, -0.33, 0.26)),
        (f"0_{side}_Limb_1", f"0_{side}_Limb_0", (sx * 0.11, -0.33, 0.26), (sx * 0.116, -0.36, 0.1)),
        (f"0_{side}_Limb_2", f"0_{side}_Limb_1", (sx * 0.116, -0.36, 0.1), (sx * 0.117, -0.43, 0.02)),
        # Hind legs from mid-haunch: knee, hock, hoof
        (f"1_{side}_Limb_0", "Pelvis", (sx * 0.1, 0.06 + hind[0], 0.36), (sx * 0.1, 0.09 + hind[0], 0.25)),
        (f"1_{side}_Limb_1", f"1_{side}_Limb_0", (sx * 0.1, 0.09 + hind[0], 0.25), (sx * 0.107, 0.02 + hind[1] * 0.3, 0.14)),
        (f"1_{side}_Limb_2", f"1_{side}_Limb_1", (sx * 0.107, 0.02 + hind[1] * 0.3, 0.14), (sx * 0.115, -0.04 + hind[1] * 0.75, 0.02)),
    ]

params = rig_kit.Params()
params.leg_top = 0.34
params.leg_full = 0.22
params.leg_core = 0.04
params.leg_radius = 0.08
params.belly_mid = 0.03
params.tail_from = 0.14
params.head_from = -0.3

# Already remeshed and baked, so it skips rig_kit.run's optimize step
mesh = bpy.data.objects["Kirin_Body"]
rig = rig_kit.build_rig("KirinRig", BONES)
rig_kit.skin(mesh, rig, BONES, params)
if os.environ.get("EXPORT", "1") == "1":
    rig_kit.export("Kirin", rig, mesh)
