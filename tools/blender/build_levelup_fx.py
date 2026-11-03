"""Renders the level-up pillar's textures (spec 2026-11-04-round4-design section 9) as white light on black;
tools/textures/make_levelup_fx.py adds the glow and turns the light into white with alpha for assets/ui/fx-levelup.
  Rune  512 x 512: a magic circle seen from above (two rings, diamonds and dots between them, a sunburst inside)
  Beam  256 x 512: a column of light, bright in the middle, with thin streaks (its height runs along a Roblox Beam)
  Mote  256 x 256: a soft four-point sparkle
Run inside Blender (MCP execute or Text Editor). Builds its own scenes (LevelUpRune, LevelUpBeam, LevelUpMote) in the
open file and renders to <temp>/levelup_fx_raw/<name>.png (LEVELUP_FX_RAW overrides).
"""
import math
import os
import random
import tempfile

import bpy

RAW_DIR = os.environ.get("LEVELUP_FX_RAW", os.path.join(tempfile.gettempdir(), "levelup_fx_raw"))
random.seed(7)


def fresh_scene(name, width, height, ortho_scale):
    old = bpy.data.scenes.get(name)
    if old:
        for ob in list(old.objects):
            bpy.data.objects.remove(ob)
        bpy.data.scenes.remove(old)
    scene = bpy.data.scenes.new(name)
    bpy.context.window.scene = scene
    try:
        scene.render.engine = "BLENDER_EEVEE"
    except TypeError:
        scene.render.engine = "BLENDER_EEVEE_NEXT"
    scene.render.resolution_x, scene.render.resolution_y = width, height
    scene.render.film_transparent = False
    scene.view_settings.view_transform = "Standard"
    world = bpy.data.worlds.new(name + "World")
    world.use_nodes = True
    bg = next(n for n in world.node_tree.nodes if n.type == "BACKGROUND")
    bg.inputs["Color"].default_value = (0, 0, 0, 1)
    bg.inputs["Strength"].default_value = 0.0
    scene.world = world
    cam_data = bpy.data.cameras.new(name + "Cam")
    cam_data.type = "ORTHO"
    cam_data.ortho_scale = ortho_scale
    cam = bpy.data.objects.new(name + "Cam", cam_data)
    scene.collection.objects.link(cam)
    cam.location = (0, -10, 0)
    cam.rotation_euler = (math.pi / 2, 0, 0)
    scene.camera = cam
    return scene


def light(name, strength):
    mat = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    mat.use_nodes = True
    nt = mat.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    emit = nt.nodes.new("ShaderNodeEmission")
    emit.inputs["Color"].default_value = (1, 1, 1, 1)
    emit.inputs["Strength"].default_value = strength
    nt.links.new(emit.outputs["Emission"], out.inputs["Surface"])
    return mat


def link(scene, ob, mat):
    for col in ob.users_collection:
        col.objects.unlink(ob)
    scene.collection.objects.link(ob)
    ob.data.materials.clear()
    ob.data.materials.append(mat)
    return ob


def ring(scene, name, radius, width, mat, segments=128):
    # A flat ring facing the camera (in the XZ plane)
    bpy.ops.mesh.primitive_circle_add(vertices=segments, radius=radius, fill_type="NOTHING", location=(0, 0, 0))
    ob = bpy.context.active_object
    ob.name = name
    ob.rotation_euler = (math.pi / 2, 0, 0)
    mod = ob.modifiers.new("Width", "SOLIDIFY")
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.mesh.extrude_region_shrink_fatten(TRANSFORM_OT_shrink_fatten={"value": width})
    bpy.ops.object.mode_set(mode="OBJECT")
    ob.modifiers.remove(mod)
    return link(scene, ob, mat)


def bar(scene, name, x, z, length, width, angle, mat):
    # A thin flat bar (a plane) centred at (x, z), turned `angle` radians in the picture
    bpy.ops.mesh.primitive_plane_add(size=1, location=(x, 0, z))
    ob = bpy.context.active_object
    ob.name = name
    ob.rotation_euler = (math.pi / 2, angle, 0)
    ob.scale = (width, length, 1)
    return link(scene, ob, mat)


