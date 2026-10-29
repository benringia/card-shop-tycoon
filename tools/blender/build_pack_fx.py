"""Renders the pack opening's effects as flipbook frames (UI project 3, spec section 5), white light on black (the
shards on a clear background); tools/textures/make_flipbooks.py packs them into sheets for assets/ui/fx.
  RipBurst   64 frames: a core flash, 22 light streaks, two expanding shockwave rings, 46 sparks with motion blur
  ShardHolo  16 frames: one irregular iridescent foil shard tumbling a full turn (loops)
  ShardGold  16 frames: the same in gold
  Glint      16 frames: a four-point twinkle that flares and fades
Run inside Blender (MCP execute or Text Editor). Builds its own scenes (RipBurst, ShardHolo, ShardGold, Glint) in the
open file and renders frames to <temp>/pack_fx_frames/<name>/NNN.png (PACK_FX_FRAMES overrides). PACK_FX picks one
effect: all (default), burst, shards or glint.
"""
import math
import os
import random
import tempfile

import bpy
from mathutils import Vector

FRAMES_DIR = os.environ.get("PACK_FX_FRAMES", os.path.join(tempfile.gettempdir(), "pack_fx_frames"))
random.seed(3)


def fresh_scene(name, size, frames, transparent=False):
    old = bpy.data.scenes.get(name)
    if old:
        for ob in list(old.objects):
            bpy.data.objects.remove(ob)
        bpy.data.scenes.remove(old)
    scene = bpy.data.scenes.new(name)
    bpy.context.window.scene = scene
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x = scene.render.resolution_y = size
    scene.render.film_transparent = transparent
    scene.view_settings.view_transform = "Standard"
    scene.frame_start, scene.frame_end = 1, frames
    world = bpy.data.worlds.new(name + "World")
    world.use_nodes = True
    bg = next(n for n in world.node_tree.nodes if n.type == "BACKGROUND")
    bg.inputs["Color"].default_value = (0, 0, 0, 1)
    bg.inputs["Strength"].default_value = 0.0 if not transparent else 0.4
    scene.world = world
    cam_data = bpy.data.cameras.new(name + "Cam")
    cam_data.type = "ORTHO"
    cam = bpy.data.objects.new(name + "Cam", cam_data)
    scene.collection.objects.link(cam)
    cam.location = (0, -10, 0)
    cam.rotation_euler = (math.pi / 2, 0, 0)
    scene.camera = cam
    return scene, cam


def glow_material(name, soft=True):
    # Emission whose strength is the object's colour alpha (keyframed per object); soft edges from facing
    mat = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    mat.use_nodes = True
    nt = mat.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    emit = nt.nodes.new("ShaderNodeEmission")
    info = nt.nodes.new("ShaderNodeObjectInfo")
    mul = nt.nodes.new("ShaderNodeMath"); mul.operation = "MULTIPLY"; mul.inputs[1].default_value = 6.0
    nt.links.new(info.outputs["Alpha"], mul.inputs[0])
    if soft:
        weight = nt.nodes.new("ShaderNodeLayerWeight"); weight.inputs["Blend"].default_value = 0.35
        inv = nt.nodes.new("ShaderNodeMath"); inv.operation = "SUBTRACT"; inv.inputs[0].default_value = 1.0
        nt.links.new(weight.outputs["Facing"], inv.inputs[1])
        mul2 = nt.nodes.new("ShaderNodeMath"); mul2.operation = "MULTIPLY"
        nt.links.new(mul.outputs[0], mul2.inputs[0]); nt.links.new(inv.outputs[0], mul2.inputs[1])
        nt.links.new(mul2.outputs[0], emit.inputs["Strength"])
    else:
        nt.links.new(mul.outputs[0], emit.inputs["Strength"])
    nt.links.new(info.outputs["Color"], emit.inputs["Color"])
    nt.links.new(emit.outputs["Emission"], out.inputs["Surface"])
    return mat


