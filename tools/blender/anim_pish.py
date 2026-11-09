"""Pish's idle clips (the tutorial's guide puppy; owner 2026-11-09: "a lot of random high quality animation, like
sitting, sniffing, barking, rolling on the ground, digging"), keyed with anim_bone_kit on assets/blender/Pish/Pish.blend
(rig_pish.py) and exported for Roblox (docs/animations.md "Bone rigs"). Each starts and ends at rest, so the game can
play any of them at random while he waits.

  sit    4.0 s  sits down, looks left, right, tilts his head, wags, stands up
  sniff  3.0 s  nose down, sniffs left and right along the ground, looks up
  bark   2.2 s  dips, then three barks, head thrown up, mouth open; markers Bark1..Bark3 for the sound
  roll   4.4 s  lies down, rolls onto his back, paws in the air wiggling, rolls back and gets up

Armature axes: X his left, Y his back, Z up. A positive X turn tips a forward-pointing bone (Pelvis, Spine, Head) down
and swings a hanging leg back (negative X swings it forward); a positive Z turn looks to his left; a positive Y turn
rolls him onto his left side. Pelvis is the top deform bone: whole-body moves are its turn and offset.

Run in a background Blender:
  blender -b assets/blender/Pish/Pish.blend --python tools/blender/anim_pish.py
CLIP=<name> keys and previews one clip only (PREVIEW=0 skips the preview strips); JSON goes to
assets/blender/Animations/Pish/<clip>.json, previews to assets/blender/Pish/preview_<clip>.png (not in git).
Then: lune run tools/anim/build_bone_clips Pish
"""
import importlib
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import anim_bone_kit as kit  # noqa: E402

importlib.reload(kit)

REPO = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
JSON_DIR = os.path.join(REPO, "assets", "blender", "Animations", "Pish")
FOLDER = os.path.join(REPO, "assets", "blender", "Pish")


def legs(front=(0, 0, 0), hind=(0, 0, 0), left_front=None, right_front=None, left_hind=None, right_hind=None):
    """Both front legs' (shoulder, wrist, paw) and both hind legs' (hip, hock, paw) X turns; a side's own overrides"""
    pose = {}
    for side, own in (("Left", left_front), ("Right", right_front)):
        for i, angle in enumerate(own or front):
            pose[f"0_{side}_Limb_{i}"] = (angle, 0, 0)
    for side, own in (("Left", left_hind), ("Right", right_hind)):
        for i, angle in enumerate(own or hind):
            pose[f"1_{side}_Limb_{i}"] = (angle, 0, 0)
    return pose


def merge(*poses):
    out = {}
    for pose in poses:
        out.update(pose)
    return out


def timeline(rig, keys):
    """keys: (frame, pose) in time order"""
    for frame, pose in keys:
        kit.key_pose(rig, frame, pose)


# --- sit -----------------------------------------------------------------------------------------------------------
SIT = merge(
    {
        "Pelvis": ((-24, 0, 0), (0, 0.0, -0.15)),
        "Spine_0": (5, 0, 0),
        "Spine_1": (6, 0, 0),
        "Head_0": (10, 0, 0),
        "Tail_0": (24, 0, 0),
    },
    legs(front=(13, 0, 0), hind=(-52, 82, -30)),
)


def sit_look(turn, tilt=0, wag=0):
    pose = dict(SIT)
    pose["Neck"] = (0, 0, turn * 0.4)
    pose["Head_0"] = (10, tilt, turn * 0.6)
    pose["Ear_Left_0"] = (0, -tilt * 0.6, 0)
    pose["Ear_Right_0"] = (0, -tilt * 0.6, 0)
    pose["Tail_0"] = (20, 0, wag)
    pose["Tail_1"] = (0, 0, wag * 0.6)
    return pose


def _sit(rig):  # 4.0 s = frames 1-121
    timeline(rig, [
        (1, {}),
        (8, merge({"Pelvis": ((4, 0, 0), (0, -0.01, 0.0))}, legs(hind=(-8, 10, 0)))),  # shifts forward, gathers
        (20, merge(SIT, {"Pelvis": ((-26, 0, 0), (0, 0.0, -0.16))})),  # down a touch past
        (26, SIT),
        (40, sit_look(28, 0, 18)),
        (52, sit_look(30, 0, -18)),
        (66, sit_look(-28, 0, 18)),
        (78, sit_look(-30, 0, -18)),
        (90, sit_look(0, 22, 10)),  # a curious head tilt
        (100, sit_look(0, 20, -10)),
        (106, SIT),
        (114, merge({"Pelvis": ((3, 0, 0), (0, 0, 0.01))}, legs(hind=(6, -8, 0)))),  # up, a little past
        (121, {}),
    ])


