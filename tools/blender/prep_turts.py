"""Prepares Turts, the plaza shopkeeper (the owner's dog: a shaggy black Shih Tzu, cross-eyed, an underbite with his
tongue always out; spec 2026-11-13-turts-shop-design), for rig_turts.py.

Meshy image-to-3D through the Blender MCP from the owner's pick, concept A with bigger pupils
(assets/blender/Turts/concept_A3.png, kept out of git with the owner's photo), saved raw as
assets/blender/Turts/Turts_raw.glb (also out of git). Run in a background Blender:

  blender -b --factory-startup --python tools/blender/prep_turts.py

The same steps as prep_chikin.py: imports the raw model, turns it so its front feet face -Y (measured from the four
feet), stands it on its feet's centre, scales it to HEIGHT metres and reduces it to ~10,000 triangles
(rig_kit.optimize). Saves assets/blender/Turts/Turts_meshy.blend (object "Turts_Dog") and preview renders next to it.
"""
import math
import os
import sys

import bpy
from mathutils import Matrix, Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import rig_kit  # noqa: E402

NAME = "Turts"
FOLDER = os.path.join(rig_kit.REPO, "assets", "blender", NAME)
RAW = os.path.join(FOLDER, "Turts_raw.glb")
HEIGHT = 1.0  # metres, like Pish and Chikin; the game scales the model


def feet(points):
    """The four feet's centres: the vertices on the ground, split into four clusters (as prep_pish.feet_centre)"""
    import numpy as np

    low, high = points[:, 2].min(), points[:, 2].max()
    ground = points[points[:, 2] < low + 0.05 * (high - low)][:, :2]
    centres = [ground[ground[:, 0].argmin()]]
    while len(centres) < 4:
        gap = np.min([((ground - c) ** 2).sum(1) for c in centres], axis=0)
        centres.append(ground[gap.argmax()])
    centres = np.array(centres)
    for _ in range(40):
        label = ((ground[:, None, :] - centres[None]) ** 2).sum(-1).argmin(1)
        centres = np.array([ground[label == k].mean(0) if (label == k).any() else centres[k] for k in range(4)])
    print("feet:", [tuple(round(float(v), 4) for v in c) for c in centres])
    return centres


def import_raw():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=RAW)
    meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    assert len(meshes) == 1, f"expected one mesh in {RAW}, got {len(meshes)}"
    source = meshes[0]
    source.name = "Turts_Src"
    source.parent = None
    source.matrix_world = source.matrix_world.copy()
    bpy.context.view_layer.objects.active = source
    source.select_set(True)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    for other in [o for o in bpy.context.scene.objects if o is not source]:
        bpy.data.objects.remove(other)
    return source


def straighten(source):
    """Front feet toward -Y, the feet's centre at the origin, the feet on the ground, HEIGHT tall"""
    import numpy as np

    count = len(source.data.vertices)
    co = np.empty(count * 3)
    source.data.vertices.foreach_get("co", co)
    co = co.reshape(-1, 3)
    centres = feet(co)
    order = centres[:, 1].argsort()
    front, back = centres[order[:2]].mean(0), centres[order[2:]].mean(0)
    turn = math.atan2(back[0] - front[0], back[1] - front[1])
    print("turn:", round(math.degrees(turn), 1), "degrees")
    middle = centres.mean(0)
    scale = HEIGHT / (co[:, 2].max() - co[:, 2].min())
    move = Matrix.Translation(Vector((-middle[0], -middle[1], -co[:, 2].min())))
    source.data.transform(Matrix.Scale(scale, 4) @ Matrix.Rotation(turn, 4, "Z") @ move)
    source.data.update()


FACE_TRIS = int(os.environ.get("TRIS", "16000"))  # Roblox takes up to 20,000 a MeshPart
# His face (front of the head: the crossed eyes, nose, underbite and tongue) kept far denser than his coat: at a plain
# 10,000 the pupils smeared, the nose vanished and the tongue became a shard. Box in metres after straighten().
FACE_BOX = {"y": (-0.75, -0.25), "z": (0.5, 0.95), "x": (-0.32, 0.32)}
FACE_SHARE = float(os.environ.get("FACE_SHARE", "0.35"))  # of FACE_TRIS spent on the face


