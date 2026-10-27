"""Rigs Reefray, a mythical coral manta ray (a Rare, so slightly dangerous and medium size; a full redesign replacing the
bought metal crab, chosen by the user): generated with Meshy through the Blender MCP from this prompt (object
"Reefray_Src"):

  mythical coral manta ray, rare tide creature, slightly dangerous, thick sturdy body, big wide wings spread out flat
  and level, symmetric, gliding straight forward in a neutral pose, deep teal back with glowing aqua spots, pale belly,
  a ridge of chunky pink and orange coral crests along its back, two short curled head fins like horns, fierce glowing
  aqua eyes, a long thick tail with a coral spike tip. Stylized cartoon game model, smooth simple rounded shapes, flat
  clean colors, low poly, no realistic textures. Perfectly symmetrical. Isolated single character only, nothing else:
  no base, no ground, no water, no rocks, no props. One solid closed shape.

Meshy made a pale manta with aqua spots, teal edges and curled coral head fins (no back ridge), standing on its end:
turned 90 degrees about X, then 180 about Y (it lay belly up), and centred. Kept at its generated scale (1.35 m
wingspan, 0.34 m tall): the game scales models by height, so Party gives it a small size. rig_kit.optimize took it to
8,000 triangles (collapse decimate: the thin wings would melt in a voxel remesh). Saved as "Reefray_Manta" in
assets/blender/Reefray/Reefray.blend.

It glides (flies), its wings beating slowly; the coral head fins flick like ears and the tail trails. Bone positions
are read off that mesh. Writes assets/blender/Reefray/Reefray.fbx.
"""
import os
import sys

import bpy

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import rig_kit  # noqa: E402

BONES = [
    ("Root", None, (0, 0, 0), (0, 0, 0.1)),
    ("Pelvis", "Root", (0, 0.15, 0.22), (0, 0.0, 0.22)),
    ("Spine_0", "Pelvis", (0, 0.0, 0.22), (0, -0.15, 0.23)),
    ("Spine_1", "Spine_0", (0, -0.15, 0.23), (0, -0.24, 0.23)),
    ("Neck", "Spine_1", (0, -0.24, 0.23), (0, -0.31, 0.22)),
    ("Head_0", "Neck", (0, -0.31, 0.22), (0, -0.46, 0.21)),
    # The long tail, curling a little to the right at its coral tip
    ("Tail_0", "Pelvis", (0, 0.2, 0.22), (0, 0.3, 0.23)),
    ("Tail_1", "Tail_0", (0, 0.3, 0.23), (-0.01, 0.38, 0.23)),
    ("Tail_2", "Tail_1", (-0.01, 0.38, 0.23), (-0.05, 0.45, 0.2)),
    ("Tail_3", "Tail_2", (-0.05, 0.45, 0.2), (-0.13, 0.5, 0.15)),
]
for side, sx in (("Left", 1), ("Right", -1)):
    BONES += [
        # Coral head fins, curling forward
        (f"Ear_{side}_0", "Head_0", (sx * 0.08, -0.43, 0.2), (sx * 0.1, -0.5, 0.17)),
        # Wings from the body out to the tips, arching down
        (f"Wing_{side}_0", "Spine_0", (sx * 0.08, -0.05, 0.22), (sx * 0.28, -0.03, 0.2)),
        (f"Wing_{side}_1", f"Wing_{side}_0", (sx * 0.28, -0.03, 0.2), (sx * 0.48, -0.06, 0.14)),
        (f"Wing_{side}_2", f"Wing_{side}_1", (sx * 0.48, -0.06, 0.14), (sx * 0.645, -0.18, 0.03)),
    ]

params = rig_kit.Params()
params.tail_from = 0.18
params.head_from = -0.25
params.smooth_radius = 0.05

mesh = bpy.data.objects["Reefray_Manta"]
rig = rig_kit.build_rig("ReefrayRig", BONES)
rig_kit.skin(mesh, rig, BONES, params)
if os.environ.get("EXPORT", "1") == "1":
    rig_kit.export("Reefray", rig, mesh)
