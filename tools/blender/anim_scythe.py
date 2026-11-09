"""The scythe moveset's moves (Config/Swords scythe, weapons round 3; spec 2026-11-09-weapons-round3-scythes-design 5.2,
the owner: "epic. I want exaggerated moves, wide slashes in all directions", "a bit slower but still flashy"), keyed on
anim_kit's rig with the scythe prop (PROP) at the scythe grip.

    "C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" -b --factory-startup --python tools/blender/run_sword_moves.py -- --sword scythe [--preview <dir>] [move ...]

JSON goes to assets/blender/Animations/Scythe, then `lune run tools/anim/build_kfs assets/blender/Animations/Scythe
assets/animations/Scythe`. Each attack's "Hit" marker is its strike frame and matches Config/Swords scythe (hitAt,
length).

How the scythe points: its grip is the spear's (anim_kit.hand_grip("scythe"), angleX -90): a hanging arm holds the shaft
straight ahead, the blade out to the left of its top, flat. Its pitch (degrees up from straight ahead) is about the sum
of the shoulder's, the elbow's and the wrist's x angles (arm()); its yaw comes from turning the body (R, W; + turns to
the left). Held upright at the right side between moves, the blade facing forward (HOLD_TURN); every attack swings it down into both
hands with a heavy wind-up (two_hands, the left hand up the shaft). The sweeps go right to left, the blade's tip leading
(a real scythe's stroke); the blade sits about 30 degrees left of where the shaft points, so a Hit's shaft points a
little right of the front.
"""
import importlib
import math
import os

import anim_kit as kit

importlib.reload(kit)
FOOT_Z = kit.FOOT_Z
PROP = "scythe"
FOLDER = "Scythe"
LEFT_ALONG = 1.5  # studs up the shaft from the right hand to the left (two hands)

NATURAL = ("cut1", "cut2", "cut3", "skill")


def arm(rs, re, pitch, rwz=0):
    """The right arm with the shoulder at `rs` (x, y, z), the elbow bent `re`, and the wrist set so the scythe points
    `pitch` degrees up from straight ahead (90: upright, -90: straight down)."""
    return {"RS": rs, "RE": (re, 0, 0), "RW": (pitch - rs[0] - re, 0, rwz)}


LEFT_FREE = {"LS": (8, 0, -8), "LE": (20, 0, 0)}
# Held between moves (ready, run): the scythe turned a quarter round its shaft by the wrist so the blade faces forward
# (owner 2026-11-09: "the blade is facing on my head. make it look forward"); the attacks hold it with the blade to the
# side (flat, the tip leading the sweeps) and turn into that through their wind-ups
HOLD_TURN = 90
# Upright at the right side, the butt by the right foot, the blade forward over your head
READY = dict(arm((-4, 0, 14), 64, 88, -12 + HOLD_TURN), **LEFT_FREE)
# The waist, neck and free left arm trail; the right arm aims the scythe as one (the spear's overlap)
LAG_SCYTHE = {"W": 1, "N": 2, "LS": 1, "LE": 2, "LW": 2}


def _pose(rig, f, t, p, lift, ease=kit.SOFT):
    kit.key_pose(rig, kit.frame_at(f, t), p, lift, ease, LAG_SCYTHE)


def _root(rig, f, t, forward, ease=kit.SOFT):
    kit.key_root(rig, kit.frame_at(f, t), forward, 0.0, ease)


def _foot(side, f, t, pos, ease=kit.SOFT):
    kit.key_foot(side, kit.frame_at(f, t), pos, ease)


def _feet(f, t, right, left, ease=kit.SOFT):
    _foot("Right", f, t, (-0.5, -right, FOOT_Z), ease)
    _foot("Left", f, t, (0.5, -left, FOOT_Z), ease)


def _both(rig, f, on, full, release, off):
    kit.two_hands(rig, lambda t: kit.frame_at(f, t), on, full, release, off, along=LEFT_ALONG, family="scythe")


def _body(yaw, waist, neck, lean=0):
    """The hips turned `yaw` degrees (+ left), the waist turned `waist` more and leaning `lean` forward, the neck turned
    `neck` (back towards the front, so the head keeps looking ahead)."""
    return {"R": (0, yaw, 0), "W": (lean, waist, 0), "N": (0, neck, 0)}


