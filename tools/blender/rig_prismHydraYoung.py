"""Rigs the prologue's young Hydra (spec docs/superpowers/specs/2026-11-14-prologue-hydra-design.md; owner's pick A on
2026-11-15, after the cut two-headed model showed a hole): one horned head, two crystal buds on its chest where the
other heads will grow, the Dungeon's Prism Hydra's look (carved blue-grey stone, rainbow rune lines, prism crystals).
Meshy image to 3D from assets/blender/PrismHydraYoung/PrismHydraYoung_concept.png, prepared by prep_frontier_model.py
(NAME=PrismHydraYoung YAW=0 HEIGHT=1: 1 m tall, facing -Y, "PrismHydraYoung_Src" in PrismHydraYoung.blend).

Meshy guessed the parts the concept hides (hind legs, belly, the tail's root) in pale mint and cream; they are
repainted the stone's blue-grey (`recolor_hidden`), keeping their light and shade. The bones keep the Prism Hydra's
names so its clips (assets/monster-animations/prismHydra) play on it: four legs (front 0_<side>_Limb_0..2, hind
1_<side>_Limb_0..2), Pelvis, Spine_0/1, Tail_0..4, its one neck Hydra_0_0..2 with the head Hydra_0_3 and the jaw Jaw_0
(head 0: the middle one). Positions were read off the mesh (feet per quadrant, the head's top and snout, the tail
curling back to its left). Run in a background Blender:

  blender -b assets/blender/PrismHydraYoung/PrismHydraYoung.blend --python tools/blender/rig_prismHydraYoung.py

Writes PrismHydraYoung.fbx, PrismHydraYoung_color.png and PrismHydraYoung_glow.png next to the .blend and saves it.
EXPORT=0 skips the FBX; PREVIEW=<folder> renders it textured from five sides there.
"""
import importlib
import os
import sys

import bpy
import numpy as np
from mathutils import Matrix, Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import rig_kit  # noqa: E402

importlib.reload(rig_kit)

NAME = "PrismHydraYoung"
SIDES = (("Left", 1), ("Right", -1))
# The tail curls out to the left (+X), so the prepared mesh is centred off its body: this moves the body's middle
# (halfway between the front feet) onto x = 0
BODY_SHIFT_X = 0.062


def rig_bones():
    bones = [
        ("Root", None, (0, 0, 0), (0, 0, 0.1)),
        ("Pelvis", "Root", (0, 0.08, 0.3), (0, -0.05, 0.37)),
        ("Spine_0", "Pelvis", (0, -0.05, 0.37), (0, -0.15, 0.46)),
        ("Spine_1", "Spine_0", (0, -0.15, 0.46), (0, -0.18, 0.58)),
    ]
    tail = [(0, 0.12, 0.3), (0.06, 0.2, 0.27), (0.16, 0.28, 0.24), (0.27, 0.34, 0.24), (0.36, 0.39, 0.27), (0.4, 0.44, 0.31)]
    for i in range(5):
        bones.append((f"Tail_{i}", "Pelvis" if i == 0 else f"Tail_{i - 1}", tail[i], tail[i + 1]))
    for side, sx in SIDES:
        bones += [
            (f"0_{side}_Limb_0", "Spine_1", (sx * 0.24, -0.22, 0.55), (sx * 0.28, -0.28, 0.3)),
            (f"0_{side}_Limb_1", f"0_{side}_Limb_0", (sx * 0.28, -0.28, 0.3), (sx * 0.3, -0.33, 0.08)),
            (f"0_{side}_Limb_2", f"0_{side}_Limb_1", (sx * 0.3, -0.33, 0.08), (sx * 0.3, -0.42, 0.02)),
            (f"1_{side}_Limb_0", "Pelvis", (sx * 0.15, 0.07, 0.3), (sx * 0.17, -0.01, 0.17)),
            (f"1_{side}_Limb_1", f"1_{side}_Limb_0", (sx * 0.17, -0.01, 0.17), (sx * 0.17, 0.05, 0.07)),
            (f"1_{side}_Limb_2", f"1_{side}_Limb_1", (sx * 0.17, 0.05, 0.07), (sx * 0.17, -0.03, 0.02)),
        ]
    # its one neck: short and thick, from the top of the chest to the back of the head, then the head and its jaw
    neck = [(0, -0.18, 0.58), (0, -0.18, 0.64), (0, -0.18, 0.7), (0, -0.17, 0.76)]
    for i in range(3):
        bones.append((f"Hydra_0_{i}", "Spine_1" if i == 0 else f"Hydra_0_{i - 1}", neck[i], neck[i + 1]))
    bones.append(("Hydra_0_3", "Hydra_0_2", neck[3], (0, -0.34, 0.75)))
    bones.append(("Jaw_0", "Hydra_0_3", (0, -0.22, 0.7), (0, -0.33, 0.68)))
    return bones


def params():
    p = rig_kit.Params()
    p.leg_top = 0.42  # the front legs reach up into the shoulders
    p.leg_full = 0.22
    p.leg_core = 0.06
    p.leg_radius = 0.12
    p.head_from = -0.1  # the neck and head only take what's in front of the body's middle
    p.tail_from = 0.12
    return p


def colour_map(mesh):
    return next(n for mat in mesh.data.materials if mat and mat.use_nodes
                for n in mat.node_tree.nodes if n.type == "TEX_IMAGE" and n.image)


