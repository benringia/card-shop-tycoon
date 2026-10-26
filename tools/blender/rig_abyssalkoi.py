"""Rigs Abyssal Koi, a giant menacing deep-sea koi (an Epic, so very dangerous and big) that swims: generated with Meshy
through the Blender MCP from this prompt (object "AbyssalKoi_Fish" in assets/blender/AbyssalKoi/AbyssalKoi.blend, 1 m
tall as generated), then optimized by rig_kit.optimize to about 8,500 triangles:

  giant menacing abyssal koi fish monster, mythical deep-sea creature, very dangerous, massive thick heavy bulky body,
  side view swimming pose, big wide jaw with rows of sharp white fangs, fierce glowing cyan eyes, deep navy-blue
  armoured scales with glowing cyan crystal plates along its back, long flowing glowing cyan whiskers, large thick
  crystal fins and a big wide flowing crystal tail fin, glowing cyan spots along its sides. Stylized cartoon game
  model, smooth simple rounded shapes, big simple forms, flat clean colors, low poly, no realistic textures. Perfectly
  symmetrical. Isolated single character only, nothing else: no base, no ground, no water, no rocks, no props. One
  solid closed shape.

Right first time: an armoured abyss fish with a huge fanged maw, glowing cyan spots and crystal fins. Vertices within
1 mm merged and small holes filled. It swims (Party.UNDULATE "swim"): a chain from head to tail fin waves side to
side. Bone positions are read off that mesh. Writes assets/blender/AbyssalKoi/AbyssalKoi.fbx.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import rig_kit  # noqa: E402

BONES = [
    ("Root", None, (0, 0, 0), (0, 0, 0.2)),
    ("Pelvis", "Root", (0, 0.15, 0.55), (0, -0.05, 0.55)),
    ("Spine_0", "Pelvis", (0, -0.05, 0.55), (0, -0.25, 0.52)),
    ("Spine_1", "Spine_0", (0, -0.25, 0.52), (0, -0.4, 0.48)),
    ("Neck", "Spine_1", (0, -0.4, 0.48), (0, -0.55, 0.45)),
    ("Head_0", "Neck", (0, -0.55, 0.45), (0, -0.86, 0.38)),
    # The body narrows into the tail and its big fin
    ("Tail_0", "Pelvis", (0, 0.15, 0.55), (0, 0.32, 0.53)),
    ("Tail_1", "Tail_0", (0, 0.32, 0.53), (0, 0.48, 0.52)),
    ("Tail_2", "Tail_1", (0, 0.48, 0.52), (0, 0.64, 0.56)),
    ("Tail_3", "Tail_2", (0, 0.64, 0.56), (0, 0.86, 0.6)),
]

params = rig_kit.Params()
params.tail_from = 0.1
params.head_from = -0.38
params.smooth_radius = 0.07

rig_kit.run("AbyssalKoi", "AbyssalKoi_Fish", BONES, params, target_tris=9000)