def _spin_feet(f, t, yaw, travel=0.0, lift=0.0, ease=kit.SOFT, wide=0.5):
    """Both feet round the body turned `yaw` degrees (a spin), `travel` studs forward, `lift` up, `wide` from the middle."""
    a = math.radians(yaw)
    for side, sx in (("Right", -wide), ("Left", wide)):
        _foot(side, f, t, (sx * math.cos(a), -travel + sx * math.sin(a), FOOT_Z + lift), ease)


def _cut1(rig, f):
    """Reap: swung down into both hands and wound far back to the right, crouched, then one huge sweep right to left
    across the front at chest height, arms long, the tip leading (the Hit as the blade crosses the front), a low
    follow-through to the left, and back up to upright."""
    _pose(rig, f, 0, READY, 0)
    _pose(rig, f, 0.14, dict(_body(-45, -35, 35, 10), **arm((40, 0, 30), 30, 22)), -0.5)
    _pose(rig, f, 0.22, dict(_body(-58, -45, 45, 12), **arm((46, 0, 40), 26, 26)), -0.62, kit.SNAP)
    _pose(rig, f, 0.34, dict(_body(-10, -12, 15, -4), **arm((68, 0, -8), 4, 6)), -0.7, kit.SNAP)
    _pose(rig, f, 0.46, dict(_body(38, 45, -35, -8), **arm((56, 0, -26), 10, 0)), -0.75)
    _pose(rig, f, 0.60, dict(_body(44, 50, -40, -6), **arm((50, 0, -28), 16, 4)), -0.7)
    _pose(rig, f, 0.85, READY, 0)
    _both(rig, f, 0.04, 0.14, 0.58, 0.70)
    _root(rig, f, 0, 0)
    _root(rig, f, 0.22, -0.3, kit.SNAP)
    _root(rig, f, 0.34, 1.1)
    _feet(f, 0, 0, 0)
    _foot("Right", f, 0.14, (-0.8, 0.6, FOOT_Z))
    _foot("Left", f, 0.14, (0.6, -0.4, FOOT_Z))
    _foot("Left", f, 0.34, (0.75, -1.9, FOOT_Z), kit.SNAP)
    _foot("Right", f, 0.34, (-0.7, 0.4, FOOT_Z), kit.SNAP)
    _feet(f, 0.85, 1.1, 1.1)


def _cut2(rig, f):
    """Back Sweep: crouched low with the body wound right, then a full spin to the left on the spot, the blade carving
    low round behind you and through the front again (the Hit), a low finish and back up to upright facing the front."""
    _pose(rig, f, 0, READY, 0)
    _pose(rig, f, 0.10, dict(_body(-40, -30, 30, 14), **arm((30, 0, 30), 30, -4)), -0.8)
    _pose(rig, f, 0.15, dict(_body(-50, -36, 36, 16), **arm((34, 0, 34), 28, -6)), -0.85, kit.SNAP)
    spin = [(0.22, 60, kit.SNAP), (0.29, 170, kit.HOLD), (0.36, 280, kit.HOLD), (0.42, 340, kit.SNAP)]
    for t, yaw, ease in spin:
        _pose(rig, f, t, dict(_body(yaw, 18, -14, 10), **arm((52, 0, 8), 4, -14)), -0.85, ease)
        _spin_feet(f, t, yaw, 0.8 * min(1, t / 0.42), 0.0, ease, 0.6)
    _pose(rig, f, 0.54, dict(_body(380, 34, -30, 12), **arm((46, 0, -18), 10, -12)), -0.9)
    _pose(rig, f, 0.66, dict(_body(385, 36, -32, 10), **arm((44, 0, -20), 14, -8)), -0.85)
    _pose(rig, f, 0.90, dict(READY, R=(0, 360, 0)), 0)
    _both(rig, f, 0.03, 0.10, 0.58, 0.68)
    _root(rig, f, 0, 0)
    _root(rig, f, 0.15, 0, kit.SNAP)
    _root(rig, f, 0.42, 0.8)
    _feet(f, 0, 0, 0)
    _foot("Right", f, 0.10, (-0.85, 0.5, FOOT_Z))
    _foot("Left", f, 0.10, (0.6, -0.3, FOOT_Z))
    _spin_feet(f, 0.66, 380, 0.8, 0.0, kit.SOFT, 0.6)
    _spin_feet(f, 0.90, 360, 0.8)


