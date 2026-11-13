"""Pish trotting in place, rendered as a flipbook for the loading screen (owner 2026-11-13: "the loading style to like
pish running/walking"): a looping walk keyed on his rig (rig_pish.py, the same helpers as anim_pish.py), seen from his
right and a little in front so he trots left to right, rendered on a transparent background, FRAMES frames packed into
one sheet (COLUMNS across) for an ImageLabel to step through (Config/LoadingScreen PISH_WALK).

Run in a background Blender:
  blender -b assets/blender/Pish/Pish.blend --python tools/blender/build_pish_walk_sheet.py
Writes assets/ui/loading/pish_walk.png (the sheet, uploaded as an image) and assets/ui/loading/pish_walk_frames/
(each frame, for previews; not synced).
"""
import math
import os
import sys

import bpy
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import anim_pish as ap  # noqa: E402

REPO = ap.REPO
OUT_DIR = os.path.join(REPO, "assets", "ui", "loading")
FRAME_DIR = os.path.join(OUT_DIR, "pish_walk_frames")
FRAMES = 12  # one stride, looping
COLUMNS = 4
SIZE = 256  # pixels per frame

# A trot: the diagonal pairs swing together. Front legs (shoulder, wrist, paw), hind legs (hip, hock, paw), X turns:
# negative swings a leg forward. Reaching, pushing back, and lifted (folded while it swings forward)
FRONT_REACH, FRONT_PUSH, FRONT_LIFT = (-40, 10, -6), (32, -8, 12), (-14, 64, -22)
HIND_REACH, HIND_PUSH, HIND_LIFT = (-34, 18, -8), (30, -14, 12), (-14, 44, -16)


def lerp(a, b, t):
    return tuple(x + (y - x) * t for x, y in zip(a, b))


def stride(phase):
    """The pose at `phase` (0..1 round one stride): the left-front and right-hind pair reach at 0 and push at 0.5"""
    def leg(reach, push, lift, p):
        # 0 -> 0.5 planted, sliding back from reach to push; 0.5 -> 1 lifted, swinging forward again
        if p < 0.5:
            return lerp(reach, push, p / 0.5)
        t = (p - 0.5) / 0.5
        mid = lift
        return lerp(push, mid, t / 0.5) if t < 0.5 else lerp(mid, reach, (t - 0.5) / 0.5)

    a, b = phase % 1.0, (phase + 0.5) % 1.0
    bob = 0.03 * math.cos(phase * 4 * math.pi)  # up twice a stride, as each pair passes under him
    wag = 22 * math.sin(phase * 2 * math.pi)
    nod = 5 * math.cos(phase * 4 * math.pi)
    return ap.merge(
        ap.body(tilt=-2, roll=2.5 * math.sin(phase * 2 * math.pi), up=0.012 + bob),
        {
            "Head_0": (nod - 4, 0, 0),
            "Ear_Left_0": (-nod * 2, 0, 0),
            "Ear_Right_0": (-nod * 2, 0, 0),
            "Tail_0": (-30, 0, wag),
            "Tail_1": (0, 0, wag * 0.6),
        },
        ap.legs(
            left_front=leg(FRONT_REACH, FRONT_PUSH, FRONT_LIFT, a),
            right_hind=leg(HIND_REACH, HIND_PUSH, HIND_LIFT, a),
            right_front=leg(FRONT_REACH, FRONT_PUSH, FRONT_LIFT, b),
            left_hind=leg(HIND_REACH, HIND_PUSH, HIND_LIFT, b),
        ),
    )


def key_walk(rig):
    ap.kit.reset(rig)
    ap.timeline(rig, [(1 + i, stride(i / FRAMES)) for i in range(FRAMES)])
    ap.continuous(rig)


def setup_render():
    scene = bpy.context.scene
    for engine in ("BLENDER_EEVEE", "BLENDER_EEVEE_NEXT"):
        try:
            scene.render.engine = engine
            break
        except TypeError:
            continue
    scene.render.resolution_x = scene.render.resolution_y = SIZE * 2
    scene.render.resolution_percentage = 50
    scene.render.film_transparent = True
    for transform in ("AgX", "Filmic", "Standard"):
        try:
            scene.view_settings.view_transform = transform
            break
        except TypeError:
            continue
    world = scene.world or bpy.data.worlds.new("World")
    scene.world = world
    if not world.use_nodes:
        world.use_nodes = True
    bg = next(n for n in world.node_tree.nodes if n.type == "BACKGROUND")
    bg.inputs[0].default_value = (0.8, 0.85, 1.0, 1)
    bg.inputs[1].default_value = 0.5
    sun = bpy.data.objects.get("WalkSun")
    if not sun:
        sun = bpy.data.objects.new("WalkSun", bpy.data.lights.new("WalkSun", "SUN"))
        scene.collection.objects.link(sun)
    sun.data.energy = 2.4
    scene.view_settings.exposure = 0.35  # his white fur reads white, not grey
    sun.rotation_euler = (math.radians(50), 0, math.radians(-40))

    cam = bpy.data.objects.get("WalkCam") or bpy.data.objects.new("WalkCam", bpy.data.cameras.new("WalkCam"))
    if cam.name not in scene.collection.objects:
        scene.collection.objects.link(cam)
    scene.camera = cam
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = 1.55
    target = Vector((0, -0.12, 0.42))
    # From his right (-X), a little in front (-Y) and above: he faces screen right
    cam.location = target + Vector((-1.0, -0.62, 0.3)).normalized() * 4
    cam.rotation_euler = (target - cam.location).to_track_quat("-Z", "Y").to_euler()
    return scene


def render_sheet(scene):
    os.makedirs(FRAME_DIR, exist_ok=True)
    paths = []
    for i in range(FRAMES):
        scene.frame_set(1 + i)
        path = os.path.join(FRAME_DIR, f"frame_{i + 1:02d}.png")
        scene.render.filepath = path
        bpy.ops.render.render(write_still=True)
        paths.append(path)
    import numpy as np

    rows = FRAMES // COLUMNS
    sheet = np.zeros((rows * SIZE, COLUMNS * SIZE, 4), dtype=np.float32)
    for i, path in enumerate(paths):
        img = bpy.data.images.load(path)
        px = np.array(img.pixels[:], dtype=np.float32).reshape(SIZE, SIZE, 4)[::-1]  # top row first
        r, c = divmod(i, COLUMNS)
        sheet[r * SIZE:(r + 1) * SIZE, c * SIZE:(c + 1) * SIZE] = px
        bpy.data.images.remove(img)
    out = bpy.data.images.new("pish_walk", COLUMNS * SIZE, rows * SIZE, alpha=True)
    out.pixels[:] = sheet[::-1].ravel()
    out.filepath_raw = os.path.join(OUT_DIR, "pish_walk.png")
    out.file_format = "PNG"
    out.save()
    print("sheet", out.filepath_raw, COLUMNS * SIZE, rows * SIZE)


if __name__ == "__main__":
    rig = ap.kit.armature()
    key_walk(rig)
    render_sheet(setup_render())