def decimate(obj, target):
    tris = sum(len(p.vertices) - 2 for p in obj.data.polygons)
    if tris <= target:
        return
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    mod = obj.modifiers.new("Decimate", "DECIMATE")
    mod.decimate_type = "COLLAPSE"
    mod.use_collapse_triangulate = True
    mod.ratio = target / tris
    bpy.ops.object.modifier_apply(modifier=mod.name)


def decimate_face_kept(mesh, target):
    """Splits off the face (faces centred in FACE_BOX), decimates it to FACE_SHARE of `target` and the rest of him
    to the remainder, then joins them and welds the seam back"""
    import bmesh

    box = FACE_BOX
    bm = bmesh.new()
    bm.from_mesh(mesh.data)
    for f in bm.faces:
        c = f.calc_center_median()
        f.select = box["x"][0] <= c.x <= box["x"][1] and box["y"][0] <= c.y <= box["y"][1] and box["z"][0] <= c.z <= box["z"][1]
    for v in bm.verts:
        v.select = False
    for e in bm.edges:
        e.select = False
    for f in bm.faces:
        if f.select:
            for v in f.verts:
                v.select = True
    bm.to_mesh(mesh.data)
    bm.free()
    bpy.ops.object.select_all(action="DESELECT")
    mesh.select_set(True)
    bpy.context.view_layer.objects.active = mesh
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_mode(type="FACE")
    bpy.ops.mesh.separate(type="SELECTED")
    bpy.ops.object.mode_set(mode="OBJECT")
    face = next(o for o in bpy.context.scene.objects if o.type == "MESH" and o is not mesh)
    print("face triangles before:", sum(len(p.vertices) - 2 for p in face.data.polygons))
    decimate(face, int(target * FACE_SHARE))
    decimate(mesh, int(target * (1 - FACE_SHARE)))
    bpy.ops.object.select_all(action="DESELECT")
    face.select_set(True)
    mesh.select_set(True)
    bpy.context.view_layer.objects.active = mesh
    bpy.ops.object.join()
    bm = bmesh.new()
    bm.from_mesh(mesh.data)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.004)
    bm.to_mesh(mesh.data)
    bm.free()
    print("decimated to", sum(len(p.vertices) - 2 for p in mesh.data.polygons), "triangles")


HULL_VOXEL = float(os.environ.get("HULL_VOXEL", "0.035"))  # metres: big enough to close the gaps between fur flaps
HULL_INSET = float(os.environ.get("HULL_INSET", "0.022"))  # metres under the fur's outer surface
HULL_TRIS = int(os.environ.get("HULL_TRIS", "2500"))


def dark_uv(mesh):
    """A UV on the colour map where the fur is darkest (15th percentile): the under-coat's colour"""
    import numpy as np

    image = next(n.image for n in mesh.data.materials[0].node_tree.nodes if n.type == "TEX_IMAGE" and n.image)
    w, h = image.size
    pixels = np.array(image.pixels[:]).reshape(h, w, 4)[:, :, :3]
    light = pixels.mean(axis=2)
    target = np.percentile(light, 15)
    y, x = np.unravel_index(np.abs(light - target).argmin(), light.shape)
    print("under-coat colour", [round(float(c), 3) for c in pixels[y, x]], "at", int(x), int(y))
    return (x + 0.5) / w, (y + 0.5) / h


def add_undercoat(mesh):
    """A closed dark shell just inside his fur (owner 2026-11-13: "turts got so many holes on him"): Meshy's fur is
    thousands of open flaps, and the cut down to his triangle budget opened gaps between them that showed the sky.
    The shell is his own shape voxel-remeshed (closing the gaps), pushed HULL_INSET inward and joined into his mesh,
    every corner on a dark texel of his colour map, so a gap shows dark fur."""
    import bmesh

    u, v = dark_uv(mesh)
    bpy.ops.object.select_all(action="DESELECT")
    mesh.select_set(True)
    bpy.context.view_layer.objects.active = mesh
    bpy.ops.object.duplicate()
    hull = bpy.context.active_object
    hull.name = "Turts_Undercoat"
    remesh = hull.modifiers.new("Remesh", "REMESH")
    remesh.mode = "VOXEL"
    remesh.voxel_size = HULL_VOXEL
    remesh.adaptivity = 0
    bpy.ops.object.modifier_apply(modifier=remesh.name)
    tris = sum(len(p.vertices) - 2 for p in hull.data.polygons)
    if tris > HULL_TRIS:
        mod = hull.modifiers.new("Decimate", "DECIMATE")
        mod.decimate_type = "COLLAPSE"
        mod.use_collapse_triangulate = True
        mod.ratio = HULL_TRIS / tris
        bpy.ops.object.modifier_apply(modifier=mod.name)
    bm = bmesh.new()
    bm.from_mesh(hull.data)
    bm.normal_update()
    for vert in bm.verts:
        vert.co -= vert.normal * HULL_INSET
    bmesh.ops.triangulate(bm, faces=bm.faces)
    bm.to_mesh(hull.data)
    bm.free()
    name = mesh.data.uv_layers.active.name
    layer = hull.data.uv_layers.get(name) or hull.data.uv_layers.new(name=name)
    for loop in layer.data:
        loop.uv = (u, v)
    hull.data.materials.clear()
    hull.data.materials.append(mesh.data.materials[0])
    print("under-coat:", sum(len(p.vertices) - 2 for p in hull.data.polygons), "triangles")
    bpy.ops.object.select_all(action="DESELECT")
    hull.select_set(True)
    mesh.select_set(True)
    bpy.context.view_layer.objects.active = mesh
    bpy.ops.object.join()


