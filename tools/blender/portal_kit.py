"""Shared kit for the town portal build scripts (build_portal_<world>.py; spec 2026-10-30-town-portals-design).

Shapes on voxel_kit.Builder (one mesh, faces coloured by palette cells): tube (tapered, through points: roots, vines),
crystal (a faceted prism with a pointed tip: ice, obsidian), disc (a flat round: pools, the opening) and marker (a
tiny cube object the game finds by name and hides: where an effect starts). begin() clears the scene; export() links
the objects with one palette material, prints triangles and saves assets/blender/<Name>/<Name>.{blend,fbx} unless
EXPORT=0.

Blender: Z up, 1 unit = 1 stud, origin at the bottom centre, the front (the side players walk up to) faces -Y; it
imports facing -Z, the props' front. Parts the game looks up keep their names (Util/PortalLooks.parts).
"""
import math
import os
import sys

import bpy
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)) if "__file__" in globals() else
                os.path.join(os.environ.get("CARD_SHOP_REPO", r"C:\Users\Ben\Documents\roblox-project\card-shop-tycoon"), "tools", "blender"))
import voxel_kit  # noqa: E402

BONE = "Root"  # the kit weights every vertex to a bone; props have no rig, so one name for all
MAX_TRIANGLES = 4000  # per portal model (DESIGN 10.5: a landmark's exception to the 2k-per-prop rule)


def _ring(centre, side, up, radius, sides):
    return [centre + (side * math.cos(2 * math.pi * k / sides) + up * math.sin(2 * math.pi * k / sides)) * radius
            for k in range(sides)]


def tube(b, points, radii, color, sides=7):
    """A tapered tube through points (one radius per point), capped at both ends. The side vector is carried along
    the path so the tube doesn't twist."""
    pts = [Vector(p) for p in points]
    rings = []
    side = None
    for i, p in enumerate(pts):
        d = (pts[min(i + 1, len(pts) - 1)] - pts[max(i - 1, 0)]).normalized()
        if side is None:
            ref = Vector((0, 0, 1)) if abs(d.z) < 0.9 else Vector((1, 0, 0))
            side = d.cross(ref).normalized()
        else:
            side = (side - d * side.dot(d)).normalized()
        up = d.cross(side).normalized()
        rings.append(b._verts(_ring(p, side, up, radii[i], sides), BONE))
    for r0, r1 in zip(rings, rings[1:]):
        for k in range(sides):
            k2 = (k + 1) % sides
            b._face([r0[k], r0[k2], r1[k2], r1[k]], color)
    b._face(list(reversed(rings[0])), color)
    b._face(rings[-1], color)


def crystal(b, base, direction, radius, length, color, sides=6, tip=0.3, tip_color=None):
    """A faceted prism from base along direction, its last `tip` share a point (tip_color, default color)."""
    base, d = Vector(base), Vector(direction).normalized()
    ref = Vector((0, 0, 1)) if abs(d.z) < 0.9 else Vector((1, 0, 0))
    side = d.cross(ref).normalized()
    up = d.cross(side).normalized()
    body = length * (1 - tip)
    r0 = b._verts(_ring(base, side, up, radius, sides), BONE)
    r1 = b._verts(_ring(base + d * body, side, up, radius, sides), BONE)
    apex = b._verts([base + d * length], BONE)[0]
    b._face(list(reversed(r0)), color)
    for k in range(sides):
        k2 = (k + 1) % sides
        b._face([r0[k], r0[k2], r1[k2], r1[k]], color)
        b._face([r1[k], r1[k2], apex], tip_color or color)


def ribbon(b, a, c, width, color, thickness=0.18):
    """A flat strip from a to c, its broad side facing the front (-Y): lava cracks and streams on a face."""
    a, c = Vector(a), Vector(c)
    along = c - a
    rot = along.to_track_quat("Z", "Y").to_matrix()
    b.box((a + c) / 2, (width, thickness, along.length), color, BONE, rot)


def disc(b, centre, radius, color, normal=(0, 0, 1), sides=12, radius_y=None):
    """A flat round (an ellipse with radius_y across its second axis) facing along normal."""
    c, n = Vector(centre), Vector(normal).normalized()
    ref = Vector((0, 0, 1)) if abs(n.z) < 0.9 else Vector((1, 0, 0))
    side = n.cross(ref).normalized()
    up = n.cross(side).normalized()
    ry = radius_y if radius_y is not None else radius
    points = [c + side * math.cos(2 * math.pi * k / sides) * radius + up * math.sin(2 * math.pi * k / sides) * ry
              for k in range(sides)]
    b._face(b._verts(points, BONE), color)


def marker(name, location, colors, color):
    """A 0.2-stud cube object named for the game to find (it hides it and starts an effect there)."""
    b = voxel_kit.Builder(colors)
    b.box(location, (0.2, 0.2, 0.2), color, BONE)
    return b.to_object(name)


def begin(name):
    """A clean scene and the output folder."""
    os.makedirs(voxel_kit.out_dir(name), exist_ok=True)
    if bpy.context.object and bpy.context.object.mode != "OBJECT":
        bpy.ops.object.mode_set(mode="OBJECT")
    for obj in list(bpy.data.objects):
        bpy.data.objects.remove(obj, do_unlink=True)
    bpy.data.orphans_purge(do_recursive=True)


def triangles(obj):
    return sum(len(p.vertices) - 2 for p in obj.data.polygons)


def export(name, objects, colors):
    """Links the objects with one palette material, prints triangles, saves .blend and FBX unless EXPORT=0."""
    material = voxel_kit.make_material(name, voxel_kit.make_palette(name, colors))
    scene = bpy.context.scene
    for obj in objects:
        scene.collection.objects.link(obj)
        obj.data.materials.append(material)
        obj.vertex_groups.clear()
    total = sum(triangles(o) for o in objects)
    print("parts:", ", ".join(o.name for o in objects))
    print("tris:", ", ".join(f"{o.name} {triangles(o)}" for o in objects), "| total", total)
    assert total <= MAX_TRIANGLES, f"{name} has {total} triangles (cap {MAX_TRIANGLES})"
    if os.environ.get("EXPORT", "1") == "1":
        bpy.ops.object.select_all(action="DESELECT")
        for obj in objects:
            obj.select_set(True)
        bpy.context.view_layer.objects.active = objects[0]
        bpy.ops.wm.save_as_mainfile(filepath=os.path.join(voxel_kit.out_dir(name), f"{name}.blend"))
        bpy.ops.export_scene.fbx(
            filepath=os.path.join(voxel_kit.out_dir(name), f"{name}.fbx"),
            use_selection=True,
            object_types={"MESH"},
            path_mode="COPY",
            embed_textures=True,
            mesh_smooth_type="FACE",
            apply_scale_options="FBX_SCALE_ALL",
        )
        print("exported to", voxel_kit.out_dir(name))
    return objects
