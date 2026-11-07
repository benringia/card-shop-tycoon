"""The spear moveset's moves (Config/Swords spear, weapons round 2; the owner's storyboard 2026-11-07, spec
2026-11-07-weapons-round2-design 5.2), keyed on anim_kit's rig with the spear prop (PROP) at the spear grip.

    "C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" -b --factory-startup --python tools/blender/run_sword_moves.py -- --sword spear [--preview <dir>] [move ...]

JSON goes to assets/blender/Animations/Spear, then `lune run tools/anim/build_kfs assets/blender/Animations/Spear
assets/animations/Spear`. Each attack's "Hit" marker is its strike frame and matches Config/Swords spear (hitAt, length).

How the spear points: the grip (anim_kit.hand_grip("spear"), angleX -90) makes a hanging arm hold it straight ahead, and
its pitch (degrees up from straight ahead) is about the sum of the shoulder's, the elbow's and the wrist's x angles
(arm() picks the wrist for a wanted pitch). Its yaw comes from turning the body (R, W). The spear is held upright at
the right side between moves (the owner's pick C); every attack swings it down into both hands first (two_hands, the
left hand up the shaft).
"""
import importlib
import math
import os

import anim_kit as kit

importlib.reload(kit)
FOOT_Z = kit.FOOT_Z
PROP = "spear"
FOLDER = "Spear"
LEFT_ALONG = 1.5  # studs up the shaft from the right hand to the left (two hands)

NATURAL = ("cut1", "cut2", "cut3", "skill")


def arm(rs, re, pitch, rwz=0):
    """The right arm with the shoulder at `rs` (x, y, z), the elbow bent `re`, and the wrist set so the spear points
    `pitch` degrees up from straight ahead (90: upright, -90: straight down)."""
    return {"RS": rs, "RE": (re, 0, 0), "RW": (pitch - rs[0] - re, 0, rwz)}


LEFT_FREE = {"LS": (8, 0, -8), "LE": (20, 0, 0)}
# Upright at the right side, the butt by the right foot (pick C)
READY = dict(arm((-4, 0, 14), 64, 88, -12), **LEFT_FREE)


# The body's overlap without the sword's arm lag: the right shoulder, elbow and wrist aim the spear together (a lagging
# wrist pointed it up on every snap), so only the waist, the neck and the free left arm trail
LAG_SPEAR = {"W": 1, "N": 2, "LS": 1, "LE": 2, "LW": 2}


def _pose(rig, f, t, p, lift, ease=kit.SOFT):
    kit.key_pose(rig, kit.frame_at(f, t), p, lift, ease, LAG_SPEAR)


def _root(rig, f, t, forward, ease=kit.SOFT):
    kit.key_root(rig, kit.frame_at(f, t), forward, 0.0, ease)


def _foot(side, f, t, pos, ease=kit.SOFT):
    kit.key_foot(side, kit.frame_at(f, t), pos, ease)


def _feet(f, t, right, left, ease=kit.SOFT):
    _foot("Right", f, t, (-0.5, -right, FOOT_Z), ease)
    _foot("Left", f, t, (0.5, -left, FOOT_Z), ease)


def _both(rig, f, on, full, release, off):
    kit.two_hands(rig, lambda t: kit.frame_at(f, t), on, full, release, off, along=LEFT_ALONG, family="spear")


def _body(r, w, n):
    """The hips (R), waist (W) and neck (N) angles."""
    return {"R": r, "W": w, "N": n}


def _spin_feet(f, t, yaw, travel=0.0, lift=0.0, ease=kit.SOFT):
    """Both feet round the body turned `yaw` degrees (a spin), `travel` studs forward and `lift` up."""
    a = math.radians(yaw)
    for side, sx in (("Right", -0.5), ("Left", 0.5)):
        _foot(side, f, t, (sx * math.cos(a), -travel + sx * math.sin(a), FOOT_Z + lift), ease)


