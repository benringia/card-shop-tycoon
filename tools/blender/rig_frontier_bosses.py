"""Rigs the Frontier's three bosses (spec docs/superpowers/specs/2026-11-10-frontier-valley-design.md; the owner's picks
Frost Tyrant A, Storm Sovereign B, Rift Devourer A), each made by Meshy from its cut-out concept
(assets/blender/<Name>/<Name>_concept.png; jobs in the plan's ledger) and prepared by prep_frontier_model.py (1 m tall,
facing -Y, "<Name>_Src" in assets/blender/<Name>/<Name>.blend). Bone positions were read off orthographic grid renders,
the Devourer's feet off its ground vertices. Each has zero-influence Fx_ bones (left out of skinning; the importer keeps
them with Keep Zero Influence Bones) where its fight moment's effect starts. Run in a background Blender:

  NAME=FrostTyrant blender -b assets/blender/FrostTyrant/FrostTyrant.blend --python tools/blender/rig_frontier_bosses.py

Writes <Name>.fbx and <Name>_glow.png next to the .blend and saves it. EXPORT=0 skips the FBX.
"""
import importlib
import os
import sys

import bpy

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import rig_kit  # noqa: E402

importlib.reload(rig_kit)

SIDES = (("Left", 1), ("Right", -1))


def params_with(**values):
    params = rig_kit.Params()
    for key, value in values.items():
        setattr(params, key, value)
    return params


def frost_tyrant():
    """The ice yeti king: a biped with long arms and crystal fists, a bearded jaw, a crown (Fx_Crown: his ice shield
    starts there). The cape rides the spine. Glow: the icy crystals and eyes, not the pale fur."""
    bones = [
        ("Root", None, (0, 0, 0), (0, 0, 0.2)),
        ("Pelvis", "Root", (0, 0.02, 0.3), (0, 0.0, 0.46)),
        ("Spine_0", "Pelvis", (0, 0.0, 0.46), (0, -0.02, 0.58)),
        ("Spine_1", "Spine_0", (0, -0.02, 0.58), (0, -0.04, 0.66)),
        ("Neck", "Spine_1", (0, -0.04, 0.66), (0, -0.1, 0.72)),
        ("Head_0", "Neck", (0, -0.1, 0.72), (0, -0.2, 0.88)),
        ("Jaw_0", "Head_0", (0, -0.18, 0.68), (0, -0.26, 0.52)),
    ]
    for side, sx in SIDES:
        bones += [
            (f"Arm_{side}_0", "Spine_1", (sx * 0.24, 0.0, 0.64), (sx * 0.37, 0.0, 0.45)),
            (f"Arm_{side}_1", f"Arm_{side}_0", (sx * 0.37, 0.0, 0.45), (sx * 0.38, -0.02, 0.28)),
            (f"Arm_{side}_2", f"Arm_{side}_1", (sx * 0.38, -0.02, 0.28), (sx * 0.37, -0.05, 0.16)),
            (f"0_{side}_Limb_0", "Pelvis", (sx * 0.1, 0.02, 0.3), (sx * 0.12, 0.0, 0.15)),
            (f"0_{side}_Limb_1", f"0_{side}_Limb_0", (sx * 0.12, 0.0, 0.15), (sx * 0.12, 0.0, 0.05)),
            (f"0_{side}_Limb_2", f"0_{side}_Limb_1", (sx * 0.12, 0.0, 0.05), (sx * 0.12, -0.08, 0.01)),
        ]
    fx = [("Fx_Crown", "Head_0", (0, -0.12, 0.96), (0, -0.12, 1.0))]
    params = params_with(leg_top=0.28, leg_full=0.16, leg_core=0.06, leg_radius=0.1, belly_mid=0.04, head_from=0.4,
                         arm_core=0.07, arm_radius=0.13, tail_from=1.0)
    glow = [{"hue": (185, 205), "sat": (0.55, 1.0), "val": (0.8, 1.0)}]  # vivid ice only: the fur is pale blue too
    return bones, fx, params, glow, 8000


