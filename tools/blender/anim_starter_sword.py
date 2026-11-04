"""The starter sword's moves (Config/Swords starterSword), keyed on anim_kit's rig. Docs: docs/animations.md.

In Blender (through the Blender MCP), with tools/blender on sys.path:
    import anim_starter_sword as moves
    moves.make("cut1", json_dir, render_dir)   # or moves.make_all(json_dir, render_dir)
Each move builds a fresh rig, keys it, exports assets/blender/Animations/StarterSword/<move>.json and renders front and side frames
for the GIF previews (the sword moves: tools/blender/run_sword_moves.py, 60 fps MP4 previews, in the background). Times are seconds; each cut's "Hit" marker is its strike frame and matches Config/Swords
(hitAt, length), which the server's damage timing uses.

Pose keys: R hips, W waist, N neck, RS/RE/RW and LS/LE/LW the arms, as Roblox CFrame.Angles degrees (x raises an arm
forward, z swings it out to its side, y turns about the vertical once it's raised sideways).
"""
import importlib
import math
import os

import anim_kit as kit

importlib.reload(kit)
READY = kit.READY
FOOT_Z = kit.FOOT_Z


# The sword moves (spec 2026-11-04-sword-moves-design, approved previews `sword-v3.html`): eased keys and the LAG_SWORD
# overlap, exported in place at 60 fps (the game moves the character: Config/Swords lunges and the skill's dash)
NATURAL = ("cut1", "cut2", "cut3", "skill")


def _pose(rig, f, t, p, lift, ease=kit.SOFT):
    kit.key_pose(rig, kit.frame_at(f, t), p, lift, ease, kit.LAG_SWORD)


def _root(rig, f, t, forward, ease=kit.SOFT):
    kit.key_root(rig, kit.frame_at(f, t), forward, 0.0, ease)


def _foot(side, f, t, pos, ease=kit.SOFT):
    kit.key_foot(side, kit.frame_at(f, t), pos, ease)


def _feet(f, t, right, left, ease=kit.SOFT):
    _foot("Right", f, t, (-0.5, -right, FOOT_Z), ease)
    _foot("Left", f, t, (0.5, -left, FOOT_Z), ease)


def _cut1(rig, f):
    """Forehand: coil right with the sword cocked high and the left hand aimed at the target, snap a diagonal cut down
    across to the left while lunging in, overshoot, settle."""
    _pose(rig, f, 0, READY, 0)
    _pose(rig, f, 0.10, {"R": (0, -20, 0), "W": (-6, -30, 0), "N": (0, 35, 0), "RS": (150, 0, 55), "RE": (75, 0, 0), "RW": (25, 0, 0), "LS": (70, 0, -20), "LE": (15, 0, 0)}, -0.3)
    _pose(rig, f, 0.167, {"R": (0, -24, 0), "W": (-8, -36, 0), "N": (0, 40, 0), "RS": (158, 0, 58), "RE": (80, 0, 0), "RW": (30, 0, 0), "LS": (75, 0, -22), "LE": (10, 0, 0)}, -0.32, kit.SNAP)
    _pose(rig, f, 0.217, {"R": (0, 22, 0), "W": (14, 38, 0), "N": (0, -20, 0), "RS": (25, -30, -40), "RE": (5, 0, 0), "RW": (-20, 0, 0), "LS": (-35, 0, -55), "LE": (20, 0, 0)}, -0.55, kit.SNAP)
    _pose(rig, f, 0.317, {"R": (0, 28, 0), "W": (18, 48, 0), "N": (0, -26, 0), "RS": (5, -40, -50), "RE": (12, 0, 0), "RW": (-30, 0, 0), "LS": (-40, 0, -62), "LE": (25, 0, 0)}, -0.58)
    _pose(rig, f, 0.45, {"R": (0, 15, 0), "W": (8, 25, 0), "N": (0, -12, 0), "RS": (30, -15, -15), "RE": (35, 0, 0), "RW": (-10, 0, 0), "LS": (-10, 0, -30), "LE": (25, 0, 0)}, -0.25)
    _pose(rig, f, 0.60, READY, 0)
    _root(rig, f, 0, 0)
    _root(rig, f, 0.167, -0.15, kit.SNAP)
    _root(rig, f, 0.25, 1.1)
    _feet(f, 0, 0, 0)
    _feet(f, 0.10, 0.3, -0.2)
    _foot("Right", f, 0.167, (-0.5, 0.1, 0.35), kit.SNAP)
    _foot("Right", f, 0.22, (-0.55, -1.6, FOOT_Z))
    _foot("Left", f, 0.167, (0.5, 0.2, FOOT_Z))
    _foot("Left", f, 0.45, (0.5, -0.4, FOOT_Z))
    _feet(f, 0.60, 1.1, 1.1)


