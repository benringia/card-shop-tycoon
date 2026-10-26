"""Rigs Briarhorn, a forest bull (a Very Rare, so confident and slightly fierce): generated with Meshy through the
Blender MCP from this prompt (object "Briarhorn_Src", scaled x0.6 to 1 m tall):

  stylized cartoon forest bull, mythical bloom creature, confident and slightly fierce, sturdy stocky body on four
  thick legs with hooves, head lowered, narrowed glowing green eyes, a broad snout, rich brown body with a cream belly,
  two big curved pale horns wrapped in thick dark green thorny vines with a few pink roses, a patch of smooth green moss
  on its shoulders, a short tail with a leafy tuft. Toy-like collectible creature, smooth simple rounded shapes, big
  simple forms, flat clean colors, low poly, no fur detail, no realistic textures. Perfectly symmetrical. Isolated
  single character only, nothing else: no base, no ground, no grass, no rocks, no props. Legs clearly separate. One
  solid closed shape.

Meshy wrapped the thorny rose vines round its body instead of its horns (2.35M triangles of roses): kept. It went
through rig_kit.remesh_bake (voxel 8 mm, 10,000 triangles, colours baked) into "Briarhorn_Bull" in
assets/blender/Briarhorn/Briarhorn.blend. It stood turned about 19 degrees mid-stride, so the mesh was turned back
(rotate 19 degrees about Z, then 6.7 cm along +X) so the body runs along Y with its feet square.

It plods on four legs with a heavy step, the head held low. Bone positions are read off that mesh. Writes
assets/blender/Briarhorn/Briarhorn.fbx.
"""
import os
import sys

import bpy

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import rig_kit  # noqa: E402

BONES = [
    ("Root", None, (0, 0, 0), (0, 0, 0.2)),
    ("Pelvis", "Root", (0, 0.3, 0.55), (0, 0.05, 0.55)),
    ("Spine_0", "Pelvis", (0, 0.05, 0.55), (0, -0.2, 0.58)),
    ("Spine_1", "Spine_0", (0, -0.2, 0.58), (0, -0.35, 0.62)),
    ("Neck", "Spine_1", (0, -0.35, 0.62), (0, -0.45, 0.7)),
    ("Head_0", "Neck", (0, -0.45, 0.7), (0.05, -0.62, 0.64)),
    ("Tail_0", "Pelvis", (0.02, 0.4, 0.6), (0.08, 0.5, 0.48)),
    ("Tail_1", "Tail_0", (0.08, 0.5, 0.48), (0.15, 0.58, 0.32)),
    ("Tail_2", "Tail_1", (0.15, 0.58, 0.32), (0.2, 0.65, 0.2)),
]
for side, sx in (("Left", 1), ("Right", -1)):
    BONES += [
        # Horns, curving up and out, flick like ears
        (f"Ear_{side}_0", "Head_0", (sx * 0.1, -0.48, 0.82), (sx * 0.24, -0.45, 1.0)),
        # Front legs: shoulder, knee, fetlock, hoof
        (f"0_{side}_Limb_0", "Spine_1", (sx * 0.15, -0.3, 0.5), (sx * 0.18, -0.32, 0.28)),
        (f"0_{side}_Limb_1", f"0_{side}_Limb_0", (sx * 0.18, -0.32, 0.28), (sx * 0.19, -0.33, 0.08)),
        (f"0_{side}_Limb_2", f"0_{side}_Limb_1", (sx * 0.19, -0.33, 0.08), (sx * 0.19, -0.4, 0.01)),
        # Hind legs from mid-haunch: knee, hock, hoof
        (f"1_{side}_Limb_0", "Pelvis", (sx * 0.15, 0.25, 0.5), (sx * 0.17, 0.3, 0.28)),
        (f"1_{side}_Limb_1", f"1_{side}_Limb_0", (sx * 0.17, 0.3, 0.28), (sx * 0.18, 0.26, 0.08)),
        (f"1_{side}_Limb_2", f"1_{side}_Limb_1", (sx * 0.18, 0.26, 0.08), (sx * 0.18, 0.2, 0.01)),
    ]

params = rig_kit.Params()
params.leg_top = 0.45
params.leg_full = 0.28
params.leg_core = 0.07
params.leg_radius = 0.14
params.belly_mid = 0.04
params.tail_from = 0.38
params.head_from = -0.35
params.smooth_radius = 0.07

# Already remeshed and baked, so it skips rig_kit.run's optimize step
mesh = bpy.data.objects["Briarhorn_Bull"]
rig = rig_kit.build_rig("BriarhornRig", BONES)
rig_kit.skin(mesh, rig, BONES, params)
if os.environ.get("EXPORT", "1") == "1":
    rig_kit.export("Briarhorn", rig, mesh)
