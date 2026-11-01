"""Rigs the Ash Wolf, the ember ridge's fast hunter (spec 2026-11-01-wild-monster-models-design, style B "wild-touched").
The user picked the "cinder mane" concept; Meshy made it from that picture (image to 3D, job
meshy:i2m:01a19311-8d10-7713-beab-044f8f540535, cut-out assets/blender/AshWolf/AshWolf_concept.png, the smoke wisp
erased first): a charcoal wolf with a big ash-white mane, a snarling fanged face with orange-marked eyes, glowing ember
cracks on its legs and flanks and a bushy orange-tipped tail, 0.9 m tall and 1.76 m long with the tail, facing -Y.

"AshWolf_Src" in assets/blender/AshWolf/AshWolf.blend is that mesh. It came out leaner than the chunky concept, so the
user asked for it bulked up about 15% (not a new generation): bulk_up widens the body and legs from the midline by up to
15% and deepens the torso by up to 15% about its centre line, fading out over the head and mane (high at the front) and
the tail, then it is renamed "AshWolf_Body". A quadruped with a jaw, ears and a four-bone tail; a zero-influence Fx_Tail
bone at the tail tip carries the game's smoke (Config/Wild fx; skipped when skinning). The glow mask lights the ember
cracks, the eye marks and the tail tip. Writes AshWolf.fbx and AshWolf_glow.png next to the .blend. RIG=0 only bulks.
"""
import importlib
import os
import sys

import bpy

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import rig_kit  # noqa: E402

importlib.reload(rig_kit)

BULK = 0.15


def _ramp(value, zero, one):
    t = (value - zero) / (one - zero)
    t = max(0.0, min(1.0, t))
    return t * t * (3 - 2 * t)


def bulk_up(mesh):
    """Widens the body and legs from the midline and deepens the torso about z 0.55, by up to BULK, fading out over the
    head and mane (in front of y -0.2 and above z 0.4) and the tail (behind y 0.4). A smooth function of position, so
    Meshy's split seam vertices move together and no cracks open."""
    for v in mesh.data.vertices:
        p = v.co
        head = _ramp(p.y, -0.2, -0.45) * _ramp(p.z, 0.4, 0.55)
        tail = _ramp(p.y, 0.4, 0.5)
        weight = (1 - head) * (1 - tail)
        torso = _ramp(p.z, 0.3, 0.45)
        p.x *= 1 + BULK * weight
        p.z = 0.55 + (p.z - 0.55) * (1 + BULK * weight * torso)
    mesh.data.update()


source = bpy.data.objects.get("AshWolf_Src")
if source:
    bulk_up(source)
    source.name = "AshWolf_Body"
    source.data.name = "AshWolf_Body"
    print("bulked up by", BULK)

# Bone positions read off the bulked mesh: front paws at x 0.24, y -0.48; hind paws at x 0.2, y 0.19 (hocks behind at
# y 0.29); the mane from y -0.25 to -0.55 hides small ears, which ride the head (ear bones dragged the mane)
BONES = [
    ("Root", None, (0, 0, 0), (0, 0, 0.2)),
    ("Pelvis", "Root", (0, 0.3, 0.52), (0, 0.1, 0.54)),
    ("Spine_0", "Pelvis", (0, 0.1, 0.54), (0, -0.1, 0.57)),
    ("Spine_1", "Spine_0", (0, -0.1, 0.57), (0, -0.32, 0.62)),
    ("Neck", "Spine_1", (0, -0.32, 0.62), (0, -0.52, 0.66)),
    ("Head_0", "Neck", (0, -0.52, 0.66), (0, -0.86, 0.55)),
    ("Jaw_0", "Head_0", (0, -0.62, 0.5), (0, -0.85, 0.44)),
    # The bushy tail, curling up to its orange tip
    ("Tail_0", "Pelvis", (0, 0.42, 0.5), (0, 0.55, 0.46)),
    ("Tail_1", "Tail_0", (0, 0.55, 0.46), (0, 0.66, 0.47)),
    ("Tail_2", "Tail_1", (0, 0.66, 0.47), (0, 0.76, 0.56)),
    ("Tail_3", "Tail_2", (0, 0.76, 0.56), (0, 0.84, 0.68)),
]
for side, sx in (("Left", 1), ("Right", -1)):
    BONES += [
        # Front legs: shoulder, elbow, wrist, paw forward
        (f"0_{side}_Limb_0", "Spine_1", (sx * 0.17, -0.42, 0.45), (sx * 0.22, -0.44, 0.26)),
        (f"0_{side}_Limb_1", f"0_{side}_Limb_0", (sx * 0.22, -0.44, 0.26), (sx * 0.24, -0.45, 0.09)),
        (f"0_{side}_Limb_2", f"0_{side}_Limb_1", (sx * 0.24, -0.45, 0.09), (sx * 0.25, -0.51, 0.01)),
        # Hind legs: hip, knee, hock, paw
        (f"1_{side}_Limb_0", "Pelvis", (sx * 0.15, 0.22, 0.47), (sx * 0.2, 0.17, 0.27)),
        (f"1_{side}_Limb_1", f"1_{side}_Limb_0", (sx * 0.2, 0.17, 0.27), (sx * 0.19, 0.28, 0.09)),
        (f"1_{side}_Limb_2", f"1_{side}_Limb_1", (sx * 0.19, 0.28, 0.09), (sx * 0.2, 0.18, 0.01)),
    ]
FX = [("Fx_Tail", "Tail_3", (0, 0.83, 0.66), (0, 0.85, 0.7))]

params = rig_kit.Params()
params.leg_top = 0.42
params.leg_full = 0.26
params.leg_core = 0.07
params.leg_radius = 0.14
params.belly_mid = 0.05
params.tail_from = 0.42
params.head_from = -0.3

GLOW = [{"hue": (12, 42), "sat": (0.55, 1.0), "val": (0.68, 1.0)}]  # the ember cracks, eye marks and tail tip

if os.environ.get("RIG", "1") == "1":
    mesh = bpy.data.objects["AshWolf_Body"]
    mesh.parent = None
    for mod in [m for m in mesh.modifiers if m.type == "ARMATURE"]:
        mesh.modifiers.remove(mod)
    rig_kit.optimize(mesh, "AshWolf", 5000)
    rig = rig_kit.build_rig("AshWolfRig", BONES + FX)
    rig_kit.skin(mesh, rig, BONES, params)
    if os.environ.get("EXPORT", "1") == "1":
        rig_kit.export("AshWolf", rig, mesh)
    rig_kit.glow_mask(mesh, "AshWolf", GLOW, grow=1)
    bpy.ops.wm.save_mainfile()