def add_mesh(scene, name, op, mat, **kw):
    op(**kw)
    ob = bpy.context.active_object
    ob.name = name
    ob.data.materials.append(mat)
    return ob


def key(ob, frame, loc=None, scale=None, alpha=None, rot=None, color=None):
    if loc is not None:
        ob.location = loc; ob.keyframe_insert("location", frame=frame)
    if scale is not None:
        ob.scale = scale if isinstance(scale, (tuple, list, Vector)) else (scale, scale, scale)
        ob.keyframe_insert("scale", frame=frame)
    if rot is not None:
        ob.rotation_euler = rot; ob.keyframe_insert("rotation_euler", frame=frame)
    if alpha is not None:
        c = list(color or ob.color)
        c[3] = alpha
        ob.color = c; ob.keyframe_insert("color", frame=frame)


def bloom(scene, threshold=0.8, size=0.45, strength=0.6):
    # Blender 5: the compositor is a node group on the scene
    tree = bpy.data.node_groups.new(scene.name + "Comp", "CompositorNodeTree")
    tree.interface.new_socket("Image", in_out="OUTPUT", socket_type="NodeSocketColor")
    rl = tree.nodes.new("CompositorNodeRLayers")
    rl.scene = scene
    glare = tree.nodes.new("CompositorNodeGlare")
    for value in ("Bloom", "BLOOM"):
        try:
            glare.inputs["Type"].default_value = value
            break
        except (TypeError, ValueError):
            pass
    glare.inputs["Threshold"].default_value = threshold
    glare.inputs["Size"].default_value = size
    glare.inputs["Strength"].default_value = strength
    out = tree.nodes.new("NodeGroupOutput")
    tree.links.new(rl.outputs["Image"], glare.inputs["Image"])
    tree.links.new(glare.outputs["Image"], out.inputs[0])
    scene.compositing_node_group = tree


def render_frames(scene, folder):
    os.makedirs(folder, exist_ok=True)
    for f in range(scene.frame_start, scene.frame_end + 1):
        scene.frame_set(f)
        scene.render.filepath = os.path.join(folder, f"{f:03d}.png")
        bpy.ops.render.render(write_still=True, scene=scene.name)


def ease_out(t):
    return 1 - (1 - t) ** 3


