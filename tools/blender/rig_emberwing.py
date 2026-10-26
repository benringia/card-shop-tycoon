"""Rigs Emberwing, a proud fire swallow (a Very Rare, so slightly fierce) that flies: generated with Meshy through the
Blender MCP from this prompt (object "Emberwing_Bird" in assets/blender/Emberwing/Emberwing.blend, scaled x1.43 to
1 m tall), then optimized by rig_kit.optimize to about 8,000 triangles (collapse decimation keeps the thin flame
feathers, which a voxel remesh would melt):

  stylized cartoon fire swallow bird, mythical ember creature, slightly fierce and proud, compact rounded body, sharp
  glowing amber eyes with determined brows, short golden beak, charcoal-grey body with glowing orange ember stripes on
  wings and chest, a crest of three flame-shaped feathers on its head, two big thick chunky rounded wings spread wide
  to the sides, a long forked tail of two flame-shaped feathers glowing orange to yellow, small feet tucked under.
  Toy-like collectible creature, smooth simple rounded shapes, flat clean colors, low poly, no feather detail, no
  realistic textures. Perfectly symmetrical. Isolated single character only, nothing else: no base, no ground, no
  rocks, no props, no fire around it. One solid closed shape.

Right first time: wings of flame feathers spread wide, a flame crest and a fanned flame tail. Vertices within 1 mm
merged and small holes filled.

It flies (Party.CREATURE_MODELS flies = true): Wing_<Side>_0..2 run from the shoulder out along the wing, which sweeps
up and back to its tip; the flame tail fans out behind, low. Bone positions are read off that mesh. Writes
assets/blender/Emberwing/Emberwing.fbx.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import rig_kit  # noqa: E402

BONES = [
    ("Root", None, (0, 0, 0), (0, 0, 0.2)),
    ("Pelvis", "Root", (0, -0.05, 0.25), (0, -0.25, 0.32)),
    ("Spine_0", "Pelvis", (0, -0.25, 0.32), (0, -0.35, 0.45)),
    ("Spine_1", "Spine_0", (0, -0.35, 0.45), (0, -0.42, 0.56)),
    ("Neck", "Spine_1", (0, -0.42, 0.56), (0, -0.46, 0.64)),
    ("Head_0", "Neck", (0, -0.46, 0.64), (0, -0.56, 0.95)),
    # The flame tail runs back low and fans out
    ("Tail_0", "Pelvis", (0, 0.0, 0.26), (0, 0.2, 0.23)),
    ("Tail_1", "Tail_0", (0, 0.2, 0.23), (0, 0.4, 0.2)),
    ("Tail_2", "Tail_1", (0, 0.4, 0.2), (0, 0.55, 0.22)),
    ("Tail_3", "Tail_2", (0, 0.55, 0.22), (0, 0.68, 0.24)),
]
for side, sx in (("Left", 1), ("Right", -1)):
    BONES += [
        # Wings from the shoulder out to the tips, sweeping up and back
        (f"Wing_{side}_0", "Spine_1", (sx * 0.16, -0.3, 0.5), (sx * 0.4, -0.29, 0.52)),
        (f"Wing_{side}_1", f"Wing_{side}_0", (sx * 0.4, -0.29, 0.52), (sx * 0.64, -0.28, 0.56)),
        (f"Wing_{side}_2", f"Wing_{side}_1", (sx * 0.64, -0.28, 0.56), (sx * 0.88, -0.29, 0.72)),
        # Thin legs to small taloned feet
        (f"0_{side}_Limb_0", "Pelvis", (sx * 0.1, -0.3, 0.22), (sx * 0.13, -0.32, 0.1)),
        (f"0_{side}_Limb_1", f"0_{side}_Limb_0", (sx * 0.13, -0.32, 0.1), (sx * 0.14, -0.33, 0.03)),
        (f"0_{side}_Limb_2", f"0_{side}_Limb_1", (sx * 0.14, -0.33, 0.03), (sx * 0.15, -0.44, 0.01)),
    ]

params = rig_kit.Params()
params.leg_top = 0.18
params.leg_full = 0.1
params.leg_core = 0.04
params.leg_radius = 0.08
params.tail_from = -0.05
params.head_from = -0.4

rig_kit.run("Emberwing", "Emberwing_Bird", BONES, params, target_tris=8100)
