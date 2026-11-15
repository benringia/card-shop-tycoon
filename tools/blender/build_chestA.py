"""The boss chest, remade (owner 2026-11-16: "we need a chest design for after the boss is killed. it looks too ugly";
pick A from assets/blender/Chest/concepts_v2.png: honey wood, chunky riveted gold bands, a glowing purple gem lock).
Meshy image to 3D from assets/blender/ChestA/ChestA_concept.png ("ChestA_Src" in ChestA.blend, 0.66 m wide, its front
facing -Y, origin at the bottom). This reduces it to about TARGET_TRIS triangles (rig_kit.optimize keeps only its colour
map), cuts it at the lid's seam (the top of the horizontal gold band: SEAM_Z) into Body and Lid, caps both cuts in the
chest's dark wood, and saves ChestA.blend and ChestA.fbx (Body + Lid, texture embedded). The game swings the Lid on the
Body's top back edge (Util/ChestModel), so nothing else is needed. Run in Blender (Blender MCP: runpy.run_path(path)),
with ChestA.blend open.

PREVIEW=1 also renders it closed and open into assets/blender/ChestA/ChestA_preview_<view>.png.

The committed ChestA.blend holds only Body and Lid: the raw Meshy mesh (768,000 triangles, 38 MB) was deleted to keep
the file small. To run this again, import a fresh generation from ChestA_concept.png as "ChestA_Src" first.
"""
import importlib
import math
import os
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector

REPO = os.environ.get("CARD_SHOP_REPO", r"C:\Users\Ben\Documents\roblox-project\card-shop-tycoon")
sys.path.insert(0, os.path.join(REPO, "tools", "blender"))
import rig_kit  # noqa: E402

importlib.reload(rig_kit)

NAME = "ChestA"
OUT = os.path.join(REPO, "assets", "blender", NAME)
TARGET_TRIS = 18000  # 9,000 crumpled the bands and planks; each half stays under Roblox's 20,000 a part
SEAM_Z = 0.355  # the top of the horizontal gold band: the barrel lid starts here (measured off the mesh)


def dark_wood_uv(mesh):
    """A UV point on the plain wood of the chest's back (the caps take its colour)."""
    uv = mesh.data.uv_layers.active.data
    best, best_score = None, -1.0
    for poly in mesh.data.polygons:
        centre = poly.center
        if poly.normal.y > 0.8 and abs(centre.x) < 0.1 and 0.12 < centre.z < 0.24:
            score = poly.area
            if score > best_score:
                best, best_score = poly, score
    if not best:
        return (0.5, 0.5)
    first = uv[best.loop_indices[0]].uv
    return (first.x, first.y)


def half(source, keep_below, cap_uv):
    """A copy of `source` keeping what's below (or above) SEAM_Z, its cut closed with a flat cap in `cap_uv`."""
    obj = source.copy()
    obj.data = source.data.copy()
    bpy.context.scene.collection.objects.link(obj)
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    geom = bm.verts[:] + bm.edges[:] + bm.faces[:]
    result = bmesh.ops.bisect_plane(
        bm, geom=geom, dist=0.0001, plane_co=Vector((0, 0, SEAM_Z)), plane_no=Vector((0, 0, 1)),
        clear_outer=keep_below, clear_inner=not keep_below,
    )
    cut_edges = [e for e in result["geom_cut"] if isinstance(e, bmesh.types.BMEdge)]
    filled = bmesh.ops.holes_fill(bm, edges=cut_edges, sides=0)
    uv_layer = bm.loops.layers.uv.active
    for face in filled["faces"]:
        face.smooth = False  # flat: smooth normals streaked across the long fan triangles
        for loop in face.loops:
            loop[uv_layer].uv = cap_uv
    bm.normal_update()
    bm.to_mesh(obj.data)
    bm.free()
    return obj


def preview(body, lid):
    os.makedirs(OUT, exist_ok=True)
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.display.shading.color_type = "TEXTURE"
    scene.display.shading.light = "STUDIO"
    scene.render.resolution_x, scene.render.resolution_y = 600, 600
    cam = bpy.data.objects.new("PreviewCam", bpy.data.cameras.new("PreviewCam"))
    scene.collection.objects.link(cam)
    scene.camera = cam
    centre = Vector((0, 0, 0.3))
    hinge_y = max((body.matrix_world @ Vector(c)).y for c in body.bound_box)
    for label, opened in (("closed", 0), ("open", 105)):
        lid.matrix_world = (Matrix.Translation((0, hinge_y, SEAM_Z)) @ Matrix.Rotation(math.radians(-opened), 4, "X")
                            @ Matrix.Translation((0, -hinge_y, -SEAM_Z)))
        cam.location = centre + Vector((0.75, -1.0, 0.65)).normalized() * 1.5
        cam.rotation_euler = (centre - cam.location).to_track_quat("-Z", "Y").to_euler()
        scene.render.filepath = os.path.join(OUT, f"{NAME}_preview_{label}.png")
        bpy.ops.render.render(write_still=True)
    lid.matrix_world = Matrix.Identity(4)
    bpy.data.objects.remove(cam)


def build():
    source = bpy.data.objects[f"{NAME}_Src"]
    for old in [o for o in bpy.data.objects if o.name in ("Body", "Lid")]:
        bpy.data.objects.remove(old)
    work = source.copy()
    work.data = source.data.copy()
    work.name = f"{NAME}_Work"
    work.hide_viewport = work.hide_render = False  # the source is hidden after a first run: its copies would be too
    bpy.context.scene.collection.objects.link(work)
    rig_kit.optimize(work, NAME, TARGET_TRIS)
    # crisp where the bands meet the wood, smooth along the curves (all-smooth normals looked crumpled once reduced)
    bpy.ops.object.select_all(action="DESELECT")
    work.select_set(True)
    bpy.context.view_layer.objects.active = work
    bpy.ops.object.shade_smooth_by_angle(angle=math.radians(35))
    cap = dark_wood_uv(work)
    body = half(work, True, cap)
    body.name = body.data.name = "Body"
    lid = half(work, False, cap)
    lid.name = lid.data.name = "Lid"
    bpy.data.objects.remove(work)
    source.hide_viewport = source.hide_render = True
    tris = {o.name: sum(len(p.vertices) - 2 for p in o.data.polygons) for o in (body, lid)}
    if os.environ.get("PREVIEW") == "1":
        preview(body, lid)
    for key in [k for k in bpy.context.scene.keys() if k.startswith("blendermcp_")]:
        del bpy.context.scene[key]
    bpy.ops.wm.save_mainfile()
    bpy.ops.object.select_all(action="DESELECT")
    body.select_set(True)
    lid.select_set(True)
    bpy.context.view_layer.objects.active = body
    bpy.ops.export_scene.fbx(
        filepath=os.path.join(OUT, f"{NAME}.fbx"),
        use_selection=True,
        object_types={"MESH"},
        path_mode="COPY",
        embed_textures=True,
        apply_scale_options="FBX_SCALE_ALL",
    )
    print("built", NAME, tris)
    return tris


build()