def measure(mesh):
    """Prints the shape rig_turts.py places its bones by: the bounds and the spine's top along y"""
    rows = {}
    for v in mesh.data.vertices:
        p = mesh.matrix_world @ v.co
        if abs(p.x) < 0.04:
            key = round(p.y, 1)
            rows[key] = max(rows.get(key, -1), p.z)
    print("spine top by y:", sorted((k, round(z, 3)) for k, z in rows.items()))
    xs = [(mesh.matrix_world @ v.co) for v in mesh.data.vertices]
    print("bounds x", round(min(p.x for p in xs), 3), round(max(p.x for p in xs), 3),
          "y", round(min(p.y for p in xs), 3), round(max(p.y for p in xs), 3),
          "z", round(min(p.z for p in xs), 3), round(max(p.z for p in xs), 3))


def preview(mesh):
    scene = bpy.context.scene
    try:
        scene.render.engine = "BLENDER_EEVEE_NEXT"
    except TypeError:
        scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x, scene.render.resolution_y = 640, 640
    if not scene.world:
        scene.world = bpy.data.worlds.new("World")
    scene.world.use_nodes = True
    background = next(n for n in scene.world.node_tree.nodes if n.type == "BACKGROUND")
    background.inputs["Color"].default_value = (0.32, 0.4, 0.5, 1)
    background.inputs["Strength"].default_value = 1.0
    sun = bpy.data.objects.new("Sun", bpy.data.lights.new("Sun", "SUN"))
    sun.data.energy = 3
    sun.rotation_euler = (math.radians(40), 0, math.radians(25))
    scene.collection.objects.link(sun)
    cam = bpy.data.objects.new("PreviewCam", bpy.data.cameras.new("PreviewCam"))
    scene.collection.objects.link(cam)
    scene.camera = cam
    middle = Vector((0, 0, HEIGHT * 0.45))
    views = {
        "front": Vector((0, -1, 0.15)),
        "three_quarter": Vector((0.75, -0.7, 0.45)),
        "side": Vector((1, 0, 0.1)),
        "face": Vector((0, -1, 0.1)),
    }
    for view, direction in views.items():
        aim = Vector((0, -0.45, 0.72)) if view == "face" else middle
        cam.location = aim + direction.normalized() * HEIGHT * (0.9 if view == "face" else 3.2)
        cam.rotation_euler = (aim - cam.location).to_track_quat("-Z", "Y").to_euler()
        scene.render.filepath = os.path.join(FOLDER, f"{NAME}_preview_{view}.png")
        bpy.ops.render.render(write_still=True)
    bpy.data.objects.remove(sun)
    bpy.data.objects.remove(cam)


dog = import_raw()
straighten(dog)
decimate_face_kept(dog, FACE_TRIS)
rig_kit.optimize(dog, NAME, target_tris=FACE_TRIS)
add_undercoat(dog)
dog.name = "Turts_Dog"
measure(dog)
bpy.ops.outliner.orphans_purge(do_recursive=True)
for key in [k for k in bpy.context.scene.keys() if k.startswith("blendermcp_")]:
    del bpy.context.scene[key]
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(FOLDER, f"{NAME}_meshy.blend"))
preview(dog)
print("saved", os.path.join(FOLDER, f"{NAME}_meshy.blend"))