def _cut2(rig, f):
    """Backhand: wound low across to the left (where the forehand ended), a rising sweep out to the right with the body
    lifting onto its toes, overshoot, settle."""
    _pose(rig, f, 0, READY, 0)
    _pose(rig, f, 0.08, {"R": (0, 25, 0), "W": (10, 40, 0), "N": (0, -30, 0), "RS": (10, 140, 70), "RE": (40, 0, 0), "RW": (0, -35, 0), "LS": (-20, 0, -45), "LE": (30, 0, 0)}, -0.45)
    _pose(rig, f, 0.133, {"R": (0, 28, 0), "W": (12, 44, 0), "N": (0, -32, 0), "RS": (5, 148, 68), "RE": (42, 0, 0), "RW": (0, -38, 0), "LS": (-22, 0, -48), "LE": (30, 0, 0)}, -0.47, kit.SNAP)
    _pose(rig, f, 0.183, {"R": (0, -20, 0), "W": (-10, -38, 0), "N": (0, 25, 0), "RS": (35, -20, 105), "RE": (5, 0, 0), "RW": (0, 30, 0), "LS": (40, 0, -30), "LE": (35, 0, 0)}, -0.2, kit.SNAP)
    _pose(rig, f, 0.283, {"R": (0, -26, 0), "W": (-14, -48, 0), "N": (0, 30, 0), "RS": (50, -35, 110), "RE": (12, 0, 0), "RW": (0, 38, 0), "LS": (45, 0, -28), "LE": (40, 0, 0)}, -0.1)
    _pose(rig, f, 0.43, {"R": (0, -10, 0), "W": (-4, -20, 0), "N": (0, 10, 0), "RS": (35, -5, 45), "RE": (40, 0, 0), "RW": (0, 10, 0), "LS": (20, 0, -18), "LE": (35, 0, 0)}, -0.15)
    _pose(rig, f, 0.58, READY, 0)
    _root(rig, f, 0, 0)
    _root(rig, f, 0.133, 0, kit.SNAP)
    _root(rig, f, 0.22, 0.8)
    _feet(f, 0, 0, 0)
    _foot("Left", f, 0.133, (0.5, -0.1, 0.35), kit.SNAP)
    _foot("Left", f, 0.19, (0.65, -1.3, FOOT_Z))
    _foot("Right", f, 0.19, (-0.5, -0.2, FOOT_Z))
    _foot("Right", f, 0.43, (-0.5, -0.6, FOOT_Z))
    _feet(f, 0.58, 0.8, 0.8)


# The finisher's air poses: the sword raised two-handed overhead (the waist and neck lean forward: in these angles a
# positive x tips the body back)
RAISED = {"W": (-18, 0, 0), "N": (-10, 0, 0), "RS": (172, 0, -22), "RE": (40, 0, 0), "RW": (22, 0, 0), "LS": (172, 0, 22), "LE": (40, 0, 0)}
HANG = {"W": (-30, 0, 0), "N": (-16, 0, 0), "RS": (178, 0, -18), "RE": (30, 0, 0), "RW": (30, 0, 0), "LS": (178, 0, 18), "LE": (30, 0, 0)}
# Landing: kneeling over the sword stabbed point-down into the ground in front, both hands on the hilt, head bowed
STAB = {"RS": (60, 0, -12), "RE": (20, 0, 0), "RW": (-75, 0, 0), "LS": (60, 0, 12), "LE": (24, 0, 0)}