def _cut1(rig, f):
    """Thrust (exaggerated, owner 2026-11-07): swung down into both hands and coiled far back, the body wound and low,
    then exploding forward into a deep lunge, both arms out long and the body leaning into it; a held push and back up
    to upright."""
    _pose(rig, f, 0, READY, 0)
    _pose(rig, f, 0.10, dict(_body((0, 30, 0), (12, 26, 0), (0, -26, 0)), **arm((-45, 0, 8), 42, 4)), -0.55)
    _pose(rig, f, 0.16, dict(_body((0, 34, 0), (14, 30, 0), (0, -30, 0)), **arm((-52, 0, 8), 44, 2)), -0.62, kit.SNAP)
    _pose(rig, f, 0.22, dict(_body((0, -10, 0), (-16, -12, 0), (8, 12, 0)), **arm((82, 0, 3), 0, -2)), -0.8, kit.SNAP)
    _pose(rig, f, 0.32, dict(_body((0, -12, 0), (-18, -14, 0), (8, 14, 0)), **arm((86, 0, 3), 0, -4)), -0.84)
    _pose(rig, f, 0.46, dict(_body((0, -4, 0), (-4, -4, 0), (0, 4, 0)), **arm((24, 0, 10), 44, 55)), -0.3)
    _pose(rig, f, 0.62, READY, 0)
    _both(rig, f, 0.04, 0.10, 0.36, 0.46)
    _root(rig, f, 0, 0)
    _root(rig, f, 0.16, -0.45, kit.SNAP)
    _root(rig, f, 0.22, 2.0)
    _feet(f, 0, 0, 0)
    _feet(f, 0.10, 0.6, -0.5)
    _foot("Left", f, 0.16, (0.5, 0.5, 0.45), kit.SNAP)
    _foot("Left", f, 0.22, (0.6, -3.2, FOOT_Z))
    _foot("Right", f, 0.22, (-0.55, 0.6, FOOT_Z))
    _feet(f, 0.62, 2.0, 2.0)


def _cut2(rig, f):
    """Sweep (exaggerated, owner 2026-11-07): pulled back low with the body wound right, then a full spin on the spot,
    the head slicing across the front at hip height (the Hit) and on round behind, a low finish facing front again, back
    up to upright."""
    _pose(rig, f, 0, READY, 0)
    _pose(rig, f, 0.08, dict(_body((0, 55, 0), (12, 40, 0), (0, -40, 0)), **arm((-15, 0, 14), 22, -4)), -0.6)
    _pose(rig, f, 0.12, dict(_body((0, 60, 0), (14, 44, 0), (0, -44, 0)), **arm((-18, 0, 14), 22, -6)), -0.65, kit.SNAP)
    spin = [(0.20, -10, kit.SNAP), (0.28, -150, kit.HOLD), (0.36, -270, kit.HOLD), (0.44, -345, kit.SOFT)]
    for t, yaw, ease in spin:
        _pose(rig, f, t, dict(_body((0, yaw, 0), (8, -30, 0), (0, 24, 0)), **arm((16, 0, 26), 10, -4)), -0.6, ease)
        _spin_feet(f, t, yaw, 0.4, 0.0, ease)
    _pose(rig, f, 0.52, dict(_body((0, -360, 0), (6, -16, 0), (0, 10, 0)), **arm((12, 0, 18), 40, 50)), -0.3)
    _pose(rig, f, 0.62, dict(READY, R=(0, -360, 0)), 0)
    _both(rig, f, 0.03, 0.08, 0.44, 0.52)
    _root(rig, f, 0, 0)
    _root(rig, f, 0.12, 0, kit.SNAP)
    _root(rig, f, 0.36, 0.4)
    _feet(f, 0, 0, 0)
    _foot("Right", f, 0.08, (-0.8, 0.4, FOOT_Z))
    _foot("Left", f, 0.08, (0.6, -0.3, FOOT_Z))
    _spin_feet(f, 0.62, -360, 0.4)


