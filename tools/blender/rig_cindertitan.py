"""Rigs Cinder Titan, a massive volcano gorilla (an Epic, so very dangerous and big): generated with Meshy through the
Blender MCP from this prompt (object "CinderTitan_Src", scaled x0.588 to 1 m tall):

  massive menacing volcano gorilla lava golem, mythical ember creature, very dangerous, huge heavy bulky muscular
  body, enormous broad shoulders and chest, thick heavy arms with giant boulder fists wreathed in flames, short thick
  legs, standing upright on its legs and knuckles, dark charcoal rock skin with glowing orange molten lava cracks, heavy
  black volcanic rock armour plates on its shoulders, chest and forearms, a small smoking volcano crater on its back,
  fierce glowing orange eyes, angry brow. Stylized cartoon game model, smooth simple rounded shapes, big simple forms,
  flat clean colors, low poly, no fur, no realistic textures. Perfectly symmetrical. Isolated single character only,
  nothing else: no base, no ground, no rocks, no props. One solid closed shape.

Meshy made a bulky charcoal rock gorilla with a molten lava chest, glowing claws and rock shoulder armour, standing
upright (no back crater; the flaming fists are a game effect). Its 1.2M triangles collapse-decimated into shards, so it
went through rig_kit.remesh_bake (voxel 7 mm, 10,000 triangles, colours baked) into "CinderTitan_Gorilla" in
assets/blender/CinderTitan/CinderTitan.blend.

It walks upright on short thick legs, its huge arms swinging. Bone positions are read off that mesh. Writes
assets/blender/CinderTitan/CinderTitan.fbx.
"""
import os
import sys

import bpy

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import rig_kit  # noqa: E402

BONES = [
    ("Root", None, (0, 0, 0), (0, 0, 0.2)),
    ("Pelvis", "Root", (0, 0.04, 0.36), (0, 0.03, 0.5)),
    ("Spine_0", "Pelvis", (0, 0.03, 0.5), (0, 0.03, 0.62)),
    ("Spine_1", "Spine_0", (0, 0.03, 0.62), (0, 0.02, 0.74)),
    ("Neck", "Spine_1", (0, 0.02, 0.74), (0, -0.02, 0.8)),
    ("Head_0", "Neck", (0, -0.02, 0.8), (0, -0.08, 0.98)),
]
for side, sx in (("Left", 1), ("Right", -1)):
    BONES += [
        # Huge arms: shoulder, elbow, wrist, the boulder fist
        (f"Arm_{side}_0", "Spine_1", (sx * 0.2, 0.05, 0.72), (sx * 0.37, 0.07, 0.5)),
        (f"Arm_{side}_1", f"Arm_{side}_0", (sx * 0.37, 0.07, 0.5), (sx * 0.34, 0.0, 0.3)),
        (f"Arm_{side}_2", f"Arm_{side}_1", (sx * 0.34, 0.0, 0.3), (sx * 0.34, -0.02, 0.15)),
        # Short thick legs: hip, knee, ankle, foot forward
        (f"0_{side}_Limb_0", "Pelvis", (sx * 0.15, 0.04, 0.36), (sx * 0.18, 0.01, 0.2)),
        (f"0_{side}_Limb_1", f"0_{side}_Limb_0", (sx * 0.18, 0.01, 0.2), (sx * 0.21, 0.0, 0.05)),
        (f"0_{side}_Limb_2", f"0_{side}_Limb_1", (sx * 0.21, 0.0, 0.05), (sx * 0.22, -0.12, 0.02)),
    ]

params = rig_kit.Params()
params.leg_top = 0.36
params.leg_full = 0.24
params.leg_core = 0.06
params.leg_radius = 0.11
params.belly_mid = 0.04
params.head_from = 0.4  # the head sits on the shoulders; neck and head bones may reach everything
params.arm_core = 0.06
params.arm_radius = 0.11
params.tail_from = 1.0  # no tail

# Already remeshed and baked, so it skips rig_kit.run's optimize step
mesh = bpy.data.objects["CinderTitan_Gorilla"]
rig = rig_kit.build_rig("CinderTitanRig", BONES)
rig_kit.skin(mesh, rig, BONES, params)
if os.environ.get("EXPORT", "1") == "1":
    rig_kit.export("CinderTitan", rig, mesh)
