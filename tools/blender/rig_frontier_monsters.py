"""Rigs the Frontier's six wild monsters (spec docs/superpowers/specs/2026-11-10-frontier-valley-design.md; pipeline
docs/creatures.md "Frontier monsters"), each made by Meshy from the owner's kept concept (image to 3D from the cut-out
assets/blender/<Name>/<Name>_concept.png; jobs in the plan's ledger) and prepared by prep_frontier_model.py (1 m tall,
facing -Y, "<Name>_Src" in assets/blender/<Name>/<Name>.blend). Bone positions were read off orthographic grid renders
and the feet off the mesh's ground vertices (k-means). Run in a background Blender on the species' file:

  NAME=ShadeLynx blender -b assets/blender/ShadeLynx/ShadeLynx.blend --python tools/blender/rig_frontier_monsters.py

It renames the source "<Name>_Body", reduces it (rig_kit.optimize), builds PetRig-named bones, skins, exports
<Name>.fbx and writes <Name>_glow.png (the glowing markings), then saves the .blend. EXPORT=0 skips the FBX.
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


def frost_wisp():
    """A legless ice slime: the body bobs on Pelvis and Spine_0, the crowned top on Head_0, the fanged mouth on Jaw_0."""
    bones = [
        ("Root", None, (0, 0, 0), (0, 0, 0.1)),
        ("Pelvis", "Root", (0, 0.05, 0.15), (0, 0.0, 0.42)),
        ("Spine_0", "Pelvis", (0, 0.0, 0.42), (0, -0.05, 0.62)),
        ("Head_0", "Spine_0", (0, -0.05, 0.62), (0, -0.1, 0.95)),
        ("Jaw_0", "Head_0", (0, -0.3, 0.38), (0, -0.55, 0.3)),
    ]
    params = params_with(leg_top=0.05, leg_full=0.02, leg_core=0.02, leg_radius=0.03, belly_mid=0.05, tail_from=1.0, head_from=-0.25)
    glow = [{"hue": (185, 215), "sat": (0.35, 1.0), "val": (0.7, 1.0)}]  # the icy eyes

    def region(centre):
        return centre.y < -0.4 and 0.45 < centre.z < 0.7

    return bones, params, glow, region, 5000


def shade_lynx():
    """A bulky shadow lynx: four three-segment legs, a jaw, a four-bone tail; violet stripes and eyes glow."""
    bones = [
        ("Root", None, (0, 0, 0), (0, 0, 0.2)),
        ("Pelvis", "Root", (0, 0.28, 0.52), (0, 0.08, 0.54)),
        ("Spine_0", "Pelvis", (0, 0.08, 0.54), (0, -0.12, 0.56)),
        ("Spine_1", "Spine_0", (0, -0.12, 0.56), (0, -0.32, 0.58)),
        ("Neck", "Spine_1", (0, -0.32, 0.58), (0, -0.44, 0.62)),
        ("Head_0", "Neck", (0, -0.44, 0.62), (0, -0.66, 0.6)),
        ("Jaw_0", "Head_0", (0, -0.5, 0.53), (0, -0.64, 0.5)),
        ("Tail_0", "Pelvis", (0, 0.36, 0.5), (0, 0.44, 0.48)),
        ("Tail_1", "Tail_0", (0, 0.44, 0.48), (0, 0.52, 0.5)),
        ("Tail_2", "Tail_1", (0, 0.52, 0.5), (0, 0.58, 0.58)),
        ("Tail_3", "Tail_2", (0, 0.58, 0.58), (0, 0.6, 0.66)),
    ]
    for side, sx in SIDES:
        bones += [
            (f"0_{side}_Limb_0", "Spine_1", (sx * 0.18, -0.34, 0.45), (sx * 0.21, -0.35, 0.25)),
            (f"0_{side}_Limb_1", f"0_{side}_Limb_0", (sx * 0.21, -0.35, 0.25), (sx * 0.21, -0.35, 0.08)),
            (f"0_{side}_Limb_2", f"0_{side}_Limb_1", (sx * 0.21, -0.35, 0.08), (sx * 0.21, -0.41, 0.01)),
            (f"1_{side}_Limb_0", "Pelvis", (sx * 0.17, 0.2, 0.47), (sx * 0.2, 0.16, 0.27)),
            (f"1_{side}_Limb_1", f"1_{side}_Limb_0", (sx * 0.2, 0.16, 0.27), (sx * 0.2, 0.26, 0.1)),
            (f"1_{side}_Limb_2", f"1_{side}_Limb_1", (sx * 0.2, 0.26, 0.1), (sx * 0.2, 0.2, 0.01)),
        ]
    params = params_with(leg_top=0.42, leg_full=0.26, leg_core=0.07, leg_radius=0.14, belly_mid=0.05, tail_from=0.36, head_from=-0.3)
    glow = [{"hue": (255, 305), "sat": (0.25, 1.0), "val": (0.6, 1.0)}]  # the violet stripes, eyes and tail tip
    return bones, params, glow, None, 6000


def storm_hawk():
    """An upright storm hawk, wings spread: three-segment wings, short legs with talons, a two-bone tail fan; the yellow
    lightning marks glow (not the beak or talons)."""
    bones = [
        ("Root", None, (0, 0, 0), (0, 0, 0.2)),
        ("Pelvis", "Root", (0, 0.02, 0.28), (0, 0.0, 0.45)),
        ("Spine_0", "Pelvis", (0, 0.0, 0.45), (0, -0.02, 0.6)),
        ("Neck", "Spine_0", (0, -0.02, 0.6), (0, -0.04, 0.68)),
        ("Head_0", "Neck", (0, -0.04, 0.68), (0, -0.12, 0.92)),
        ("Tail_0", "Pelvis", (0, 0.04, 0.25), (0, 0.06, 0.12)),
        ("Tail_1", "Tail_0", (0, 0.06, 0.12), (0, 0.07, 0.01)),
    ]
    for side, sx in SIDES:
        bones += [
            (f"Wing_{side}_0", "Spine_0", (sx * 0.15, 0.02, 0.6), (sx * 0.33, 0.04, 0.78)),
            (f"Wing_{side}_1", f"Wing_{side}_0", (sx * 0.33, 0.04, 0.78), (sx * 0.47, 0.05, 0.62)),
            (f"Wing_{side}_2", f"Wing_{side}_1", (sx * 0.47, 0.05, 0.62), (sx * 0.5, 0.05, 0.2)),
            (f"0_{side}_Limb_0", "Pelvis", (sx * 0.1, 0.0, 0.32), (sx * 0.16, -0.03, 0.22)),
            (f"0_{side}_Limb_1", f"0_{side}_Limb_0", (sx * 0.16, -0.03, 0.22), (sx * 0.19, -0.06, 0.13)),
        ]
    params = params_with(leg_top=0.3, leg_full=0.2, leg_core=0.04, leg_radius=0.08, belly_mid=0.03, tail_from=1.0, head_from=0.3)
    glow = [{"hue": (42, 62), "sat": (0.5, 1.0), "val": (0.72, 1.0)}]  # the yellow lightning marks

    def region(centre):
        # not the beak (in front of the face) or the talons (low, in front)
        beak = centre.z > 0.62 and abs(centre.x) < 0.1 and centre.y < -0.1
        talons = centre.z < 0.27 and abs(centre.x) < 0.25 and centre.y < 0.0
        return not beak and not talons

    return bones, params, glow, region, 6000


def lava_brute():
    """A hulking two-legged lava brute: long arms, short legs, a jaw; its magma cracks and eyes glow."""
    bones = [
        ("Root", None, (0, 0, 0), (0, 0, 0.2)),
        ("Pelvis", "Root", (0, 0.05, 0.3), (0, 0.04, 0.48)),
        ("Spine_0", "Pelvis", (0, 0.04, 0.48), (0, 0.02, 0.62)),
        ("Spine_1", "Spine_0", (0, 0.02, 0.62), (0, -0.05, 0.74)),
        ("Neck", "Spine_1", (0, -0.05, 0.74), (0, -0.15, 0.74)),
        ("Head_0", "Neck", (0, -0.15, 0.74), (0, -0.3, 0.76)),
        ("Jaw_0", "Head_0", (0, -0.2, 0.66), (0, -0.3, 0.62)),
    ]
    for side, sx in SIDES:
        bones += [
            (f"Arm_{side}_0", "Spine_1", (sx * 0.3, 0.0, 0.72), (sx * 0.45, 0.0, 0.5)),
            (f"Arm_{side}_1", f"Arm_{side}_0", (sx * 0.45, 0.0, 0.5), (sx * 0.45, -0.02, 0.32)),
            (f"Arm_{side}_2", f"Arm_{side}_1", (sx * 0.45, -0.02, 0.32), (sx * 0.43, -0.05, 0.18)),
            (f"0_{side}_Limb_0", "Pelvis", (sx * 0.14, 0.05, 0.3), (sx * 0.2, 0.03, 0.15)),
            (f"0_{side}_Limb_1", f"0_{side}_Limb_0", (sx * 0.2, 0.03, 0.15), (sx * 0.21, 0.02, 0.05)),
            (f"0_{side}_Limb_2", f"0_{side}_Limb_1", (sx * 0.21, 0.02, 0.05), (sx * 0.21, -0.06, 0.01)),
        ]
    params = params_with(leg_top=0.28, leg_full=0.16, leg_core=0.07, leg_radius=0.12, belly_mid=0.04, head_from=0.4,
                         arm_core=0.08, arm_radius=0.14, tail_from=1.0)
    glow = [{"hue": (8, 45), "sat": (0.5, 1.0), "val": (0.62, 1.0)}]  # the magma cracks and eyes
    return bones, params, glow, None, 8000


def rift_horror():
    """A six-legged void beetle: three two-segment leg pairs (the beetle's tripod walk), a head with two mandibles; the
    violet cracks, eyes and crystals glow."""
    bones = [
        ("Root", None, (0, 0, 0), (0, 0, 0.1)),
        ("Pelvis", "Root", (0, 0.3, 0.45), (0, 0.0, 0.47)),
        ("Spine_0", "Pelvis", (0, 0.0, 0.47), (0, -0.25, 0.47)),
        ("Neck", "Spine_0", (0, -0.25, 0.47), (0, -0.33, 0.45)),
        ("Head_0", "Neck", (0, -0.33, 0.45), (0, -0.48, 0.42)),
    ]
    tips = [(0.405, -0.303), (0.482, 0.066), (0.37, 0.434)]
    roots = [(0.22, -0.22), (0.24, 0.05), (0.22, 0.3)]
    for side, sx in SIDES:
        for pair, ((tx, ty), (rx, ry)) in enumerate(zip(tips, roots)):
            knee = (sx * ((rx + tx) / 2 + 0.03), (ry + ty) / 2, 0.24)
            bones += [
                (f"{pair}_{side}_Limb_0", "Spine_0" if pair == 0 else "Pelvis", (sx * rx, ry, 0.26), knee),
                (f"{pair}_{side}_Limb_1", f"{pair}_{side}_Limb_0", knee, (sx * tx, ty, 0.0)),
            ]
        bones += [(f"Pincer_{side}_0", "Head_0", (sx * 0.1, -0.42, 0.3), (sx * 0.12, -0.55, 0.21))]
    params = params_with(leg_top=0.24, leg_full=0.16, leg_core=0.05, leg_radius=0.09, belly_mid=0.05, head_from=-0.32, tail_from=1.0)
    glow = [{"hue": (255, 305), "sat": (0.25, 1.0), "val": (0.55, 1.0)}]  # the violet cracks, eyes and crystals
    return bones, params, glow, None, 6000


def prism_crab():
    """A crystal crab: three two-segment leg pairs (its own feet, read off the mesh: Meshy left them a little uneven),
    two claws on two bones each; the prism crystals glow faintly."""
    bones = [
        ("Root", None, (0, 0, 0), (0, 0, 0.1)),
        ("Pelvis", "Root", (0, 0.2, 0.45), (0, 0.0, 0.47)),
        ("Spine_0", "Pelvis", (0, 0.0, 0.47), (0, -0.18, 0.47)),
        ("Neck", "Spine_0", (0, -0.18, 0.47), (0, -0.24, 0.5)),
        ("Head_0", "Neck", (0, -0.24, 0.5), (0, -0.32, 0.58)),
    ]
    tips = {"Left": [(0.383, -0.228), (0.41, 0.129), (0.296, 0.334)], "Right": [(-0.311, -0.348), (-0.415, -0.079), (-0.41, 0.259)]}
    roots = [(0.2, -0.16), (0.22, 0.02), (0.2, 0.2)]
    for side, sx in SIDES:
        for pair, ((tx, ty), (rx, ry)) in enumerate(zip(tips[side], roots)):
            knee = (sx * ((rx + abs(tx)) / 2 + 0.04), (ry + ty) / 2, 0.24)
            bones += [
                (f"{pair}_{side}_Limb_0", "Spine_0" if pair == 0 else "Pelvis", (sx * rx, ry, 0.28), knee),
                (f"{pair}_{side}_Limb_1", f"{pair}_{side}_Limb_0", knee, (tx, ty, 0.0)),
            ]
        bones += [
            (f"Claw_{side}_0", "Spine_0", (sx * 0.24, -0.18, 0.45), (sx * 0.38, -0.28, 0.46)),
            (f"Claw_{side}_1", f"Claw_{side}_0", (sx * 0.38, -0.28, 0.46), (sx * 0.42, -0.36, 0.44)),
        ]
    params = params_with(leg_top=0.26, leg_full=0.16, leg_core=0.04, leg_radius=0.08, belly_mid=0.05, head_from=-0.22, tail_from=1.0)
    glow = [{"hue": (140, 190), "sat": (0.2, 0.7), "val": (0.85, 1.0)}]  # the crystals' bright facets
    return bones, params, glow, None, 7000


# Collapse decimation shreds the crab's dense crystal shell into shards (as it did the Puddle Crab's): rebuilt as one
# clean surface instead (rig_kit.remesh_bake: voxel remesh, colours baked across)
REMESH = {"PrismCrab": 0.007}


SPECIES = {
    "FrostWisp": frost_wisp,
    "ShadeLynx": shade_lynx,
    "StormHawk": storm_hawk,
    "LavaBrute": lava_brute,
    "RiftHorror": rift_horror,
    "PrismCrab": prism_crab,
}

name = os.environ["NAME"]
bones, params, glow, region, tris = SPECIES[name]()
source = bpy.data.objects.get(f"{name}_Src")
if name in REMESH:
    if source:
        low = rig_kit.remesh_bake(source, name, voxel=REMESH[name], target_tris=tris)
        bpy.data.objects.remove(source, do_unlink=True)
        low.name = f"{name}_Body"
        low.data.name = f"{name}_Body"
    mesh = bpy.data.objects[f"{name}_Body"]
    rig = rig_kit.build_rig(name + "Rig", bones)
    rig_kit.skin(mesh, rig, bones, params)
    if os.environ.get("EXPORT", "1") == "1":
        rig_kit.export(name, rig, mesh)
else:
    if source:
        source.name = f"{name}_Body"
        source.data.name = f"{name}_Body"
    rig, mesh = rig_kit.run(name, f"{name}_Body", bones, params, target_tris=tris)
rig_kit.glow_mask(mesh, name, glow, grow=1, region=region)
bpy.ops.outliner.orphans_purge(do_recursive=True)
bpy.ops.wm.save_mainfile()
print("rigged", name)
