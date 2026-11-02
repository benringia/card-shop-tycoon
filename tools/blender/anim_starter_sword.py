"""The starter sword's moves (Config/Swords starterSword), keyed on anim_kit's rig. Docs: docs/animations.md.

In Blender (through the Blender MCP), with tools/blender on sys.path:
    import anim_starter_sword as moves
    moves.make("cut1", json_dir, render_dir)   # or moves.make_all(json_dir, render_dir)
Each move builds a fresh rig, keys it, exports assets/blender/Animations/StarterSword/<move>.json and renders front and side frames
for the GIF previews. Times are seconds; each cut's "Hit" marker is its strike frame and matches Config/Swords
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


def _cut1(rig, f):
    """A diagonal cut from high right down across to the left hip, stepping in on the right foot and back."""
    F = lambda t: kit.frame_at(f, t)
    kit.key_pose(rig, F(0), READY)
    kit.key_pose(rig, F(0.08), {"W": (0, -20, 0), "R": (0, -8, 0), "N": (0, 17, 0), "RS": (95, 0, 30), "RE": (70, 0, 0), "RW": (15, 0, 0), "LS": (15, 0, -15), "LE": (35, 0, 0)}, -0.15)
    kit.key_pose(rig, F(0.16), {"W": (0, -38, 0), "R": (0, -15, 0), "N": (0, 32, 0), "RS": (155, 0, 40), "RE": (45, 0, 0), "RW": (15, 0, 0), "LS": (30, 0, -25), "LE": (35, 0, 0)}, -0.2)
    kit.key_pose(rig, F(0.24), {"W": (5, 28, 0), "R": (0, 10, 0), "N": (0, -22, 0), "RS": (28, -20, -30), "RE": (10, 0, 0), "RW": (-30, 0, 0), "LS": (-20, 0, -35), "LE": (25, 0, 0)}, -0.45)
    kit.key_pose(rig, F(0.32), {"W": (8, 38, 0), "R": (0, 14, 0), "N": (0, -30, 0), "RS": (12, -28, -38), "RE": (18, 0, 0), "RW": (-40, 0, 0), "LS": (-28, 0, -38), "LE": (25, 0, 0)}, -0.4)
    kit.key_pose(rig, F(0.42), {"W": (4, 30, 0), "R": (0, 10, 0), "N": (0, -24, 0), "RS": (20, -22, -30), "RE": (25, 0, 0), "RW": (-25, 0, 0), "LS": (-20, 0, -30), "LE": (25, 0, 0)}, -0.2)
    kit.key_pose(rig, F(0.56), READY, 0)
    for t, forward in ((0, 0), (0.08, 0), (0.24, 0.9), (0.42, 0.9), (0.56, 0)):
        kit.key_root(rig, F(t), forward)
    kit.plant_feet(F(0))
    kit.key_foot("Right", F(0.08), (-0.5, 0, FOOT_Z))
    kit.key_foot("Right", F(0.16), (-0.45, -0.9, 0.6))
    kit.key_foot("Right", F(0.24), (-0.45, -1.6, FOOT_Z))
    kit.key_foot("Right", F(0.42), (-0.45, -1.6, FOOT_Z))
    kit.key_foot("Right", F(0.50), (-0.5, -0.7, 0.45))
    kit.key_foot("Left", F(0.42), (0.5, 0, FOOT_Z))
    kit.plant_feet(F(0.56))


def _cut2(rig, f):
    """A flat sweep from the right side across to the left at chest height, turning the hips into it."""
    F = lambda t: kit.frame_at(f, t)
    kit.key_pose(rig, F(0), READY)
    kit.key_pose(rig, F(0.07), {"W": (0, -35, 0), "R": (0, -12, 0), "N": (0, 25, 0), "RS": (0, -15, 88), "RE": (25, 0, 0), "RW": (0, 20, 0), "LS": (20, 0, -20), "LE": (45, 0, 0)}, -0.2)
    kit.key_pose(rig, F(0.15), {"W": (0, -5, 0), "R": (0, 0, 0), "N": (0, 5, 0), "RS": (0, 70, 90), "RE": (10, 0, 0), "RW": (0, 0, 0), "LS": (0, 0, -30), "LE": (35, 0, 0)}, -0.3)
    kit.key_pose(rig, F(0.20), {"W": (0, 28, 0), "R": (0, 10, 0), "N": (0, -18, 0), "RS": (0, 115, 88), "RE": (8, 0, 0), "RW": (0, -20, 0), "LS": (-15, 0, -40), "LE": (25, 0, 0)}, -0.32)
    kit.key_pose(rig, F(0.30), {"W": (0, 40, 0), "R": (0, 14, 0), "N": (0, -26, 0), "RS": (0, 150, 80), "RE": (25, 0, 0), "RW": (0, -30, 0), "LS": (-22, 0, -42), "LE": (25, 0, 0)}, -0.25)
    kit.key_pose(rig, F(0.50), READY, 0)
    for t, forward in ((0, 0), (0.07, 0), (0.18, 0.5), (0.32, 0.5), (0.50, 0)):
        kit.key_root(rig, F(t), forward)
    kit.plant_feet(F(0))
    kit.key_foot("Right", F(0.07), (-0.5, 0, FOOT_Z))
    kit.key_foot("Right", F(0.13), (-0.55, -0.5, 0.45))
    kit.key_foot("Right", F(0.18), (-0.6, -0.9, FOOT_Z))
    kit.key_foot("Right", F(0.36), (-0.6, -0.9, FOOT_Z))
    kit.key_foot("Left", F(0.36), (0.5, 0, FOOT_Z))
    kit.plant_feet(F(0.50))


def _cut3(rig, f):
    """A leaping two-handed overhead slam: crouch, jump in with the sword raised, slam it down, rise."""
    F = lambda t: kit.frame_at(f, t)
    kit.key_pose(rig, F(0), READY)
    kit.key_pose(rig, F(0.10), {"W": (18, 0, 0), "N": (-10, 0, 0), "RS": (40, 0, 20), "RE": (75, 0, 0), "LS": (35, 0, -15), "LE": (70, 0, 0)}, -0.7)
    kit.key_pose(rig, F(0.22), {"W": (-14, 0, 0), "N": (-8, 0, 0), "RS": (172, 0, 12), "RE": (22, 0, 0), "RW": (10, 0, 0), "LS": (172, 0, -12), "LE": (22, 0, 0)}, 0.9)
    kit.key_pose(rig, F(0.35), {"W": (38, 0, 0), "N": (12, 0, 0), "RS": (42, 0, 6), "RE": (5, 0, 0), "RW": (-30, 0, 0), "LS": (46, 0, -6), "LE": (8, 0, 0)}, -0.55)
    kit.key_pose(rig, F(0.50), {"W": (34, 0, 0), "N": (10, 0, 0), "RS": (38, 0, 6), "RE": (8, 0, 0), "RW": (-25, 0, 0), "LS": (42, 0, -6), "LE": (10, 0, 0)}, -0.5)
    kit.key_pose(rig, F(0.75), READY, 0)
    for t, forward in ((0, 0), (0.10, 0), (0.35, 1.3), (0.55, 1.3), (0.75, 0)):
        kit.key_root(rig, F(t), forward)
    kit.plant_feet(F(0))
    kit.plant_feet(F(0.10))
    kit.key_foot("Right", F(0.22), (-0.5, -0.8, 0.9))
    kit.key_foot("Left", F(0.22), (0.5, -0.6, 0.9))
    kit.plant_feet(F(0.35), 1.6, 1.0)
    kit.plant_feet(F(0.55), 1.6, 1.0)
    kit.key_foot("Right", F(0.66), (-0.5, -0.8, 0.45))
    kit.plant_feet(F(0.75))


def _skill(rig, f):
    """A spinning slash: the sword held out to the right, one full turn on the spot with a small hop."""
    F = lambda t: kit.frame_at(f, t)
    arm = {"RS": (0, -5, 92), "RE": (5, 0, 0), "RW": (0, 15, 0), "LS": (10, 0, -55), "LE": (20, 0, 0)}
    kit.key_pose(rig, F(0), READY)
    windup = dict(arm, W=(0, -30, 0), N=(0, 20, 0), R=(0, 0, 0))
    kit.key_pose(rig, F(0.10), windup, -0.35)
    # the turn: 45 degrees a key so the hips (and the feet round them) follow a circle
    spin = [(0.10, 0), (0.15, -45), (0.20, -90), (0.25, -135), (0.30, -180), (0.35, -225), (0.40, -270), (0.45, -315), (0.50, -360)]
    for t, yaw in spin:
        lift = 0.25 if 0.2 <= t <= 0.4 else -0.2
        kit.key_pose(rig, F(t), dict(arm, R=(0, yaw, 0), W=(0, 10, 0)), lift)
        a = math.radians(yaw)
        for side, sx in (("Right", -0.5), ("Left", 0.5)):
            x = sx * math.cos(a)
            y = sx * math.sin(a)
            z = FOOT_Z + (0.35 if 0.2 <= t <= 0.4 else 0)
            kit.key_foot(side, F(t), (x, y, z))
    kit.key_pose(rig, F(0.62), dict(arm, R=(0, -360, 0), W=(0, 20, 0)), -0.25)
    kit.key_pose(rig, F(0.80), dict(READY, R=(0, -360, 0)), 0)
    kit.key_root(rig, F(0), 0)
    kit.plant_feet(F(0))
    kit.plant_feet(F(0.62))
    kit.plant_feet(F(0.80))


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
    "cut1": (_cut1, 0.56, False, [{"name": "Hit", "t": 0.28}], False, "Action"),
    "cut2": (_cut2, 0.50, False, [{"name": "Hit", "t": 0.20}], False, "Action"),
    "cut3": (_cut3, 0.75, False, [{"name": "Hit", "t": 0.35}], False, "Action"),
    "skill": (_skill, 0.80, False, [{"name": "Hit", "t": 0.30}], False, "Action"),
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
    last = kit.frame_at(first, length)
    kit.bpy.context.scene.frame_start, kit.bpy.context.scene.frame_end = first, last
    count = kit.export_move(rig, os.path.join(json_dir, name + ".json"), name, first, last, loop, kit.UPPER_BODY if upper else None, markers, priority)
    if render_dir:
        frames = list(range(first, last + 1, kit.EXPORT_STEP))
        kit.render_frames(os.path.join(render_dir, name, "front"), frames, *FRONT)
        kit.render_frames(os.path.join(render_dir, name, "side"), frames, *SIDE)
    return count


def make_all(json_dir, render_dir=None):
    return {name: make(name, json_dir, render_dir) for name in MOVES}
