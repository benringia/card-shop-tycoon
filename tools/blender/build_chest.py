"""The boss chest (spec docs/superpowers/specs/2026-11-11-boss-chests-design.md), built in Blender: a chunky cartoon
treasure chest in flat colours, a body and a separate lid hinged along its top back edge (the game swings it open).

Run inside Blender (Blender MCP: runpy.run_path(path)). Z up, its front faces -Y (Roblox: -Z once imported); the body's
origin is its bottom centre, the lid's its hinge. Meshes are built with bmesh only (no operators, so it runs in an
empty file). LOOKS holds the colour sets; build(look, x) makes one chest at x. render_concepts() builds every look side
by side and renders assets/blender/Chest/concepts.png; export(look) saves assets/blender/Chest/Chest.fbx (Body + Lid).
"""
import math
import os
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector

REPO = os.environ.get("CARD_SHOP_REPO", r"C:\Users\Ben\Documents\roblox-project\card-shop-tycoon")
OUT = os.path.join(REPO, "assets", "blender", "Chest")
sys.path.insert(0, os.path.join(REPO, "tools", "blender"))
import voxel_kit  # noqa: E402  (the palette texture: one colour per cell, as the portals and creatures use)

W, D, H = 2.0, 1.3, 1.05  # body width, depth, height
LID_R = D / 2  # the lid is a half barrel over the body's depth

LOOKS = {
    # darker than first built (the owner's pick): the stage is lit by the town's daylight, which washed it out
    "classic": {"wood": (0.50, 0.28, 0.12), "dark": (0.30, 0.16, 0.07), "gold": (0.88, 0.62, 0.18), "gem": (0.52, 0.28, 0.88), "hole": (0.13, 0.08, 0.05)},
    "royal": {"wood": (0.24, 0.30, 0.78), "dark": (0.15, 0.18, 0.52), "gold": (1.0, 0.78, 0.30), "gem": (1.0, 0.30, 0.45), "hole": (0.08, 0.08, 0.20)},
    "candy": {"wood": (1.0, 0.55, 0.72), "dark": (0.86, 0.36, 0.56), "gold": (1.0, 0.86, 0.42), "gem": (0.35, 0.85, 1.0), "hole": (0.35, 0.12, 0.25)},
}
SLOTS = ["wood", "dark", "gold", "gem", "hole"]


def material(name, rgb, metal=0.0, rough=0.55, emit=0.0):
    m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    m.use_nodes = True
    bsdf = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    linear = tuple(channel ** 2.2 for channel in rgb)  # the LOOKS are screen colours
    bsdf.inputs["Base Color"].default_value = (*linear, 1)
    bsdf.inputs["Metallic"].default_value = metal
    bsdf.inputs["Roughness"].default_value = rough
    if emit > 0:
        bsdf.inputs["Emission Color"].default_value = (*linear, 1)
        bsdf.inputs["Emission Strength"].default_value = emit
    return m