# ---------------- 1. Rip burst: 64 frames ----------------
def rip_burst():
    scene, cam = fresh_scene("RipBurst", 256, 64)
    cam.data.ortho_scale = 4.8
    scene.render.use_motion_blur = True
    scene.render.motion_blur_shutter = 0.8
    soft = glow_material("GlowSoft", soft=True)
    hard = glow_material("GlowHard", soft=False)
    warm = (1.0, 0.96, 0.88, 1.0)
    # core flash
    core = add_mesh(scene, "Core", bpy.ops.mesh.primitive_uv_sphere_add, soft, radius=0.5, segments=32, ring_count=16)
    key(core, 1, scale=0.2, alpha=0.0, color=warm)
    key(core, 3, scale=0.9, alpha=1.6, color=warm)
    key(core, 10, scale=0.7, alpha=0.7, color=warm)
    key(core, 22, scale=0.3, alpha=0.0, color=warm)
    # shockwave ring (facing the camera)
    ring = add_mesh(scene, "Ring", bpy.ops.mesh.primitive_torus_add, hard, major_radius=1.0, minor_radius=0.035, major_segments=96, minor_segments=8, rotation=(math.pi / 2, 0, 0))
    key(ring, 2, scale=0.12, alpha=1.4, color=warm)
    key(ring, 14, scale=1.25, alpha=0.6, color=warm)
    key(ring, 26, scale=1.8, alpha=0.0, color=warm)
    # a second, slower ring
    ring2 = add_mesh(scene, "Ring2", bpy.ops.mesh.primitive_torus_add, hard, major_radius=1.0, minor_radius=0.02, major_segments=96, minor_segments=8, rotation=(math.pi / 2, 0, 0))
    key(ring2, 5, scale=0.1, alpha=0.0, color=warm)
    key(ring2, 7, scale=0.3, alpha=0.9, color=warm)
    key(ring2, 34, scale=1.6, alpha=0.0, color=warm)
    # light streaks radiating out
    for i in range(22):
        angle = i / 22 * math.tau + random.uniform(-0.12, 0.12)
        length = random.uniform(0.5, 1.1)
        streak = add_mesh(scene, f"Streak{i}", bpy.ops.mesh.primitive_cone_add, soft, vertices=8, radius1=0.035, radius2=0.0, depth=1.0)
        direction = Vector((math.cos(angle), 0, math.sin(angle)))
        streak.rotation_euler = direction.to_track_quat("Z", "Y").to_euler()
        start = random.randint(1, 4)
        key(streak, start, loc=direction * 0.15, scale=(1, 1, 0.05), alpha=0.0, color=warm)
        key(streak, start + 3, loc=direction * 0.6, scale=(1, 1, length), alpha=1.2, color=warm)
        key(streak, start + 16, loc=direction * 1.6, scale=(0.6, 0.6, length * 0.3), alpha=0.0, color=warm)
    # sparks flying out and falling a little
    for i in range(46):
        angle = random.uniform(0, math.tau)
        speed = random.uniform(0.9, 1.9)
        spark = add_mesh(scene, f"Spark{i}", bpy.ops.mesh.primitive_ico_sphere_add, hard, subdivisions=1, radius=0.036)
        start = random.randint(2, 6)
        life = random.randint(26, 50)
        size = random.uniform(0.7, 1.4)
        for step in range(0, life + 1, 4):
            t = step / life
            d = speed * ease_out(t)
            pos = Vector((math.cos(angle) * d, 0, math.sin(angle) * d - 0.5 * t * t))
            key(spark, start + step, loc=pos, scale=size * (1 - 0.8 * t), alpha=1.5 * (1 - t) ** 1.5, color=warm)
        key(spark, 1, loc=(0, 0, 0), scale=0.01, alpha=0.0, color=warm)
    bloom(scene)
    render_frames(scene, os.path.join(FRAMES_DIR, "ripburst"))


# ---------------- 2. Foil shards: 16 frames of one shard tumbling ----------------
def shard_material(name, gold):
    mat = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    mat.use_nodes = True
    nt = mat.node_tree
    bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Metallic"].default_value = 1.0
    bsdf.inputs["Roughness"].default_value = 0.18
    weight = nt.nodes.new("ShaderNodeLayerWeight"); weight.inputs["Blend"].default_value = 0.5
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    els = ramp.color_ramp.elements
    if gold:
        els[0].color = (1.0, 0.55, 0.1, 1); els[1].color = (1.0, 0.92, 0.55, 1)
    else:
        els[0].color = (1.0, 0.3, 0.8, 1); els[1].color = (0.3, 1.0, 1.0, 1)
        mid = els.new(0.5); mid.color = (1.0, 1.0, 0.45, 1)
    nt.links.new(weight.outputs["Facing"], ramp.inputs["Fac"])
    nt.links.new(ramp.outputs["Color"], bsdf.inputs["Base Color"])
    nt.links.new(ramp.outputs["Color"], bsdf.inputs["Emission Color"])
    bsdf.inputs["Emission Strength"].default_value = 0.35
    return mat