def _cut3(rig, f):
    """Finisher (owner 2026-11-04): a deep crouch, a big leap (about 5 studs up) with a spin while the sword rises
    two-handed overhead, a slow-motion hang at the top still turning, a hard fall into a slam that stabs the sword into
    the ground, then kneeling over it head bowed (the cool-down) before standing. The hang's slow motion is in the keys,
    so the Hit marker stays where the server lands the hit (Config/Swords hitAt 0.70; the arms trail the landing)."""
    _pose(rig, f, 0, READY, 0)
    _pose(rig, f, 0.12, {"R": (0, 25, 0), "W": (32, 30, 0), "N": (0, -20, 0), "RS": (35, 0, -10), "RE": (85, 0, 0), "RW": (20, 0, 0), "LS": (35, 0, 15), "LE": (80, 0, 0)}, -1.05)
    _pose(rig, f, 0.17, {"R": (0, 28, 0), "W": (35, 32, 0), "N": (0, -22, 0), "RS": (32, 0, -10), "RE": (88, 0, 0), "RW": (22, 0, 0), "LS": (32, 0, 15), "LE": (82, 0, 0)}, -1.1, kit.SNAP)
    # (time, spin, lift, pose, ease, forward travel): the launch, then the hang, slow and steady
    air = [
        (0.22, -100, 2.2, RAISED, kit.HOLD, 0.6),
        (0.27, -210, 4.0, RAISED, kit.HOLD, 1.0),
        (0.31, -275, 4.7, HANG, kit.HOLD, 1.3),
        (0.44, -305, 4.95, HANG, kit.HOLD, 1.65),
        (0.56, -330, 4.8, HANG, ("EXPO", "EASE_IN"), 2.0),
    ]
    for t, yaw, lift, pose, ease, travel in air:
        _pose(rig, f, t, dict(pose, R=(0, yaw, 0)), lift, ease)
        a = math.radians(yaw)
        tuck = 0.55 if t < 0.5 else 0.35  # knees up in the air, reaching down for the landing
        for side, sx in (("Right", -0.5), ("Left", 0.5)):
            _foot(side, f, t, (sx * math.cos(a), -travel + sx * math.sin(a), FOOT_Z + lift - tuck - 0.2), kit.HOLD)
    _pose(rig, f, 0.66, dict(STAB, R=(0, -360, 0), W=(-15, 0, 0), N=(-20, 0, 0)), -1.25, kit.SNAP)
    _pose(rig, f, 0.82, dict(STAB, R=(0, -360, 0), W=(-22, 0, 0), N=(-38, 0, 0)), -1.35)
    _pose(rig, f, 1.02, dict(STAB, R=(0, -360, 0), W=(-24, 0, 0), N=(-40, 0, 0)), -1.33)
    _pose(rig, f, 1.25, dict(READY, R=(0, -360, 0)), 0)
    kit.two_hands(rig, lambda t: kit.frame_at(f, t), 0.02, 0.12, 1.04, 1.16)
    _root(rig, f, 0, 0)
    _root(rig, f, 0.17, -0.2, kit.HOLD)
    _root(rig, f, 0.31, 1.3, kit.HOLD)
    _root(rig, f, 0.56, 2.0, ("EXPO", "EASE_IN"))
    _root(rig, f, 0.66, 3.0, kit.SNAP)
    _feet(f, 0, 0, 0)
    _feet(f, 0.12, 0.6, -0.5)
    _feet(f, 0.17, 0.6, -0.5, kit.HOLD)
    _feet(f, 0.66, 4.0, 2.1, kit.SNAP)
    _feet(f, 1.02, 4.0, 2.1)
    _feet(f, 1.25, 3.0, 3.0)


