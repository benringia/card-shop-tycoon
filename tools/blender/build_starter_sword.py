"""The starter sword (Config/Swords starterSword, model "StarterSword"): a plain steel blade in the game's smooth cartoon
style. Run in Blender (through the Blender MCP). Builds Blade, Guard, Grip and Pommel around the grip's centre (the
origin; the blade points up +Z, its flat faces along Y), renders previews, exports StarterSword.fbx and saves
StarterSword.blend in assets/blender/StarterSword/ (set CARD_SHOP_REPO if the repo isn't at the default path).

In Roblox the model's origin is where the hand holds it: Blender +Z becomes Roblox +Y (the blade), matching the grip
the animations were keyed with (Config/Swords GRIPS.sword.hand). Import: docs/animations.md "The sword model".
"""
import math
import os

import bmesh
import bpy

REPO = os.environ.get("CARD_SHOP_REPO", r"C:\Users\Ben\Documents\roblox-project\card-shop-tycoon")
OUT = os.path.join(REPO, "assets", "blender", "StarterSword")

STEEL = (0.80, 0.85, 0.92, 1)
GOLD = (0.92, 0.70, 0.28, 1)
LEATHER = (0.36, 0.22, 0.14, 1)


def material(name, rgba, metallic=0.0, roughness=0.45):
    mat = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    mat.diffuse_color = rgba
    mat.use_nodes = True
    bsdf = next(n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Base Color"].default_value = rgba
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Roughness"].default_value = roughness
    return mat


def mesh_object(name, bm, mat, smooth):
    data = bpy.data.meshes.new(name)
    bm.to_mesh(data)
    bm.free()
    obj = bpy.data.objects.new(name, data)
    bpy.context.scene.collection.objects.link(obj)
    data.materials.append(mat)
    for poly in data.polygons:
        poly.use_smooth = smooth
    return obj


def blade():
    """A diamond-section blade from the guard to a point, slightly tapering."""
    bm = bmesh.new()
    thickness = 0.13
    rings = [(0.62, 0.5), (3.3, 0.46), (3.9, 0.36), (4.25, 0.2)]
    loops = []
    for z, width in rings:
        loops.append([bm.verts.new(v) for v in ((width / 2, 0, z), (0, thickness / 2, z), (-width / 2, 0, z), (0, -thickness / 2, z))])
    for a, b in zip(loops, loops[1:]):
        for i in range(4):
            bm.faces.new((a[i], a[(i + 1) % 4], b[(i + 1) % 4], b[i]))
    tip = bm.verts.new((0, 0, 4.55))
    last = loops[-1]
    for i in range(4):
        bm.faces.new((last[i], last[(i + 1) % 4], tip))
    bm.faces.new(list(reversed(loops[0])))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return mesh_object("Blade", bm, material("Steel", STEEL, metallic=0.6, roughness=0.3), smooth=False)


def rounded_box(name, size, location, mat, bevel):
    bpy.ops.mesh.primitive_cube_add(size=1, location=location)
    obj = bpy.context.active_object
    obj.name = name
    obj.scale = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    mod = obj.modifiers.new("Bevel", "BEVEL")
    mod.width, mod.segments, mod.limit_method = bevel, 3, "NONE"
    bpy.ops.object.modifier_apply(modifier=mod.name)
    obj.data.materials.append(mat)
    for poly in obj.data.polygons:
        poly.use_smooth = True
    return obj


def guard():
    """A gold crossguard with round knobs on its ends."""
    gold = material("Gold", GOLD, metallic=0.5, roughness=0.35)
    bar = rounded_box("Guard", (1.25, 0.34, 0.24), (0, 0, 0.52), gold, 0.08)
    knobs = []
    for x in (-0.66, 0.66):
        bpy.ops.mesh.primitive_uv_sphere_add(segments=16, ring_count=10, radius=0.16, location=(x, 0, 0.55))
        knob = bpy.context.active_object
        knob.data.materials.append(gold)
        knobs.append(knob)
    for knob in knobs:
        knob.select_set(True)
    bar.select_set(True)
    bpy.context.view_layer.objects.active = bar
    bpy.ops.object.join()
    for poly in bar.data.polygons:
        poly.use_smooth = True
    return bar


def grip():
    """The leather-wrapped grip with two bands (the part the hand holds: its centre is the origin)."""
    leather = material("Leather", LEATHER, roughness=0.8)
    bpy.ops.mesh.primitive_cylinder_add(vertices=16, radius=0.13, depth=0.9, location=(0, 0, -0.02))
    body = bpy.context.active_object
    body.name = "Grip"
    bands = []
    for z in (-0.3, 0.22):
        bpy.ops.mesh.primitive_cylinder_add(vertices=16, radius=0.155, depth=0.07, location=(0, 0, z))
        bands.append(bpy.context.active_object)
    for band in bands:
        band.select_set(True)
    body.select_set(True)
    bpy.context.view_layer.objects.active = body
    bpy.ops.object.join()
    body.data.materials.append(leather)
    for poly in body.data.polygons:
        poly.use_smooth = True
    return body


def pommel():
    gold = material("Gold", GOLD, metallic=0.5, roughness=0.35)
    bpy.ops.mesh.primitive_uv_sphere_add(segments=16, ring_count=10, radius=0.2, location=(0, 0, -0.62))
    obj = bpy.context.active_object
    obj.name = "Pommel"
    obj.data.materials.append(gold)
    for poly in obj.data.polygons:
        poly.use_smooth = True
    return obj


def build():
    for obj in list(bpy.data.objects):
        bpy.data.objects.remove(obj)
    parts = [blade(), guard(), grip(), pommel()]
    for obj in parts:
        obj.location = (0, 0, 0) if obj.name == "Blade" else obj.location
    return parts


def triangles(obj):
    return sum(len(p.vertices) - 2 for p in obj.data.polygons)


def render(path, cam_location, target=(0, 0, 1.9)):
    from mathutils import Vector
    scene = bpy.context.scene
    cam = bpy.data.objects.get("PreviewCam") or bpy.data.objects.new("PreviewCam", bpy.data.cameras.new("PreviewCam"))
    if cam.name not in scene.collection.objects:
        scene.collection.objects.link(cam)
    cam.location = Vector(cam_location)
    cam.rotation_euler = (Vector(target) - cam.location).to_track_quat("-Z", "Y").to_euler()
    scene.camera = cam
    try:
        scene.render.engine = "BLENDER_WORKBENCH"
    except TypeError:
        pass
    scene.display.shading.color_type = "MATERIAL"
    scene.display.shading.light = "STUDIO"
    if scene.world is None:
        scene.world = bpy.data.worlds.new("Sky")
    scene.world.color = (0.62, 0.72, 0.82)
    scene.render.resolution_x, scene.render.resolution_y = 520, 520
    scene.render.filepath = path
    bpy.ops.render.render(write_still=True)


def export():
    os.makedirs(OUT, exist_ok=True)
    meshes = [o for o in bpy.data.objects if o.type == "MESH"]
    for obj in bpy.data.objects:
        obj.select_set(obj in meshes)
    window = bpy.context.window_manager.windows[0]
    with bpy.context.temp_override(window=window, screen=window.screen, selected_objects=meshes, active_object=meshes[0]):
        bpy.ops.export_scene.fbx(filepath=os.path.join(OUT, "StarterSword.fbx"), use_selection=True, object_types={"MESH"},
                                 mesh_smooth_type="FACE", apply_scale_options="FBX_SCALE_ALL")
    print("exported", ", ".join(f"{o.name} {triangles(o)} tris" for o in meshes))


def save():
    preview = bpy.data.objects.get("PreviewCam")
    if preview:
        bpy.data.objects.remove(preview)
    bpy.data.orphans_purge(do_recursive=True)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, "StarterSword.blend"))