# --- sniff ---------------------------------------------------------------------------------------------------------
# He has almost no neck, so the nose goes down mostly by lowering his whole front (front legs bent, back tipped
# forward): a head tipped further opened the skin between the back of his skull and his back
NOSE_DOWN = merge(
    {
        "Pelvis": ((10, 0, 0), (0, 0, -0.03)),
        "Spine_0": (6, 0, 0),
        "Spine_1": (8, 0, 0),
        "Neck": (10, 0, 0),
        "Head_0": (14, 0, 0),
        "Ear_Left_0": (-6, 0, 0),
        "Ear_Right_0": (-6, 0, 0),
        "Tail_0": (-12, 0, 0),
    },
    legs(front=(-40, 62, -22), hind=(-12, 14, -2)),
)


def sniff_at(turn, nod=0):
    pose = dict(NOSE_DOWN)
    pose["Neck"] = (10, 0, turn * 0.5)
    pose["Head_0"] = (14 + nod, 0, turn * 0.5)
    pose["Tail_0"] = (-10, 0, turn * 0.8)
    return pose


def _sniff(rig):  # 3.0 s = frames 1-91
    keys = [(1, {}), (12, sniff_at(0, 4)), (16, sniff_at(0))]
    # little sniffs, the nose working along the ground from his left to his right and back
    for i, turn in enumerate((14, 18, 10, 0, -10, -18, -14, -4)):
        frame = 20 + i * 6
        keys.append((frame, sniff_at(turn, 3 if i % 2 == 0 else -1)))
    keys += [
        (72, sniff_at(-2, 2)),
        (78, merge({"Neck": (-8, 0, 0), "Head_0": (-10, 0, 0), "Ear_Left_0": (12, 0, 0), "Ear_Right_0": (12, 0, 0),
                    "Tail_0": (-15, 0, 0)})),  # looks up, ears flop
        (84, {"Head_0": (3, 0, 0), "Ear_Left_0": (-6, 0, 0), "Ear_Right_0": (-6, 0, 0)}),
        (91, {}),
    ]
    timeline(rig, keys)


# --- bark ----------------------------------------------------------------------------------------------------------
BARK_DIP = merge(
    {
        "Pelvis": ((4, 0, 0), (0, 0.01, -0.025)),
        "Spine_1": (6, 0, 0),
        "Neck": (8, 0, 0),
        "Head_0": (10, 0, 0),
        "Ear_Left_0": (-8, 0, 0),
        "Ear_Right_0": (-8, 0, 0),
    },
    legs(front=(-6, 10, -4), hind=(-6, 10, -4)),
)


def bark_open(strength=1.0):
    return merge(
        {
            "Pelvis": ((-7 * strength, 0, 0), (0, -0.015 * strength, 0.015 * strength)),
            "Spine_1": (-6 * strength, 0, 0),
            "Neck": (-6 * strength, 0, 0),
            "Head_0": (-8 * strength, 0, 0),
            "Jaw_0": (38 * strength, 0, 0),
            "Ear_Left_0": (8 * strength, -7 * strength, 0),  # ears flick up and out (more stretched the cheek)
            "Ear_Right_0": (8 * strength, 7 * strength, 0),
            "Tail_0": (-25, 0, 20),
            "Tail_1": (0, 0, 15),
        },
        legs(front=(-8 * strength, 0, 0), hind=(4, 0, 0)),
    )


def bark_shut():
    return merge(
        {
            "Pelvis": ((1, 0, 0), (0, 0, -0.005)),
            "Neck": (-4, 0, 0),
            "Head_0": (-2, 0, 0),
            "Jaw_0": (2, 0, 0),
            "Ear_Left_0": (-6, 0, 0),
            "Ear_Right_0": (-6, 0, 0),
            "Tail_0": (-25, 0, -20),
            "Tail_1": (0, 0, -15),
        },
        legs(front=(-2, 0, 0)),
    )


def _bark(rig):  # 2.2 s = frames 1-67; barks open at frames 13, 25, 37
    timeline(rig, [
        (1, {}),
        (9, BARK_DIP),
        (13, bark_open(1.0)),
        (18, bark_shut()),
        (25, bark_open(0.9)),
        (30, bark_shut()),
        (37, bark_open(1.1)),
        (44, bark_shut()),
        (54, {"Head_0": (3, 0, 0), "Ear_Left_0": (-4, 0, 0), "Ear_Right_0": (-4, 0, 0), "Tail_0": (-10, 0, 8)}),
        (67, {}),
    ])


# --- roll ----------------------------------------------------------------------------------------------------------
LIE = merge(
    {
        "Pelvis": ((0, 0, 0), (0, 0, -0.17)),
        "Neck": (-6, 0, 0),
        "Head_0": (2, 0, 0),
        "Tail_0": (20, 0, 10),
    },
    legs(front=(-70, 30, -10), hind=(-55, 90, -30)),
)


