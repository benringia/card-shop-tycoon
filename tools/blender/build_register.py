"""The register's body (owner 2026-11-16: "you can use meshy to draw the cash register. make sure the final model
doesnt have holes, smooth"; concept B in the shop's colours, assets/blender/Register/concept_B_shop.png: a white base
with a drawer and a lilac strip, a charcoal pole, a tablet screen in a charcoal bezel). Meshy image to 3D, imported as
"RegisterBody_raw" (0.36 m wide, its front facing -Y, origin at the bottom; kept as RegisterBody_raw.glb, gitignored).

This lengthens the pole (RAISE: the screen stands clear above the card machine on the base's front, owner: "give change
and card machine overlapping"), stretches the screen along its tilt so its glass matches the game's screen layout
(SCREEN_ASPECT, Util/RegisterScreen), rebuilds it as one closed smooth surface with its colours baked
(rig_kit.remesh_bake: no holes), smooth-shades it by angle, and measures it for the game: the base's height and depth,
and the screen glass's centre, size and tilt, relative to the bottom centre (written to RegisterBody_measure.json, in
metres and as fractions of the base's width; Config/RegisterStation BODY holds them in studs). Saves Register.blend
(the body only) and RegisterBody.fbx (texture embedded). The game keeps its own working parts on top: the screen
picture, the drawer and the card machine (Util/RegisterBuild).

Run in Blender (Blender MCP: runpy.run_path(path)). PREVIEW=1 also renders it into RegisterBody_preview.png.
"""
import importlib
import json
import math
import os
import sys

import bpy
import numpy as np
from mathutils import Vector

REPO = os.environ.get("CARD_SHOP_REPO", r"C:\Users\Ben\Documents\roblox-project\card-shop-tycoon")
sys.path.insert(0, os.path.join(REPO, "tools", "blender"))
import rig_kit  # noqa: E402

importlib.reload(rig_kit)

NAME = "Register"
OUT = os.path.join(REPO, "assets", "blender", NAME)
RAW = "RegisterBody_raw"
RAW_GLB = os.path.join(OUT, "RegisterBody_raw.glb")
POLE_SPLIT = 0.15  # m: the pole's middle; everything above rises
POLE_TOP = 0.185  # m: where the screen's bezel starts (measured off the raw mesh)
RAISE = 0.09  # m: how much higher the screen stands (the bigger screen still clears the card machine)
SCREEN_GROW = 1.25  # the screen made bigger in its own plane (owner 2026-11-16: "make the screen bigger so the display
#                     fits"), so the game's display and its buttons are bigger too
RIM = 0.006  # m: the bezel left showing round the game's display
SCREEN_ASPECT = 1.64  # the glass's width over its height (Config/RegisterStation UNIT screen size)
BEZEL = 0.012  # m: the bezel's width round the glass
VOXEL = 0.0035  # m: finer than the lilac strip and the drawer handle
TARGET_TRIS = 8000
PALETTE = [(240, 240, 242), (52, 54, 60), (185, 165, 219)]  # the shop's white, its charcoal, the lilac strip
BASE_TOP = 0.105  # m: the base's top (measured); faces above it are the pole and the screen


def raw_object():
    raw = bpy.data.objects.get(RAW)
    if raw:
        return raw
    bpy.ops.import_scene.gltf(filepath=RAW_GLB)
    raw = bpy.context.selected_objects[0]
    raw.name = RAW
    return raw


def coordinates(mesh):
    co = np.empty(len(mesh.vertices) * 3)
    mesh.vertices.foreach_get("co", co)
    return co.reshape(-1, 3)


def principal_axes(points):
    """The centre and the axes of `points` (largest spread first) with their extents."""
    centre = points.mean(axis=0)
    values, vectors = np.linalg.eigh(np.cov((points - centre).T))
    order = np.argsort(values)[::-1]
    axes = [vectors[:, i] for i in order]
    extents = [float(np.ptp((points - centre) @ axis)) for axis in axes]
    return centre, axes, extents


