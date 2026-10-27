"""Rigs Coalbit, a cute baby coal salamander (a Common, so cute and small; replaces the tinted bought Salamander):
generated with Meshy through the Blender MCP from this prompt (object "Coalbit_Src", scaled x1.667 to 1 m tall):

  very cute chubby cartoon baby coal salamander, mythical ember creature, exactly four short thick legs placed straight
  down under its round body like a puppy, standing still in a neutral pose, all four feet planted square, head and body
  facing straight forward, short thick tail straight back. Toy-like collectible creature, round plump body, big round
  head, big shiny dark eyes set close together, pink blush cheeks, small happy smile, dark charcoal grey skin with
  glowing orange ember spots, a small orange flame tuft on its head, a small flame on its tail tip. Smooth simple
  rounded shapes, flat clean colors, low poly, no spikes. Perfectly symmetrical. Isolated single character only,
  nothing else: no base, no ground, no rocks, no props. Legs clearly separate. One solid closed shape.

(The first Coalbit, a splayed four-legged salamander, came out with five legs and was replaced; its files are in
Coalbit_v1.blend.) Meshy made this one sitting up on two hind legs with its arms on its peach belly, like Cindercub:
kept (the user's call) and rigged as a two-legged waddler. rig_kit.optimize took it to 8,000 triangles. By hand: a
second thin tail, a loose separate piece lying beside the real one, was deleted; the body stood turned 17.4 degrees
(feet not square), so it was turned back about Z and centred; that turned its head, which had faced forward, so the
head (weight smoothstep(z, 0.48, 0.62)) was turned back 16.7 degrees about a vertical axis at (0, -0.08). Saved as
"Coalbit_Cub" in assets/blender/Coalbit/Coalbit.blend.

It waddles on two short legs, paws resting on its belly, its thick tail trailing and ears flicking. Bone positions are
read off that mesh. Writes assets/blender/Coalbit/Coalbit.fbx.
"""
import os
import sys

import bpy

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import rig_kit  # noqa: E402

BONES = [
    ("Root", None, (0, 0, 0), (0, 0, 0.2)),
    ("Pelvis", "Root", (0, -0.06, 0.2), (0, -0.07, 0.34)),
    ("Spine_0", "Pelvis", (0, -0.07, 0.34), (0, -0.08, 0.46)),
    # The big round head sits right on the short body (no room for a neck), its flame tuft on top
    ("Head_0", "Spine_0", (0, -0.08, 0.46), (0, -0.12, 0.96)),
    # The thick tail, lying behind it a little to its left
    ("Tail_0", "Pelvis", (0.01, 0.1, 0.2), (0.07, 0.22, 0.17)),
    ("Tail_1", "Tail_0", (0.07, 0.22, 0.17), (0.12, 0.34, 0.14)),
]
for side, sx in (("Left", 1), ("Right", -1)):
    BONES += [
        (f"Ear_{side}_0", "Head_0", (sx * 0.14, -0.06, 0.76), (sx * 0.17, -0.06, 0.84)),
        # Arms hang from the shoulders with the paws resting on the belly
        (f"Arm_{side}_0", "Spine_0", (sx * 0.15, -0.14, 0.42), (sx * 0.17, -0.16, 0.35)),
        (f"Arm_{side}_1", f"Arm_{side}_0", (sx * 0.17, -0.16, 0.35), (sx * 0.15, -0.21, 0.3)),
        (f"Arm_{side}_2", f"Arm_{side}_1", (sx * 0.15, -0.21, 0.3), (sx * 0.11, -0.24, 0.28)),
        # Short legs: hip, knee, ankle, toes
        (f"0_{side}_Limb_0", "Pelvis", (sx * 0.13, -0.12, 0.3), (sx * 0.15, -0.16, 0.17)),
        (f"0_{side}_Limb_1", f"0_{side}_Limb_0", (sx * 0.15, -0.16, 0.17), (sx * 0.17, -0.12, 0.06)),
        (f"0_{side}_Limb_2", f"0_{side}_Limb_1", (sx * 0.17, -0.12, 0.06), (sx * 0.19, -0.21, 0.01)),
    ]

params = rig_kit.Params()
params.leg_top = 0.28
params.leg_full = 0.18
params.leg_core = 0.04
params.leg_radius = 0.09
params.belly_mid = 0.03
params.arm_core = 0.03
params.arm_radius = 0.06
params.tail_from = 0.1
params.head_from = 0.4  # the head sits right over the body: split by height alone

mesh = bpy.data.objects["Coalbit_Cub"]
rig = rig_kit.build_rig("CoalbitRig", BONES)
rig_kit.skin(mesh, rig, BONES, params)
# The ear bones sit on the head's surface, so skin() gave them most of the round head and an ear flick warped it: only
# the ear tips (above EAR_BASE, out past EAR_SIDE) stay on them, the rest goes back to the head
EAR_BASE, EAR_SIDE = 0.79, 0.11
ear_groups = {mesh.vertex_groups[f"Ear_{side}_0"].index for side in ("Left", "Right")}


def head_share(p, index):
    on_ear = any(g.group in ear_groups and g.weight > 0 for g in mesh.data.vertices[index].groups)
    return 1.0 if on_ear and not (p.z > EAR_BASE and abs(p.x) > EAR_SIDE) else 0.0


positions = {v.index: v.co.copy() for v in mesh.data.vertices}
lookup = {tuple(round(c, 6) for c in co): i for i, co in positions.items()}
rig_kit.reweight(mesh, "Head_0", lambda p: head_share(p, lookup[tuple(round(c, 6) for c in p)]))
for side in ("Left", "Right"):
    group = mesh.vertex_groups[f"Ear_{side}_0"]
    group.remove([v.index for v in mesh.data.vertices if head_share(v.co, v.index) == 1.0 and any(g.group == group.index for g in v.groups)])
if os.environ.get("EXPORT", "1") == "1":
    rig_kit.export("Coalbit", rig, mesh)
