"""Pish's idle clips (the tutorial's guide puppy; owner 2026-11-09: "a lot of random high quality animation, like
sitting, sniffing, barking, rolling on the ground, digging"), keyed with anim_bone_kit on assets/blender/Pish/Pish.blend
(rig_pish.py) and exported for Roblox (docs/animations.md "Bone rigs"). Each starts and ends at rest, so the game can
play any of them at random while he waits.

  sit    4.0 s  sits down, looks left, right, tilts his head, wags, stands up
  sniff  3.0 s  nose down, sniffs left and right along the ground, looks up
  bark   2.2 s  dips, then three barks, head thrown up, mouth open; markers Bark1..Bark3 for the sound
  roll   4.4 s  lies down, rolls onto his back, paws in the air wiggling, rolls back and gets up
  dig          3.0 s  front down, back end up, front paws scraping fast; DigStart / DigEnd for the dirt
  shake        1.8 s  a wet-dog shake rolling from his head to his tail
  playBow      2.4 s  front down, rear up, tail going, two bounces, pops back up; Bark1
  headTilt     2.2 s  a curious tilt one way, then the other
  yawnStretch  3.6 s  stretches forward low with a big yawn, then each back leg; Yawn
  nap          5.4 s  lies down, chin on his paws, breathes slowly, wakes and gets up
  tailChase    2.8 s  turns round once chasing his tail, a dizzy wobble
  happyHop     2.0 s  two happy hops, tail wagging
  scratch      3.2 s  sits and scratches behind his ear with a back leg
  petted       2.4 s  leans into a pat, wiggles all over, a little hop (being petted)
  point        1.8 s  lifts a front paw toward something ahead and barks once (the tutorial's "over there"); Bark1
  celebrate    2.2 s  a jump with a full spin, a bark as he lands; Bark1

He has almost no neck and a big head: the head only tips a little (more opened the skin behind his skull) and the
ears move a few degrees; the nose goes down by lowering his whole front (tools/blender/check_stretch.py checks it).

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


# --- the rest of the idle set ----------------------------------------------------------------------------------------
def spun(degrees, centre=(0.0, 0.03)):
    """The Pelvis offset that keeps the body's middle in place while it turns `degrees` about the vertical (the
    Pelvis turns about its head, at his hips)"""
    a = math.radians(degrees)
    cx, cy = centre[0] - 0.0, centre[1] - 0.25
    return (cx - (cx * math.cos(a) - cy * math.sin(a)), cy - (cx * math.sin(a) + cy * math.cos(a)))


def body(tilt=0.0, turn=0.0, roll=0.0, up=0.0, forward=0.0, spin_centre=True):
    """The Pelvis: tilted (positive: front down), turned about the vertical round his middle, rolled, raised"""
    dx, dy = spun(turn) if spin_centre and turn else (0.0, 0.0)
    return {"Pelvis": ((tilt, roll, turn), (dx, dy - forward, up))}


FRONT_LOW = merge(  # front end down, rear up: the dig and the play bow start here
    body(tilt=16, up=-0.02),
    {"Spine_0": (4, 0, 0), "Spine_1": (6, 0, 0), "Head_0": (-10, 0, 0), "Tail_0": (-20, 0, 0)},
    legs(front=(-50, 80, -30), hind=(-14, 10, 4)),
)


def _dig(rig):  # 3.0 s = frames 1-91; scraping from frame 14 to 74
    keys = [(1, {}), (12, FRONT_LOW)]
    for i in range(10):
        reach, pull = (-75, 70, -10), (-25, 60, -40)
        left, right = (reach, pull) if i % 2 == 0 else (pull, reach)
        pose = merge(FRONT_LOW, legs(left_front=left, right_front=right, hind=(-14, 10, 4)),
                     {"Tail_0": (-20, 0, 18 if i % 2 == 0 else -18), "Head_0": (-10, 0, 4 if i % 2 == 0 else -4)})
        keys.append((14 + i * 6, pose))
    keys += [
        (80, merge(FRONT_LOW, {"Head_0": (-16, 0, 0)})),  # looks at the hole
        (91, {}),
    ]
    timeline(rig, keys)


def _shake(rig):  # 1.8 s = frames 1-55: the wave runs head first, the tail a beat behind
    keys = [(1, {}), (6, merge(body(up=-0.02), legs(front=(-6, 10, -4), hind=(-6, 10, -4))))]
    for i in range(8):
        side = 1 if i % 2 == 0 else -1
        fade = 1 - i / 10
        keys.append((9 + i * 4, merge(
            body(roll=side * 9 * fade, up=-0.02),
            {"Spine_0": (0, side * 7 * fade, -side * 8 * fade), "Spine_1": (0, side * 6 * fade, side * 10 * fade),
             "Neck": (0, 0, -side * 10 * fade), "Head_0": (0, side * 6 * fade, -side * 8 * fade),
             "Ear_Left_0": (0, -side * 6, 0), "Ear_Right_0": (0, -side * 6, 0),
             "Tail_0": (0, 0, side * 30 * fade), "Tail_1": (0, 0, side * 20 * fade)},
            legs(front=(-6, 10, -4), hind=(-6, 10, -4)),
        )))
    keys += [(46, {"Head_0": (-4, 0, 0)}), (55, {})]
    timeline(rig, keys)


BOW = merge(
    body(tilt=18, up=-0.03),
    {"Spine_0": (6, 0, 0), "Spine_1": (8, 0, 0), "Head_0": (-16, 0, 0), "Tail_0": (-30, 0, 0)},
    legs(front=(-58, 90, -32), hind=(-10, 6, 4)),
)


def _play_bow(rig):  # 2.4 s = frames 1-73; the bark at frame 40
    keys = [(1, {}), (10, BOW)]
    for i, frame in enumerate((16, 22, 28, 34)):  # tail going hard
        keys.append((frame, merge(BOW, {"Tail_0": (-30, 0, 28 if i % 2 == 0 else -28), "Tail_1": (0, 0, 15 if i % 2 == 0 else -15)})))
    keys += [
        (38, merge(BOW, body(tilt=12, up=0.0), {"Jaw_0": (34, 0, 0), "Head_0": (-20, 0, 0)})),  # bounce and bark
        (44, merge(BOW, {"Jaw_0": (0, 0, 0)})),
        (50, merge(BOW, body(tilt=12, up=0.0))),
        (56, BOW),
        (64, merge(body(tilt=-4, up=0.03), legs(front=(4, -6, 0), hind=(6, -8, 0)), {"Tail_0": (-20, 0, 10)})),  # pops up
        (73, {}),
    ]
    timeline(rig, keys)


def tilt_pose(side, amount=1.0):
    return {"Neck": (0, side * 6 * amount, side * 4 * amount), "Head_0": (-4 * amount, side * 16 * amount, side * 6 * amount),
            "Ear_Left_0": (0, -side * 4 * amount, 0), "Ear_Right_0": (0, -side * 4 * amount, 0), "Tail_0": (0, 0, side * 10)}


def _head_tilt(rig):  # 2.2 s = frames 1-67
    timeline(rig, [
        (1, {}),
        (10, tilt_pose(1, 1.1)),
        (14, tilt_pose(1)),
        (28, tilt_pose(1)),
        (38, tilt_pose(-1, 1.1)),
        (42, tilt_pose(-1)),
        (56, tilt_pose(-1, 0.6)),
        (67, {}),
    ])


STRETCH = merge(
    body(tilt=14, up=-0.04, forward=0.03),
    {"Spine_0": (5, 0, 0), "Spine_1": (8, 0, 0), "Head_0": (-14, 0, 0), "Tail_0": (-25, 0, 0)},
    legs(front=(-70, 60, -20), hind=(-6, 4, 2)),
)


def _yawn_stretch(rig):  # 3.6 s = frames 1-109; the yawn opens at frame 28
    timeline(rig, [
        (1, {}),
        (18, STRETCH),
        (28, merge(STRETCH, {"Jaw_0": (40, 0, 0), "Head_0": (-20, 0, 0), "Neck": (-4, 0, 0)})),
        (44, merge(STRETCH, {"Jaw_0": (42, 0, 0), "Head_0": (-22, 0, 0), "Neck": (-4, 0, 0)})),  # holds the yawn
        (54, STRETCH),
        (64, merge(body(tilt=-6, up=0.0), legs(left_hind=(24, -10, 10), right_hind=(-2, 2, 0)), {"Tail_0": (10, 0, 0)})),
        (76, merge(body(tilt=-6, up=0.0), legs(right_hind=(24, -10, 10), left_hind=(-2, 2, 0)), {"Tail_0": (10, 0, 0)})),
        (88, merge(body(tilt=-2), {"Head_0": (4, 0, 0)})),
        (100, {"Head_0": (-3, 0, 0)}),
        (109, {}),
    ])


NAP = merge(
    {"Pelvis": ((0, 0, 0), (0, 0, -0.17)), "Neck": (6, 0, 0), "Head_0": (8, 0, 0), "Tail_0": (24, 0, 14),
     "Ear_Left_0": (0, -4, 0), "Ear_Right_0": (0, 4, 0)},
    legs(front=(-70, 30, -10), hind=(-55, 90, -30)),
)


def _nap(rig):  # 5.4 s = frames 1-163: breathing every 30 frames
    keys = [(1, {}), (14, merge(LIE, {"Pelvis": ((0, 0, 0), (0, 0, -0.19))})), (22, LIE), (34, NAP)]
    for i in range(4):
        keys.append((44 + i * 24, merge(NAP, {"Pelvis": ((0, 0, 0), (0, 0, -0.16)), "Spine_0": (-2, 0, 0)})))
        keys.append((56 + i * 24, NAP))
    keys += [
        (140, merge(LIE, {"Head_0": (-6, 0, 0)})),  # wakes, looks up
        (152, merge({"Pelvis": ((2, 0, 0), (0, 0, 0.01))}, legs(front=(4, -4, 0), hind=(4, -6, 0)))),
        (163, {}),
    ]
    timeline(rig, keys)


def chase(turn):
    """Turned `turn` degrees round his middle, head and tail curled toward each other (he chases it to his left)"""
    return merge(
        body(turn=turn),
        {"Spine_0": (0, 0, 10), "Spine_1": (0, 0, 12), "Neck": (0, 0, 14), "Head_0": (4, 0, 14),
         "Tail_0": (0, 0, -30), "Tail_1": (0, 0, -20)},
        legs(left_front=(-20, 20, 0), right_front=(10, 6, 0), left_hind=(12, 0, 0), right_hind=(-14, 10, 0)),
    )


def _tail_chase(rig):  # 2.8 s = frames 1-85: one turn to his left, keyed every 45 degrees, then a dizzy wobble
    keys = [(1, {}), (8, chase(0))]
    for i in range(1, 9):
        keys.append((8 + i * 6, chase(45 * i)))
    keys += [
        (62, merge(body(roll=6, turn=360), {"Head_0": (0, 10, 0)})),
        (70, merge(body(roll=-5, turn=360), {"Head_0": (0, -8, 0)})),
        (78, merge(body(turn=360), {"Head_0": (0, 3, 0)})),
        (85, body(turn=360)),
    ]
    timeline(rig, keys)


def _happy_hop(rig):  # 2.0 s = frames 1-61: two hops
    crouch = merge(body(up=-0.04), legs(front=(-12, 22, -8), hind=(-16, 26, -8)), {"Tail_0": (-15, 0, 0)})
    air = merge(body(tilt=-6, up=0.14), legs(front=(-24, 30, -10), hind=(18, -6, 10)), {"Tail_0": (-25, 0, 20), "Head_0": (-6, 0, 0)})
    land = merge(body(up=-0.03), legs(front=(-8, 14, -6), hind=(-10, 18, -6)), {"Tail_0": (-15, 0, -20)})
    timeline(rig, [
        (1, {}), (8, crouch), (14, air), (20, land), (25, crouch), (31, merge(air, {"Tail_0": (-25, 0, -20)})), (37, land),
        (46, merge(body(up=0.0), {"Tail_0": (-15, 0, 16), "Head_0": (-4, 0, 0)})), (54, {"Tail_0": (-10, 0, -10)}), (61, {}),
    ])


SIT_SCRATCH = merge(SIT, {"Neck": (0, 8, 10), "Head_0": (10, 14, 10)})


def _scratch(rig):  # 3.2 s = frames 1-97: sits, the left hind leg scratches up by his left ear
    keys = [(1, {}), (16, SIT), (24, merge(SIT_SCRATCH, legs(hind=(-52, 82, -30), left_hind=(-95, 60, -20))))]
    for i in range(10):
        up = i % 2 == 0
        keys.append((28 + i * 4, merge(SIT_SCRATCH, legs(hind=(-52, 82, -30),
                                                          left_hind=(-105 if up else -88, 66 if up else 52, -20)))))
    keys += [(72, SIT), (84, merge({"Pelvis": ((3, 0, 0), (0, 0, 0.01))}, legs(hind=(6, -8, 0)))), (97, {})]
    timeline(rig, keys)


def _petted(rig):  # 2.4 s = frames 1-73: leans up into the hand, wiggles, a hop
    lean = merge(body(tilt=-6, up=0.01), {"Neck": (-6, 4, 0), "Head_0": (-10, 10, 0), "Tail_0": (-25, 0, 0)},
                 legs(front=(4, -2, 0), hind=(-4, 6, -2)))
    keys = [(1, {}), (10, lean)]
    for i in range(6):
        side = 1 if i % 2 == 0 else -1
        keys.append((14 + i * 5, merge(lean, body(tilt=-6, roll=side * 5, up=0.01),
                                       {"Spine_0": (0, 0, side * 6), "Spine_1": (0, 0, -side * 6),
                                        "Head_0": (-10, 10 - side * 6, 0), "Tail_0": (-25, 0, side * 30), "Tail_1": (0, 0, side * 20)})))
    keys += [
        (46, merge(body(up=-0.03), legs(front=(-10, 18, -6), hind=(-12, 20, -6)))),
        (52, merge(body(tilt=-4, up=0.1), legs(front=(-20, 24, -8), hind=(14, -4, 8)), {"Tail_0": (-25, 0, 20)})),
        (58, merge(body(up=-0.02), legs(front=(-6, 10, -4), hind=(-8, 12, -4)))),
        (73, {}),
    ]
    timeline(rig, keys)


POINT = merge(
    body(tilt=-4),
    {"Neck": (-4, 0, 0), "Head_0": (-4, 0, 0), "Tail_0": (-28, 0, 0)},
    legs(right_front=(-62, 46, -10), left_front=(4, 0, 0), hind=(-4, 4, 0)),
)


def _point(rig):  # 1.8 s = frames 1-55; the bark at frame 22
    timeline(rig, [
        (1, {}),
        (10, POINT),
        (16, merge(POINT, {"Head_0": (2, 0, 0)})),  # a little nod toward it
        (22, merge(POINT, {"Jaw_0": (34, 0, 0), "Head_0": (-8, 0, 0)})),
        (27, POINT),
        (36, merge(POINT, {"Tail_0": (-28, 0, 18)})),
        (44, merge(POINT, {"Tail_0": (-28, 0, -18)})),
        (55, {}),
    ])


def _celebrate(rig):  # 2.2 s = frames 1-67: a jump with a full turn, a bark as he lands (frame 38)
    crouch = merge(body(up=-0.05), legs(front=(-14, 24, -8), hind=(-18, 30, -10)), {"Tail_0": (-20, 0, 0)})
    tuck = legs(front=(-30, 40, -10), hind=(20, -4, 10))
    keys = [(1, {}), (9, crouch)]
    for i, (frame, up) in enumerate(((14, 0.12), (19, 0.22), (24, 0.25), (29, 0.2), (33, 0.08))):
        keys.append((frame, merge(body(tilt=-6, turn=72 * (i + 1), up=up), tuck, {"Tail_0": (-25, 0, 20)})))
    keys += [
        (36, merge(body(turn=360, up=-0.04), legs(front=(-10, 18, -6), hind=(-12, 20, -6)))),
        (40, merge(body(turn=360, up=-0.01), {"Jaw_0": (36, 0, 0), "Head_0": (-10, 0, 0), "Tail_0": (-25, 0, 22)})),
        (46, merge(body(turn=360), {"Tail_0": (-20, 0, -22)})),
        (54, merge(body(turn=360), {"Tail_0": (-15, 0, 16)})),
        (67, body(turn=360)),
    ]
    timeline(rig, keys)


# name -> (keying, last frame, markers)
CLIPS = {
    "sit": (_sit, 121, {}),
    "sniff": (_sniff, 91, {}),
    "bark": (_bark, 67, {"Bark1": round(12 / kit.FPS, 3), "Bark2": round(24 / kit.FPS, 3), "Bark3": round(36 / kit.FPS, 3)}),
    "roll": (_roll, 133, {}),
    "dig": (_dig, 91, {"DigStart": round(13 / kit.FPS, 3), "DigEnd": round(73 / kit.FPS, 3)}),
    "shake": (_shake, 55, {}),
    "playBow": (_play_bow, 73, {"Bark1": round(37 / kit.FPS, 3)}),
    "headTilt": (_head_tilt, 67, {}),
    "yawnStretch": (_yawn_stretch, 109, {"Yawn": round(27 / kit.FPS, 3)}),
    "nap": (_nap, 163, {}),
    "tailChase": (_tail_chase, 85, {}),
    "happyHop": (_happy_hop, 61, {}),
    "scratch": (_scratch, 97, {}),
    "petted": (_petted, 73, {}),
    "point": (_point, 55, {"Bark1": round(21 / kit.FPS, 3)}),
    "celebrate": (_celebrate, 67, {"Bark1": round(39 / kit.FPS, 3)}),
}


def continuous(rig):
    """Keeps each bone's rotation keys on one side of the quaternion sphere (a full turn keyed at 360 degrees came out
    as the unturned quaternion, and the curve between went back the long way)"""
    import anim_kit

    curves = {}
    for fc in anim_kit.fcurves_of(rig):
        if fc.data_path.endswith("rotation_quaternion"):
            curves.setdefault(fc.data_path, {})[fc.array_index] = fc
    for parts in curves.values():
        if len(parts) < 4:
            continue
        points = [parts[i].keyframe_points for i in range(4)]
        previous = None
        for k in range(len(points[0])):
            q = [points[i][k].co[1] for i in range(4)]
            if previous and sum(a * b for a, b in zip(previous, q)) < 0:
                q = [-v for v in q]
                for i in range(4):
                    points[i][k].co[1] = q[i]
                    points[i][k].handle_left[1] = -points[i][k].handle_left[1]
                    points[i][k].handle_right[1] = -points[i][k].handle_right[1]
            previous = q
        for i in range(4):
            parts[i].update()


def key(name):
    import bpy
    rig = kit.armature()
    kit.reset(rig)
    keying, last, _ = CLIPS[name]
    keying(rig)
    continuous(rig)
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