def reshape(source):
    """The pole lengthened and the screen stretched along its tilt (on a copy's vertices)."""
    co = coordinates(source.data)
    co[co[:, 2] > POLE_SPLIT, 2] += RAISE
    screen = co[:, 2] > POLE_TOP + RAISE
    centre, axes, extents = principal_axes(co[screen])
    width, height = extents[0], extents[1]
    up = axes[1] if axes[1][2] > 0 else -axes[1]
    k = ((width - 2 * BEZEL) / SCREEN_ASPECT + 2 * BEZEL) / height
    offsets = (co[screen] - centre) @ up
    co[screen] += np.outer(offsets * (k - 1), up)
    # then grown in its own plane (not its thickness), round its middle
    across = (co[screen] - centre) @ axes[0]
    along = (co[screen] - centre) @ up
    co[screen] += np.outer(across * (SCREEN_GROW - 1), axes[0]) + np.outer(along * (SCREEN_GROW - 1), up)
    source.data.vertices.foreach_set("co", co.ravel())
    source.data.update()
    print(f"reshape: screen {width:.3f} x {height:.3f} m stretched x{k:.3f} along its tilt, grown x{SCREEN_GROW}")


def flatten_colours(body):
    """The baked map in the shop's flat colours (Meshy's texture left black blotches and light scratches on the bezel
    and glass): everything above the base (the pole, the bezel, the glass, which the game covers with its own screen)
    solid charcoal; the base's texels snapped to the nearest of PALETTE (white, the charcoal handle, the lilac strip)."""
    mat = body.data.materials[0]
    image = next(n.image for n in mat.node_tree.nodes if n.type == "TEX_IMAGE" and n.image)
    width, height = image.size
    pixels = np.empty(width * height * 4, dtype=np.float32)
    image.pixels.foreach_get(pixels)
    rgba = pixels.reshape(height, width, 4)
    palette = np.array(PALETTE, dtype=np.float32) / 255
    nearest = np.argmin(((rgba[:, :, None, :3] - palette[None, None, :, :]) ** 2).sum(axis=3), axis=2)
    rgba[:, :, :3] = palette[nearest]
    upper = np.zeros((height, width), dtype=bool)
    uv = body.data.uv_layers.active.data
    for poly in body.data.polygons:
        if poly.center.z <= BASE_TOP + 0.004:
            continue
        corners = [uv[i].uv for i in poly.loop_indices]
        for i in range(1, len(corners) - 1):
            rig_kit._fill_triangle(upper, corners[0], corners[i], corners[i + 1])
    rgba[upper, :3] = palette[1]
    image.pixels.foreach_set(rgba.ravel())
    image.save()
    image.pack()
    print("flatten_colours:", int(upper.sum()), "texels painted charcoal above the base")


def measure(body):
    """Where the game puts its own parts, relative to the bottom centre (front -Y)."""
    co = coordinates(body.data)
    width = float(np.ptp(co[:, 0]))
    # the base: the slices as wide as the body
    slices = {}
    for z in np.arange(0.0, 0.2, 0.005):
        band = co[(co[:, 2] >= z) & (co[:, 2] < z + 0.005)]
        if len(band):
            slices[round(float(z), 3)] = float(np.ptp(band[:, 0]))
    base_top = max(z for z, w in slices.items() if w > width * 0.85) + 0.005
    base = co[co[:, 2] < base_top * 0.6]
    base_front, base_back = float(base[:, 1].min()), float(base[:, 1].max())
    # the screen's plane from its upper part (clear of the pole)...
    high = co[:, 2] > POLE_TOP + RAISE + 0.03
    centre, axes, extents = principal_axes(co[high])
    up = axes[1] if axes[1][2] > 0 else -axes[1]
    normal = axes[2] if axes[2][1] < 0 else -axes[2]  # toward the front (-Y)
    # ...then its whole front face: every vertex above the base whose normal faces the front, on the front of that plane
    # (the pole's sides face sideways, so it never counts)
    normals = np.empty(len(body.data.vertices) * 3)
    body.data.vertices.foreach_get("normal", normals)
    normals = normals.reshape(-1, 3)
    facing = (co[:, 2] > BASE_TOP + 0.05) & (normals @ normal > 0.85) & ((co - centre) @ normal > -0.005)
    face = co[facing]
    u = (face - centre) @ axes[0]
    v = (face - centre) @ up
    depth = float(((face - centre) @ normal).max())
    mid_u, mid_v = (u.max() + u.min()) / 2, (v.max() + v.min()) / 2
    front = centre + axes[0] * mid_u + up * mid_v + normal * depth
    tilt = math.degrees(math.atan2(-up[1], up[2]))  # back from upright (its top toward +Y)
    glass_w, glass_h = float(u.max() - u.min()) - 2 * RIM, float(v.max() - v.min()) - 2 * RIM
    data = {
        "width": width,
        "height": float(co[:, 2].max()),
        "baseTop": base_top,
        "baseFront": -base_front,  # metres in front of the centre
        "baseBack": base_back,
        "screenCentre": [float(front[0]), float(-front[1]), float(front[2])],  # x, toward the front, up
        "screenSize": [glass_w, glass_h],
        "screenTilt": tilt,
    }
    data["fractions"] = {key: (value / width if isinstance(value, float) else [v / width for v in value]) for key, value in data.items() if key not in ("width", "screenTilt")}
    return data