# Sky Pierce's air poses: the spear raised high in both hands, upright (the tip up), then swung down tip-first
RAISED = dict({"W": (-14, 0, 0), "N": (-8, 0, 0)}, **arm((165, 0, -10), 20, 95))
HANG = dict({"W": (-26, 0, 0), "N": (-16, 0, 0)}, **arm((174, 0, -8), 14, 104))
# Landing: crouched low over the spear driven tip-first into the ground ahead, both hands on it
PLUNGE = dict({"W": (-34, 0, 0), "N": (-26, 0, 0)}, **arm((74, 0, 4), 8, -62))


def _cut3(rig, f):
    """Sky Pierce (finisher, exaggerated, owner 2026-11-07): a deep crouch with the spear swung up, a big leap (about 6
    studs) spinning a full turn with it held high, a slow hang at the top, then a fall that drives it tip-first into the
    ground ahead (the Hit), crouched low over it with a bounce, and a pull out back up to upright. Slower, so it hits
    hardest (the damage a second stays)."""
    _pose(rig, f, 0, READY, 0)
    _pose(rig, f, 0.12, dict({"W": (32, 0, 0), "N": (12, 0, 0)}, **arm((60, 0, -6), 70, 95)), -1.2)
    _pose(rig, f, 0.17, dict({"W": (34, 0, 0), "N": (14, 0, 0)}, **arm((70, 0, -6), 70, 98)), -1.25, kit.SNAP)
    air = [
        (0.24, -110, 2.8, RAISED, kit.HOLD, 0.8),
        (0.31, -220, 5.2, HANG, kit.HOLD, 1.3),
        (0.44, -300, 5.9, HANG, kit.HOLD, 1.7),
        (0.56, -350, 5.2, dict(HANG, **arm((150, 0, -8), 10, 60)), ("EXPO", "EASE_IN"), 2.2),
    ]
    for t, yaw, lift, pose, ease, travel in air:
        _pose(rig, f, t, dict(pose, R=(0, yaw, 0)), lift, ease)
        tuck = 0.6 if t < 0.5 else 0.35
        _spin_feet(f, t, yaw, travel, lift - tuck - 0.2, kit.HOLD)
    _pose(rig, f, 0.70, dict(PLUNGE, R=(0, -360, 0)), -1.45, kit.SNAP)
    _pose(rig, f, 0.78, dict(PLUNGE, R=(0, -360, 0), W=(-30, 0, 0)), -1.25)
    _pose(rig, f, 0.88, dict(PLUNGE, R=(0, -360, 0), W=(-38, 0, 0), N=(-32, 0, 0)), -1.5)
    _pose(rig, f, 1.04, dict({"R": (0, -360, 0), "W": (-10, 0, 0), "N": (-6, 0, 0)}, **arm((50, 0, 8), 30, 30)), -0.7)
    _pose(rig, f, 1.25, dict(READY, R=(0, -360, 0)), 0)
    _both(rig, f, 0.05, 0.14, 1.02, 1.12)
    _root(rig, f, 0, 0)
    _root(rig, f, 0.17, -0.3, kit.HOLD)
    _root(rig, f, 0.31, 1.3, kit.HOLD)
    _root(rig, f, 0.56, 2.2, ("EXPO", "EASE_IN"))
    _root(rig, f, 0.70, 3.0, kit.SNAP)
    _feet(f, 0, 0, 0)
    _feet(f, 0.12, 0.5, -0.4)
    _feet(f, 0.17, 0.5, -0.4, kit.HOLD)
    _foot("Right", f, 0.70, (-0.6, -3.7, FOOT_Z), kit.SNAP)
    _foot("Left", f, 0.70, (0.65, -2.2, FOOT_Z), kit.SNAP)
    _feet(f, 1.04, 3.7, 2.4)
    _feet(f, 1.25, 3.0, 3.0)


