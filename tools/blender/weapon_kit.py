"""Shared kit for the weapons made with Meshy (weapons round 1; docs/weapons.md): turns a generated sword into a light
Roblox model shaped like the Steel Sword (tools/blender/build_starter_sword.py).

Each weapon has a small build_weapon_<id>.py that calls build(). Run them in a background Blender, never the owner's
open one:

  "C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" -b --factory-startup --python tools/blender/build_weapon_<id>.py

It reads assets/blender/<Name>/<Name>_raw.glb (the Meshy model as generated, exported from the Blender MCP; kept out of
git) and:
  1. reduces it to about TARGET_TRIS triangles with one 1024-pixel colour map (rig_kit.optimize)
  2. stands it blade up (+Z), flat faces along Y, at its rarity's length (studs: Blender units are studs here)
  3. finds the grip from the mesh's width along its length (the guard is the widest part of the lower half, the grip the
     narrow band under it) and puts the grip's centre on the origin: where the hand holds it in Roblox
  4. splits it into Blade, Guard and Grip (the pommel goes with the grip), all sharing that origin
  5. writes <Name>.fbx (textures embedded), <Name>_color.png, <Name>.blend and two previews

Element recolours (the Forge Sword): recolor() tints the bright, pale texels on the gems' faces into each element's
colour and writes <Name>_<Element>_color.png, for tools/weapons to swap into copies of the imported model.

Spears (weapons round 2, spec 2026-11-07-weapons-round2-design 7): build_spear() does steps 1, 2 and 5, but the head is
found from the width (the first slice above the shaft's width in the upper part; its collar counts), the origin goes on
the grip (31% of the length up from the butt: held upright at your side, the butt by your foot) and the parts are Head
and Shaft.

Scythes (weapons round 3, spec 2026-11-09-weapons-round3-scythes-design): build_scythe() is build_spear() with the
shaft centred (the blade sticks out to one side), the blade turned to -X, the head found from the blade's hanging tip
(find_scythe_head) and the grip a third up from the butt.
"""
import math
import os
import sys

import bmesh
import bpy
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import rig_kit  # noqa: E402

REPO = rig_kit.REPO
TARGET_TRIS = 4000
# The Forge weapons' gem colours by element, 0-1: deeper than Config/WeaponLooks BY_ELEMENT's glow (the pale glow
# colours read pastel on a gem; checked in renders 2026-11-06)
FORGE_GEMS = {
    "Ember": (1.0, 0.42, 0.08),
    "Tide": (0.15, 0.58, 1.0),
    "Bloom": (0.25, 0.82, 0.25),
    "Volt": (1.0, 0.8, 0.05),
    "Shade": (0.58, 0.25, 1.0),
}
BINS = 120  # slices along the length when measuring the width


def folder(name):
    return os.path.join(REPO, "assets", "blender", name)


def load_raw(name):
    """A clean scene with the raw model as one mesh object named `name`, its transforms applied."""
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=os.path.join(folder(name), name + "_raw.glb"))
    meshes = [o for o in bpy.data.objects if o.type == "MESH"]
    assert meshes, "the raw file has no mesh"
    bpy.ops.object.select_all(action="DESELECT")
    for obj in meshes:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = meshes[0]
    if len(meshes) > 1:
        bpy.ops.object.join()
    obj = bpy.context.view_layer.objects.active
    obj.parent = None
    for empty in [o for o in bpy.data.objects if o.type != "MESH"]:
        bpy.data.objects.remove(empty)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    obj.name = name
    return obj


def widths(obj):
    """(bottom z, top z, the widest |x| in each of BINS slices from the bottom)."""
    zs = [v.co.z for v in obj.data.vertices]
    low, high = min(zs), max(zs)
    step = (high - low) / BINS
    width = [0.0] * BINS
    for v in obj.data.vertices:
        index = min(BINS - 1, int((v.co.z - low) / step))
        width[index] = max(width[index], abs(v.co.x))
    return low, high, width


