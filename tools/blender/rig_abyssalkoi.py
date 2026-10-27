"""Rigs Abyssal Koi, a massive mythical ice shark (an Epic, so very dangerous and big; remade on the user's call after
the first armoured koi): generated with Meshy through the Blender MCP from this prompt (object "AbyssalKoi_Src",
scaled x0.667 to 1 m tall):

  massive fierce mythical ice shark, epic deep sea creature, very dangerous but cool and handsome, huge thick powerful
  bulky body, broad heavy head, confident fierce glowing cyan eyes, wide mouth with neat rows of sharp white teeth, deep
  navy blue skin with a pale blue belly, big glowing icy blue crystal shards growing on its dorsal fin, pectoral fins
  and tail fin, a few small ice crystal spikes along its back, glowing cyan rune lines on its sides. Side view swimming
  pose. Stylized cartoon game model, smooth simple rounded shapes, big simple forms, flat clean colors, low poly, no
  realistic textures. Perfectly symmetrical. Isolated single character only, nothing else: no base, no ground, no
  water, no rocks, no props. One solid closed shape.

Meshy made a clean, fierce cartoon shark but the ice was only cyan fin tips, so the crystals are added here by hand
(rig_kit.crystal, no credits): a crown on the dorsal fin, a ridge along the back, ice horns over the eyes and shards on
the pectoral fins and tail lobes. rig_kit.optimize took it to 8,000 triangles first (collapse decimate: the thin fins
would melt in a voxel remesh). Saved as "AbyssalKoi_Shark" in assets/blender/AbyssalKoi/AbyssalKoi.blend.

It swims (Party.UNDULATE "swim"): a chain from head to tail fin waves side to side. Bone positions are read off that
mesh. Writes assets/blender/AbyssalKoi/AbyssalKoi.fbx.
"""
import os
import sys

import bpy

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import rig_kit  # noqa: E402

ICE = (0.2, 0.65, 1.0)
ICE_TIP = (0.75, 0.95, 1.0)
# (base on the surface, direction, length, radius)
CRYSTALS = [
    # Crown on the dorsal fin
    ((0, 0.2, 0.74), (0, 0.35, 1), 0.26, 0.042),
    ((0.02, 0.13, 0.66), (0.5, 0.1, 1), 0.17, 0.034),
    ((-0.02, 0.13, 0.66), (-0.5, 0.1, 1), 0.17, 0.034),
    ((0, 0.3, 0.68), (0, 0.8, 0.7), 0.15, 0.03),
    # Ridge along the back
    ((0, -0.2, 0.57), (0, 0.3, 1), 0.1, 0.028),
    ((0, -0.02, 0.67), (0, 0.3, 1), 0.13, 0.032),
    ((0, 0.5, 0.52), (0, 0.5, 1), 0.09, 0.025),
    ((0, 0.65, 0.56), (0, 0.5, 1), 0.1, 0.025),
    # Tail lobes
    ((0, 0.93, 0.86), (0, 0.7, 0.9), 0.16, 0.03),
    ((0, 0.88, 0.72), (0, 0.9, 0.4), 0.11, 0.026),
    ((0, 1.0, 0.28), (0, 0.6, -0.7), 0.11, 0.026),
]
for sx in (1, -1):
    CRYSTALS += [
        # Ice horns over the eyes
        ((sx * 0.1, -0.58, 0.43), (sx * 0.35, 0.3, 1), 0.1, 0.024),
        # Pectoral fins
        ((sx * 0.55, -0.01, 0.13), (sx * 0.5, 0.25, 1), 0.13, 0.032),
        ((sx * 0.75, 0.03, 0.07), (sx * 0.8, 0.3, 0.8), 0.11, 0.027),
        ((sx * 0.9, 0.07, 0.03), (sx * 1, 0.15, 0.1), 0.11, 0.024),
    ]

BONES = [
    ("Root", None, (0, 0, 0), (0, 0, 0.2)),
    ("Pelvis", "Root", (0, 0.15, 0.4), (0, -0.05, 0.4)),
    ("Spine_0", "Pelvis", (0, -0.05, 0.4), (0, -0.3, 0.38)),
    ("Spine_1", "Spine_0", (0, -0.3, 0.38), (0, -0.48, 0.34)),
    ("Neck", "Spine_1", (0, -0.48, 0.34), (0, -0.62, 0.31)),
    ("Head_0", "Neck", (0, -0.62, 0.31), (0, -1.0, 0.28)),
    # The body narrows into the tail and its tall fin
    ("Tail_0", "Pelvis", (0, 0.15, 0.4), (0, 0.4, 0.42)),
    ("Tail_1", "Tail_0", (0, 0.4, 0.42), (0, 0.62, 0.44)),
    ("Tail_2", "Tail_1", (0, 0.62, 0.44), (0, 0.82, 0.5)),
    ("Tail_3", "Tail_2", (0, 0.82, 0.5), (0, 1.02, 0.56)),
]

params = rig_kit.Params()
params.tail_from = 0.1
params.head_from = -0.45
params.smooth_radius = 0.07

mesh = bpy.data.objects["AbyssalKoi_Shark"]
if "crystals" not in mesh:
    side = rig_kit.paint_patch(mesh, ICE)
    tip = rig_kit.paint_patch(mesh, ICE_TIP)
    for i, (base, direction, length, radius) in enumerate(CRYSTALS):
        rig_kit.crystal(mesh, base, direction, length, radius, side, tip, spin=i * 0.7)
    mesh["crystals"] = len(CRYSTALS)
rig = rig_kit.build_rig("AbyssalKoiRig", BONES)
rig_kit.skin(mesh, rig, BONES, params)
if os.environ.get("EXPORT", "1") == "1":
    rig_kit.export("AbyssalKoi", rig, mesh)
