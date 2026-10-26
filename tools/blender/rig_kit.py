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
from mathutils import Vector, kdtree

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


def paint_patch(mesh, color, cells=64):
    """Paints a small patch of `color` (RGB 0..1) into a corner of the colour map no UV uses and returns its UV, so
    pieces added by hand (bolt()) take that colour without a second material. Run after optimize()."""
    import numpy as np

    image = next(n.image for n in mesh.data.materials[0].node_tree.nodes if n.type == "TEX_IMAGE")
    used = np.zeros((cells, cells), bool)
    for loop in mesh.data.uv_layers.active.data:
        u, v = loop.uv
        used[min(cells - 1, max(0, int(v * cells))), min(cells - 1, max(0, int(u * cells)))] = True
    free = next((cx, cy) for cy in range(1, cells - 1) for cx in range(1, cells - 1)
                if not used[cy - 1:cy + 2, cx - 1:cx + 2].any())
    w, h = image.size
    cell = w // cells
    px = np.array(image.pixels[:]).reshape(h, w, 4)
    cx, cy = free
    px[cy * cell:(cy + 1) * cell, cx * cell:(cx + 1) * cell, :3] = color
    image.pixels[:] = px.ravel()
    image.update()
    image.pack()
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
    """The leg prefix nearest this vertex on its side ("0_Left_", "1_Right_", ...), or None without legs there."""
    side = "Left_" if p.x > params.mid_x else "Right_"
    best, best_distance = None, None
    for pair in ("0_", "1_"):
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


def run(name, mesh_name, bones, params=None, target_tris=10000):
    """Optimizes the mesh, builds the skeleton, skins the mesh and (unless EXPORT=0) exports
    assets/blender/<name>/<name>.fbx."""
    params = params or Params()
    mesh = bpy.data.objects[mesh_name]
    mesh.parent = None
    for mod in [m for m in mesh.modifiers if m.type == "ARMATURE"]:
        mesh.modifiers.remove(mod)
    optimize(mesh, name, target_tris)
    rig = build_rig(name + "Rig", bones)
    skin(mesh, rig, bones, params)
    if os.environ.get("EXPORT", "1") == "1":
        export(name, rig, mesh)
    return rig, mesh