def find_grip(obj, guard_share=0.6, grip_share=0.55, smooth=2):
    """Where the guard and the grip are: (guard bottom z, guard top z, grip centre z). The width is smoothed first (the
    widest of `smooth` slices either side), so a guard of separate rays or leaves counts as one (the Sunforged Blade's
    sun disc). The guard is the widest smoothed slice in the lower half and spans the slices round it at least
    guard_share as wide; the grip is the longest run under it narrower than grip_share of the guard (the pommel widens
    again below it)."""
    low, high, width = widths(obj)
    step = (high - low) / BINS
    wide = [max(width[max(0, i - smooth):i + smooth + 1]) for i in range(BINS)]
    lower = range(int(BINS * 0.05), int(BINS * 0.5))
    guard = max(lower, key=lambda i: wide[i])
    widest = wide[guard]
    top = guard
    while top + 1 < BINS and wide[top + 1] >= widest * guard_share:
        top += 1
    bottom = guard
    while bottom - 1 >= 0 and wide[bottom - 1] >= widest * guard_share:
        bottom -= 1
    runs, start = [], None
    for i in range(bottom):
        narrow = width[i] < widest * grip_share
        if narrow and start is None:
            start = i
        if start is not None and (not narrow or i == bottom - 1):
            runs.append((start, i if narrow else i - 1))
            start = None
    assert runs, "no grip found under the guard"
    grip_bottom, grip_top = max(runs, key=lambda run: run[1] - run[0])
    z = lambda i: low + (i + 0.5) * step  # noqa: E731
    return low + bottom * step, low + (top + 1) * step, (z(grip_top) + z(grip_bottom)) / 2


def place(obj, length):
    """Scales it to `length` studs, centres it on X and Y and puts the grip's centre on the origin; returns the guard's
    bottom and top z after the move."""
    zs = [v.co.z for v in obj.data.vertices]
    scale = length / (max(zs) - min(zs))
    obj.scale = (scale, scale, scale)
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    guard_bottom, guard_top, grip = find_grip(obj)
    xs = [v.co.x for v in obj.data.vertices]
    ys = [v.co.y for v in obj.data.vertices]
    offset = Vector(((max(xs) + min(xs)) / 2, (max(ys) + min(ys)) / 2, grip))
    for v in obj.data.vertices:
        v.co -= offset
    obj.data.update()
    return guard_bottom - grip, guard_top - grip


def cut(obj, pieces):
    """One copy of `obj` per (name, keep): each keeps only the faces whose centre's z `keep` takes; `obj` is removed."""
    parts = []
    for part, keep in pieces:
        copy = obj.copy()
        copy.data = obj.data.copy()
        copy.name = part
        copy.data.name = part
        bpy.context.scene.collection.objects.link(copy)
        bm = bmesh.new()
        bm.from_mesh(copy.data)
        bmesh.ops.delete(bm, geom=[f for f in bm.faces if not keep(f.calc_center_median().z)], context="FACES")
        bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
        bm.to_mesh(copy.data)
        bm.free()
        parts.append(copy)
    bpy.data.objects.remove(obj)
    return parts


def split(obj, guard_bottom, guard_top):
    """Blade (above the guard), Guard and Grip (below it, the pommel too), each a copy keeping only its faces."""
    return cut(obj, (
        ("Blade", lambda z: z >= guard_top),
        ("Guard", lambda z: guard_bottom <= z < guard_top),
        ("Grip", lambda z: z < guard_bottom),
    ))


