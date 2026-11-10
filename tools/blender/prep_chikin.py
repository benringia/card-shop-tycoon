"""Prepares Chikin, the combat tutorial's guide puppy (the owner's black Shih Tzu x toy poodle), for rig_chikin.py.

Meshy image-to-3D through the Blender MCP from the owner's pick C of the Figma concepts, made a little less shaggy
(owner 2026-11-10: "lets do C. but not to shaggy"): a black puppy with neat wavy curls, a short fringe and beard, curly
floppy ears, a happy pant with a pink tongue, a curled tail (assets/blender/Chikin/concept_C2.png, kept out of git like
the owner's reference photos), saved raw as assets/blender/Chikin/Chikin_raw.glb (also kept out of git). Run in a
background Blender:

  blender -b --factory-startup --python tools/blender/prep_chikin.py

The same steps as prep_pish.py (Pish's own fixes, his head turn, ear flap and back patch, aren't needed): it imports
the raw model, turns it so its front feet face -Y (measured from the four feet: Meshy copied the concept's
three-quarter view, about 19 degrees), stands it on its feet's centre, scales it to HEIGHT metres and reduces it to
~10,000 triangles (rig_kit.optimize). Saves assets/blender/Chikin/Chikin_meshy.blend (object "Chikin_Dog") and preview
renders next to it.
"""
import math
import os
import sys

import bpy
from mathutils import Matrix, Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import rig_kit  # noqa: E402

NAME = "Chikin"
FOLDER = os.path.join(rig_kit.REPO, "assets", "blender", NAME)
RAW = os.path.join(FOLDER, "Chikin_raw.glb")
HEIGHT = 1.0  # metres, like Pish; the game scales the model (Config/Pish CHIKIN.HEIGHT)


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
    source.name = "Chikin_Src"
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


def measure(mesh):
    """Prints the shape rig_chikin.py places its bones by: the bounds and the spine's top along y"""
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
    }
    for view, direction in views.items():
        cam.location = middle + direction.normalized() * HEIGHT * 3.2
        cam.rotation_euler = (middle - cam.location).to_track_quat("-Z", "Y").to_euler()
        scene.render.filepath = os.path.join(FOLDER, f"{NAME}_preview_{view}.png")
        bpy.ops.render.render(write_still=True)
    bpy.data.objects.remove(sun)
    bpy.data.objects.remove(cam)


dog = import_raw()
straighten(dog)
rig_kit.optimize(dog, NAME, target_tris=10000)
dog.name = "Chikin_Dog"
measure(dog)
bpy.ops.outliner.orphans_purge(do_recursive=True)
for key in [k for k in bpy.context.scene.keys() if k.startswith("blendermcp_")]:
    del bpy.context.scene[key]
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(FOLDER, f"{NAME}_meshy.blend"))
preview(dog)
print("saved", os.path.join(FOLDER, f"{NAME}_meshy.blend"))
