"""Rigs Gloomlet, a very cute shadow bat (a Common) that flies: generated with Meshy through the Blender MCP from this
prompt (object "Gloomlet_Bat" in assets/blender/Gloomlet/Gloomlet.blend, scaled x10 to 0.8 m tall), then optimized
by rig_kit.optimize to about 8,000 triangles (collapse decimation keeps the thin wing membranes, which a voxel
remesh would melt):

  very cute chubby cartoon bat, mythical shadow creature, round plump ball-shaped body, big round head, big shiny dark
  eyes set close together with violet shine, small centred smile with two tiny fangs, soft lavender blush, dark purple
  body with a lighter lilac belly, big pointed ears with small glowing violet flame wisps at the tips, a glowing violet
  crescent moon mark on its forehead, two thick chunky rounded bat wings spread straight out to the sides, short stubby
  feet tucked under. Perfectly symmetrical face. Smooth simple rounded shapes, big simple forms, flat clean colors,
  low poly, no fur detail, no realistic textures. Isolated single character only, nothing else: no base, no ground,
  no grass, no rocks, no stand, no props. One solid closed shape.

Meshy left out the ear wisps, so a glowing violet teardrop wisp was added on each ear tip by hand (stretched
icosphere, radius 0.045, coloured 0.78, 0.45, 1.0 from rig_kit.paint_patch). Vertices within 1 mm merged and small
holes filled.

It flies (Party.CREATURE_MODELS flies = true): the Wing_<Side>_0..2 chains flap, its stubby legs tuck. Bone
positions are read off that mesh. Writes assets/blender/Gloomlet/Gloomlet.fbx.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import rig_kit  # noqa: E402

BONES = [
    ("Root", None, (0, 0, 0), (0, 0, 0.2)),
    ("Pelvis", "Root", (0, 0.02, 0.12), (0, 0.0, 0.26)),
    ("Spine_0", "Pelvis", (0, 0.0, 0.26), (0, 0.0, 0.36)),
    ("Spine_1", "Spine_0", (0, 0.0, 0.36), (0, 0.0, 0.42)),
    ("Neck", "Spine_1", (0, 0.0, 0.42), (0, -0.01, 0.46)),
    ("Head_0", "Neck", (0, -0.01, 0.46), (0, -0.04, 0.72)),
]
for side, sx in (("Left", 1), ("Right", -1)):
    BONES += [
        (f"Ear_{side}_0", "Head_0", (sx * 0.19, 0.05, 0.64), (sx * 0.29, 0.08, 0.84)),
        # Wings from the shoulders straight out to the tips, a little behind the body
        (f"Wing_{side}_0", "Spine_1", (sx * 0.24, 0.1, 0.44), (sx * 0.34, 0.12, 0.48)),
        (f"Wing_{side}_1", f"Wing_{side}_0", (sx * 0.34, 0.12, 0.48), (sx * 0.44, 0.14, 0.5)),
        (f"Wing_{side}_2", f"Wing_{side}_1", (sx * 0.44, 0.14, 0.5), (sx * 0.53, 0.15, 0.52)),
        # Stubby feet, tucked when flying
        (f"0_{side}_Limb_0", "Pelvis", (sx * 0.07, 0.0, 0.15), (sx * 0.07, 0.0, 0.07)),
        (f"0_{side}_Limb_1", f"0_{side}_Limb_0", (sx * 0.07, 0.0, 0.07), (sx * 0.07, -0.03, 0.02)),
    ]

params = rig_kit.Params()
params.leg_top = 0.13
params.leg_full = 0.08
params.leg_core = 0.04
params.leg_radius = 0.08
params.head_from = 0.3  # the head sits right on the body; neck and head bones may reach everything in front
params.tail_from = 1.0  # no tail

rig_kit.run("Gloomlet", "Gloomlet_Bat", BONES, params, target_tris=8100)