def _skill(rig, f):
    """Dash slash: a deep draw stance with the sword at the left hip, a charged hold, a dash forward drawing it in one
    cut, the low follow-through frozen while the cut lines appear behind, a flick back up."""
    stance = {"R": (0, 30, 0), "W": (20, 35, 0), "N": (0, -35, 0), "RS": (25, 0, -50), "RE": (70, 0, 0), "RW": (0, -35, 0), "LS": (20, 0, -10), "LE": (75, 0, 0)}
    finish = {"R": (0, -25, 0), "W": (30, -40, 0), "N": (5, 35, 0), "RS": (0, -40, 100), "RE": (0, 0, 0), "RW": (0, 25, 0), "LS": (-30, 0, -70), "LE": (15, 0, 0)}
    _pose(rig, f, 0, READY, 0)
    _pose(rig, f, 0.15, stance, -0.85)
    _pose(rig, f, 0.32, dict(stance, W=(22, 37, 0)), -0.9, kit.SNAP)
    _pose(rig, f, 0.36, {"R": (0, 0, 0), "W": (40, 0, 0), "N": (-10, 0, 0), "RS": (10, 50, 90), "RE": (10, 0, 0), "RW": (0, 0, 0), "LS": (-10, 0, -40), "LE": (30, 0, 0)}, -0.95, kit.SNAP)
    _pose(rig, f, 0.40, finish, -1.0, kit.SNAP)
    _pose(rig, f, 0.72, dict(finish, W=(32, -42, 0)), -1.02)
    _pose(rig, f, 0.86, {"W": (5, 0, 0), "RS": (60, 0, 50), "RE": (60, 0, 0), "RW": (20, 0, 0), "LS": (10, 0, -15), "LE": (30, 0, 0)}, -0.4)
    _pose(rig, f, 1.0, READY, 0)
    _root(rig, f, 0, 0)
    _root(rig, f, 0.32, 0, kit.SNAP)
    _root(rig, f, 0.40, 9.0)
    _feet(f, 0, 0, 0)
    _feet(f, 0.15, 1.0, -0.8)
    _feet(f, 0.32, 1.0, -0.8, kit.SNAP)
    _foot("Right", f, 0.36, (-0.5, -5.5, 0.4), kit.SNAP)
    _foot("Left", f, 0.36, (0.5, -4.0, 0.5), kit.SNAP)
    _feet(f, 0.40, 10.3, 8.0)
    _feet(f, 0.72, 10.3, 8.0)
    _feet(f, 1.0, 9.0, 9.0)


MOVES = {"cut1": (_cut1, 0.60), "cut2": (_cut2, 0.58), "cut3": (_cut3, 1.25), "skill": (_skill, 1.0)}
VIEWS = {
    "default": {"front": ((9.0, -14.0, 5.6), (0, -1.5, 2.5)), "side": ((16.0, -1.5, 4.6), (0, -1.5, 2.5))},
    "skill": {"front": ((13.0, -24.0, 7.5), (0, -5.0, 2.5)), "side": ((24.0, -5.0, 5.0), (0, -5.0, 2.5))},
}
LEAD, TAIL = 12, 24  # frames of standing still before and after, so the loop reads


def _dodge(rig, f):
    """A quick tucked crouch for the dash (the dash itself moves the character in the game)."""
    F = lambda t: kit.frame_at(f, t)
    tuck = {"W": (22, 0, 0), "N": (12, 0, 0), "RS": (45, 0, 12), "RE": (85, 0, 0), "LS": (45, 0, -12), "LE": (85, 0, 0)}
    kit.key_pose(rig, F(0), READY)
    kit.key_pose(rig, F(0.07), tuck, -0.8)
    kit.key_pose(rig, F(0.24), tuck, -0.75)
    kit.key_pose(rig, F(0.35), READY, 0)
    kit.key_root(rig, F(0), 0)
    kit.plant_feet(F(0))
    kit.plant_feet(F(0.35))