def preview(body):
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.display.shading.color_type = "TEXTURE"
    scene.display.shading.light = "STUDIO"
    scene.render.resolution_x, scene.render.resolution_y = 700, 700
    cam = bpy.data.objects.new("PreviewCam", bpy.data.cameras.new("PreviewCam"))
    scene.collection.objects.link(cam)
    scene.camera = cam
    centre = Vector((0, 0, 0.2))
    cam.location = centre + Vector((0.6, -1.0, 0.55)).normalized() * 0.95
    cam.rotation_euler = (centre - cam.location).to_track_quat("-Z", "Y").to_euler()
    scene.render.filepath = os.path.join(OUT, "RegisterBody_preview.png")
    bpy.ops.render.render(write_still=True)
    bpy.data.objects.remove(cam)


def build():
    os.makedirs(OUT, exist_ok=True)
    raw = raw_object()
    if not os.path.exists(RAW_GLB):
        bpy.ops.object.select_all(action="DESELECT")
        raw.select_set(True)
        bpy.ops.export_scene.gltf(filepath=RAW_GLB, use_selection=True, export_format="GLB")
    for old in [o for o in bpy.data.objects if o.name.startswith("RegisterBody") and o != raw]:
        bpy.data.objects.remove(old)
    source = raw.copy()
    source.data = raw.data.copy()
    source.name = "RegisterBody_Src"
    bpy.context.scene.collection.objects.link(source)
    reshape(source)
    body = rig_kit.remesh_bake(source, NAME, voxel=VOXEL, target_tris=TARGET_TRIS)
    body.name = body.data.name = "RegisterBody"
    bpy.ops.object.select_all(action="DESELECT")
    body.select_set(True)
    bpy.context.view_layer.objects.active = body
    bpy.ops.object.shade_smooth_by_angle(angle=math.radians(35))
    flatten_colours(body)
    data = measure(body)
    with open(os.path.join(OUT, "RegisterBody_measure.json"), "w") as handle:
        json.dump(data, handle, indent=2)
    if os.environ.get("PREVIEW") == "1":
        preview(body)
    # the file keeps the body only (the raw mesh is in the glb)
    for obj in [o for o in bpy.data.objects if o != body]:
        bpy.data.objects.remove(obj)
    bpy.ops.outliner.orphans_purge(do_recursive=True)
    for key in [k for k in bpy.context.scene.keys() if k.startswith("blendermcp_")]:
        del bpy.context.scene[key]
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, f"{NAME}.blend"))
    bpy.ops.object.select_all(action="DESELECT")
    body.select_set(True)
    bpy.context.view_layer.objects.active = body
    bpy.ops.export_scene.fbx(
        filepath=os.path.join(OUT, "RegisterBody.fbx"),
        use_selection=True,
        object_types={"MESH"},
        path_mode="COPY",
        embed_textures=True,
        apply_scale_options="FBX_SCALE_ALL",
    )
    tris = sum(len(p.vertices) - 2 for p in body.data.polygons)
    print("built RegisterBody", tris, "triangles", json.dumps(data))
    return data


build()