def _skill(rig, f):
    """Piercing Rush: crouched low, the spear aimed straight ahead in both hands and drawn back, a moment's charge, then
    a rush 12 studs tip-first (the Hit as it arrives: every foe along the line), a skid to a stop and back up to
    upright."""
    aim = dict(_body((0, 18, 0), (24, 14, 0), (-14, -14, 0)), **arm((-30, 0, 8), 34, 2))
    lunge = dict(_body((0, -8, 0), (30, -10, 0), (-18, 8, 0)), **arm((70, 0, 4), 0, -4))
    _pose(rig, f, 0, READY, 0)
    _pose(rig, f, 0.15, aim, -0.9)
    _pose(rig, f, 0.28, dict(aim, W=(26, 16, 0)), -0.95, kit.SNAP)
    _pose(rig, f, 0.34, lunge, -0.75, kit.SNAP)
    _pose(rig, f, 0.45, dict(lunge, W=(32, -12, 0)), -0.8)
    _pose(rig, f, 0.66, dict(lunge, W=(24, -8, 0)), -0.7)
    _pose(rig, f, 0.82, dict({"W": (6, 0, 0)}, **arm((20, 0, 12), 40, 60)), -0.3)
    _pose(rig, f, 1.0, READY, 0)
    _both(rig, f, 0.05, 0.15, 0.7, 0.82)
    _root(rig, f, 0, 0)
    _root(rig, f, 0.28, -0.3, kit.SNAP)
    _root(rig, f, 0.42, 12.0)
    _feet(f, 0, 0, 0)
    _feet(f, 0.15, 0.9, -0.7)
    _feet(f, 0.28, 0.9, -0.7, kit.SNAP)
    _foot("Right", f, 0.34, (-0.5, -6.0, 0.4), kit.SNAP)
    _foot("Left", f, 0.34, (0.5, -4.5, 0.5), kit.SNAP)
    _foot("Right", f, 0.42, (-0.5, -11.0, FOOT_Z))
    _foot("Left", f, 0.42, (0.6, -13.4, FOOT_Z))
    _feet(f, 0.66, 11.0, 13.4)
    _feet(f, 1.0, 12.0, 12.0)


def _ready(rig, f):
    """Upright at the right side while drawn (upper body only: Roblox's idle and walk keep the legs), breathing."""
    F = lambda t: kit.frame_at(f, t)  # noqa: E731
    kit.key_pose(rig, F(0), READY)
    kit.key_pose(rig, F(0.9), dict(READY, W=(3, 0, 0), N=(-2, 0, 0), **arm((-2, 0, 14), 66, 87, -12)))
    kit.key_pose(rig, F(1.8), READY)
    kit.key_root(rig, F(0), 0)
    kit.plant_feet(F(0))


def _draw(rig, f):
    """Reaching over the right shoulder for the spear on the back ("Grab"), swinging it round and down into the
    upright guard."""
    F = lambda t: kit.frame_at(f, t)  # noqa: E731
    kit.key_pose(rig, F(0), {})
    kit.key_pose(rig, F(0.16), {"W": (0, -12, 0), "N": (0, -12, 0), "RS": (165, 0, 18), "RE": (115, 0, 0), "RW": (0, 0, 0)}, 0)
    kit.key_pose(rig, F(0.32), dict({"W": (0, 8, 0), "N": (0, 4, 0)}, **arm((60, 0, 25), 40, 120)), -0.1)
    kit.key_pose(rig, F(0.50), READY, 0)
    kit.key_root(rig, F(0), 0)
    kit.plant_feet(F(0))
    kit.plant_feet(F(0.50))


