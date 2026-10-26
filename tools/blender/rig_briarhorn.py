"""Rigs Briarhorn, a massive forest bison bull (a Very Rare, so heavy and slightly fierce; remodelled to match its card
art after the first, too skinny cow): generated with Meshy through the Blender MCP from this prompt (object
"Briarhorn_Src", scaled x0.667 to 1 m tall):

  massive heavy forest bison bull, very rare mythical bloom creature, slightly fierce, huge bulky muscular body with a
  big tall shoulder hump, very thick sturdy legs with dark hooves, head lowered, broad snout with a silver nose ring,
  rusty orange-brown body with big cream patches, two thick white horns wrapped in simple dark green thorny vines with
  a few pink roses, short tail with a dark tuft. Stylized cartoon game model, smooth simple rounded shapes, big simple
  forms, flat clean colors, low poly, no fur detail, no realistic textures. Perfectly symmetrical. Isolated single
  character only, nothing else: no base, no ground, no grass, no rocks, no props. Legs clearly separate. One solid
  closed shape.

Meshy put a wreath of roses on its hump as well as round the horns (2.86M triangles of petals): kept. It went through
rig_kit.remesh_bake (voxel 7 mm, 10,000 triangles, colours baked) into "Briarhorn_Bull" in
assets/blender/Briarhorn/Briarhorn.blend.

It plods on four splayed legs with a heavy step, the horned head held low. Bone positions are read off that mesh.
Writes assets/blender/Briarhorn/Briarhorn.fbx.
"""
import os
import sys

import bpy

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import rig_kit  # noqa: E402

BONES = [
    ("Root", None, (0, 0, 0), (0, 0, 0.2)),
    ("Pelvis", "Root", (0, 0.45, 0.6), (0, 0.15, 0.62)),
    ("Spine_0", "Pelvis", (0, 0.15, 0.62), (0, -0.15, 0.65)),
    ("Spine_1", "Spine_0", (0, -0.15, 0.65), (0, -0.3, 0.64)),
    ("Neck", "Spine_1", (0, -0.3, 0.64), (0, -0.5, 0.6)),
    ("Head_0", "Neck", (0, -0.5, 0.6), (0, -0.76, 0.42)),
    # The tufted tail hangs down behind
    ("Tail_0", "Pelvis", (0, 0.68, 0.6), (0.04, 0.74, 0.5)),
    ("Tail_1", "Tail_0", (0.04, 0.74, 0.5), (0.06, 0.76, 0.37)),
    ("Tail_2", "Tail_1", (0.06, 0.76, 0.37), (0.05, 0.76, 0.22)),
]
for side, sx in (("Left", 1), ("Right", -1)):
    ahead = 0.0 if side == "Left" else -0.06  # the right front hoof stands a little ahead
    BONES += [
        # Rose-wrapped horns, curving out, flick like ears
        (f"Ear_{side}_0", "Head_0", (sx * 0.15, -0.5, 0.72), (sx * 0.3, -0.52, 0.82)),
        # Front legs: shoulder, knee, fetlock, hoof
        (f"0_{side}_Limb_0", "Spine_1", (sx * 0.2, -0.25 + ahead * 0.5, 0.48), (sx * 0.26, -0.22 + ahead, 0.25)),
        (f"0_{side}_Limb_1", f"0_{side}_Limb_0", (sx * 0.26, -0.22 + ahead, 0.25), (sx * 0.28, -0.22 + ahead, 0.08)),
        (f"0_{side}_Limb_2", f"0_{side}_Limb_1", (sx * 0.28, -0.22 + ahead, 0.08), (sx * 0.29, -0.3 + ahead, 0.01)),
        # Hind legs from mid-haunch: knee, hock, hoof
        (f"1_{side}_Limb_0", "Pelvis", (sx * 0.13, 0.42, 0.5), (sx * 0.13, 0.48, 0.28)),
        (f"1_{side}_Limb_1", f"1_{side}_Limb_0", (sx * 0.13, 0.48, 0.28), (sx * 0.13, 0.53, 0.08)),
        (f"1_{side}_Limb_2", f"1_{side}_Limb_1", (sx * 0.13, 0.53, 0.08), (sx * 0.15, 0.46, 0.01)),
    ]

params = rig_kit.Params()
params.leg_top = 0.4
params.leg_full = 0.24
params.leg_core = 0.07
params.leg_radius = 0.14
params.belly_mid = 0.04
params.tail_from = 0.62
params.head_from = -0.3

# Already remeshed and baked, so it skips rig_kit.run's optimize step
mesh = bpy.data.objects["Briarhorn_Bull"]
rig = rig_kit.build_rig("BriarhornRig", BONES)
rig_kit.skin(mesh, rig, BONES, params)
if os.environ.get("EXPORT", "1") == "1":
    rig_kit.export("Briarhorn", rig, mesh)
