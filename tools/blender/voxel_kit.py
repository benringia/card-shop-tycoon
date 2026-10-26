"""Shared kit for the blocky creature build scripts (build_<card>.py) run inside Blender.

Builder collects boxes, pyramids, rounded boxes and smooth ellipsoids into one mesh, each face coloured by a palette
cell (an 8x8 grid texture) and every vertex weighted fully to one bone. New models should lean on round_box and blob
so they look as little blocky as possible (box and spike stay for the older, chunkier ones). build() makes a fresh file with the armature and mesh, export() saves
assets/blender/<Name>/<Name>.blend and .fbx (texture embedded) for Studio's 3D Importer.

Blender: Z up, creatures face -Y, their left is +X (Roblox: -Z front once imported).
"""
import os

import bmesh
import bpy
from mathutils import Matrix, Vector

REPO = os.environ.get("CARD_SHOP_REPO", r"C:\Users\Ben\Documents\roblox-project\card-shop-tycoon")
CELLS = 8
CELL_PX = 8


def out_dir(name):
    return os.path.join(REPO, "assets", "blender", name)


def frame(forward, up=(0, 0, 1)):
    """3x3 matrix whose columns are right, forward and up: local (x side, y forward, z up) to world."""
    f = Vector(forward).normalized()
    r = f.cross(Vector(up)).normalized()
    u = r.cross(f).normalized()
    return Matrix((r, f, u)).transposed()


