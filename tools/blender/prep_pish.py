"""Prepares Pish, the tutorial's guide puppy (the owner's own Shih Tzu, with his underbite), for rig_pish.py.

Meshy image-to-3D through the Blender MCP from the owner's pick B of the Figma concepts (a groomed white Shih Tzu with
cream ears tipped grey-brown, big dark eyes, the underbite with two bottom teeth and the tip of the tongue, a curled
tail; assets/blender/Pish/concept_B.png, kept out of git, like the owner's reference photos), saved raw as
assets/blender/Pish/Pish_raw.glb (also kept out of git). Run in a background Blender:

  blender -b --factory-startup --python tools/blender/prep_pish.py

It imports the raw model, stands it on its feet's centre facing -Y (Meshy copied the concept's three-quarter view:
the dog stood turned 41 degrees to its right), scales it to HEIGHT metres, rebuilds it as one clean ~10,000-triangle
surface with its colours baked (rig_kit.remesh_bake) and paints the light brown patch the owner asked for on the top
of its back, between its head and its tail (rig_kit.paint_region; PATCH=0 skips it). Saves
assets/blender/Pish/Pish_meshy.blend (object "Pish_Dog") and preview renders next to it.
"""
import math
import os
import sys

import bpy
from mathutils import Matrix, Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import rig_kit  # noqa: E402

NAME = "Pish"
FOLDER = os.path.join(rig_kit.REPO, "assets", "blender", NAME)
RAW = os.path.join(FOLDER, "Pish_raw.glb")
HEIGHT = 1.0  # metres, like the other generated creatures; the game scales the model
TURN = 41  # degrees about the vertical: the dog stood turned this far to its right
VOXEL = 0.004  # metres: keeps the eyes, the two bottom teeth and the tongue tip
# The patch on its back (owner 2026-11-09: "light brown, at the top of his spine, between his head and his tail"):
# a soft ellipse on the upward-facing fur, centred on the spine
PATCH_COLOR = (0.62, 0.45, 0.30)  # light brown, a little warmer than the ear tips
PATCH_CENTRE = (0.0, 0.12)  # x, y in metres: the back's top runs from behind the head (y 0) to the tail (y 0.25)
PATCH_RADII = (0.19, 0.17)  # half width, half length
PATCH_EDGE = 0.35  # of the radius: the soft edge
PATCH_UP = 0.35  # only fur facing at least this much up (normal z)
PATCH_BELOW = 0.7  # metres: the back is about 0.58 up; the tail curled over the rump and the back of the head are higher


def feet_centre(points):
    """The middle of the four feet: the vertices on the ground, split into four clusters."""
    import numpy as np

    low, high = points[:, 2].min(), points[:, 2].max()
    feet = points[points[:, 2] < low + 0.05 * (high - low)][:, :2]
    # Start from points far apart (a random start merged the two front feet and split a hind one)
    centres = [feet[feet[:, 0].argmin()]]
    while len(centres) < 4:
        gap = np.min([((feet - c) ** 2).sum(1) for c in centres], axis=0)
        centres.append(feet[gap.argmax()])
    centres = np.array(centres)
    for _ in range(40):
        label = ((feet[:, None, :] - centres[None]) ** 2).sum(-1).argmin(1)
        centres = np.array([feet[label == k].mean(0) if (label == k).any() else centres[k] for k in range(4)])
    print("feet:", [tuple(round(float(v), 4) for v in c) for c in centres])
    return centres.mean(0)


def import_raw():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=RAW)
    meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    assert len(meshes) == 1, f"expected one mesh in {RAW}, got {len(meshes)}"
    source = meshes[0]
    source.name = "Pish_Src"
    source.parent = None
    source.matrix_world = source.matrix_world.copy()
    bpy.context.view_layer.objects.active = source
    source.select_set(True)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    for other in [o for o in bpy.context.scene.objects if o is not source]:
        bpy.data.objects.remove(other)
    return source


def straighten(source):
    import numpy as np

    count = len(source.data.vertices)
    co = np.empty(count * 3)
    source.data.vertices.foreach_get("co", co)
    co = co.reshape(-1, 3)
    centre = feet_centre(co)
    scale = HEIGHT / (co[:, 2].max() - co[:, 2].min())
    move = Matrix.Translation(Vector((-centre[0], -centre[1], -co[:, 2].min())))
    source.data.transform(Matrix.Scale(scale, 4) @ Matrix.Rotation(math.radians(TURN), 4, "Z") @ move)
    source.data.update()


def patch_weight(position, normal):
    """1 in the patch, fading to 0 over its soft edge; only on fur facing up"""
    if normal.z < PATCH_UP or position.z > PATCH_BELOW:
        return 0.0
    dx = (position.x - PATCH_CENTRE[0]) / PATCH_RADII[0]
    dy = (position.y - PATCH_CENTRE[1]) / PATCH_RADII[1]
    reach = math.sqrt(dx * dx + dy * dy)
    if reach >= 1:
        return 0.0
    edge = min(1.0, (1 - reach) / PATCH_EDGE)
    up = min(1.0, (normal.z - PATCH_UP) / 0.2)
    return edge * edge * (3 - 2 * edge) * up


def measure(mesh):
    """Prints where the back is, to place the patch: the highest fur along the spine, by y"""
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
    # A soft sky all round (EEVEE lights only through the world's nodes; world.color alone left the shaded side black)
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
        "top": Vector((0.001, 0.25, 1)),
        "back_three_quarter": Vector((-0.6, 0.75, 0.6)),
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
# Meshy's surface isn't closed, so a voxel remesh (rig_kit.remesh_bake) loses the body: reduce it instead
rig_kit.optimize(dog, NAME, target_tris=10000)
dog.name = "Pish_Dog"
measure(dog)
if os.environ.get("PATCH", "1") == "1":
    rig_kit.paint_region(dog, NAME, PATCH_COLOR, patch_weight)
bpy.ops.outliner.orphans_purge(do_recursive=True)
for key in [k for k in bpy.context.scene.keys() if k.startswith("blendermcp_")]:
    del bpy.context.scene[key]
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(FOLDER, f"{NAME}_meshy.blend"))
preview(dog)
print("saved", os.path.join(FOLDER, f"{NAME}_meshy.blend"))
