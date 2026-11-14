"""Shared kit for rigging generated creature meshes (made with Meshy through the Blender MCP, in the stylized cartoon
style of the Cute Pets pack) with bones named for src/shared/Util/PetRig.luau, so the game's code animation drives
them. Each creature has a small rig_<card>.py with its bone positions (read off its mesh) and calls run().

Blender's automatic (heat) weighting fails on generated meshes, which are many separate overlapping pieces, so skin()
weights every vertex itself: a vertex is shared between its leg and the body by how far down the leg and how close to
the leg's column it is (a smooth blend, so the belly never tears away with a swinging leg); within each part it
follows its nearest bones (inverse distance); then the weights are smoothed over everything within a few centimetres
(by distance, not edges, so loose pieces move with the surface under them). At most four bones per vertex, as Roblox
allows.

Blender space: Z up, creatures face -Y, their left is +X. Run inside Blender with the creature's .blend open.
"""
import os

import bpy
from mathutils import Matrix, Vector, kdtree

REPO = os.environ.get("CARD_SHOP_REPO", r"C:\Users\Ben\Documents\roblox-project\card-shop-tycoon")
MAX_BONES = 4  # Roblox's limit


class Params:
    """How a creature's skin is shared out; the defaults suit a four-legged creature about 1.2 m tall."""

    mid_x = 0.0  # the body's midline (left side is +X)
    leg_top = 0.65  # above this a vertex is all body; below leg_full (the elbows and knees) it can be all leg
    leg_full = 0.42
    leg_core = 0.07  # within this of a leg's column a vertex can be all leg; beyond leg_radius it's all body
    leg_radius = 0.15
    # Within belly_mid of the midline a vertex is all body, fading to normal by belly_mid + belly_fade, so the belly
    # between the legs doesn't tear down the middle (each side follows its own leg); 0 turns it off
    belly_mid = 0.0
    belly_fade = 0.04
    arm_core = 0.04  # within this of an arm bone a vertex can be all arm; beyond arm_radius it's all body
    arm_radius = 0.08
    tail_from = 0.4  # tail bones only move vertices behind this (Y)
    head_from = -0.45  # neck and head bones only move vertices in front of this (Y)
    falloff = 2.5  # how sharply a vertex prefers its nearest bone (lower blends more)
    smooth = 0.5  # each smoothing pass mixes this much of the nearby vertices' weights in
    smooth_passes = 4
    smooth_radius = 0.05  # metres


def optimize(mesh, name, target_tris=10000, texture_size=1024, crumb_verts=12):
    """Makes a generated mesh light for Roblox: merges overlapping vertices, deletes tiny loose pieces (the generator's
    crumbs, mostly hidden inside the body), reduces it to about target_tris triangles (collapse decimate) and keeps
    only the colour map at texture_size pixels (a flat cartoon doesn't need the normal or metal/roughness maps, and the
    normal map was baked for the full-detail mesh, so on the reduced one it paints false facets). Safe to run again."""
    import bmesh

    bm = bmesh.new()
    bm.from_mesh(mesh.data)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.0005)
    seen, crumbs = set(), []
    for v in bm.verts:
        if v in seen:
            continue
        island, stack = [], [v]
        seen.add(v)
        while stack:
            cur = stack.pop()
            island.append(cur)
            for e in cur.link_edges:
                w = e.other_vert(cur)
                if w not in seen:
                    seen.add(w)
                    stack.append(w)
        if len(island) < crumb_verts:
            crumbs.extend(island)
    bmesh.ops.delete(bm, geom=crumbs, context="VERTS")
    bm.to_mesh(mesh.data)
    bm.free()
    tris = sum(len(p.vertices) - 2 for p in mesh.data.polygons)
    if tris > target_tris * 1.05:
        bpy.ops.object.select_all(action="DESELECT")
        mesh.select_set(True)
        bpy.context.view_layer.objects.active = mesh
        mod = mesh.modifiers.new("Decimate", "DECIMATE")
        mod.decimate_type = "COLLAPSE"
        mod.use_collapse_triangulate = True
        mod.ratio = target_tris / tris
        bpy.ops.object.modifier_apply(modifier=mod.name)
    for poly in mesh.data.polygons:
        poly.use_smooth = True
    for mat in mesh.data.materials:
        if not mat or not mat.use_nodes:
            continue
        nt = mat.node_tree
        for n in list(nt.nodes):
            if n.type in ("NORMAL_MAP", "SEPARATE_COLOR") or (
                    n.type == "TEX_IMAGE" and n.image and n.image.colorspace_settings.name == "Non-Color"):
                nt.nodes.remove(n)
        bsdf = next((n for n in nt.nodes if n.type == "BSDF_PRINCIPLED"), None)
        if bsdf:
            bsdf.inputs["Metallic"].default_value = 0.0
            bsdf.inputs["Roughness"].default_value = 0.7
        for n in nt.nodes:
            if n.type != "TEX_IMAGE" or not n.image:
                continue
            # Resize in memory, write it out as its own PNG and pack that, so the FBX embeds the small map (resizing
            # alone leaves the original full-size data packed)
            image = n.image
            if max(image.size) > texture_size:
                image.scale(texture_size, texture_size)
            path = os.path.join(REPO, "assets", "blender", name, f"{name}_color.png")
            # save() writes the pixels as they are; save_render() runs them through the scene's view transform
            # (AgX), which washed the colours out more on every run
            image.filepath_raw = path
            image.file_format = "PNG"
            image.save()
            small = bpy.data.images.load(path, check_existing=False)
            small.pack()
            n.image = small
    print("optimized:", len(crumbs), "crumb vertices removed,",
          sum(len(p.vertices) - 2 for p in mesh.data.polygons), "triangles,", len(mesh.data.vertices), "vertices")


