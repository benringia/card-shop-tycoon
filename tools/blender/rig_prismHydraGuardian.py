"""Rigs the Meshy Prism Hydra (spec docs/superpowers/specs/2026-11-11-dungeon-puzzles-design.md, the owner's pick B
"temple guardian": carved stone armour, glowing rune lines, crystals), made by Meshy from
assets/blender/PrismHydraGuardian/PrismHydraGuardian_concept.png and prepared by prep_frontier_model.py (1 m tall,
facing -Y, "PrismHydraGuardian_Src" in PrismHydraGuardian.blend, reduced to 12000 triangles by rig_kit.optimize).

The bones keep the names the blocky Hydra (build_prismHydra.py) gave and src/shared/Util/PetRig.luau and
MonsterController read: four legs (front 0_<side>_Limb_0..2, hind 1_<side>_Limb_0..2), Pelvis, Spine_0/1, Tail_0..4,
five necks Hydra_<head>_0..2 with the head Hydra_<head>_3 (the phase's head glows there) and a jaw Jaw_<head>. Head 0
is the middle one, then outwards alternating sides (1 inner left, 2 inner right, 3 outer left, 4 outer right; left is
+X). Positions were read off the mesh: its 5 head clusters, its feet and knees per quadrant, the necks' x at each
height. Run in a background Blender:

  blender -b assets/blender/PrismHydraGuardian/PrismHydraGuardian.blend --python tools/blender/rig_prismHydraGuardian.py

Writes PrismHydraGuardian.fbx and PrismHydraGuardian_glow.png next to the .blend and saves it. EXPORT=0 skips the FBX;
POSE_TEST=<folder> also renders the necks bent and the legs stepping (a skinning check) there.
"""
import importlib
import math
import os
import sys

import bpy
from mathutils import Euler, Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import rig_kit  # noqa: E402

importlib.reload(rig_kit)

NAME = "PrismHydraGuardian"
SIDES = (("Left", 1), ("Right", -1))
# Each head: (its top's x, its height); the neck's base x on the chest (read off the mesh)
HEADS = [(0.003, 0.879, 0.0), (0.191, 0.851, 0.16), (-0.193, 0.848, -0.16), (0.387, 0.8, 0.31), (-0.394, 0.799, -0.31)]
NECK_BONES = 3


def neck(head):
    """One neck's bones, base on the chest to the back of its head, then the head and its jaw."""
    x, z, base_x = HEADS[head]
    base = Vector((base_x, -0.3, 0.52))
    top = Vector((x, -0.35, z - 0.03))
    control = Vector(((base_x + x) / 2, -0.3, (base.z + top.z) / 2 + 0.03))
    points = [base * (1 - t) ** 2 + control * 2 * t * (1 - t) + top * t * t for t in (i / NECK_BONES for i in range(NECK_BONES + 1))]
    bones = []
    for i in range(NECK_BONES):
        parent = "Spine_1" if i == 0 else f"Hydra_{head}_{i - 1}"
        bones.append((f"Hydra_{head}_{i}", parent, tuple(points[i]), tuple(points[i + 1])))
    snout = Vector((x, -0.6, z - 0.04))
    bones.append((f"Hydra_{head}_3", f"Hydra_{head}_{NECK_BONES - 1}", tuple(top), tuple(snout)))
    bones.append((f"Jaw_{head}", f"Hydra_{head}_3", (x, -0.42, z - 0.06), (x, -0.57, z - 0.08)))
    return bones


def rig_bones():
    bones = [
        ("Root", None, (0, 0, 0), (0, 0, 0.1)),
        ("Pelvis", "Root", (0, 0.05, 0.3), (0, -0.15, 0.38)),
        ("Spine_0", "Pelvis", (0, -0.15, 0.38), (0, -0.32, 0.44)),
        ("Spine_1", "Spine_0", (0, -0.32, 0.44), (0, -0.42, 0.52)),
    ]
    tail = [(0, 0.12, 0.31), (0, 0.24, 0.31), (0, 0.36, 0.3), (0, 0.47, 0.3), (0, 0.56, 0.32), (0, 0.65, 0.33)]
    for i in range(5):
        bones.append((f"Tail_{i}", "Pelvis" if i == 0 else f"Tail_{i - 1}", tail[i], tail[i + 1]))
    for side, sx in SIDES:
        bones += [
            (f"0_{side}_Limb_0", "Spine_1", (sx * 0.24, -0.44, 0.42), (sx * 0.25, -0.45, 0.2)),
            (f"0_{side}_Limb_1", f"0_{side}_Limb_0", (sx * 0.25, -0.45, 0.2), (sx * 0.27, -0.52, 0.06)),
            (f"0_{side}_Limb_2", f"0_{side}_Limb_1", (sx * 0.27, -0.52, 0.06), (sx * 0.27, -0.62, 0.02)),
            (f"1_{side}_Limb_0", "Pelvis", (sx * 0.14, 0.02, 0.3), (sx * 0.16, 0.05, 0.15)),
            (f"1_{side}_Limb_1", f"1_{side}_Limb_0", (sx * 0.16, 0.05, 0.15), (sx * 0.17, -0.02, 0.05)),
            (f"1_{side}_Limb_2", f"1_{side}_Limb_1", (sx * 0.17, -0.02, 0.05), (sx * 0.17, -0.09, 0.02)),
        ]
    for head in range(len(HEADS)):
        bones += neck(head)
    return bones