def dot(scene, name, x, z, radius, mat):
    bpy.ops.mesh.primitive_circle_add(vertices=24, radius=radius, fill_type="NGON", location=(x, 0, z))
    ob = bpy.context.active_object
    ob.name = name
    ob.rotation_euler = (math.pi / 2, 0, 0)
    return link(scene, ob, mat)


def star(scene, name, outer, inner, points, mat, turn=0.0):
    # A flat star polygon facing the camera: `points` tips at `outer`, the notches between them at `inner`
    verts = []
    for index in range(points * 2):
        a = turn + index / (points * 2) * math.tau + math.pi / 2
        r = outer if index % 2 == 0 else inner
        verts.append((math.cos(a) * r, 0, math.sin(a) * r))
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(verts, [], [list(range(len(verts)))])
    ob = bpy.data.objects.new(name, mesh)
    scene.collection.objects.link(ob)
    mesh.materials.append(mat)
    return ob


def render(scene, name):
    os.makedirs(RAW_DIR, exist_ok=True)
    scene.render.filepath = os.path.join(RAW_DIR, name + ".png")
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGB"
    bpy.ops.render.render(write_still=True, scene=scene.name)


def build_rune():
    scene = fresh_scene("LevelUpRune", 512, 512, 2.3)
    bright, soft = light("LevelUpBright", 1.0), light("LevelUpSoft", 0.55)
    ring(scene, "Outer", 1.0, 0.045, bright)
    ring(scene, "OuterThin", 0.93, 0.012, soft)
    ring(scene, "Inner", 0.72, 0.03, bright)
    # Between the rings: 24 marks, small diamonds alternating with dots
    for index in range(24):
        a = index / 24 * math.tau
        r = 0.825
        x, z = math.cos(a) * r, math.sin(a) * r
        if index % 2 == 0:
            bar(scene, f"Diamond{index}", x, z, 0.06, 0.06, -a + math.pi / 4, bright)
        else:
            dot(scene, f"Dot{index}", x, z, 0.022, bright)
    # Inside: a sunburst of 12 short rays round a small ring and a four-point sparkle in the middle (no symbol that
    # reads as a sign of any faith)
    for index in range(12):
        a = index / 12 * math.tau
        long = index % 2 == 0
        r0, r1 = 0.3, 0.62 if long else 0.5
        x, z = math.cos(a) * (r0 + r1) / 2, math.sin(a) * (r0 + r1) / 2
        bar(scene, f"Ray{index}", x, z, r1 - r0, 0.022 if long else 0.014, -(a - math.pi / 2), soft)
    ring(scene, "Core", 0.24, 0.02, soft)
    star(scene, "Sparkle", 0.17, 0.045, 4, bright)
    render(scene, "Rune")


def build_beam():
    scene = fresh_scene("LevelUpBeam", 256, 512, 2.0)
    bright, soft = light("LevelUpBright", 1.0), light("LevelUpFaint", 0.35)
    # Ortho scale 2 on the long side: the picture is 1 wide and 2 tall in scene units
    bar(scene, "Core", 0, 0, 2.2, 0.1, 0, bright)
    for index in range(7):
        x = random.uniform(-0.3, 0.3)
        bar(scene, f"Streak{index}", x, 0, 2.2, random.uniform(0.008, 0.02), 0, soft)
    render(scene, "Beam")


def build_mote():
    scene = fresh_scene("LevelUpMote", 256, 256, 2.2)
    bright = light("LevelUpBright", 1.0)
    star(scene, "Sparkle", 0.9, 0.16, 4, bright)
    star(scene, "Glint", 0.42, 0.12, 4, light("LevelUpSoft", 0.55), math.pi / 4)
    dot(scene, "Heart", 0, 0, 0.1, bright)
    render(scene, "Mote")


build_rune()
build_beam()
build_mote()
print("rendered to", RAW_DIR)