def remesh_bake(source, name, voxel=0.006, target_tris=10000, texture_size=1024):
    """For generated meshes that collapse-decimate badly (dense fine detail like grass blades eats the triangle budget
    and the body turns to shards): rebuilds `source` as one clean closed surface (voxel remesh), reduces that to about
    target_tris, unwraps it and bakes the source's colours onto a new texture_size map, saved as
    assets/blender/<name>/<name>_color.png. Returns the new object (<source name>_Remesh); the source is hidden, kept
    for re-baking. Fine detail thinner than `voxel` (metres) melts away, which is usually what we want."""
    bpy.ops.object.select_all(action="DESELECT")
    low = source.copy()
    low.data = source.data.copy()
    low.name = source.name + "_Remesh"
    bpy.context.scene.collection.objects.link(low)
    low.data.materials.clear()
    bpy.context.view_layer.objects.active = low
    low.select_set(True)
    remesh = low.modifiers.new("Remesh", "REMESH")
    remesh.mode = "VOXEL"
    remesh.voxel_size = voxel
    bpy.ops.object.modifier_apply(modifier=remesh.name)
    tris = sum(len(p.vertices) - 2 for p in low.data.polygons)
    if tris > target_tris:
        dec = low.modifiers.new("Decimate", "DECIMATE")
        dec.decimate_type = "COLLAPSE"
        dec.use_collapse_triangulate = True
        dec.ratio = target_tris / tris
        bpy.ops.object.modifier_apply(modifier=dec.name)
    for poly in low.data.polygons:
        poly.use_smooth = True
    while low.data.uv_layers:
        low.data.uv_layers.remove(low.data.uv_layers[0])
    low.data.uv_layers.new(name="UVMap")
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=1.15, island_margin=0.004)
    bpy.ops.object.mode_set(mode="OBJECT")

    image = bpy.data.images.new(f"{name}_color", texture_size, texture_size)
    mat = bpy.data.materials.new(f"{name}_mat")
    mat.use_nodes = True
    tex = mat.node_tree.nodes.new("ShaderNodeTexImage")
    tex.image = image
    bsdf = next(n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    mat.node_tree.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 0.7
    low.data.materials.append(mat)
    mat.node_tree.nodes.active = tex

    scene = bpy.context.scene
    engine = scene.render.engine
    try:
        scene.render.engine = "CYCLES"
    except TypeError:
        pass
    scene.cycles.samples = 1
    bake = scene.render.bake
    bake.use_selected_to_active = True
    bake.cage_extrusion = voxel * 3
    bake.max_ray_distance = voxel * 8
    bake.use_pass_direct = False
    bake.use_pass_indirect = False
    bake.margin = 4
    bpy.ops.object.select_all(action="DESELECT")
    source.hide_set(False)
    source.select_set(True)
    low.select_set(True)
    bpy.context.view_layer.objects.active = low
    bpy.ops.object.bake(type="DIFFUSE")
    scene.render.engine = engine
    path = os.path.join(REPO, "assets", "blender", name, f"{name}_color.png")
    image.filepath_raw = path
    image.file_format = "PNG"
    image.save()
    image.pack()
    source.hide_set(True)
    print("remesh_bake:", sum(len(p.vertices) - 2 for p in low.data.polygons), "triangles, baked", path)
    return low


def _fill_triangle(grid, a, b, c):
    """Sets the texels of `grid` (rows from v = 0) whose centres fall inside the UV triangle a, b, c."""
    import numpy as np

    height, width = grid.shape
    xs = [p[0] * width for p in (a, b, c)]
    ys = [p[1] * height for p in (a, b, c)]
    x0, x1 = max(0, int(min(xs))), min(width - 1, int(max(xs)) + 1)
    y0, y1 = max(0, int(min(ys))), min(height - 1, int(max(ys)) + 1)
    if x1 < x0 or y1 < y0:
        return
    px, py = np.meshgrid(np.arange(x0, x1 + 1) + 0.5, np.arange(y0, y1 + 1) + 0.5)
    (ax, bx, cx), (ay, by, cy) = xs, ys
    area = (bx - ax) * (cy - ay) - (cx - ax) * (by - ay)
    if abs(area) < 1e-9:
        return
    w0 = ((bx - px) * (cy - py) - (cx - px) * (by - py)) / area
    w1 = ((cx - px) * (ay - py) - (ax - px) * (cy - py)) / area
    inside = (w0 >= -1e-6) & (w1 >= -1e-6) & (1 - w0 - w1 >= -1e-6)
    grid[y0:y1 + 1, x0:x1 + 1] |= inside


def glow_mask(mesh, name, rules, grow=1, region=None):
    """Writes assets/blender/<name>/<name>_glow.png: an emissive mask for the game (white where the model glows, black
    elsewhere) the same size as `mesh`'s colour map, from the map's own colours. A texel glows when it matches any rule,
    a dict {"hue": (lo, hi) degrees (lo > hi wraps through red), "sat": (lo, hi), "val": (lo, hi)} on 0-1 HSV, and (with
    `region`, a function of a face's world-space centre) only on faces in that part of the body, for a colour that also
    appears where it mustn't glow (the Mossling's tusks are as cream as its mushrooms). The mask is then grown by `grow`
    texels so the glow reaches the painted edge. Uploaded and set as the SurfaceAppearance's EmissiveMaskContent in
    Studio (a plugin-only property). Returns the path."""
    import numpy as np

    image = next(n.image for mat in mesh.data.materials if mat and mat.use_nodes
                 for n in mat.node_tree.nodes if n.type == "TEX_IMAGE" and n.image)
    width, height = image.size
    rgb = np.array(image.pixels[:], dtype=np.float32).reshape(height, width, 4)[:, :, :3]
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    top, low = rgb.max(axis=2), rgb.min(axis=2)
    spread = top - low
    sat = np.where(top > 0, spread / np.maximum(top, 1e-6), 0)
    hue = np.zeros_like(top)
    coloured = spread > 1e-6
    red = coloured & (top == r)
    green = coloured & ~red & (top == g)
    blue = coloured & ~red & ~green
    hue[red] = ((g - b)[red] / spread[red]) % 6
    hue[green] = (b - r)[green] / spread[green] + 2
    hue[blue] = (r - g)[blue] / spread[blue] + 4
    hue *= 60
    mask = np.zeros_like(top, dtype=bool)
    for rule in rules:
        lo, hi = rule["hue"]
        in_hue = (hue >= lo) & (hue <= hi) if lo <= hi else (hue >= lo) | (hue <= hi)
        mask |= (in_hue & (sat >= rule["sat"][0]) & (sat <= rule["sat"][1])
                 & (top >= rule["val"][0]) & (top <= rule["val"][1]))
    if region is not None:
        allowed = np.zeros_like(mask)
        uv = mesh.data.uv_layers.active.data
        for poly in mesh.data.polygons:
            if not region(mesh.matrix_world @ poly.center):
                continue
            corners = [uv[i].uv for i in poly.loop_indices]
            for k in range(1, len(corners) - 1):
                _fill_triangle(allowed, corners[0], corners[k], corners[k + 1])
        mask &= allowed
    for _ in range(grow):
        grown = mask.copy()
        grown[1:, :] |= mask[:-1, :]
        grown[:-1, :] |= mask[1:, :]
        grown[:, 1:] |= mask[:, :-1]
        grown[:, :-1] |= mask[:, 1:]
        mask = grown
    out = np.ones((height, width, 4), dtype=np.float32)
    out[..., :3] = mask[..., None]
    result = bpy.data.images.new(name + "_glow", width, height, alpha=False)
    result.pixels[:] = out.ravel()
    path = os.path.join(REPO, "assets", "blender", name, f"{name}_glow.png")
    result.filepath_raw = path
    result.file_format = "PNG"
    result.save()
    bpy.data.images.remove(result)
    print("glow mask:", int(mask.sum()), "of", width * height, "texels ->", path)
    return path


def _fill_weighted(grid, corners, weights):
    """Raises the texels of `grid` (rows from v = 0) inside the UV triangle `corners` to the triangle's weights,
    interpolated across it (never lowers one)."""
    import numpy as np

    height, width = grid.shape
    xs = [p[0] * width for p in corners]
    ys = [p[1] * height for p in corners]
    x0, x1 = max(0, int(min(xs))), min(width - 1, int(max(xs)) + 1)
    y0, y1 = max(0, int(min(ys))), min(height - 1, int(max(ys)) + 1)
    if x1 < x0 or y1 < y0:
        return
    px, py = np.meshgrid(np.arange(x0, x1 + 1) + 0.5, np.arange(y0, y1 + 1) + 0.5)
    (ax, bx, cx), (ay, by, cy) = xs, ys
    area = (bx - ax) * (cy - ay) - (cx - ax) * (by - ay)
    if abs(area) < 1e-9:
        return
    w0 = ((bx - px) * (cy - py) - (cx - px) * (by - py)) / area
    w1 = ((cx - px) * (ay - py) - (ax - px) * (cy - py)) / area
    w2 = 1 - w0 - w1
    inside = (w0 >= -1e-6) & (w1 >= -1e-6) & (w2 >= -1e-6)
    value = np.where(inside, w0 * weights[0] + w1 * weights[1] + w2 * weights[2], 0)
    block = grid[y0:y1 + 1, x0:x1 + 1]
    np.maximum(block, value, out=block)


def paint_region(mesh, name, color, weight_of, grow=3):
    """Blends `color` (RGB 0..1) into `mesh`'s colour map by weight_of(world position, world normal) at each vertex
    (0..1, soft at the edges), interpolated across the faces, so a marking (a patch on a dog's back) follows the
    surface whatever the UV layout. The mask then grows `grow` texels into texels it hasn't touched, to cover the bake's
    seams. Saves the map over assets/blender/<name>/<name>_color.png. Run after remesh_bake or optimize (the final UVs)."""
    import numpy as np

    image = next(n.image for mat in mesh.data.materials if mat and mat.use_nodes
                 for n in mat.node_tree.nodes if n.type == "TEX_IMAGE" and n.image)
    width, height = image.size
    px = np.array(image.pixels[:], dtype=np.float32).reshape(height, width, 4)
    mask = np.zeros((height, width), dtype=np.float32)
    world = mesh.matrix_world
    turn = world.to_3x3().inverted().transposed()
    weights = [weight_of(world @ v.co, (turn @ v.normal).normalized()) for v in mesh.data.vertices]
    loops = mesh.data.loops
    uv = mesh.data.uv_layers.active.data
    for poly in mesh.data.polygons:
        ws = [weights[loops[i].vertex_index] for i in poly.loop_indices]
        if max(ws) <= 0:
            continue
        corners = [uv[i].uv for i in poly.loop_indices]
        for k in range(1, len(corners) - 1):
            _fill_weighted(mask, (corners[0], corners[k], corners[k + 1]), (ws[0], ws[k], ws[k + 1]))
    for _ in range(grow):
        grown = mask.copy()
        for shifted in (np.roll(mask, 1, 0), np.roll(mask, -1, 0), np.roll(mask, 1, 1), np.roll(mask, -1, 1)):
            np.maximum(grown, np.where(mask == 0, shifted, 0), out=grown)
        mask = grown
    share = mask[..., None]
    px[..., :3] = px[..., :3] * (1 - share) + np.array(color, dtype=np.float32) * share
    image.pixels[:] = px.ravel()
    image.update()
    path = os.path.join(REPO, "assets", "blender", name, f"{name}_color.png")
    image.filepath_raw = path
    image.file_format = "PNG"
    image.save()
    image.pack()
    print("paint_region:", int((mask > 0.5).sum()), "texels painted ->", path)
    return path


def paint_patch(mesh, color, cells=64):
    """Paints a small patch of `color` (RGB 0..1) into a corner of the colour map no UV uses and returns its UV, so
    pieces added by hand (bolt()) take that colour without a second material. Run after optimize()."""
    import numpy as np

    image = next(n.image for n in mesh.data.materials[0].node_tree.nodes if n.type == "TEX_IMAGE")
    used = np.zeros((cells, cells), bool)
    uvs = mesh.data.uv_layers.active.data
    # Every cell a face's UV triangle box touches is taken (its corners alone miss the cells inside big triangles)
    for face in mesh.data.polygons:
        corners = [uvs[i].uv for i in face.loop_indices]
        lo_u, hi_u = (min(max(0, int(f(c.x for c in corners) * cells)), cells - 1) for f in (min, max))
        lo_v, hi_v = (min(max(0, int(f(c.y for c in corners) * cells)), cells - 1) for f in (min, max))
        used[lo_v:hi_v + 1, lo_u:hi_u + 1] = True
    # Patches painted earlier that no face uses yet (two colours painted before adding the parts) stay taken too
    painted = list(mesh.get("painted_patches", []))
    for i in range(0, len(painted), 2):
        used[painted[i + 1], painted[i]] = True
    spots = [(cx, cy) for cy in range(1, cells - 1) for cx in range(1, cells - 1) if not used[cy, cx]]
    # A cell with free neighbours keeps the texture's blur off it; a tightly packed map (Meshy fur) may have none
    free = next((spot for spot in spots if not used[spot[1] - 1:spot[1] + 2, spot[0] - 1:spot[0] + 2].any()), None) \
        or spots[0]
    w, h = image.size
    cell = w // cells
    px = np.array(image.pixels[:]).reshape(h, w, 4)
    cx, cy = free
    px[cy * cell:(cy + 1) * cell, cx * cell:(cx + 1) * cell, :3] = color
    image.pixels[:] = px.ravel()
    image.update()
    image.pack()
    mesh["painted_patches"] = painted + [cx, cy]
    return ((cx + 0.5) / cells, (cy + 0.5) / cells)


BOLT_SHAPE = [(0.05, 1.0), (0.45, 1.0), (0.22, 0.58), (0.5, 0.58), (-0.1, -0.25), (0.12, 0.38), (-0.12, 0.38)]


def bolt(mesh, base, up, side, size, thick, uv):
    """Adds a flat zigzag lightning bolt with real thickness to the mesh: from `base` it rises along `up`, its zigzag
    spread along `side`, its sharp tip furthest out. All its faces take the colour at `uv` (paint_patch)."""
    import bmesh

    up, side = Vector(up).normalized(), Vector(side).normalized()
    normal = up.cross(side).normalized()
    base = Vector(base)
    points = [base + side * ((a - 0.17) * size) + up * ((1.0 - b) * size) for a, b in BOLT_SHAPE]
    bm = bmesh.new()
    bm.from_mesh(mesh.data)
    front = [bm.verts.new(p + normal * thick / 2) for p in points]
    back = [bm.verts.new(p - normal * thick / 2) for p in points]
    faces = [bm.faces.new(front), bm.faces.new(list(reversed(back)))]
    for i in range(len(points)):
        j = (i + 1) % len(points)
        faces.append(bm.faces.new((front[j], front[i], back[i], back[j])))
    bmesh.ops.recalc_face_normals(bm, faces=faces)
    layer = bm.loops.layers.uv.active
    for face in bmesh.ops.triangulate(bm, faces=faces)["faces"]:
        face.smooth = False
        for loop in face.loops:
            loop[layer].uv = uv
    bm.to_mesh(mesh.data)
    bm.free()


def crystal(mesh, base, direction, length, radius, uv_side, uv_tip, sides=6, spin=0.0):
    """Adds a pointed ice crystal to the mesh: a `sides`-sided prism from `base` (sunk a little into the surface) along
    `direction`, `length` long, ending in a point. Its sides take the colour at uv_side, its pointed tip uv_tip (a
    lighter shade, so the facets read). `spin` turns the prism round its axis (radians)."""
    import bmesh
    import math

    axis = Vector(direction).normalized()
    side = axis.cross(Vector((0, 0, 1)) if abs(axis.z) < 0.9 else Vector((1, 0, 0))).normalized()
    other = axis.cross(side)
    base = Vector(base) - axis * radius
    def ring(at, r):
        return [at + (side * math.cos(spin + a) + other * math.sin(spin + a)) * r
                for a in (2 * math.pi * i / sides for i in range(sides))]
    bm = bmesh.new()
    bm.from_mesh(mesh.data)
    bottom = [bm.verts.new(p) for p in ring(base, radius)]
    top = [bm.verts.new(p) for p in ring(base + axis * (length * 0.72 + radius), radius * 0.9)]
    tip = bm.verts.new(base + axis * (length + radius))
    sides_faces, tip_faces = [bm.faces.new(list(reversed(bottom)))], []
    for i in range(sides):
        j = (i + 1) % sides
        sides_faces.append(bm.faces.new((bottom[i], bottom[j], top[j], top[i])))
        tip_faces.append(bm.faces.new((top[i], top[j], tip)))
    bmesh.ops.recalc_face_normals(bm, faces=sides_faces + tip_faces)
    layer = bm.loops.layers.uv.active
    for faces, uv in ((sides_faces, uv_side), (tip_faces, uv_tip)):
        for face in bmesh.ops.triangulate(bm, faces=faces)["faces"]:
            face.smooth = False
            for loop in face.loops:
                loop[layer].uv = uv
    bm.to_mesh(mesh.data)
    bm.free()


def droplet(mesh, base, radius, height, uv_body, uv_tip, segments=12, rings=10):
    """Adds a water droplet to the mesh: a round bottom resting on `base` (sunk a little into the surface) rising to a
    point `height` above it, `radius` at its widest (the teardrop curve x = sin t * sin(t / 2)^1.5, z = cos t). Its
    lower part takes the colour at uv_body, its upper third uv_tip (a paler shine)."""
    import bmesh
    import math

    base = Vector(base)
    bm = bmesh.new()
    bm.from_mesh(mesh.data)
    profile = []
    for i in range(1, rings):
        t = math.pi * i / rings
        profile.append((math.sin(t) * math.sin(t / 2) ** 1.5, (math.cos(t) + 1) / 2))
    widest = max(r for r, _ in profile)
    top = bm.verts.new(base + Vector((0, 0, height * 0.95)))
    bottom = bm.verts.new(base - Vector((0, 0, height * 0.05)))
    ring_verts = []
    for r, h in profile:
        ring_verts.append([bm.verts.new(base + Vector((math.cos(a) * r / widest * radius, math.sin(a) * r / widest * radius,
                                                        h * height - height * 0.05)))
                           for a in (2 * math.pi * k / segments for k in range(segments))])
    faces = []
    for k in range(segments):
        j = (k + 1) % segments
        faces.append(bm.faces.new((top, ring_verts[0][k], ring_verts[0][j])))
        for ring in range(len(ring_verts) - 1):
            a, b = ring_verts[ring], ring_verts[ring + 1]
            faces.append(bm.faces.new((a[k], b[k], b[j], a[j])))
        faces.append(bm.faces.new((ring_verts[-1][k], bottom, ring_verts[-1][j])))
    bmesh.ops.recalc_face_normals(bm, faces=faces)
    layer = bm.loops.layers.uv.active
    for face in bmesh.ops.triangulate(bm, faces=faces)["faces"]:
        face.smooth = True
        upper = face.calc_center_median().z > base.z + height * 0.6
        for loop in face.loops:
            loop[layer].uv = uv_tip if upper else uv_body
    bm.to_mesh(mesh.data)
    bm.free()


def orb(mesh, centre, radius, uv, segments=16, rings=10):
    """Adds a smooth ball of `radius` at `centre` to the mesh, all its faces the colour at `uv` (paint_patch): a glowing
    orb on a tail tip, say."""
    import bmesh

    bm = bmesh.new()
    bm.from_mesh(mesh.data)
    made = bmesh.ops.create_uvsphere(bm, u_segments=segments, v_segments=rings, radius=radius,
                                     matrix=Matrix.Translation(Vector(centre)))
    faces = list({f for v in made["verts"] for f in v.link_faces})
    layer = bm.loops.layers.uv.active
    for face in bmesh.ops.triangulate(bm, faces=faces)["faces"]:
        face.smooth = True
        for loop in face.loops:
            loop[layer].uv = uv
    bm.to_mesh(mesh.data)
    bm.free()


def tail(mesh, points, widest, uv_body, uv_tip, tip_from=0.72, segments=12, rings=24):
    """Adds a smooth bushy tail to the mesh along the cubic Bezier `points` (root, two handles, tip; the root sunk into
    the body): narrow at the root, `widest` across past its middle, closing to a point. Rings past `tip_from` of its
    length take the colour at uv_tip (a white tip), the rest uv_body. Each tail is its own shell, so tails never stick
    together the way generated ones do."""
    import bmesh
    import math

    p0, p1, p2, p3 = (Vector(p) for p in points)
    def at(t):
        s = 1 - t
        return p0 * s ** 3 + p1 * 3 * s * s * t + p2 * 3 * s * t * t + p3 * t ** 3
    def radius(t):
        return widest * math.sin(math.pi * (0.12 + 0.88 * t ** 1.25)) ** 0.7
    centres = [at(i / rings) for i in range(rings + 1)]
    # Parallel transport keeps the rings from twisting round the curve
    axis = (centres[1] - centres[0]).normalized()
    side = axis.cross(Vector((0, 0, 1)) if abs(axis.z) < 0.9 else Vector((1, 0, 0))).normalized()
    bm = bmesh.new()
    bm.from_mesh(mesh.data)
    ring_verts = []
    for i in range(rings):
        nxt = (centres[i + 1] - centres[i]).normalized()
        side = (side - nxt * side.dot(nxt)).normalized()
        other = nxt.cross(side)
        r = radius(i / rings)
        ring_verts.append([bm.verts.new(centres[i] + (side * math.cos(a) + other * math.sin(a)) * r)
                           for a in (2 * math.pi * k / segments for k in range(segments))])
    tip = bm.verts.new(centres[-1])
    faces = [bm.faces.new(list(reversed(ring_verts[0])))]
    for k in range(segments):
        j = (k + 1) % segments
        for ring in range(rings - 1):
            a, b = ring_verts[ring], ring_verts[ring + 1]
            faces.append(bm.faces.new((a[k], a[j], b[j], b[k])))
        faces.append(bm.faces.new((ring_verts[-1][k], ring_verts[-1][j], tip)))
    bmesh.ops.recalc_face_normals(bm, faces=faces)
    layer = bm.loops.layers.uv.active
    for face in bmesh.ops.triangulate(bm, faces=faces)["faces"]:
        face.smooth = True
        # How far along the tail the face sits, by the nearest ring centre
        centre = face.calc_center_median()
        nearest = min(range(rings + 1), key=lambda i: (centres[i] - centre).length)
        for loop in face.loops:
            loop[layer].uv = uv_tip if nearest / rings > tip_from else uv_body
    bm.to_mesh(mesh.data)
    bm.free()


def build_rig(name, bones):
    """A fresh armature from (bone, parent, head, tail) tuples; Root doesn't deform."""
    old = bpy.data.objects.get(name)
    if old:
        bpy.data.objects.remove(old, do_unlink=True)
    data = bpy.data.armatures.new(name)
    rig = bpy.data.objects.new(name, data)
    bpy.context.scene.collection.objects.link(rig)
    bpy.ops.object.select_all(action="DESELECT")
    bpy.context.view_layer.objects.active = rig
    bpy.ops.object.mode_set(mode="EDIT")
    for bone_name, parent, head, tail in bones:
        bone = data.edit_bones.new(bone_name)
        bone.head, bone.tail = head, tail
        if parent:
            bone.parent = data.edit_bones[parent]
    if "Root" in data.edit_bones:
        data.edit_bones["Root"].use_deform = False
    bpy.ops.object.mode_set(mode="OBJECT")
    data.display_type = "STICK"
    rig.show_in_front = True
    return rig


def _segment_distance(p, a, b):
    ab = b - a
    t = max(0.0, min(1.0, (p - a).dot(ab) / max(ab.length_squared, 1e-9)))
    return (p - (a + ab * t)).length


def _flat_distance(p, a, b):
    """Distance from p to the segment a-b ignoring height: how far a vertex is from a leg's column."""
    return _segment_distance(Vector((p.x, p.y, 0)), Vector((a.x, a.y, 0)), Vector((b.x, b.y, 0)))


def _ramp(value, zero, one):
    """0 at `zero`, 1 at `one`, smooth between."""
    t = max(0.0, min(1.0, (value - zero) / (one - zero)))
    return t * t * (3 - 2 * t)


def _leg_of(p, params, deform):
    """The leg prefix nearest this vertex on its side ("0_Left_", "1_Right_", ...), or None without legs there. Up to four
    pairs, front to back (the Wild's six-legged crab and beetle)."""
    side = "Left_" if p.x > params.mid_x else "Right_"
    best, best_distance = None, None
    for pair in ("0_", "1_", "2_", "3_"):
        upper = deform.get(pair + side + "Limb_0")
        if upper:
            d = _flat_distance(p, *upper)
            if best_distance is None or d < best_distance:
                best, best_distance = pair + side, d
    return best


def _body_allowed(name, p, params):
    if name.startswith("Tail_"):
        return p.y > params.tail_from
    if name in ("Neck", "Head_0") or name.startswith("Jaw_") or name.startswith("Ear_"):
        return p.y < params.head_from
    return True


def skin(mesh, rig, bones, params):
    mesh.parent = None
    mesh.vertex_groups.clear()
    for mod in [m for m in mesh.modifiers if m.type == "ARMATURE"]:
        mesh.modifiers.remove(mod)
    deform = {n: (Vector(h), Vector(t)) for n, parent, h, t in bones if n != "Root"}
    mw = mesh.matrix_world
    points = [mw @ v.co for v in mesh.data.vertices]
    weights = []
    for p in points:
        leg = _leg_of(p, params, deform)
        share = 0.0
        if leg:
            # How close it is to this leg: the nearest of its bones in 3D, so feet and hocks that stick out from the
            # leg's top still count fully as leg (measuring from the top bone alone left paws mostly body, so they
            # stretched instead of stepping)
            near_leg = min(_segment_distance(p, *deform[leg + f"Limb_{i}"]) for i in range(3) if leg + f"Limb_{i}" in deform)
            share = _ramp(p.z, params.leg_top, params.leg_full) * _ramp(near_leg, params.leg_radius, params.leg_core)
            if params.belly_mid > 0:
                share *= _ramp(abs(p.x - params.mid_x), params.belly_mid, params.belly_mid + params.belly_fade)
        # Arms (two-legged creatures) work like legs without the height rule: only vertices close to that side's
        # arm bones follow them, so hands resting on the belly don't drag it along
        arm = "Arm_" + ("Left_" if p.x > params.mid_x else "Right_")
        arm_bones = [deform[arm + str(i)] for i in range(3) if arm + str(i) in deform]
        arm_share = 0.0
        if arm_bones:
            near_arm = min(_segment_distance(p, *bone) for bone in arm_bones)
            if leg and share > 0 and near_arm < near_leg:
                share = 0.0  # knuckles hanging by the knees belong to the arm, or they'd stretch with the stride
            arm_share = _ramp(near_arm, params.arm_radius, params.arm_core) * (1 - share)
        body = 1 - share - arm_share
        scored = {}
        for name, (a, b) in deform.items():
            if "_Limb_" in name:
                if not leg or not name.startswith(leg) or share <= 0:
                    continue
                part = share
            elif name.startswith("Arm_"):
                if not name.startswith(arm) or arm_share <= 0:
                    continue
                part = arm_share
            else:
                if not _body_allowed(name, p, params) or body <= 0:
                    continue
                part = body
            scored[name] = part / (_segment_distance(p, a, b) ** params.falloff + 1e-6)
        total = sum(scored.values())
        weights.append({n: w / total for n, w in scored.items()})
    tree = kdtree.KDTree(len(points))
    for i, p in enumerate(points):
        tree.insert(p, i)
    tree.balance()
    near = [[j for _, j, _ in tree.find_range(p, params.smooth_radius) if j != i] for i, p in enumerate(points)]
    for _ in range(params.smooth_passes):
        smoothed = []
        for i, own in enumerate(weights):
            if not near[i]:
                smoothed.append(own)
                continue
            mix = {n: w * (1 - params.smooth) for n, w in own.items()}
            share = params.smooth / len(near[i])
            for j in near[i]:
                for n, w in weights[j].items():
                    mix[n] = mix.get(n, 0) + w * share
            smoothed.append(mix)
        weights = smoothed
    groups = {n: mesh.vertex_groups.new(name=n) for n in deform}
    for i, mix in enumerate(weights):
        top = sorted(mix.items(), key=lambda kv: -kv[1])[:MAX_BONES]
        total = sum(w for _, w in top)
        for n, w in top:
            groups[n].add([i], w / total, "REPLACE")
    mesh.parent = rig
    mod = mesh.modifiers.new("Armature", "ARMATURE")
    mod.object = rig
    print("vertices:", len(mesh.data.vertices), "without a bone:", sum(1 for v in mesh.data.vertices if not v.groups))
    # A bone that moves nothing means it sits away from its part (Petalpaw's arm bones were behind the arms, which
    # then never moved in game): move it into the mesh
    moved = {n: 0 for n in deform}
    names = {g.index: g.name for g in mesh.vertex_groups}
    for v in mesh.data.vertices:
        for g in v.groups:
            if g.weight > 0.3:
                moved[names[g.group]] += 1
    idle = [n for n, count in moved.items() if count == 0]
    if idle:
        print("WARNING: these bones move no vertices, move them into the mesh:", ", ".join(sorted(idle)))


def reweight(mesh, bone, share_of):
    """Hands part of the mesh to one bone after skin(): share_of(point) gives each vertex's share (0..1) for `bone`;
    the vertex's other weights are scaled down to make room (a jaw cut out of a head, say). Keeps four bones a vertex."""
    group = mesh.vertex_groups.get(bone) or mesh.vertex_groups.new(name=bone)
    names = {g.index: g for g in mesh.vertex_groups}
    for v in mesh.data.vertices:
        share = share_of(mesh.matrix_world @ v.co)
        if share <= 0:
            continue
        others = [(names[g.group], g.weight) for g in v.groups if g.group != group.index]
        for g, w in others:
            g.add([v.index], w * (1 - share), "REPLACE")
        group.add([v.index], share, "REPLACE")
        kept = sorted(((names[g.group], g.weight) for g in v.groups), key=lambda gw: -gw[1])
        for g, _ in kept[MAX_BONES:]:
            g.remove([v.index])


def vertex_colours(mesh):
    """Each vertex's colour from the mesh's colour map ({index: (r, g, b)}, 0..1; a loose vertex has none)"""
    import numpy as np

    image = next(n.image for mat in mesh.data.materials if mat and mat.use_nodes
                 for n in mat.node_tree.nodes if n.type == "TEX_IMAGE" and n.image)
    width, height = image.size
    px = np.array(image.pixels[:], dtype=np.float32).reshape(height, width, 4)
    uv = mesh.data.uv_layers.active.data
    colours = {}
    for loop in mesh.data.loops:
        u, v = uv[loop.index].uv
        colours[loop.vertex_index] = tuple(px[min(height - 1, int(v * height)), min(width - 1, int(u * width)), :3])
    return colours


def is_gold(rgb):
    """A golden colour (0..1 rgb): armour, horns, halos"""
    r, g, b = rgb
    top, low = max(rgb), min(rgb)
    sat = (top - low) / top if top > 0 else 0
    return sat > 0.3 and r > 0.45 and g > 0.3 and g / max(r, 1e-6) > 0.55 and b < g * 0.7


def mark_pieces(mesh, group_name, keep):
    """Marks whole pieces of a raw generated mesh (its separate islands: a halo, horns) in a vertex group before
    optimize() welds them to the body; the reduction keeps vertex groups, so marked() finds them afterwards (skin()
    clears the groups: read them before it). keep(centre, colours) says which pieces: their middle (a Vector) and their
    vertices' colours (rgb tuples). Returns how many vertices were marked."""
    import bmesh

    colours = vertex_colours(mesh)
    bm = bmesh.new()
    bm.from_mesh(mesh.data)
    seen, picked = set(), []
    for v in bm.verts:
        if v.index in seen:
            continue
        stack, members = [v], []
        seen.add(v.index)
        while stack:
            cur = stack.pop()
            members.append(cur.index)
            for e in cur.link_edges:
                w = e.other_vert(cur)
                if w.index not in seen:
                    seen.add(w.index)
                    stack.append(w)
        centre = sum((mesh.data.vertices[i].co for i in members), Vector()) / len(members)
        if keep(centre, [colours.get(i, (0, 0, 0)) for i in members]):
            picked.extend(members)
    bm.free()
    group = mesh.vertex_groups.get(group_name) or mesh.vertex_groups.new(name=group_name)
    group.add(picked, 1.0, "REPLACE")
    return len(picked)


def marked(mesh, group_name):
    """The vertices mark_pieces() marked (after optimize())"""
    group = mesh.vertex_groups.get(group_name)
    if not group:
        return set()
    return {v.index for v in mesh.data.vertices for g in v.groups if g.group == group.index and g.weight > 0.5}


def confine(mesh, bones, share_of, fallback, whole=None, only=None):
    """Hands a part of the mesh to its own bones after skin(), so it moves as one piece (a chibi's big head: skin()'s
    nearest-bone weights left the back of Pish's skull on the spine, which stretched it whenever the head moved).
    share_of(point) gives each vertex's share (0..1, blending at the part's edge): that share of its weight goes to
    `bones` in the proportions it already had among them (all to `fallback` if it had none), the rest stays as it was.
    whole(vertex index) can claim a vertex outright (an ear hanging below the head's edge); only(vertex index) limits
    it to some vertices (the Kirin's tail by its colour, not the white rump round its root). Four bones at most."""
    names = {g.index: g.name for g in mesh.vertex_groups}
    groups = {g.name: g for g in mesh.vertex_groups}
    for bone in list(bones) + [fallback]:
        if bone not in groups:
            groups[bone] = mesh.vertex_groups.new(name=bone)
    for v in mesh.data.vertices:
        if only and not only(v.index):
            continue
        old = {names[g.group]: g.weight for g in v.groups if g.weight > 0}
        share = share_of(mesh.matrix_world @ v.co)
        if whole and whole(v.index):
            share = 1.0
        if share <= 0:
            continue
        own = {n: w for n, w in old.items() if n in bones}
        total = sum(own.values())
        if total < 1e-4:
            own, total = {fallback: 1.0}, 1.0
        new = {n: (1 - share) * w for n, w in old.items()}
        for n, w in own.items():
            new[n] = new.get(n, 0) + share * w / total
        kept = sorted(new.items(), key=lambda nw: -nw[1])[:MAX_BONES]
        scale = sum(w for _, w in kept) or 1
        for g in list(v.groups):
            mesh.vertex_groups[g.group].remove([v.index])
        for n, w in kept:
            if w > 0:
                groups[n].add([v.index], w / scale, "REPLACE")


def restrict(mesh, bones, factor):
    """Scales `bones`' weights on each vertex by factor(vertex index) (0..1; soft at a part's edge), sharing what they
    lose among the vertex's other bones (skin()'s smoothing spreads a tail's weight onto the rump, which then stretched
    whenever the tail moved). A vertex with no other bone keeps them."""
    names = {g.index: g.name for g in mesh.vertex_groups}
    for v in mesh.data.vertices:
        keep = factor(v.index)
        if keep >= 1:
            continue
        old = [(names[g.group], g.group, g.weight) for g in v.groups if g.weight > 0]
        rest = [(n, i, w) for n, i, w in old if n not in bones]
        kept = sum(w for _, _, w in rest)
        taken = sum(w for n, _, w in old if n in bones) * (1 - keep)
        if taken <= 0 or kept <= 0:
            continue
        for n, i, w in old:
            if n in bones:
                if keep <= 0:
                    mesh.vertex_groups[i].remove([v.index])
                else:
                    mesh.vertex_groups[i].add([v.index], w * keep, "REPLACE")
            else:
                mesh.vertex_groups[i].add([v.index], w * (kept + taken) / kept, "REPLACE")


def smooth_field(mesh, field, passes, where=None):
    """Blurs a per-vertex value (a list) along the mesh's edges `passes` times (each vertex half its own value, half
    its neighbours' average), on the vertices where(index) allows (all by default), so a part's edge fades softly."""
    neighbours = [[] for _ in mesh.data.vertices]
    for edge in mesh.data.edges:
        a, b = edge.vertices
        neighbours[a].append(b)
        neighbours[b].append(a)
    field = list(field)
    for _ in range(passes):
        blurred = list(field)
        for i, near in enumerate(neighbours):
            if near and (where is None or where(i)):
                blurred[i] = 0.5 * field[i] + 0.5 * sum(field[n] for n in near) / len(near)
        field = blurred
    return field


def set_bone(mesh, bone, field):
    """Gives `bone` exactly field[i] (0..1) of each vertex, scaling the vertex's other weights to the rest (a vertex
    with no other bone gets `bone` alone); where field is 0 the bone comes off. Four bones at most."""
    names = {g.index: g.name for g in mesh.vertex_groups}
    group = mesh.vertex_groups.get(bone) or mesh.vertex_groups.new(name=bone)
    for v in mesh.data.vertices:
        share = max(0.0, min(1.0, field[v.index]))
        others = [(names[g.group], g.group, g.weight) for g in v.groups if g.group != group.index and g.weight > 0]
        total = sum(w for _, _, w in others)
        if share <= 0:
            if any(g.group == group.index for g in v.groups) and total > 0:
                group.remove([v.index])
                for _, i, w in others:
                    mesh.vertex_groups[i].add([v.index], w / total, "REPLACE")
            continue
        if total <= 0:
            group.add([v.index], 1.0, "REPLACE")
            continue
        for _, i, w in others:
            mesh.vertex_groups[i].add([v.index], w / total * (1 - share), "REPLACE")
        group.add([v.index], share, "REPLACE")
        kept = sorted(((names[g.group], g.group, g.weight) for g in v.groups), key=lambda x: -x[2])
        for _, i, _ in kept[MAX_BONES:]:
            mesh.vertex_groups[i].remove([v.index])


def jaw_share(hinge_y, tip_y, top_hinge, top_tip, bottom, half_width, mid_x=0.0, blend=0.012, top_blend=None):
    """A lower jaw's share for reweight(): the vertices from the mouth's corner (hinge_y) forward to its tip (tip_y,
    further toward -y), under the mouth line (top_hinge at the corner sloping to top_tip at the tip), above the throat
    (bottom) and within half_width of mid_x, each edge blending over `blend` into the head (the mouth line over
    `top_blend`, small where mouth_cut() split it). For a closed or only slightly open mouth (Eclipse Fox, Thunderhorn,
    Stormking's lower mouth plate); Infernox keeps its own sloped cut."""
    lip = blend if top_blend is None else top_blend

    def share(p):
        if p.y > hinge_y + blend or p.y < tip_y - blend or abs(p.x - mid_x) > half_width + blend:
            return 0.0
        t = min(1.0, max(0.0, (p.y - hinge_y) / (tip_y - hinge_y)))
        top = top_hinge + (top_tip - top_hinge) * t
        if p.z > top + lip or p.z < bottom - blend:
            return 0.0
        along = min(1.0, (hinge_y + blend - p.y) / blend)
        tip = min(1.0, (p.y - (tip_y - blend)) / blend)
        below = min(1.0, (top + lip - p.z) / lip)
        above = min(1.0, (p.z - (bottom - blend)) / blend)
        side = min(1.0, (half_width + blend - abs(p.x - mid_x)) / blend)
        return max(0.0, along * tip * below * above * side)

    return share


def mouth_cut(mesh, share, hinge_y, tip_y, top_hinge, top_tip, cavity_color):
    """Opens a closed mouth (owner 2026-11-06: a jaw on a closed mouth only stretched the snout): splits the surface along
    the mouth line from just in front of its corner (hinge_y) to its tip (tip_y), where faces under the line (share of
    their centre over a half) meet faces above it, and joins each split edge to its copy with a face in cavity_color: shut,
    those faces have no area; as the jaw drops they open into a dark mouth instead of showing the head's hollow. Marks
    each vertex's side in the "mouth_side" attribute (1 the jaw's side of the cut, 0 the head's, -1 elsewhere) for
    reweight_jaw(). Runs once (mesh["mouth_cut"])."""
    import bmesh

    if mesh.get("mouth_cut"):
        return
    uv_cavity = paint_patch(mesh, cavity_color)
    bm = bmesh.new()
    bm.from_mesh(mesh.data)
    mw = mesh.matrix_world

    def top_at(y):
        t = min(1.0, max(0.0, (y - hinge_y) / (tip_y - hinge_y)))
        return top_hinge + (top_tip - top_hinge) * t

    jaw_face = {f: share(mw @ f.calc_center_median()) > 0.5 for f in bm.faces}
    cut = []
    for e in bm.edges:
        if len(e.link_faces) != 2 or jaw_face[e.link_faces[0]] == jaw_face[e.link_faces[1]]:
            continue
        mid = mw @ ((e.verts[0].co + e.verts[1].co) / 2)
        if tip_y - 0.004 < mid.y < hinge_y - 0.004 and abs(mid.z - top_at(mid.y)) < 0.02:
            cut.append(e)
    bmesh.ops.split_edges(bm, edges=cut)
    side = bm.verts.layers.int.get("mouth_side") or bm.verts.layers.int.new("mouth_side")
    for v in bm.verts:
        faces = [jaw_face.get(f, False) for f in v.link_faces]
        v[side] = 1 if faces and all(faces) else (0 if faces and not any(faces) else -1)
    # Each split edge now lies on its copy: the head's edge (its face above the line) and the jaw's (below). A dark face
    # between them, facing out the way the head's face does, fills the gap as it opens
    def key(e):
        a, b = (tuple(round(c, 6) for c in v.co) for v in e.verts)
        return (a, b) if a < b else (b, a)

    pairs = {}
    for e in bm.edges:
        if len(e.link_faces) == 1:
            pairs.setdefault(key(e), []).append(e)
    uv_layer = bm.loops.layers.uv.active
    bridged = 0
    for edges in pairs.values():
        if len(edges) != 2:
            continue
        head = next((e for e in edges if not jaw_face.get(e.link_faces[0], False)), None)
        jaw = next((e for e in edges if jaw_face.get(e.link_faces[0], False)), None)
        if not head or not jaw:
            continue
        h0, h1 = head.verts
        j0 = min(jaw.verts, key=lambda v: (v.co - h0.co).length)
        j1 = jaw.verts[1] if jaw.verts[0] == j0 else jaw.verts[0]
        corners = []
        for v in (h0, h1, j1, j0):  # at the cut's two ends the copies share a vertex: a triangle there
            if v not in corners:
                corners.append(v)
        if len(corners) < 3:
            continue
        face = bm.faces.new(corners)
        face.normal_update()
        if face.normal.dot(head.link_faces[0].normal) < 0:
            face.normal_flip()
        for loop in face.loops:
            loop[uv_layer].uv = uv_cavity
        bridged += 1
    print("mouth bridged:", bridged)
    bm.to_mesh(mesh.data)
    bm.free()
    mesh.data.update()
    mesh["mouth_cut"] = True
    print("mouth cut:", len(cut), "edges split")


def reweight_jaw(mesh, share):
    """reweight() for a mouth opened by mouth_cut(): the head's side of the cut keeps nothing on Jaw_0, everything else
    takes `share` (the jaw's other edges still blend into the head)."""
    attr = mesh.data.attributes.get("mouth_side")
    sides = [d.value for d in attr.data] if attr else None

    def cut_share(p, index):
        if sides is not None and sides[index] == 0:
            return 0.0
        return share(p)

    group = mesh.vertex_groups.get("Jaw_0") or mesh.vertex_groups.new(name="Jaw_0")
    names = {g.index: g for g in mesh.vertex_groups}
    for v in mesh.data.vertices:
        s = cut_share(mesh.matrix_world @ v.co, v.index)
        if s <= 0:
            continue
        for g in [g for g in v.groups if g.group != group.index]:
            names[g.group].add([v.index], g.weight * (1 - s), "REPLACE")
        group.add([v.index], s, "REPLACE")
        kept = sorted(((names[g.group], g.weight) for g in v.groups), key=lambda gw: -gw[1])
        for g, _ in kept[MAX_BONES:]:
            g.remove([v.index])


def export(name, rig, mesh):
    out = os.path.join(REPO, "assets", "blender", name, name + ".fbx")
    bpy.ops.object.select_all(action="DESELECT")
    rig.select_set(True)
    mesh.select_set(True)
    bpy.context.view_layer.objects.active = rig
    bpy.ops.wm.save_mainfile()
    bpy.ops.export_scene.fbx(
        filepath=out,
        use_selection=True,
        object_types={"ARMATURE", "MESH"},
        add_leaf_bones=False,
        bake_anim=False,
        path_mode="COPY",
        embed_textures=True,
        apply_scale_options="FBX_SCALE_ALL",
    )
    print("exported", out)


def run(name, mesh_name, bones, params=None, target_tris=10000, export_now=True):
    """Optimizes the mesh, builds the skeleton, skins the mesh and (unless EXPORT=0 or export_now is False, for a
    script that still changes the weights) exports assets/blender/<name>/<name>.fbx."""
    params = params or Params()
    mesh = bpy.data.objects[mesh_name]
    mesh.parent = None
    for mod in [m for m in mesh.modifiers if m.type == "ARMATURE"]:
        mesh.modifiers.remove(mod)
    optimize(mesh, name, target_tris)
    rig = build_rig(name + "Rig", bones)
    skin(mesh, rig, bones, params)
    if export_now and os.environ.get("EXPORT", "1") == "1":
        export(name, rig, mesh)
    return rig, mesh
