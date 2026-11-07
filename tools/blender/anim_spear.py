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


def _cut1(rig, f):
    """Thrust: swung down from upright into both hands at the hip, drawn back with the hips turned, then a straight stab
    ahead with a step, the arms out long; a short hold and back up to upright."""
    _pose(rig, f, 0, READY, 0)
    _pose(rig, f, 0.10, dict(_body((0, 14, 0), (6, 10, 0), (0, -12, 0)), **arm((-25, 0, 8), 30, 2)), -0.35)
    _pose(rig, f, 0.16, dict(_body((0, 18, 0), (8, 12, 0), (0, -14, 0)), **arm((-32, 0, 8), 28, 0)), -0.4, kit.SNAP)
    _pose(rig, f, 0.22, dict(_body((0, -6, 0), (-6, -8, 0), (0, 10, 0)), **arm((62, 0, 4), 4, -2)), -0.5, kit.SNAP)
    _pose(rig, f, 0.34, dict(_body((0, -7, 0), (-8, -9, 0), (0, 11, 0)), **arm((66, 0, 4), 2, -3)), -0.52)
    _pose(rig, f, 0.46, dict(_body((0, -6, 0), (0, -8, 0), (0, 6, 0)), **arm((20, 0, 10), 40, 50)), -0.2)
    _pose(rig, f, 0.62, READY, 0)
    _both(rig, f, 0.04, 0.10, 0.36, 0.46)
    _root(rig, f, 0, 0)
    _root(rig, f, 0.16, -0.2, kit.SNAP)
    _root(rig, f, 0.22, 1.2)
    _feet(f, 0, 0, 0)
    _feet(f, 0.10, 0.4, -0.3)
    _foot("Left", f, 0.16, (0.5, 0.3, 0.35), kit.SNAP)
    _foot("Left", f, 0.22, (0.55, -1.9, FOOT_Z))
    _foot("Right", f, 0.22, (-0.5, 0.2, FOOT_Z))
    _feet(f, 0.62, 1.2, 1.2)


def _cut2(rig, f):
    """Sweep: pulled back low with the body turned right, the head trailing behind; the hips and waist unwind and the
    head sweeps across the front from right to left at hip height; follow through, back up to upright."""
    _pose(rig, f, 0, READY, 0)
    _pose(rig, f, 0.08, dict(_body((0, 42, 0), (10, 48, 0), (0, -40, 0)), **arm((-15, 0, 12), 22, -4)), -0.5)
    _pose(rig, f, 0.13, dict(_body((0, 46, 0), (12, 52, 0), (0, -44, 0)), **arm((-18, 0, 12), 22, -6)), -0.55, kit.SNAP)
    _pose(rig, f, 0.20, dict(_body((0, -28, 0), (8, -42, 0), (0, 30, 0)), **arm((14, 0, 22), 10, -4)), -0.5, kit.SNAP)
    _pose(rig, f, 0.30, dict(_body((0, -36, 0), (6, -60, 0), (0, 40, 0)), **arm((22, 0, 28), 12, 0)), -0.45)
    _pose(rig, f, 0.44, dict(_body((0, -14, 0), (2, -20, 0), (0, 12, 0)), **arm((10, 0, 16), 45, 55)), -0.2)
    _pose(rig, f, 0.62, READY, 0)
    _both(rig, f, 0.03, 0.08, 0.32, 0.44)
    _root(rig, f, 0, 0)
    _root(rig, f, 0.13, 0, kit.SNAP)
    _root(rig, f, 0.20, 0.6)
    _feet(f, 0, 0, 0)
    _foot("Right", f, 0.08, (-0.7, 0.3, FOOT_Z))
    _foot("Left", f, 0.13, (0.5, -0.1, 0.35), kit.SNAP)
    _foot("Left", f, 0.20, (0.75, -1.2, FOOT_Z))
    _foot("Right", f, 0.44, (-0.55, -0.4, FOOT_Z))
    _feet(f, 0.62, 0.6, 0.6)


# Sky Pierce's air poses: the spear raised high in both hands, upright (the tip up), then swung down tip-first
RAISED = dict({"W": (-14, 0, 0), "N": (-8, 0, 0)}, **arm((165, 0, -10), 20, 95))
HANG = dict({"W": (-24, 0, 0), "N": (-14, 0, 0)}, **arm((172, 0, -8), 14, 100))
# Landing: crouched over the spear driven tip-first into the ground ahead, both hands on it
PLUNGE = dict({"W": (-30, 0, 0), "N": (-24, 0, 0)}, **arm((70, 0, 4), 10, -55))


def _cut3(rig, f):
    """Sky Pierce (finisher): a crouch with the spear swung up, a leap (about 4 studs) holding it high, a short hang at
    the top, then a fall that drives it tip-first into the ground ahead (the Hit), crouched over it, and a pull out back
    up to upright. Slower, so it hits hardest (the damage a second stays)."""
    _pose(rig, f, 0, READY, 0)
    _pose(rig, f, 0.12, dict({"W": (28, 0, 0), "N": (10, 0, 0)}, **arm((60, 0, -6), 70, 95)), -1.0)
    _pose(rig, f, 0.17, dict({"W": (30, 0, 0), "N": (12, 0, 0)}, **arm((70, 0, -6), 70, 98)), -1.05, kit.SNAP)
    air = [
        (0.24, 2.4, RAISED, kit.HOLD, 0.8),
        (0.31, 3.8, HANG, kit.HOLD, 1.3),
        (0.44, 4.1, HANG, kit.HOLD, 1.7),
        (0.56, 3.6, dict(HANG, **arm((150, 0, -8), 10, 60)), ("EXPO", "EASE_IN"), 2.2),
    ]
    for t, lift, pose, ease, travel in air:
        _pose(rig, f, t, pose, lift, ease)
        tuck = 0.55 if t < 0.5 else 0.35
        for side, sx in (("Right", -0.5), ("Left", 0.5)):
            _foot(side, f, t, (sx, -travel, FOOT_Z + lift - tuck - 0.2), kit.HOLD)
    _pose(rig, f, 0.70, PLUNGE, -1.2, kit.SNAP)
    _pose(rig, f, 0.86, dict(PLUNGE, W=(-34, 0, 0), N=(-30, 0, 0)), -1.3)
    _pose(rig, f, 1.02, dict({"W": (-10, 0, 0), "N": (-6, 0, 0)}, **arm((50, 0, 8), 30, 30)), -0.7)
    _pose(rig, f, 1.25, READY, 0)
    _both(rig, f, 0.05, 0.14, 1.0, 1.1)
    _root(rig, f, 0, 0)
    _root(rig, f, 0.17, -0.2, kit.HOLD)
    _root(rig, f, 0.31, 1.3, kit.HOLD)
    _root(rig, f, 0.56, 2.2, ("EXPO", "EASE_IN"))
    _root(rig, f, 0.70, 3.0, kit.SNAP)
    _feet(f, 0, 0, 0)
    _feet(f, 0.12, 0.5, -0.4)
    _feet(f, 0.17, 0.5, -0.4, kit.HOLD)
    _foot("Right", f, 0.70, (-0.55, -3.6, FOOT_Z), kit.SNAP)
    _foot("Left", f, 0.70, (0.6, -2.3, FOOT_Z), kit.SNAP)
    _feet(f, 1.02, 3.6, 2.6)
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