def _cut3(rig, f):
    """Whirlwind (finisher): a deep coil with the scythe swung back low, then two full spins to the left with it held
    straight out at shoulder height in both hands, faster and faster (the Hit as the second spin ends: every foe round
    you, a ring of light), a low wide finish and back up to upright. Slower, so it hits hardest (the damage a second
    stays)."""
    _pose(rig, f, 0, READY, 0)
    _pose(rig, f, 0.16, dict(_body(-60, -40, 40, 16), **arm((36, 0, 40), 34, 0)), -0.9)
    _pose(rig, f, 0.26, dict(_body(-72, -48, 48, 18), **arm((40, 0, 46), 30, 2)), -0.95, kit.SNAP)
    spins = [(0.34, 20), (0.44, 140), (0.54, 260), (0.63, 380), (0.72, 495), (0.81, 600), (0.90, 690), (0.98, 740)]
    for t, yaw in spins:
        ease = kit.SNAP if t in (0.34, 0.98) else kit.HOLD
        _pose(rig, f, t, dict(_body(yaw, 10, -8, 4), **arm((84, 0, 12), 0, 4)), -0.3, ease)
        _spin_feet(f, t, yaw, 0.0, 0.0, kit.HOLD, 0.65)
    _pose(rig, f, 1.10, dict(_body(765, 38, -34, 22), **arm((44, 0, -22), 10, -14)), -1.05, kit.SNAP)
    _pose(rig, f, 1.30, dict(_body(768, 40, -36, 20), **arm((42, 0, -24), 14, -10)), -1.0)
    _pose(rig, f, 1.70, dict(READY, R=(0, 720, 0)), 0)
    _both(rig, f, 0.05, 0.16, 1.28, 1.42)
    _root(rig, f, 0, 0)
    _feet(f, 0, 0, 0)
    _foot("Right", f, 0.16, (-0.9, 0.7, FOOT_Z))
    _foot("Left", f, 0.16, (0.6, -0.5, FOOT_Z))
    _foot("Right", f, 0.26, (-0.9, 0.7, FOOT_Z), kit.SNAP)
    _foot("Left", f, 0.26, (0.6, -0.5, FOOT_Z), kit.SNAP)
    _spin_feet(f, 1.10, 765, 0.0, 0.0, kit.SNAP, 0.85)
    _spin_feet(f, 1.30, 768, 0.0, 0.0, kit.SOFT, 0.85)
    _spin_feet(f, 1.70, 720)


def _skill(rig, f):
    """Reaping Cyclone: gathered low, then three spins to the left with the scythe raised high in both hands, the blade
    circling above, rising onto the toes and faster each turn (a ring of crescents each; the third is the Hit), then
    down into a crouch with the scythe swept low and wide, and back up to upright."""
    _pose(rig, f, 0, READY, 0)
    _pose(rig, f, 0.14, dict(_body(-50, -35, 35, 18), **arm((30, 0, 35), 40, 10)), -1.0)
    _pose(rig, f, 0.22, dict(_body(-58, -40, 40, 20), **arm((32, 0, 38), 38, 12)), -1.05, kit.SNAP)
    spins = [(0.30, 60), (0.41, 220), (0.51, 370), (0.61, 520), (0.70, 670), (0.78, 805), (0.86, 935), (0.94, 1050)]
    for i, (t, yaw) in enumerate(spins):
        ease = kit.SNAP if t in (0.30, 0.94) else kit.HOLD
        lift = -0.5 + 0.7 * i / (len(spins) - 1)
        _pose(rig, f, t, dict(_body(yaw, 8, -6, -6), **arm((125, 0, 12), 0, 42)), lift, ease)
        _spin_feet(f, t, yaw, 0.0, 0.0, kit.HOLD, 0.6)
    _pose(rig, f, 1.08, dict(_body(1090, 40, -36, 26), **arm((50, 0, -22), 10, -24)), -1.15, kit.SNAP)
    _pose(rig, f, 1.26, dict(_body(1094, 42, -38, 24), **arm((48, 0, -24), 14, -20)), -1.1)
    _pose(rig, f, 1.60, dict(READY, R=(0, 1080, 0)), 0)
    _both(rig, f, 0.06, 0.16, 1.24, 1.38)
    _root(rig, f, 0, 0)
    _feet(f, 0, 0, 0)
    _foot("Right", f, 0.14, (-0.9, 0.6, FOOT_Z))
    _foot("Left", f, 0.14, (0.7, -0.4, FOOT_Z))
    _foot("Right", f, 0.22, (-0.9, 0.6, FOOT_Z), kit.SNAP)
    _foot("Left", f, 0.22, (0.7, -0.4, FOOT_Z), kit.SNAP)
    _spin_feet(f, 1.08, 1090, 0.0, 0.0, kit.SNAP, 0.9)
    _spin_feet(f, 1.26, 1094, 0.0, 0.0, kit.SOFT, 0.9)
    _spin_feet(f, 1.60, 1080)


