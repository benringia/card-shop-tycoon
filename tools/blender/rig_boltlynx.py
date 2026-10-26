"""Rigs Boltlynx, the stylized cartoon electric lynx (a Rare, so a little fierce): generated with Meshy through the
Blender MCP from this prompt (object "Boltlynx_Lynx" in assets/blender/Boltlynx/Boltlynx_lynx.blend, scaled x3 to
about 1 m tall), then optimized by rig_kit.optimize to about 10,000 triangles and one 1024-pixel colour map:

  stylized cartoon electric lynx, chunky quadruped standing on all four paws with body horizontal like a walking cat,
  side view game model, toy-like collectible creature, solid compact body, thick sturdy legs, big round paws, short
  stubby bobtail, no mane, smooth simple rounded shapes, flat clean colors, low poly. Slightly fierce confident
  expression: sharp narrowed amber eyes, slanted brows, mouth closed. Golden yellow body, tall pointed ears with
  yellow lightning-bolt shaped ear tufts, glowing bright yellow cheek patches, white zigzag lightning stripes on its
  back and flanks, cream muzzle chest and belly. Mythical creature, no fur detail, no realistic textures, one solid
  closed shape

Meshy gave it a long tail and a slimmer build than asked; kept because it came out as one closed piece. Flat
lightning bolts were added by hand on the tail tip and both ear tips (mapped to a bright yellow patch painted into an
unused corner of the colour map) so it reads as mythical, not a plain cat.

Before rigging, vertices within 6 mm were merged and small holes filled (bmesh remove_doubles 0.002/0.004/0.006,
holes_fill): the reduced mesh had hairline cracks. Bone positions are read off that mesh. It stands mid-step: the right hind paw sits further forward than the left.
Writes assets/blender/Boltlynx/Boltlynx.fbx.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import rig_kit  # noqa: E402

BONES = [
    ("Root", None, (0, 0, 0), (0, 0, 0.2)),
    ("Pelvis", "Root", (0, 0.25, 0.38), (0, 0.0, 0.36)),
    ("Spine_0", "Pelvis", (0, 0.0, 0.36), (0, -0.22, 0.38)),
    ("Spine_1", "Spine_0", (0, -0.22, 0.38), (0, -0.38, 0.48)),
    ("Neck", "Spine_1", (0, -0.38, 0.48), (0, -0.5, 0.62)),
    ("Head_0", "Neck", (0, -0.5, 0.62), (0, -0.74, 0.56)),
    # The tail droops to the ground and curls up into the bolt
    ("Tail_0", "Pelvis", (0, 0.3, 0.4), (0, 0.42, 0.25)),
    ("Tail_1", "Tail_0", (0, 0.42, 0.25), (0, 0.5, 0.1)),
    ("Tail_2", "Tail_1", (0, 0.5, 0.1), (0, 0.62, 0.08)),
    ("Tail_3", "Tail_2", (0, 0.62, 0.08), (0, 0.75, 0.22)),
]
for side, sx, hind_y in (("Left", 1, 0.0), ("Right", -1, -0.08)):
    BONES += [
        (f"Ear_{side}_0", "Head_0", (sx * 0.12, -0.44, 0.76), (sx * 0.22, -0.37, 1.0)),
        # Front legs from the shoulder: elbow, wrist, toes
        (f"0_{side}_Limb_0", "Spine_1", (sx * 0.11, -0.28, 0.42), (sx * 0.1, -0.3, 0.24)),
        (f"0_{side}_Limb_1", f"0_{side}_Limb_0", (sx * 0.1, -0.3, 0.24), (sx * 0.14, -0.37, 0.12)),
        (f"0_{side}_Limb_2", f"0_{side}_Limb_1", (sx * 0.14, -0.37, 0.12), (sx * 0.17, -0.52, 0.03)),
        # Hind legs from mid-haunch: knee, hock, toes
        (f"1_{side}_Limb_0", "Pelvis", (sx * 0.12, 0.17 + hind_y, 0.42), (sx * 0.12, 0.12 + hind_y, 0.24)),
        (f"1_{side}_Limb_1", f"1_{side}_Limb_0", (sx * 0.12, 0.12 + hind_y, 0.24), (sx * 0.13, 0.18 + hind_y, 0.1)),
        (f"1_{side}_Limb_2", f"1_{side}_Limb_1", (sx * 0.13, 0.18 + hind_y, 0.1), (sx * 0.13, 0.08 + hind_y, 0.02)),
    ]

params = rig_kit.Params()
params.leg_top = 0.4
params.leg_full = 0.24
params.leg_core = 0.06
params.leg_radius = 0.13
params.tail_from = 0.32
params.head_from = -0.34  # the ears rise from behind the head
params.belly_mid = 0.03  # the belly between the legs tore down the middle without it
params.smooth_radius = 0.08  # wider smoothing eases the crease where the thighs meet the flanks
params.smooth_passes = 6

rig_kit.run("Boltlynx", "Boltlynx_Lynx", BONES, params)