def foil_shard(gold):
    name = "ShardGold" if gold else "ShardHolo"
    scene, cam = fresh_scene(name, 256, 16, transparent=True)
    cam.data.ortho_scale = 1.3
    # Foil needs something bright to reflect
    bg = next(n for n in scene.world.node_tree.nodes if n.type == "BACKGROUND")
    bg.inputs["Color"].default_value = (0.75, 0.72, 0.85, 1)
    bg.inputs["Strength"].default_value = 1.1
    for lname, loc, energy, color in (("K", (-2, -3, 3), 900, (1, 1, 1)), ("R", (3, 2, 1), 600, (0.7, 0.85, 1)), ("F", (1, -3, -2), 300, (1, 0.8, 0.9))):
        data = bpy.data.lights.new(name + lname, "AREA"); data.energy = energy; data.size = 2; data.color = color
        ob = bpy.data.objects.new(name + lname, data); scene.collection.objects.link(ob)
        ob.location = loc
        ob.rotation_euler = (Vector((0, 0, 0)) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
    # an irregular pentagon shard, slightly bent
    pts = [(0.0, 0.42), (0.36, 0.12), (0.22, -0.38), (-0.26, -0.32), (-0.38, 0.08)]
    mesh = bpy.data.meshes.new(name + "Mesh")
    verts = [(x, 0.03 * x * x * 4, z) for x, z in pts] + [(0, 0.02, 0)]
    faces = [(5, i, (i + 1) % 5) for i in range(5)]
    mesh.from_pydata(verts, [], faces)
    ob = bpy.data.objects.new(name, mesh)
    scene.collection.objects.link(ob)
    ob.data.materials.append(shard_material(name + "Mat", gold))
    solid = ob.modifiers.new("Thick", "SOLIDIFY"); solid.thickness = 0.02
    axis_tilt = (math.radians(35), math.radians(20), 0)
    for f in range(1, 18):
        t = (f - 1) / 16
        ob.rotation_euler = (axis_tilt[0] + t * math.tau, axis_tilt[1] + t * math.tau * 0.5, t * math.tau * 0.25)
        ob.keyframe_insert("rotation_euler", frame=f)
    for fc in ob.animation_data.action.fcurves if hasattr(ob.animation_data.action, "fcurves") else []:
        for kp in fc.keyframe_points:
            kp.interpolation = "LINEAR"
    render_frames(scene, os.path.join(FRAMES_DIR, name.lower()))


# ---------------- 3. Glint: a four-point twinkle, 16 frames ----------------
def glint():
    scene, cam = fresh_scene("Glint", 256, 16)
    cam.data.ortho_scale = 2.2
    soft = glow_material("GlowSoft", soft=True)
    white = (1, 1, 1, 1)
    parent = bpy.data.objects.new("GlintRoot", None)
    scene.collection.objects.link(parent)
    rays = []
    for i, (sx, sz) in enumerate(((0.06, 1.0), (1.0, 0.06), (0.04, 0.55), (0.55, 0.04))):
        ray = add_mesh(scene, f"Ray{i}", bpy.ops.mesh.primitive_uv_sphere_add, soft, radius=0.5, segments=24, ring_count=12)
        ray.parent = parent
        ray.scale = (sx, 0.05, sz)
        if i >= 2:
            ray.rotation_euler = (0, math.radians(45), 0)
        rays.append(ray)
    core = add_mesh(scene, "GlintCore", bpy.ops.mesh.primitive_uv_sphere_add, soft, radius=0.12, segments=24, ring_count=12)
    core.parent = parent
    for ob in rays + [core]:
        key(ob, 1, alpha=0.0, color=white)
        key(ob, 5, alpha=2.0 if ob is not core else 2.5, color=white)
        key(ob, 16, alpha=0.0, color=white)
    for f, s, r in ((1, 0.1, 0), (5, 1.0, 20), (16, 0.2, 60)):
        parent.scale = (s, s, s); parent.keyframe_insert("scale", frame=f)
        parent.rotation_euler = (0, math.radians(r), 0); parent.keyframe_insert("rotation_euler", frame=f)
    bloom(scene, size=0.35)
    render_frames(scene, os.path.join(FRAMES_DIR, "glint"))


WHICH = os.environ.get("PACK_FX", globals().get("WHICH", "all"))
prefs = bpy.context.preferences.edit
old_interp = prefs.keyframe_new_interpolation_type
if WHICH in ("all", "burst"):
    rip_burst()
if WHICH in ("all", "shards"):
    prefs.keyframe_new_interpolation_type = "LINEAR"
    foil_shard(False)
    foil_shard(True)
    prefs.keyframe_new_interpolation_type = old_interp
if WHICH in ("all", "glint"):
    glint()
print("vfx done", WHICH)