def _ready(rig, f):
    """Upright at the right side while drawn, the blade forward (upper body only: Roblox's idle and walk keep the
    legs), breathing."""
    F = lambda t: kit.frame_at(f, t)  # noqa: E731
    kit.key_pose(rig, F(0), READY)
    kit.key_pose(rig, F(0.9), dict(READY, W=(3, 0, 0), N=(-2, 0, 0), **arm((-2, 0, 14), 66, 87, -12 + HOLD_TURN)))
    kit.key_pose(rig, F(1.8), READY)
    kit.key_root(rig, F(0), 0)
    kit.plant_feet(F(0))


def _draw(rig, f):
    """Reaching over the right shoulder for the scythe on the back ("Grab"), swinging it round and down into the upright
    guard."""
    F = lambda t: kit.frame_at(f, t)  # noqa: E731
    kit.key_pose(rig, F(0), {})
    kit.key_pose(rig, F(0.16), {"W": (0, -12, 0), "N": (0, -12, 0), "RS": (165, 0, 18), "RE": (115, 0, 0), "RW": (0, 0, 0)}, 0)
    kit.key_pose(rig, F(0.32), dict({"W": (0, 8, 0), "N": (0, 4, 0)}, **arm((60, 0, 25), 40, 120)), -0.1)
    kit.key_pose(rig, F(0.50), READY, 0)
    kit.key_root(rig, F(0), 0)
    kit.plant_feet(F(0))
    kit.plant_feet(F(0.50))


def _sheath(rig, f):
    """The scythe swung up and back over the right shoulder onto the back ("Release"), arms down."""
    F = lambda t: kit.frame_at(f, t)  # noqa: E731
    kit.key_pose(rig, F(0), READY)
    kit.key_pose(rig, F(0.25), {"W": (0, -10, 0), "N": (0, -10, 0), "RS": (168, 0, 16), "RE": (118, 0, 0)}, 0)
    kit.key_pose(rig, F(0.50), {}, 0)
    kit.key_root(rig, F(0), 0)
    kit.plant_feet(F(0))
    kit.plant_feet(F(0.50))


def _run(rig, f):
    """Running with the scythe (upper body only, over Roblox's run): held at the right side tilted forward, the blade
    up and facing forward, the left arm pumping."""
    F = lambda t: kit.frame_at(f, t)  # noqa: E731
    scythe = arm((10, 0, 14), 50, 60, -10 + HOLD_TURN)
    kit.key_pose(rig, F(0), dict(scythe, LS=(38, 0, -6), LE=(70, 0, 0), W=(10, 8, 0), N=(-6, -6, 0)))
    kit.key_pose(rig, F(0.33), dict(scythe, LS=(-30, 0, -6), LE=(40, 0, 0), W=(10, -8, 0), N=(-6, 6, 0)))
    kit.key_pose(rig, F(0.66), dict(scythe, LS=(38, 0, -6), LE=(70, 0, 0), W=(10, 8, 0), N=(-6, -6, 0)))
    kit.key_root(rig, F(0), 0)
    kit.plant_feet(F(0))


# name -> (keying function, length in seconds, loop, markers, upper body only, priority)
MOVES = {
    "cut1": (_cut1, 0.85, False, [{"name": "Hit", "t": 0.34}], False, "Action"),
    "cut2": (_cut2, 0.90, False, [{"name": "Hit", "t": 0.42}], False, "Action"),
    "cut3": (_cut3, 1.70, False, [{"name": "Hit", "t": 0.98}], False, "Action"),
    "skill": (_skill, 1.60, False, [{"name": "Hit", "t": 0.94}], False, "Action"),
    "draw": (_draw, 0.50, False, [{"name": "Grab", "t": 0.16}], True, "Action"),
    "sheath": (_sheath, 0.50, False, [{"name": "Release", "t": 0.25}], True, "Action"),
    "ready": (_ready, 1.80, True, [], True, "Movement"),
    "run": (_run, 0.66, True, [], True, "Movement"),
}
# The scythe's previews: framed for its height and the wide sweeps
PREVIEW_VIEWS = {
    "default": {"front": ((11.0, -19.0, 7.0), (0, -1.0, 3.6)), "side": ((20.0, -1.0, 6.0), (0, -1.0, 3.6))},
}


def make(name, json_dir, render_dir=None):
    """Builds, keys and exports one move (with the scythe prop); renders front and side frames when render_dir is given."""
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