def storm_sovereign():
    """The storm wyvern: digitigrade legs, clawed arms, three-segment wings, a four-bone tail curling to its lightning
    rod, a jaw; Fx_Crown on its brow crystal (the thunderclap). Glow: the blue lightning veins and eyes."""
    bones = [
        ("Root", None, (0, 0, 0), (0, 0, 0.2)),
        ("Pelvis", "Root", (0, 0.04, 0.28), (0, 0.02, 0.44)),
        ("Spine_0", "Pelvis", (0, 0.02, 0.44), (0, 0.0, 0.56)),
        ("Spine_1", "Spine_0", (0, 0.0, 0.56), (0, -0.02, 0.64)),
        ("Neck", "Spine_1", (0, -0.02, 0.64), (0, -0.08, 0.72)),
        ("Head_0", "Neck", (0, -0.08, 0.72), (0, -0.25, 0.78)),
        ("Jaw_0", "Head_0", (0, -0.12, 0.68), (0, -0.24, 0.66)),
        ("Tail_0", "Pelvis", (0, 0.12, 0.22), (0.1, 0.18, 0.08)),
        ("Tail_1", "Tail_0", (0.1, 0.18, 0.08), (0.3, 0.2, 0.04)),
        ("Tail_2", "Tail_1", (0.3, 0.2, 0.04), (0.45, 0.2, 0.12)),
        ("Tail_3", "Tail_2", (0.45, 0.2, 0.12), (0.48, 0.2, 0.4)),
    ]
    for side, sx in SIDES:
        bones += [
            (f"Wing_{side}_0", "Spine_1", (sx * 0.14, 0.08, 0.66), (sx * 0.28, 0.1, 0.92)),
            (f"Wing_{side}_1", f"Wing_{side}_0", (sx * 0.28, 0.1, 0.92), (sx * 0.5, 0.1, 0.9)),
            (f"Wing_{side}_2", f"Wing_{side}_1", (sx * 0.5, 0.1, 0.9), (sx * 0.72, 0.1, 0.98)),
            (f"Arm_{side}_0", "Spine_1", (sx * 0.15, -0.02, 0.6), (sx * 0.25, -0.04, 0.45)),
            (f"Arm_{side}_1", f"Arm_{side}_0", (sx * 0.25, -0.04, 0.45), (sx * 0.27, -0.08, 0.32)),
            (f"0_{side}_Limb_0", "Pelvis", (sx * 0.12, 0.04, 0.3), (sx * 0.2, 0.0, 0.18)),
            (f"0_{side}_Limb_1", f"0_{side}_Limb_0", (sx * 0.2, 0.0, 0.18), (sx * 0.18, 0.04, 0.06)),
            (f"0_{side}_Limb_2", f"0_{side}_Limb_1", (sx * 0.18, 0.04, 0.06), (sx * 0.2, -0.06, 0.01)),
        ]
    fx = [("Fx_Crown", "Head_0", (0, -0.1, 0.94), (0, -0.1, 0.98))]
    params = params_with(leg_top=0.28, leg_full=0.18, leg_core=0.05, leg_radius=0.09, belly_mid=0.04, head_from=0.4,
                         arm_core=0.04, arm_radius=0.08, tail_from=0.1)
    glow = [{"hue": (192, 218), "sat": (0.45, 1.0), "val": (0.75, 1.0)}]
    return bones, fx, params, glow, 9000


def rift_devourer():
    """The void beetle titan: three leg pairs (its feet read off the mesh), a head with a round toothed mouth (Jaw_0)
    and two mandibles; Fx_Portal at the swirling portal on its back (it calls its Rift Horrors from there). Glow: the
    violet cracks, eyes, crystals and the portal."""
    bones = [
        ("Root", None, (0, 0, 0), (0, 0, 0.1)),
        ("Pelvis", "Root", (0, 0.35, 0.5), (0, 0.0, 0.52)),
        ("Spine_0", "Pelvis", (0, 0.0, 0.52), (0, -0.3, 0.5)),
        ("Neck", "Spine_0", (0, -0.3, 0.5), (0, -0.38, 0.46)),
        ("Head_0", "Neck", (0, -0.38, 0.46), (0, -0.55, 0.42)),
        ("Jaw_0", "Head_0", (0, -0.44, 0.36), (0, -0.54, 0.3)),
    ]
    tips = [(0.36, -0.41), (0.45, 0.07), (0.39, 0.46)]
    roots = [(0.25, -0.3), (0.3, 0.05), (0.27, 0.35)]
    for side, sx in SIDES:
        for pair, ((tx, ty), (rx, ry)) in enumerate(zip(tips, roots)):
            knee = (sx * ((rx + tx) / 2 + 0.04), (ry + ty) / 2, 0.28)
            bones += [
                (f"{pair}_{side}_Limb_0", "Spine_0" if pair == 0 else "Pelvis", (sx * rx, ry, 0.3), knee),
                (f"{pair}_{side}_Limb_1", f"{pair}_{side}_Limb_0", knee, (sx * tx, ty, 0.0)),
            ]
        bones += [(f"Pincer_{side}_0", "Head_0", (sx * 0.18, -0.45, 0.35), (sx * 0.15, -0.66, 0.24))]
    fx = [("Fx_Portal", "Pelvis", (-0.25, 0.0, 0.8), (-0.27, 0.0, 0.84))]
    params = params_with(leg_top=0.3, leg_full=0.2, leg_core=0.06, leg_radius=0.1, belly_mid=0.05, head_from=-0.36, tail_from=1.0)
    glow = [{"hue": (230, 310), "sat": (0.4, 1.0), "val": (0.7, 1.0)}]  # the bright violet only: the shell is dark violet
    return bones, fx, params, glow, 9000


BOSSES = {"FrostTyrant": frost_tyrant, "StormSovereign": storm_sovereign, "RiftDevourer": rift_devourer}

name = os.environ["NAME"]
bones, fx, params, glow, tris = BOSSES[name]()
source = bpy.data.objects.get(f"{name}_Src")
if source:
    source.name = f"{name}_Body"
    source.data.name = f"{name}_Body"
mesh = bpy.data.objects[f"{name}_Body"]
mesh.parent = None
for mod in [m for m in mesh.modifiers if m.type == "ARMATURE"]:
    mesh.modifiers.remove(mod)
rig_kit.optimize(mesh, name, tris)
rig = rig_kit.build_rig(f"{name}Rig", bones + fx)
rig_kit.skin(mesh, rig, bones, params)
if os.environ.get("EXPORT", "1") == "1":
    rig_kit.export(name, rig, mesh)
rig_kit.glow_mask(mesh, name, glow, grow=1)
bpy.ops.outliner.orphans_purge(do_recursive=True)
bpy.ops.wm.save_mainfile()
print("rigged", name)