class Part:
    """One mesh (the body or the lid) built from shapes, each with a material slot (SLOTS)"""

    def __init__(self):
        self.bm = bmesh.new()

    def _tag(self, verts, slot, bevel=0.0, segments=2, flat=False):
        verts = list(verts)
        faces = {f for v in verts for f in v.link_faces}
        if bevel > 0:
            edges = list({e for v in verts for e in v.link_edges})
            result = bmesh.ops.bevel(self.bm, geom=edges, offset=bevel, segments=segments, profile=0.5, affect="EDGES", clamp_overlap=True)
            faces |= set(result["faces"])
            faces = {f for f in faces if f.is_valid}
            faces |= {f for v in verts if v.is_valid for f in v.link_faces}
        for f in faces:
            f.material_index = SLOTS.index(slot)
            f.smooth = not flat

    def box(self, size, at, slot, bevel=0.0):
        m = Matrix.Translation(Vector(at)) @ Matrix.Diagonal((*size, 1))
        verts = bmesh.ops.create_cube(self.bm, size=1.0, matrix=m)["verts"]
        self._tag(verts, slot, bevel)

    def half_barrel(self, length, radius, at, slot, bevel=0.0, sides=24):
        """A half cylinder along X, flat side down at `at`"""
        m = Matrix.Translation(Vector(at)) @ Matrix.Rotation(math.pi / 2, 4, "Y")
        verts = bmesh.ops.create_cone(self.bm, cap_ends=True, segments=sides, radius1=radius, radius2=radius, depth=length, matrix=m)["verts"]
        geom = list(verts) + list({e for v in verts for e in v.link_edges}) + list({f for v in verts for f in v.link_faces})
        cut = bmesh.ops.bisect_plane(self.bm, geom=geom, plane_co=Vector(at), plane_no=(0, 0, 1), clear_inner=True)
        rim = [e for e in cut["geom_cut"] if isinstance(e, bmesh.types.BMEdge)]
        if rim:
            bmesh.ops.holes_fill(self.bm, edges=rim, sides=0)
        kept = [v for v in verts if v.is_valid] + [v for v in cut["geom_cut"] if isinstance(v, bmesh.types.BMVert)]
        self._tag(kept, slot, bevel)

    def sphere(self, at, radius, slot, ico=False):
        m = Matrix.Translation(Vector(at))
        if ico:
            verts = bmesh.ops.create_icosphere(self.bm, subdivisions=1, radius=radius, matrix=m)["verts"]
        else:
            verts = bmesh.ops.create_uvsphere(self.bm, u_segments=8, v_segments=5, radius=radius, matrix=m)["verts"]
        self._tag(verts, slot, flat=ico)

    def object(self, name, look, origin, palette=None):
        if palette:
            # One palette material: every face's UVs on its colour's cell (voxel_kit's layout)
            uv = self.bm.loops.layers.uv.new("UVMap")
            for face in self.bm.faces:
                i = face.material_index
                cell = (((i % voxel_kit.CELLS) + 0.5) / voxel_kit.CELLS, ((i // voxel_kit.CELLS) + 0.5) / voxel_kit.CELLS)
                for loop in face.loops:
                    loop[uv].uv = cell
                face.material_index = 0
            bmesh.ops.translate(self.bm, verts=self.bm.verts, vec=-Vector(origin))
            mesh = bpy.data.meshes.new(name)
            self.bm.to_mesh(mesh)
            self.bm.free()
            mesh.materials.append(palette)
            ob = bpy.data.objects.new(name, mesh)
            ob.location = origin
            bpy.context.scene.collection.objects.link(ob)
            return ob
        c = LOOKS[look]
        mats = [
            material(f"Wood_{look}", c["wood"]),
            material(f"Dark_{look}", c["dark"]),
            material(f"Gold_{look}", c["gold"], metal=0.6, rough=0.3),
            material(f"Gem_{look}", c["gem"], rough=0.15, emit=0.6),
            material(f"Hole_{look}", c["hole"]),
        ]
        bmesh.ops.translate(self.bm, verts=self.bm.verts, vec=-Vector(origin))
        mesh = bpy.data.meshes.new(name)
        self.bm.to_mesh(mesh)
        self.bm.free()
        for m in mats:
            mesh.materials.append(m)
        ob = bpy.data.objects.new(name, mesh)
        ob.location = origin
        bpy.context.scene.collection.objects.link(ob)
        return ob


def build(look, x=0.0, suffix="", palette=None):
    body = Part()
    body.box((W, D, H), (x, 0, H / 2), "wood", bevel=0.08)
    body.box((W * 1.04, D * 1.04, 0.12), (x, 0, 0.06), "dark", bevel=0.04)  # foot
    body.box((W * 1.03, D * 1.03, 0.1), (x, 0, H - 0.05), "gold", bevel=0.03)  # rim
    body.box((W * 0.9, D * 0.84, 0.03), (x, 0, H + 0.005), "hole")  # the dark inside, seen once the lid is up
    for sx in (-1, 1):
        body.box((0.16, D * 1.05, H * 0.98), (x + sx * (W / 2 - 0.02), 0, H / 2), "gold", bevel=0.04)  # corner caps
        body.box((0.12, D * 1.03, H * 0.97), (x + sx * 0.5, 0, H / 2), "dark", bevel=0.03)  # bands
        for sz in (0.25, H - 0.25):
            body.sphere((x + sx * (W / 2 - 0.02), -D * 0.53, sz), 0.06, "gold")
    # The lock: a gold plate with a keyhole on the front, under the lid's hasp
    body.box((0.42, 0.08, 0.46), (x, -D / 2 - 0.03, H - 0.3), "gold", bevel=0.06)
    body.box((0.08, 0.04, 0.16), (x, -D / 2 - 0.08, H - 0.36), "hole", bevel=0.015)
    body.sphere((x, -D / 2 - 0.08, H - 0.25), 0.06, "hole")
    body_ob = body.object(f"Body{suffix}", look, (x, 0, 0), palette)

    lid = Part()
    lid.half_barrel(W * 1.02, LID_R * 1.02, (x, 0, H), "wood", bevel=0.04)
    for sx in (-1, 1):
        lid.half_barrel(0.17, LID_R * 1.08, (x + sx * (W / 2 - 0.02), 0, H), "gold", bevel=0.02)
        lid.half_barrel(0.13, LID_R * 1.06, (x + sx * 0.5, 0, H), "dark", bevel=0.02)
    lid.box((0.3, 0.1, 0.26), (x, -LID_R * 1.04, H + 0.12), "gold", bevel=0.05)  # hasp
    lid.sphere((x, -LID_R * 0.74, H + LID_R * 0.7), 0.17, "gem", ico=True)
    lid_ob = lid.object(f"Lid{suffix}", look, (x, D / 2, H), palette)  # its hinge: the top back edge
    return body_ob, lid_ob


def clear():
    for ob in list(bpy.data.objects):
        bpy.data.objects.remove(ob, do_unlink=True)
    for mesh in list(bpy.data.meshes):
        bpy.data.meshes.remove(mesh)


def render_concepts(path=None):
    clear()
    scene = bpy.context.scene
    looks = list(LOOKS)
    for index, look in enumerate(looks):
        x = (index - (len(looks) - 1) / 2) * 3.2
        _, lid = build(look, x, f"_{look}")
        if index == 1:
            lid.rotation_euler = (math.radians(-65), 0, 0)  # one shown opening
    for engine in ("BLENDER_EEVEE_NEXT", "BLENDER_EEVEE", "BLENDER_WORKBENCH"):
        try:
            scene.render.engine = engine
            break
        except TypeError:
            continue
    scene.render.resolution_x, scene.render.resolution_y = 1600, 700
    for transform in ("Standard",):
        try:
            scene.view_settings.view_transform = transform
        except TypeError:
            pass
    world = bpy.data.worlds.get("ChestWorld") or bpy.data.worlds.new("ChestWorld")
    world.use_nodes = True
    bg = next(n for n in world.node_tree.nodes if n.type == "BACKGROUND")
    bg.inputs["Color"].default_value = (0.08, 0.06, 0.16, 1)
    bg.inputs["Strength"].default_value = 0.7
    scene.world = world
    sun = bpy.data.objects.new("Sun", bpy.data.lights.new("Sun", "SUN"))
    sun.data.energy = 3.5
    sun.rotation_euler = (math.radians(50), 0, math.radians(-30))
    scene.collection.objects.link(sun)
    fill = bpy.data.objects.new("Fill", bpy.data.lights.new("Fill", "AREA"))
    fill.data.energy = 700
    fill.data.size = 8
    fill.location = (0, -6, 5)
    fill.rotation_euler = (math.radians(50), 0, 0)
    scene.collection.objects.link(fill)
    cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
    cam.location = (0, -10.5, 4.6)
    cam.rotation_euler = (math.radians(70), 0, 0)
    cam.data.lens = 40
    scene.collection.objects.link(cam)
    scene.camera = cam
    os.makedirs(OUT, exist_ok=True)
    scene.render.filepath = path or os.path.join(OUT, "concepts.png")
    bpy.ops.render.render(write_still=True)
    return scene.render.filepath


def export(look="classic"):
    """Body and Lid with one palette material (assets/blender/Chest/Chest_palette.png), saved as Chest.blend and
    Chest.fbx; returns their triangles. Run it in an opened file (an empty new file under the MCP has no context)."""
    clear()
    colors = {slot: tuple(round(channel * 255) for channel in LOOKS[look][slot]) for slot in SLOTS}
    palette = voxel_kit.make_material("Chest", voxel_kit.make_palette("Chest", colors))
    body, lid = build(look, palette=palette)
    tris = {o.name: sum(len(p.vertices) - 2 for p in o.data.polygons) for o in (body, lid)}
    os.makedirs(OUT, exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, "Chest.blend"))
    for ob in bpy.context.scene.objects:
        ob.select_set(ob in (body, lid))
    bpy.context.view_layer.objects.active = body
    bpy.ops.export_scene.fbx(
        filepath=os.path.join(OUT, "Chest.fbx"),
        use_selection=True,
        object_types={"MESH"},
        path_mode="COPY",
        embed_textures=True,
        apply_scale_options="FBX_SCALE_ALL",
    )
    return tris