def _flinch(rig, f):
    """Hit: the body snaps back and the arms fly out, then it's ready again."""
    F = lambda t: kit.frame_at(f, t)
    kit.key_pose(rig, F(0), READY)
    kit.key_pose(rig, F(0.06), {"W": (-22, 0, 8), "N": (-18, 0, 0), "RS": (35, 0, 38), "RE": (40, 0, 0), "LS": (12, 0, -42), "LE": (30, 0, 0)}, -0.15)
    kit.key_pose(rig, F(0.30), READY, 0)
    kit.key_root(rig, F(0), 0)
    kit.plant_feet(F(0))
    kit.plant_feet(F(0.30))


KNEEL = {"W": (28, 0, 0), "N": (22, 0, 0), "RS": (18, 0, 14), "RE": (30, 0, 0), "LS": (42, 0, -10), "LE": (55, 0, 0)}


def _kneel_feet(frame):
    kit.key_foot("Right", frame, (-0.5, 1.2, FOOT_Z))  # the right shin flat behind: kneeling on the right knee
    kit.key_foot("Left", frame, (0.5, -0.7, FOOT_Z))


def _down(rig, f):
    """Knocked down: a stagger, then down on one knee; held there ("Hold") until getting up."""
    F = lambda t: kit.frame_at(f, t)
    kit.key_pose(rig, F(0), READY)
    kit.key_pose(rig, F(0.15), {"W": (-18, 0, 6), "N": (-12, 0, 0), "RS": (30, 0, 30), "RE": (35, 0, 0), "LS": (15, 0, -35), "LE": (30, 0, 0)}, -0.25)
    kit.key_pose(rig, F(0.45), KNEEL, -1.35)
    kit.key_pose(rig, F(0.60), KNEEL, -1.35)
    kit.key_root(rig, F(0), 0)
    kit.plant_feet(F(0))
    kit.plant_feet(F(0.15))
    _kneel_feet(F(0.45))
    _kneel_feet(F(0.60))


def _get_up(rig, f):
    """From one knee back up to the ready stance."""
    F = lambda t: kit.frame_at(f, t)
    kit.key_pose(rig, F(0), KNEEL, -1.35)
    kit.key_pose(rig, F(0.30), {"W": (18, 0, 0), "N": (8, 0, 0), "RS": (25, 0, 12), "RE": (45, 0, 0), "LS": (25, 0, -10), "LE": (35, 0, 0)}, -0.6)
    kit.key_pose(rig, F(0.70), READY, 0)
    kit.key_root(rig, F(0), 0)
    _kneel_feet(F(0))
    kit.key_foot("Right", F(0.30), (-0.5, 0.3, 0.45))
    kit.plant_feet(F(0.45))
    kit.plant_feet(F(0.70))


def _draw(rig, f):
    """Reaching over the right shoulder for the sword on the back ("Grab"), then a flourish into the ready stance."""
    F = lambda t: kit.frame_at(f, t)
    kit.key_pose(rig, F(0), {})
    kit.key_pose(rig, F(0.16), {"W": (0, -12, 0), "N": (0, -12, 0), "RS": (165, 0, 18), "RE": (115, 0, 0), "RW": (0, 0, 0)}, 0)
    kit.key_pose(rig, F(0.30), {"W": (0, 10, 0), "N": (0, 5, 0), "RS": (110, 0, 35), "RE": (40, 0, 0), "RW": (-25, 0, 0)}, -0.1)
    kit.key_pose(rig, F(0.50), READY, 0)
    kit.key_root(rig, F(0), 0)
    kit.plant_feet(F(0))
    kit.plant_feet(F(0.50))


