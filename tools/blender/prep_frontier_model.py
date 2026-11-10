"""Prepares a Frontier monster's or boss's raw Meshy model for its rig script (spec
docs/superpowers/specs/2026-11-10-frontier-valley-design.md; pipeline docs/creatures.md "Frontier monsters"):
imports assets/blender/<NAME>/<NAME>_raw.glb (the image-to-3D result exported from the live Blender, kept out of git),
joins it into one mesh, turns it YAW degrees about Z so it faces -Y (Meshy copies a three-quarter concept's turn),
stands it on its lowest point, centres it over the origin, scales it to HEIGHT metres (rig_kit's metre defaults) and
saves assets/blender/<NAME>/<NAME>.blend with the object "<NAME>_Src" (the rig script reduces and rigs it), plus three
preview renders to PREVIEWS (default: the scratch folder given, else the model's folder). Run in a background Blender:

  NAME=ShadeLynx YAW=-25 HEIGHT=1 blender -b --factory-startup --python tools/blender/prep_frontier_model.py
"""
import math
import os
import sys

import bpy
from mathutils import Matrix, Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import rig_kit  # noqa: E402

NAME = os.environ["NAME"]
YAW = float(os.environ.get("YAW", "0"))
HEIGHT = float(os.environ.get("HEIGHT", "1"))
FOLDER = os.path.join(rig_kit.REPO, "assets", "blender", NAME)
PREVIEWS = os.environ.get("PREVIEWS", FOLDER)


def import_raw():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=os.path.join(FOLDER, f"{NAME}_raw.glb"))
    meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    assert meshes, f"no mesh in {NAME}_raw.glb"
    for obj in meshes:
        obj.matrix_world = obj.matrix_world.copy()
        obj.parent = None
    bpy.ops.object.select_all(action="DESELECT")
    for obj in meshes:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = meshes[0]
    if len(meshes) > 1:
        bpy.ops.object.join()
    source = bpy.context.view_layer.objects.active
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    for other in [o for o in bpy.context.scene.objects if o is not source]:
        bpy.data.objects.remove(other)
    source.name = f"{NAME}_Src"
    source.data.name = f"{NAME}_Src"
    return source


def straighten(source):
    """Turned YAW degrees, standing on its lowest point, centred over the origin, HEIGHT tall"""
    source.data.transform(Matrix.Rotation(math.radians(YAW), 4, "Z"))
    points = [v.co for v in source.data.vertices]
    low = min(p.z for p in points)
    high = max(p.z for p in points)
    middle_x = (min(p.x for p in points) + max(p.x for p in points)) / 2
    middle_y = (min(p.y for p in points) + max(p.y for p in points)) / 2
    scale = HEIGHT / (high - low)
    source.data.transform(Matrix.Scale(scale, 4) @ Matrix.Translation(Vector((-middle_x, -middle_y, -low))))
    source.data.update()
    points = [v.co for v in source.data.vertices]
    print(f"{NAME}: {len(points)} verts, size x {max(p.x for p in points) - min(p.x for p in points):.3f} "
          f"y {max(p.y for p in points) - min(p.y for p in points):.3f} z {max(p.z for p in points):.3f}")


def preview(mesh):
    scene = bpy.context.scene
    try:
        scene.render.engine = "BLENDER_EEVEE_NEXT"
    except TypeError:
        scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x, scene.render.resolution_y = 480, 480
    if not scene.world:
        scene.world = bpy.data.worlds.new("World")
    scene.world.use_nodes = True
    background = next(n for n in scene.world.node_tree.nodes if n.type == "BACKGROUND")
    background.inputs["Color"].default_value = (0.32, 0.36, 0.45, 1)
    sun = bpy.data.objects.new("Sun", bpy.data.lights.new("Sun", "SUN"))
    sun.data.energy = 3
    sun.rotation_euler = (math.radians(40), 0, math.radians(25))
    scene.collection.objects.link(sun)
    cam = bpy.data.objects.new("PreviewCam", bpy.data.cameras.new("PreviewCam"))
    scene.collection.objects.link(cam)
    scene.camera = cam
    points = [v.co for v in mesh.data.vertices]
    reach = max(max(abs(p.x) for p in points), max(abs(p.y) for p in points), HEIGHT)
    middle = Vector((0, 0, HEIGHT * 0.45))
    for view, direction in {"front": Vector((0, -1, 0.15)), "three_quarter": Vector((0.75, -0.7, 0.4)), "side": Vector((1, 0, 0.1))}.items():
        cam.location = middle + direction.normalized() * reach * 3.0
        cam.rotation_euler = (middle - cam.location).to_track_quat("-Z", "Y").to_euler()
        scene.render.filepath = os.path.join(PREVIEWS, f"{NAME}_prep_{view}.png")
        bpy.ops.render.render(write_still=True)
    bpy.data.objects.remove(sun)
    bpy.data.objects.remove(cam)


source = import_raw()
straighten(source)
for key in [k for k in bpy.context.scene.keys() if k.startswith("blendermcp_")]:
    del bpy.context.scene[key]
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(FOLDER, f"{NAME}.blend"))
preview(source)
print("saved", os.path.join(FOLDER, f"{NAME}.blend"))