class Builder:
    def __init__(self, colors):
        self.index = {name: i for i, name in enumerate(colors)}
        assert len(self.index) <= CELLS * CELLS, "too many palette colours"
        self.bm = bmesh.new()
        self.uv = self.bm.loops.layers.uv.new("UVMap")
        self.deform = self.bm.verts.layers.deform.new()
        self.groups = []
        self.xform = None  # Matrix 4x4 applied to every new vertex (e.g. a part built at size 1, then scaled)

    def group(self, bone):
        if bone not in self.groups:
            self.groups.append(bone)
        return self.groups.index(bone)

    def _face(self, verts, color):
        face = self.bm.faces.new(verts)
        i = self.index[color]
        u, v = ((i % CELLS) + 0.5) / CELLS, ((i // CELLS) + 0.5) / CELLS
        for loop in face.loops:
            loop[self.uv].uv = (u, v)
        return face

    def _verts(self, points, bone):
        index = self.group(bone)
        verts = []
        for p in points:
            vert = self.bm.verts.new(self.xform @ Vector(p) if self.xform else p)
            vert[self.deform][index] = 1.0
            verts.append(vert)
        return verts

    def box(self, center, size, color, bone, rot=None):
        """Axis-aligned box (or turned by rot, a Matrix 3x3, about its centre)."""
        c = Vector(center)
        hx, hy, hz = size[0] / 2, size[1] / 2, size[2] / 2
        corners = [Vector((x, y, z)) for z in (-hz, hz) for y in (-hy, hy) for x in (-hx, hx)]
        if rot is not None:
            corners = [rot @ p for p in corners]
        v = self._verts([c + p for p in corners], bone)
        for quad in ((0, 2, 3, 1), (4, 5, 7, 6), (0, 1, 5, 4), (2, 6, 7, 3), (0, 4, 6, 2), (1, 3, 7, 5)):
            self._face([v[i] for i in quad], color)

    def span(self, a, b, width, color, bone, overlap=0.0):
        """Square-section box from point a to point b."""
        a, b = Vector(a), Vector(b)
        along = b - a
        length = along.length + overlap * 2
        rot = along.to_track_quat("Z", "Y").to_matrix()
        self.box((a + b) / 2, (width, width, length), color, bone, rot)

    def spike(self, base, direction, width, length, color, bone):
        """Four-sided pyramid from a square base, pointing along direction."""
        base, d = Vector(base), Vector(direction).normalized()
        rot = d.to_track_quat("Z", "Y").to_matrix()
        h = width / 2
        corners = [base + rot @ Vector(p) for p in ((-h, -h, 0), (h, -h, 0), (h, h, 0), (-h, h, 0))]
        v = self._verts(corners + [base + d * length], bone)
        self._face([v[3], v[2], v[1], v[0]], color)
        for i in range(4):
            self._face([v[i], v[(i + 1) % 4], v[4]], color)

    def _finish(self, faces, color, bone, smooth):
        """Colours, weights and shades faces made by a bmesh operator (new verts get the bone fully)."""
        index = self.group(bone)
        i = self.index[color]
        u, v = ((i % CELLS) + 0.5) / CELLS, ((i // CELLS) + 0.5) / CELLS
        for face in faces:
            face.smooth = smooth
            for loop in face.loops:
                loop[self.uv].uv = (u, v)
                weights = loop.vert[self.deform]
                weights.clear()
                weights[index] = 1.0

    def round_box(self, center, size, color, bone, rot=None, bevel=0.3, segments=2):
        """A box with rounded edges; bevel is the fraction of its smallest side rounded off (less blocky)."""
        before = set(self.bm.faces)
        self.box(center, size, color, bone, rot)
        made = [f for f in self.bm.faces if f not in before]
        edges = {e for f in made for e in f.edges}
        radius = min(size) * bevel * 0.5
        bmesh.ops.bevel(self.bm, geom=list(edges), offset=radius, segments=segments, profile=0.5, affect="EDGES", clamp_overlap=True)
        # Bevelling replaces the box's faces: colour everything that's new since before the box
        self._finish([f for f in self.bm.faces if f not in before], color, bone, True)

    def blob(self, center, radii, color, bone, rot=None, segments=10, rings=7):
        """A smooth ellipsoid (radii along x, y, z, turned by rot): heads, bellies, cheeks, paws."""
        m = Matrix.Translation(Vector(center)) @ (rot.to_4x4() if rot is not None else Matrix.Identity(4)) \
            @ Matrix.Diagonal((radii[0], radii[1], radii[2], 1.0))
        if self.xform is not None:
            m = self.xform @ m
        result = bmesh.ops.create_uvsphere(self.bm, u_segments=segments, v_segments=rings, radius=1.0, matrix=m)
        faces = {f for vert in result["verts"] for f in vert.link_faces}
        self._finish(list(faces), color, bone, True)

    def to_object(self, name):
        mesh = bpy.data.meshes.new(name)
        self.bm.to_mesh(mesh)
        self.bm.free()
        obj = bpy.data.objects.new(name, mesh)
        for bone in self.groups:
            obj.vertex_groups.new(name=bone)
        return obj


def make_palette(name, colors):
    size = CELLS * CELL_PX
    image = bpy.data.images.new(f"{name}_palette", size, size, alpha=False)
    pixels = [0.0] * (size * size * 4)
    names = list(colors)
    for py in range(size):
        for px in range(size):
            i = (py // CELL_PX) * CELLS + (px // CELL_PX)
            r, g, b = colors[names[i]] if i < len(names) else (255, 0, 255)
            o = (py * size + px) * 4
            pixels[o:o + 4] = [r / 255, g / 255, b / 255, 1.0]
    image.pixels = pixels
    image.filepath_raw = os.path.join(out_dir(name), f"{name}_palette.png")
    image.file_format = "PNG"
    image.save()
    return image


def make_material(name, image):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    bsdf = next(n for n in nodes if n.type == "BSDF_PRINCIPLED")
    tex = nodes.new("ShaderNodeTexImage")
    tex.image = image
    tex.interpolation = "Closest"
    mat.node_tree.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 0.8
    return mat


def build(name, colors, bones, parts):
    """A fresh file with the armature (bones: (name, parent, head, tail)) and the mesh parts(builder) adds."""
    os.makedirs(out_dir(name), exist_ok=True)
    # Start clean, so each .blend holds only its own creature (read_homefile loses the context under the MCP)
    if bpy.context.object and bpy.context.object.mode != "OBJECT":
        bpy.ops.object.mode_set(mode="OBJECT")
    for obj in list(bpy.data.objects):
        bpy.data.objects.remove(obj, do_unlink=True)
    bpy.data.orphans_purge(do_recursive=True)
    scene = bpy.context.scene
    scene.unit_settings.system = "METRIC"

    arm_data = bpy.data.armatures.new(f"{name}Rig")
    rig = bpy.data.objects.new(f"{name}Rig", arm_data)
    scene.collection.objects.link(rig)
    bpy.context.view_layer.objects.active = rig
    bpy.ops.object.mode_set(mode="EDIT")
    for bone_name, parent, head, tail in bones:
        bone = arm_data.edit_bones.new(bone_name)
        bone.head, bone.tail = head, tail
        if parent:
            bone.parent = arm_data.edit_bones[parent]
    bpy.ops.object.mode_set(mode="OBJECT")
    arm_data.display_type = "STICK"
    rig.show_in_front = True

    b = Builder(colors)
    parts(b)
    obj = b.to_object(name)
    scene.collection.objects.link(obj)
    obj.data.materials.append(make_material(name, make_palette(name, colors)))
    obj.parent = rig
    modifier = obj.modifiers.new("Armature", "ARMATURE")
    modifier.object = rig

    missing = [g for g in b.groups if g not in arm_data.bones]
    print("vertex groups without a bone:", missing)
    print("bones:", len(arm_data.bones), "verts:", len(obj.data.vertices), "tris:", sum(len(p.vertices) - 2 for p in obj.data.polygons))
    return rig, obj


def export(name, rig, obj):
    bpy.ops.object.select_all(action="DESELECT")
    rig.select_set(True)
    obj.select_set(True)
    bpy.context.view_layer.objects.active = rig
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(out_dir(name), f"{name}.blend"))
    bpy.ops.export_scene.fbx(
        filepath=os.path.join(out_dir(name), f"{name}.fbx"),
        use_selection=True,
        object_types={"ARMATURE", "MESH"},
        add_leaf_bones=False,
        bake_anim=False,
        path_mode="COPY",
        embed_textures=True,
        mesh_smooth_type="FACE",
        apply_scale_options="FBX_SCALE_ALL",
    )
    print("exported to", out_dir(name))


def run(name, colors, bones, parts):
    """Builds, then exports unless the environment says EXPORT=0 (for a look before saving)."""
    rig, obj = build(name, colors, bones, parts)
    if os.environ.get("EXPORT", "1") == "1":
        export(name, rig, obj)
    return rig, obj