def _sheath(rig, f):
    """The sword back over the right shoulder onto the back ("Release"), arms down."""
    F = lambda t: kit.frame_at(f, t)
    kit.key_pose(rig, F(0), READY)
    kit.key_pose(rig, F(0.25), {"W": (0, -10, 0), "N": (0, -10, 0), "RS": (168, 0, 16), "RE": (118, 0, 0)}, 0)
    kit.key_pose(rig, F(0.50), {}, 0)
    kit.key_root(rig, F(0), 0)
    kit.plant_feet(F(0))
    kit.plant_feet(F(0.50))


def _ready(rig, f):
    """The sword-ready stance while it's drawn (upper body only: Roblox's idle and walk keep the legs), breathing."""
    F = lambda t: kit.frame_at(f, t)
    left = {"LS": (10, 0, -8), "LE": (22, 0, 0)}
    kit.key_pose(rig, F(0), dict(READY, **left))
    kit.key_pose(rig, F(0.8), dict(left, RS=(23, 0, 10), RE=(58, 0, 0), W=(3, 0, 0), N=(-2, 0, 0)))
    kit.key_pose(rig, F(1.6), dict(READY, **left))
    kit.key_root(rig, F(0), 0)
    kit.plant_feet(F(0))


def _run(rig, f):
    """Running with the sword out (upper body only, over Roblox's run): the blade low behind, the left arm pumping."""
    F = lambda t: kit.frame_at(f, t)
    sword = {"RS": (-25, 0, 12), "RE": (35, 0, 0), "RW": (10, 0, 0)}
    kit.key_pose(rig, F(0), dict(sword, LS=(38, 0, -6), LE=(70, 0, 0), W=(10, 8, 0), N=(-6, -6, 0)))
    kit.key_pose(rig, F(0.33), dict(sword, LS=(-30, 0, -6), LE=(40, 0, 0), W=(10, -8, 0), N=(-6, 6, 0)))
    kit.key_pose(rig, F(0.66), dict(sword, LS=(38, 0, -6), LE=(70, 0, 0), W=(10, 8, 0), N=(-6, -6, 0)))
    kit.key_root(rig, F(0), 0)
    kit.plant_feet(F(0))


# name -> (keying function, length in seconds, loop, markers, upper body only, priority)
MOVES = {
    "cut1": (_cut1, 0.60, False, [{"name": "Hit", "t": 0.217}], False, "Action"),
    "cut2": (_cut2, 0.58, False, [{"name": "Hit", "t": 0.183}], False, "Action"),
    "cut3": (_cut3, 1.25, False, [{"name": "Hit", "t": 0.70}], False, "Action"),
    "skill": (_skill, 1.0, False, [{"name": "Hit", "t": 0.62}], False, "Action"),
    "dodge": (_dodge, 0.35, False, [], False, "Action"),
    "flinch": (_flinch, 0.30, False, [], False, "Action"),
    "down": (_down, 0.60, False, [{"name": "Hold", "t": 0.58}], False, "Action"),
    "getUp": (_get_up, 0.70, False, [], False, "Action"),
    "draw": (_draw, 0.50, False, [{"name": "Grab", "t": 0.16}], True, "Action"),
    "sheath": (_sheath, 0.50, False, [{"name": "Release", "t": 0.25}], True, "Action"),
    "ready": (_ready, 1.60, True, [], True, "Movement"),
    "run": (_run, 0.66, True, [], True, "Movement"),
}

FRONT = ((8.5, -12.5, 5.6), (0, -1.0, 2.5))
SIDE = ((14.5, -1.0, 4.4), (0, -1.0, 2.5))


def make(name, json_dir, render_dir=None):
    """Builds, keys and exports one move; renders its front and side frames when render_dir is given."""
    fn, length, loop, markers, upper, priority = MOVES[name]
    rig = kit.build()
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
        kit.render_frames(os.path.join(render_dir, name, "front"), frames, *FRONT)
        kit.render_frames(os.path.join(render_dir, name, "side"), frames, *SIDE)
    return count


def make_all(json_dir, render_dir=None):
    return {name: make(name, json_dir, render_dir) for name in MOVES}