def find_head(obj, start_share=0.55, factor=1.35):
    """Where a spear's head starts (its collar counts): the lowest slice from `start_share` of the length up wider than
    `factor` x the shaft (the median width of the slices from 10% to 50% up, so rings and flowers on it don't count).
    Measured on the four round 2 spears: the Forge Spear's collar at 65%, the Halberd's blade at 58%, the Trident's
    collar at 60%, the Lance's cone guard at 58%."""
    low, high, width = widths(obj)
    step = (high - low) / BINS
    shaft = sorted(width[int(BINS * 0.1):int(BINS * 0.5)])
    median = shaft[len(shaft) // 2]
    for i in range(int(BINS * start_share), BINS):
        if width[i] > median * factor:
            return low + i * step
    raise AssertionError("no head found above the shaft")


def place_spear(obj, length, grip_share):
    """Scales a spear to `length` studs, centres it on X and Y and puts the grip (`grip_share` of the length up from the
    butt) on the origin; returns the head's bottom z after the move."""
    zs = [v.co.z for v in obj.data.vertices]
    scale = length / (max(zs) - min(zs))
    obj.scale = (scale, scale, scale)
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    head = find_head(obj)
    xs = [v.co.x for v in obj.data.vertices]
    ys = [v.co.y for v in obj.data.vertices]
    zs = [v.co.z for v in obj.data.vertices]
    offset = Vector(((max(xs) + min(xs)) / 2, (max(ys) + min(ys)) / 2, min(zs) + grip_share * length))
    for v in obj.data.vertices:
        v.co -= offset
    obj.data.update()
    return head - offset.z


def find_scythe_head(obj, start_share=0.55, factor=1.6):
    """Where a scythe's head starts: the lowest slice from `start_share` of the length up whose width (the median of it
    and its neighbours, so one stray vertex doesn't count) passes `factor` x the shaft's (the median of the slices from
    10% to 50% up). The blade's hanging tip is far out to the side, so the head starts there (its socket and the shaft
    above it count). Measured on the four round 3 scythes: the tip at 68% to 77% up, 18-20x the shaft; the shaft's
    rings at most 1.5x."""
    low, high, width = widths(obj)
    step = (high - low) / BINS
    shaft = sorted(width[int(BINS * 0.1):int(BINS * 0.5)])
    median = shaft[len(shaft) // 2]
    for i in range(int(BINS * start_share), BINS):
        smooth = sorted(width[max(0, i - 1):i + 2])[1] if 0 < i < BINS - 1 else width[i]
        if smooth > median * factor:
            return low + i * step
    raise AssertionError("no head found above the shaft")


def place_scythe(obj, length, grip_share):
    """Scales a scythe to `length` studs, centres the shaft (not the whole model: the blade sticks out to one side) on X
    and Y, turns it so the blade points to -X and puts the grip (`grip_share` of the length up from the butt) on the
    origin; returns the head's bottom z after the move."""
    zs = [v.co.z for v in obj.data.vertices]
    scale = length / (max(zs) - min(zs))
    obj.scale = (scale, scale, scale)
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    zs = [v.co.z for v in obj.data.vertices]
    low = min(zs)
    shaft = [v.co for v in obj.data.vertices if low + 0.1 * length <= v.co.z <= low + 0.5 * length]
    centre = Vector(((max(c.x for c in shaft) + min(c.x for c in shaft)) / 2,
                     (max(c.y for c in shaft) + min(c.y for c in shaft)) / 2, low + grip_share * length))
    for v in obj.data.vertices:
        v.co -= centre
    head = find_scythe_head(obj)
    tip = max((v.co for v in obj.data.vertices if v.co.z >= head), key=lambda c: abs(c.x))
    if tip.x > 0:
        # Half a turn round the shaft (not a mirror: the faces stay the right way out)
        for v in obj.data.vertices:
            v.co.x, v.co.y = -v.co.x, -v.co.y
    obj.data.update()
    return head


def image_of(obj):
    return next(n.image for mat in obj.data.materials if mat and mat.use_nodes
                for n in mat.node_tree.nodes if n.type == "TEX_IMAGE" and n.image)


def recolor(name, parts, region, colors, sat_max=0.3, val_min=0.62):
    """Writes <name>_<key>_color.png for each (key, rgb 0-1) in `colors`: the colour map with the bright pale texels on
    the faces `region` picks (a function of a face's centre) tinted that colour, keeping their shading."""
    import numpy as np

    image = image_of(parts[0])
    width, height = image.size
    base = np.array(image.pixels[:], dtype=np.float32).reshape(height, width, 4)
    allowed = np.zeros((height, width), dtype=bool)
    for obj in parts:
        uv = obj.data.uv_layers.active.data
        for poly in obj.data.polygons:
            if not region(obj.matrix_world @ poly.center):
                continue
            corners = [uv[i].uv for i in poly.loop_indices]
            for k in range(1, len(corners) - 1):
                rig_kit._fill_triangle(allowed, corners[0], corners[k], corners[k + 1])
    rgb = base[..., :3]
    top, low = rgb.max(axis=2), rgb.min(axis=2)
    sat = np.where(top > 0, (top - low) / np.maximum(top, 1e-6), 0)
    mask = allowed & (sat <= sat_max) & (top >= val_min)
    print("recolor:", int(mask.sum()), "texels")
    paths = {}
    for key, color in colors.items():
        out = base.copy()
        shade = top[mask][:, None]
        tint = np.array(color, dtype=np.float32)[None, :]
        # The gem's own light and dark kept: its shading scales the colour, only the very brightest glint goes white
        out[mask, :3] = np.clip(tint * (0.25 + 0.8 * shade) + np.clip(shade - 0.97, 0, 1) * 8, 0, 1)
        result = bpy.data.images.new(f"{name}_{key}", width, height, alpha=True)
        result.pixels[:] = out.ravel()
        path = os.path.join(folder(name), f"{name}_{key}_color.png")
        result.filepath_raw = path
        result.file_format = "PNG"
        result.save()
        bpy.data.images.remove(result)
        paths[key] = path
    return paths


def preview(name, parts):
    """Two renders (front and three-quarter) into assets/blender/<name>/<name>_preview_<view>.png."""
    scene = bpy.context.scene
    try:
        scene.render.engine = "BLENDER_EEVEE_NEXT"
    except TypeError:
        scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x, scene.render.resolution_y = 480, 720
    scene.render.film_transparent = False
    if not scene.world:
        scene.world = bpy.data.worlds.new("World")
    scene.world.color = (0.62, 0.72, 0.82)
    sun = bpy.data.lights.new("Sun", "SUN")
    sun.energy = 3
    sun_obj = bpy.data.objects.new("Sun", sun)
    sun_obj.rotation_euler = (math.radians(50), 0, math.radians(30))
    scene.collection.objects.link(sun_obj)
    cam_data = bpy.data.cameras.new("PreviewCam")
    cam = bpy.data.objects.new("PreviewCam", cam_data)
    scene.collection.objects.link(cam)
    scene.camera = cam
    zs = [(o.matrix_world @ v.co).z for o in parts for v in o.data.vertices]
    middle = Vector((0, 0, (max(zs) + min(zs)) / 2))
    reach = (max(zs) - min(zs)) * 1.25
    for view, direction in (("front", Vector((0, -1, 0.1))), ("three_quarter", Vector((0.7, -0.7, 0.25)))):
        cam.location = middle + direction.normalized() * reach * 1.8
        cam.rotation_euler = (middle - cam.location).to_track_quat("-Z", "Y").to_euler()
        cam_data.lens = 50
        scene.render.filepath = os.path.join(folder(name), f"{name}_preview_{view}.png")
        bpy.ops.render.render(write_still=True)
    for obj in (sun_obj, cam):
        bpy.data.objects.remove(obj)


def export(name, parts):
    out = os.path.join(folder(name), name + ".fbx")
    bpy.ops.object.select_all(action="DESELECT")
    for obj in parts:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = parts[0]
    bpy.ops.export_scene.fbx(filepath=out, use_selection=True, object_types={"MESH"}, mesh_smooth_type="FACE",
                             path_mode="COPY", embed_textures=True, apply_scale_options="FBX_SCALE_ALL")
    print("exported", out, ", ".join(f"{o.name} {sum(len(p.vertices) - 2 for p in o.data.polygons)} tris" for o in parts))


def save(name):
    for obj in [o for o in bpy.data.objects if o.name.endswith("_Src")]:
        bpy.data.objects.remove(obj)
    bpy.data.orphans_purge(do_recursive=True)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(folder(name), name + ".blend"), compress=True)


def build(name, length, target_tris=TARGET_TRIS):
    """The cleanup up to the split; returns the parts (Blade, Guard, Grip) and the guard's bottom and top z."""
    obj = load_raw(name)
    rig_kit.optimize(obj, name, target_tris=target_tris, texture_size=1024)
    guard_bottom, guard_top = place(obj, length)
    print(f"{name}: guard {guard_bottom:.2f}..{guard_top:.2f} from the grip's centre")
    parts = split(obj, guard_bottom, guard_top)
    return parts, guard_bottom, guard_top


def build_spear(name, length, grip_share=0.31, target_tris=TARGET_TRIS):
    """A spear's cleanup up to the split; returns the parts (Head, Shaft) and the head's bottom z over the grip."""
    obj = load_raw(name)
    rig_kit.optimize(obj, name, target_tris=target_tris, texture_size=1024)
    head = place_spear(obj, length, grip_share)
    print(f"{name}: head from {head:.2f} over the grip")
    parts = cut(obj, (("Head", lambda z: z >= head), ("Shaft", lambda z: z < head)))
    return parts, head


def build_scythe(name, length, grip_share=1 / 3, target_tris=TARGET_TRIS):
    """A scythe's cleanup up to the split; returns the parts (Head, Shaft) and the head's bottom z over the grip."""
    obj = load_raw(name)
    rig_kit.optimize(obj, name, target_tris=target_tris, texture_size=1024)
    head = place_scythe(obj, length, grip_share)
    print(f"{name}: head from {head:.2f} over the grip")
    parts = cut(obj, (("Head", lambda z: z >= head), ("Shaft", lambda z: z < head)))
    return parts, head


def finish(name, parts):
    export(name, parts)
    preview(name, parts)
    save(name)