def on_side(roll, lift):
    """Rolled `roll` degrees onto his left side (180: on his back), the head rolling over with him (held upright, his
    ears pulled at his shoulders)"""
    pose = merge(
        {
            "Pelvis": ((0, roll, 0), (0, 0, -0.17 + lift)),
            "Neck": (0, -roll * 0.1, 0),
            "Head_0": (0, -roll * 0.08, 0),
            "Tail_0": (20, 0, 0),
        },
        legs(front=(-50, 60, -20), hind=(-40, 70, -20)),
    )
    return pose


def paws_up(wiggle):
    pose = on_side(170, 0.06)
    pose["Spine_0"] = (0, 0, wiggle * 6)
    pose["Spine_1"] = (0, 0, -wiggle * 6)
    pose.update(legs(
        left_front=(-45 - 15 * wiggle, 50, -20), right_front=(-45 + 15 * wiggle, 50, -20),
        left_hind=(-35 + 12 * wiggle, 60, -20), right_hind=(-35 - 12 * wiggle, 60, -20),
    ))
    pose["Head_0"] = (0, -170 * 0.08, wiggle * 8)
    pose["Tail_0"] = (20, 0, wiggle * 25)
    return pose


def _roll(rig):  # 4.4 s = frames 1-133
    keys = [
        (1, {}),
        (14, merge(LIE, {"Pelvis": ((0, 0, 0), (0, 0, -0.19))})),
        (20, LIE),
        (32, on_side(90, 0.03)),
        (42, paws_up(0)),
    ]
    for i in range(6):  # paws in the air, wiggling on his back
        keys.append((48 + i * 8, paws_up(1 if i % 2 == 0 else -1)))
    keys += [
        (96, paws_up(0)),
        (106, on_side(90, 0.03)),
        (116, LIE),
        (126, merge({"Pelvis": ((2, 0, 0), (0, 0, 0.01))}, legs(front=(4, -4, 0), hind=(4, -6, 0)))),
        (133, {}),
    ]
    timeline(rig, keys)


# name -> (keying, last frame, markers)
CLIPS = {
    "sit": (_sit, 121, {}),
    "sniff": (_sniff, 91, {}),
    "bark": (_bark, 67, {"Bark1": round(12 / kit.FPS, 3), "Bark2": round(24 / kit.FPS, 3), "Bark3": round(36 / kit.FPS, 3)}),
    "roll": (_roll, 133, {}),
}


def key(name):
    import bpy
    rig = kit.armature()
    kit.reset(rig)
    keying, last, _ = CLIPS[name]
    keying(rig)
    bpy.context.scene.frame_start, bpy.context.scene.frame_end = 1, last
    return rig, last


def preview(name, last, count=8):
    """A strip of `count` frames from the front three-quarter view: assets/blender/Pish/preview_<name>.png"""
    import bpy
    from mathutils import Vector

    scene = bpy.context.scene
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.display.shading.light = "STUDIO"
    scene.display.shading.color_type = "TEXTURE"
    scene.display.shading.background_type = "VIEWPORT"
    scene.display.shading.background_color = (0.55, 0.62, 0.7)
    scene.render.resolution_x, scene.render.resolution_y = 360, 360
    scene.render.film_transparent = False
    cam = bpy.data.objects.get("PreviewCam") or bpy.data.objects.new("PreviewCam", bpy.data.cameras.new("PreviewCam"))
    if cam.name not in scene.collection.objects:
        scene.collection.objects.link(cam)
    scene.camera = cam
    cam.data.lens = 50
    target = Vector((0, -0.05, 0.42))
    # From his left, a little in front and above: sitting, lying and rolling read from the side
    cam.location = target + Vector((1.0, -0.45, 0.35)).normalized() * 2.6
    cam.rotation_euler = (target - cam.location).to_track_quat("-Z", "Y").to_euler()
    frames = [1 + round(i * (last - 1) / (count - 1)) for i in range(count)]
    paths = []
    for frame in frames:
        scene.frame_set(frame)
        path = os.path.join(FOLDER, f"_frame_{frame}.png")
        scene.render.filepath = path
        bpy.ops.render.render(write_still=True)
        paths.append(path)
    strip = bpy.data.images.new(f"strip_{name}", 360 * count, 360)
    pixels = []
    images = [bpy.data.images.load(p) for p in paths]
    import numpy as np
    rows = np.concatenate([np.array(img.pixels[:]).reshape(360, 360, 4) for img in images], axis=1)
    strip.pixels[:] = rows.ravel()
    out = os.path.join(FOLDER, f"preview_{name}.png")
    strip.filepath_raw = out
    strip.file_format = "PNG"
    strip.save()
    for img, p in zip(images, paths):
        bpy.data.images.remove(img)
        os.remove(p)
    print("preview", out, frames)


def make_all():
    only = os.environ.get("CLIP")
    for name, (_, last, markers) in CLIPS.items():
        if only and name != only:
            continue
        rig, _ = key(name)
        print("exported", kit.export_clip(rig, name, 1, last, JSON_DIR, markers))
        if os.environ.get("PREVIEW", "1") == "1":
            preview(name, last)


if __name__ == "__main__":
    make_all()