def params():
    p = rig_kit.Params()
    p.leg_top = 0.36  # the front legs reach up to the shoulder plates
    p.leg_full = 0.18
    p.leg_core = 0.06
    p.leg_radius = 0.11
    p.head_from = -0.15  # the necks and heads only take what's in front of the body's middle
    p.tail_from = 0.1
    return p


def pose_test(rig, folder):
    """Bends every neck and steps the legs, then renders front and side: a skinning check (not exported)."""
    os.makedirs(folder, exist_ok=True)
    bpy.context.view_layer.objects.active = rig
    bpy.ops.object.mode_set(mode="POSE")
    for head in range(len(HEADS)):
        for i in range(NECK_BONES):
            bone = rig.pose.bones[f"Hydra_{head}_{i}"]
            bone.rotation_mode = "XYZ"
            bone.rotation_euler = Euler((math.radians(18 if head % 2 else -14), 0, math.radians(10 * (head - 2))))
        jaw = rig.pose.bones[f"Jaw_{head}"]
        jaw.rotation_mode = "XYZ"
        jaw.rotation_euler = Euler((math.radians(30), 0, 0))
    for side, _ in SIDES:
        for pair, angle in ((0, 25), (1, -20)):
            limb = rig.pose.bones[f"{pair}_{side}_Limb_0"]
            limb.rotation_mode = "XYZ"
            limb.rotation_euler = Euler((math.radians(angle if side == "Left" else -angle), 0, 0))
    tail = rig.pose.bones["Tail_2"]
    tail.rotation_mode = "XYZ"
    tail.rotation_euler = Euler((0, 0, math.radians(30)))
    bpy.ops.object.mode_set(mode="OBJECT")
    scene = bpy.context.scene
    engines = [i.identifier for i in bpy.types.RenderSettings.bl_rna.properties["engine"].enum_items]
    scene.render.engine = "BLENDER_WORKBENCH" if "BLENDER_WORKBENCH" in engines else scene.render.engine
    scene.display.shading.color_type = "TEXTURE"
    scene.render.resolution_x, scene.render.resolution_y = 640, 640
    camera = bpy.data.objects.new("PoseCam", bpy.data.cameras.new("PoseCam"))
    scene.collection.objects.link(camera)
    scene.camera = camera
    for label, eye in (("front", (0.0, -2.4, 0.6)), ("side", (2.4, 0.0, 0.6)), ("three_quarter", (1.6, -1.8, 1.0))):
        camera.location = eye
        camera.rotation_euler = (Vector((0, 0, 0.45)) - Vector(eye)).to_track_quat("-Z", "Y").to_euler()
        scene.render.filepath = os.path.join(folder, f"hydra_pose_{label}.png")
        bpy.ops.render.render(write_still=True)
    bpy.data.objects.remove(camera)
    bpy.context.view_layer.objects.active = rig
    bpy.ops.object.mode_set(mode="POSE")
    bpy.ops.pose.select_all(action="SELECT")
    bpy.ops.pose.transforms_clear()
    bpy.ops.object.mode_set(mode="OBJECT")


source = bpy.data.objects.get(f"{NAME}_Src")
if source:
    source.name = f"{NAME}_Body"
    source.data.name = f"{NAME}_Body"
mesh = bpy.data.objects[f"{NAME}_Body"]
mesh.parent = None
for mod in [m for m in mesh.modifiers if m.type == "ARMATURE"]:
    mesh.modifiers.remove(mod)
for old in [o for o in bpy.data.objects if o.type == "ARMATURE"]:
    bpy.data.objects.remove(old)
rig_kit.optimize(mesh, NAME, 12000)
bones = rig_bones()
rig = rig_kit.build_rig(f"{NAME}Rig", bones)
rig_kit.skin(mesh, rig, bones, params())
if os.environ.get("POSE_TEST"):
    pose_test(rig, os.environ["POSE_TEST"])
if os.environ.get("EXPORT", "1") == "1":
    rig_kit.export(NAME, rig, mesh)
# the rune lines and crystals glow (bright, saturated: every hue), not the blue-grey stone
rig_kit.glow_mask(mesh, NAME, [{"hue": (0, 360), "sat": (0.45, 1.0), "val": (0.7, 1.0)}], grow=1)
bpy.ops.outliner.orphans_purge(do_recursive=True)
bpy.ops.wm.save_mainfile()
print("rigged", NAME, len(bones), "bones")
