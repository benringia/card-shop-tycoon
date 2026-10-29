"""Shared kit for the pack build scripts (build_pack.py, build_deckbox.py, build_displaybox.py) run inside Blender.

Meshes come straight from vertex and face lists with their UVs (no modifiers), so the triangle counts are exact.
Textures come from tools/textures/make_pack_textures.py in assets/blender/Pack/. Everything for a set's packs lives
in one file, assets/blender/Pack/Pack.blend; each script replaces its own objects and exports its own FBX.

Blender: Z up, fronts face -Y (Roblox: -Z once imported). Each model's origin is its bottom centre.
"""
import os

import bpy
from mathutils import Vector

REPO = os.environ.get("CARD_SHOP_REPO", r"C:\Users\Ben\Documents\roblox-project\card-shop-tycoon")


def out_dir():
    return os.path.join(REPO, "assets", "blender", "Pack")


def texture(name):
    return os.path.join(out_dir(), name)


def open_file():
    """Opens Pack.blend if it exists (keeping what the other scripts built), else starts an empty file there."""
    path = os.path.join(out_dir(), "Pack.blend")
    if bpy.data.filepath != path:
        if os.path.exists(path):
            bpy.ops.wm.open_mainfile(filepath=path)
        else:
            bpy.ops.wm.read_homefile(use_empty=True)
            bpy.ops.wm.save_as_mainfile(filepath=path)


def remove(names):
    for name in names:
        ob = bpy.data.objects.get(name)
        if ob:
            mesh = ob.data
            bpy.data.objects.remove(ob)
            if mesh and mesh.users == 0:
                bpy.data.meshes.remove(mesh)


def material(name, image_file, metal=0.0, rough=0.5, seal_metal=None):
    """A Principled material on an image; seal_metal (share of height, top and bottom) makes the pack's seals metal."""
    mat = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    mat.use_nodes = True
    nt = mat.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = bpy.data.images.load(texture(image_file), check_existing=True)
    nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    nt.links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
    bsdf.inputs["Metallic"].default_value = metal
    bsdf.inputs["Roughness"].default_value = rough
    if seal_metal:
        uv = nt.nodes.new("ShaderNodeUVMap")
        sep = nt.nodes.new("ShaderNodeSeparateXYZ")
        nt.links.new(uv.outputs["UV"], sep.inputs[0])
        low = nt.nodes.new("ShaderNodeMath"); low.operation = "LESS_THAN"; low.inputs[1].default_value = seal_metal
        high = nt.nodes.new("ShaderNodeMath"); high.operation = "GREATER_THAN"; high.inputs[1].default_value = 1 - seal_metal
        nt.links.new(sep.outputs["Y"], low.inputs[0]); nt.links.new(sep.outputs["Y"], high.inputs[0])
        seal = nt.nodes.new("ShaderNodeMath"); seal.operation = "MAXIMUM"
        nt.links.new(low.outputs[0], seal.inputs[0]); nt.links.new(high.outputs[0], seal.inputs[1])
        ramp = nt.nodes.new("ShaderNodeMapRange")
        ramp.inputs["To Min"].default_value = metal
        ramp.inputs["To Max"].default_value = 0.9
        nt.links.new(seal.outputs[0], ramp.inputs["Value"])
        nt.links.new(ramp.outputs["Result"], bsdf.inputs["Metallic"])
    return mat


def mesh_object(name, verts, faces, uvs, mat, smooth=True):
    """uvs: one (u, v) per vertex (seams are split vertices)."""
    remove([name])
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata([tuple(v) for v in verts], [], faces)
    layer = mesh.uv_layers.new(name="UV")
    for poly in mesh.polygons:
        poly.use_smooth = smooth
        for li in poly.loop_indices:
            layer.data[li].uv = uvs[mesh.loops[li].vertex_index]
    mesh.validate()
    mesh.materials.append(mat)
    ob = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(ob)
    return ob


def box_faces(verts, uvs, faces, centre, size, regions, atlas, rotation=None):
    """Adds a box (6 quads, own vertices per face) at centre with size; regions maps a face ("front" = -Y, "back",
    "left" = -X, "right", "top", "bottom") to an atlas region (left, top, right, bottom) in px of atlas (w, h).
    rotation: an optional Matrix applied about the box's own centre."""
    cx, cy, cz = centre
    sx, sy, sz = size[0] / 2, size[1] / 2, size[2] / 2
    corners = {
        "front": [(-sx, -sy, -sz), (sx, -sy, -sz), (sx, -sy, sz), (-sx, -sy, sz)],
        "back": [(sx, sy, -sz), (-sx, sy, -sz), (-sx, sy, sz), (sx, sy, sz)],
        "left": [(-sx, sy, -sz), (-sx, -sy, -sz), (-sx, -sy, sz), (-sx, sy, sz)],
        "right": [(sx, -sy, -sz), (sx, sy, -sz), (sx, sy, sz), (sx, -sy, sz)],
        "top": [(-sx, -sy, sz), (sx, -sy, sz), (sx, sy, sz), (-sx, sy, sz)],
        "bottom": [(-sx, sy, -sz), (sx, sy, -sz), (sx, -sy, -sz), (-sx, -sy, -sz)],
    }
    aw, ah = atlas
    for face, quad in corners.items():
        region = regions.get(face)
        if region is None:
            continue
        left, top, right, bottom = region
        u0, u1 = left / aw, right / aw
        v0, v1 = 1 - bottom / ah, 1 - top / ah
        corner_uv = [(u0, v0), (u1, v0), (u1, v1), (u0, v1)]
        start = len(verts)
        for (x, y, z), uv in zip(quad, corner_uv):
            p = Vector((x, y, z))
            if rotation is not None:
                p = rotation @ p
            verts.append((cx + p.x, cy + p.y, cz + p.z))
            uvs.append(uv)
        faces.append((start, start + 1, start + 2, start + 3))


def triangles(ob):
    return sum(len(p.vertices) - 2 for p in ob.data.polygons)


def export(fbx_name, names):
    objects = [bpy.data.objects[name] for name in names]
    for ob in bpy.data.objects:
        ob.select_set(ob in objects)
    # After open_file() loads Pack.blend from a script, the operator context has no selection: give it one
    window = bpy.context.window_manager.windows[0]
    with bpy.context.temp_override(window=window, screen=window.screen, selected_objects=objects, active_object=objects[0]):
        bpy.ops.export_scene.fbx(
            filepath=os.path.join(out_dir(), fbx_name),
            use_selection=True,
            object_types={"MESH"},
            path_mode="COPY",
            embed_textures=True,
            mesh_smooth_type="FACE",
            apply_scale_options="FBX_SCALE_ALL",
        )
    print("exported", fbx_name, ", ".join(f"{n} {triangles(bpy.data.objects[n])} tris" for n in names))


def save():
    bpy.data.orphans_purge(do_recursive=True)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(out_dir(), "Pack.blend"))