def _sheath(rig, f):
    """The spear swung up and back over the right shoulder onto the back ("Release"), arms down."""
    F = lambda t: kit.frame_at(f, t)  # noqa: E731
    kit.key_pose(rig, F(0), READY)
    kit.key_pose(rig, F(0.25), {"W": (0, -10, 0), "N": (0, -10, 0), "RS": (168, 0, 16), "RE": (118, 0, 0)}, 0)
    kit.key_pose(rig, F(0.50), {}, 0)
    kit.key_root(rig, F(0), 0)
    kit.plant_feet(F(0))
    kit.plant_feet(F(0.50))


def _run(rig, f):
    """Running with the spear (upper body only, over Roblox's run): held at the right side tilted forward, the left arm
    pumping."""
    F = lambda t: kit.frame_at(f, t)  # noqa: E731
    spear = arm((10, 0, 14), 50, 55, -10)
    kit.key_pose(rig, F(0), dict(spear, LS=(38, 0, -6), LE=(70, 0, 0), W=(10, 8, 0), N=(-6, -6, 0)))
    kit.key_pose(rig, F(0.33), dict(spear, LS=(-30, 0, -6), LE=(40, 0, 0), W=(10, -8, 0), N=(-6, 6, 0)))
    kit.key_pose(rig, F(0.66), dict(spear, LS=(38, 0, -6), LE=(70, 0, 0), W=(10, 8, 0), N=(-6, -6, 0)))
    kit.key_root(rig, F(0), 0)
    kit.plant_feet(F(0))


# name -> (keying function, length in seconds, loop, markers, upper body only, priority)
MOVES = {
    "cut1": (_cut1, 0.62, False, [{"name": "Hit", "t": 0.22}], False, "Action"),
    "cut2": (_cut2, 0.62, False, [{"name": "Hit", "t": 0.20}], False, "Action"),
    "cut3": (_cut3, 1.25, False, [{"name": "Hit", "t": 0.70}], False, "Action"),
    "skill": (_skill, 1.0, False, [{"name": "Hit", "t": 0.45}], False, "Action"),
    "draw": (_draw, 0.50, False, [{"name": "Grab", "t": 0.16}], True, "Action"),
    "sheath": (_sheath, 0.50, False, [{"name": "Release", "t": 0.25}], True, "Action"),
    "ready": (_ready, 1.80, True, [], True, "Movement"),
    "run": (_run, 0.66, True, [], True, "Movement"),
}
# The spear's previews: framed for its height (the leap and the rush need more room)
PREVIEW_VIEWS = {
    "default": {"front": ((10.0, -17.0, 6.0), (0, -1.5, 3.6)), "side": ((18.0, -1.5, 5.0), (0, -1.5, 3.6))},
    "skill": {"front": ((14.0, -26.0, 8.0), (0, -6.0, 3.0)), "side": ((26.0, -6.0, 5.5), (0, -6.0, 3.0))},
    "cut3": {"front": ((15.0, -22.0, 9.5), (0, -2.0, 5.0)), "side": ((27.0, -2.0, 8.0), (0, -2.0, 5.0))},
}


def make(name, json_dir, render_dir=None):
    """Builds, keys and exports one move (with the spear prop); renders front and side frames when render_dir is given."""
    fn, length, loop, markers, upper, priority = MOVES[name]
    rig = kit.build(PROP)
    first = 1
    fn(rig, first)
    natural = name in NATURAL
    if natural:
        kit.apply_eases(rig)
    last = kit.frame_at(first, length)
    kit.bpy.context.scene.frame_start, kit.bpy.context.scene.frame_end = first, last
    count = kit.export_move(rig, os.path.join(json_dir, name + ".json"), name, first, last, loop, kit.UPPER_BODY if upper else None, markers, priority,
                            in_place=natural, step=1 if natural else None)
    if render_dir:
        frames = list(range(first, last + 1, kit.EXPORT_STEP))
        views = PREVIEW_VIEWS.get(name, PREVIEW_VIEWS["default"])
        kit.render_frames(os.path.join(render_dir, name, "front"), frames, *views["front"])
        kit.render_frames(os.path.join(render_dir, name, "side"), frames, *views["side"])
    return count
