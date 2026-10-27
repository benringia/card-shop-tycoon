"""Rigs Vinewyrm, a chunky vine serpent (a Rare, slightly fierce; replaces the bought GiantSnake, keeping its card's
look): generated with Meshy through the Blender MCP from this prompt (object "Vinewyrm_Src", scaled x2 to 1 m tall):

  chunky cartoon vine serpent, mythical bloom creature, slightly fierce, a thick heavy plump snake body lying stretched
  out straight along the ground, no coils, head raised a little and facing straight forward, bright lime green scales
  with a pale yellow-green belly, friendly but fierce glowing amber eyes, a small forked red tongue, dark green leafy
  vines wrapped around its body, a crown of pink flowers and leaves on its head, a few pink blossoms along its back, a
  thick tapering tail. Toy-like collectible, smooth simple rounded shapes, flat clean colors, low poly. Perfectly
  symmetrical. Isolated single character only, nothing else: no base, no ground, no grass, no props. One solid closed
  shape.

Right first time: its body lies along the ground, the neck rises straight up to a flower-crowned head, the tail curls up
behind, blossoms and leaves along its sides (separate pieces, merged by the remesh). 872k triangles, so
rig_kit.remesh_bake (voxel 4 mm, 10,000 triangles, colours baked) into "Vinewyrm_Serpent" in
assets/blender/Vinewyrm/Vinewyrm.blend.

It slithers (Party.UNDULATE "slither"): a chain from the head down the raised neck, along the body and up the tail
waves side to side. Bone positions are read off that mesh. Writes assets/blender/Vinewyrm/Vinewyrm.fbx.
"""
import os
import sys

import bpy

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import rig_kit  # noqa: E402

BONES = [
    ("Root", None, (0, 0, 0), (0, 0, 0.2)),
    # The body along the ground, from the back towards the raised neck
    ("Pelvis", "Root", (0, 0.18, 0.14), (0, -0.05, 0.15)),
    ("Spine_0", "Pelvis", (0, -0.05, 0.15), (0, -0.22, 0.2)),
    ("Spine_1", "Spine_0", (0, -0.22, 0.2), (0, -0.28, 0.4)),
    # The neck rises straight up to the head
    ("Neck", "Spine_1", (0, -0.28, 0.4), (0, -0.27, 0.62)),
    ("Head_0", "Neck", (0, -0.27, 0.62), (0, -0.62, 0.64)),
    # The tail curls up behind
    ("Tail_0", "Pelvis", (0, 0.18, 0.14), (0, 0.32, 0.12)),
    ("Tail_1", "Tail_0", (0, 0.32, 0.12), (0, 0.43, 0.22)),
    ("Tail_2", "Tail_1", (0, 0.43, 0.22), (0, 0.53, 0.37)),
    ("Tail_3", "Tail_2", (0, 0.53, 0.37), (0, 0.63, 0.54)),
]

params = rig_kit.Params()
params.tail_from = 0.2
params.head_from = -0.05  # neck and head take only the front half
params.smooth_radius = 0.06

mesh = bpy.data.objects["Vinewyrm_Serpent"]
rig = rig_kit.build_rig("VinewyrmRig", BONES)
rig_kit.skin(mesh, rig, BONES, params)
if os.environ.get("EXPORT", "1") == "1":
    rig_kit.export("Vinewyrm", rig, mesh)