def hidden_region(centre):
    """The parts the concept hid: the hind legs and belly below the shoulders behind the chest, and the tail's root"""
    return (centre.z < 0.42 and centre.y > -0.14) or (centre.z < 0.3 and abs(centre.x) < 0.16)


def recolor_hidden(mesh):
    """Repaints the pale mint and cream texels on the hidden parts the stone's blue-grey (the median of the front's
    stone), each keeping its own brightness against the pale texels' average, and saves the map again."""
    node = colour_map(mesh)
    image = node.image
    width, height = image.size
    pixels = np.array(image.pixels[:], dtype=np.float32).reshape(height, width, 4)
    rgb = pixels[..., :3]
    top, low = rgb.max(axis=2), rgb.min(axis=2)
    sat = np.where(top > 0, (top - low) / np.maximum(top, 1e-6), 0)
    region = np.zeros((height, width), dtype=bool)
    stone_area = np.zeros((height, width), dtype=bool)
    uv = mesh.data.uv_layers.active.data
    for poly in mesh.data.polygons:
        centre = mesh.matrix_world @ poly.center
        corners = [uv[i].uv for i in poly.loop_indices]
        if hidden_region(centre):
            target = region
        elif centre.y < -0.2 and 0.3 < centre.z < 0.6:
            target = stone_area  # the chest's front: plain stone in the concept
        else:
            continue
        for k in range(1, len(corners) - 1):
            rig_kit._fill_triangle(target, corners[0], corners[k], corners[k + 1])
    stone_px = stone_area & (sat < 0.45) & (top < 0.6)
    stone = np.median(rgb[stone_px], axis=0) if stone_px.any() else np.array([0.27, 0.31, 0.42])
    # pale: light and washed out (the rainbow runes and crystals are strongly coloured and stay)
    pale = region & (top > 0.5) & (sat < 0.5)
    if pale.any():
        light = rgb[pale].mean(axis=1)
        ratio = light / max(float(light.mean()), 1e-6)
        rgb[pale] = np.clip(stone[None, :] * (0.75 + 0.35 * ratio)[:, None], 0, 1)
    pixels[..., :3] = rgb
    path = os.path.join(rig_kit.REPO, "assets", "blender", NAME, f"{NAME}_color.png")
    fresh = bpy.data.images.new(f"{NAME}_color_fixed", width, height, alpha=True)
    fresh.pixels[:] = pixels.ravel()
    fresh.filepath_raw = path
    fresh.file_format = "PNG"
    fresh.save()
    bpy.data.images.remove(fresh)
    loaded = bpy.data.images.load(path, check_existing=False)
    loaded.pack()
    node.image = loaded
    print("recolored", int(pale.sum()), "pale texels of", int(region.sum()), "hidden ones to stone",
          [round(float(c), 3) for c in stone])


def preview(folder, mesh):
    os.makedirs(folder, exist_ok=True)
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.display.shading.color_type = "TEXTURE"
    scene.display.shading.light = "STUDIO"
    scene.render.resolution_x, scene.render.resolution_y = 520, 520
    scene.render.image_settings.file_format = "PNG"
    cam = bpy.data.objects.new("PreviewCam", bpy.data.cameras.new("PreviewCam"))
    scene.collection.objects.link(cam)
    scene.camera = cam
    centre = Vector((0, 0, 0.45))
    for label, way in {"front": (0, -1, 0.2), "three_quarter": (0.75, -0.75, 0.35), "side": (1, 0, 0.15),
                       "back": (-0.3, 1, 0.3), "low_back": (0.6, 0.8, -0.05)}.items():
        cam.location = centre + Vector(way).normalized() * 2.4
        cam.rotation_euler = (centre - cam.location).to_track_quat("-Z", "Y").to_euler()
        scene.render.filepath = os.path.join(folder, label + ".png")
        bpy.ops.render.render(write_still=True)
    bpy.data.objects.remove(cam)


source = bpy.data.objects.get(f"{NAME}_Src")
if source:
    source.data.transform(Matrix.Translation(Vector((BODY_SHIFT_X, 0, 0))))
    source.name = f"{NAME}_Body"
    source.data.name = f"{NAME}_Body"
mesh = bpy.data.objects[f"{NAME}_Body"]
mesh.parent = None
for mod in [m for m in mesh.modifiers if m.type == "ARMATURE"]:
    mesh.modifiers.remove(mod)
for old in [o for o in bpy.data.objects if o.type == "ARMATURE"]:
    bpy.data.objects.remove(old)
rig_kit.optimize(mesh, NAME, 12000)
recolor_hidden(mesh)
bones = rig_bones()
rig = rig_kit.build_rig(f"{NAME}Rig", bones)
rig_kit.skin(mesh, rig, bones, params())
if os.environ.get("EXPORT", "1") == "1":
    rig_kit.export(NAME, rig, mesh)
# the rune lines and crystals glow (bright, saturated: every hue), not the blue-grey stone
rig_kit.glow_mask(mesh, NAME, [{"hue": (0, 360), "sat": (0.45, 1.0), "val": (0.7, 1.0)}], grow=1)
if os.environ.get("PREVIEW"):
    preview(os.environ["PREVIEW"], mesh)
for key in [k for k in bpy.context.scene.keys() if k.startswith("blendermcp_")]:
    del bpy.context.scene[key]
bpy.ops.outliner.orphans_purge(do_recursive=True)
bpy.ops.wm.save_mainfile()
print("rigged", NAME, len(bones), "bones")
