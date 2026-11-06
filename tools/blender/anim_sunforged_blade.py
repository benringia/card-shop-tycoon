"""The Sunforged Blade's skill, Sunfall Cleave (Config/Swords sunforgedBlade; spec
docs/superpowers/specs/2026-11-06-sword-skills-design.md 5), keyed on anim_kit's rig like the starter sword's moves.

Its cuts are the starter sword's (shared); only the skill is its own. Export and previews in a background Blender:
    "C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" -b --factory-startup --python tools/blender/run_sword_moves.py -- --sword sunforged_blade [--preview <dir>]
then `lune run tools/anim/build_kfs assets/blender/Animations/SunforgedBlade assets/animations/SunforgedBlade`.
The "Hit" marker is the swing's strike and matches Config/Swords sunforgedBlade.skill.hitAt (the wave leaves then).

Beats (owner 2026-11-07, after the first preview): a crouch, a high jump (about 5 studs), a long hang at the top
charging with the blade overhead two-handed, one huge cleave down in the air (the "Hit": the fire crescent leaves and
glides down toward the aim), the fall into a low landing over the front knee, back to ready. The character doesn't
move across the ground in the game, so the root stays put; the jump is the hips' lift (as the finisher's).
"""
import importlib
import os

import anim_kit as kit

importlib.reload(kit)
READY = kit.READY
FOOT_Z = kit.FOOT_Z
FOLDER = "SunforgedBlade"
NATURAL = ("skill",)
LENGTH = 1.85
HIT = 1.18


def _pose(rig, f, t, p, lift, ease=kit.SOFT):
    kit.key_pose(rig, kit.frame_at(f, t), p, lift, ease, kit.LAG_SWORD)


def _foot(side, f, t, pos, ease=kit.SOFT):
    kit.key_foot(side, kit.frame_at(f, t), pos, ease)


def _feet(f, t, right, left, ease=kit.SOFT):
    _foot("Right", f, t, (-0.5, -right, FOOT_Z), ease)
    _foot("Left", f, t, (0.5, -left, FOOT_Z), ease)


# Overhead with both hands, the blade pointing up and a little back (in these angles a positive waist x leans back)
OVERHEAD = {"W": (14, 0, 0), "N": (14, 0, 0), "RS": (178, 0, -12), "RE": (12, 0, 0), "RW": (-70, 0, 0), "LS": (178, 0, 12), "LE": (12, 0, 0)}
# The cleave's strike: arms out level in front, the blade sweeping down through the foe
STRIKE = {"W": (-25, 0, 0), "N": (-10, 0, 0), "RS": (70, 0, -10), "RE": (5, 0, 0), "RW": (-20, 0, 0), "LS": (70, 0, 10), "LE": (5, 0, 0)}
# The follow-through: bent over the front knee, the blade low in front pointing at the ground ahead
LOW = {"W": (-30, 0, 0), "N": (-8, 0, 0), "RS": (58, 0, -12), "RE": (5, 0, 0), "RW": (-12, 0, 0), "LS": (58, 0, 12), "LE": (8, 0, 0)}


# Crouched to jump, the blade low in both hands
CROUCH = {"W": (-15, 0, 0), "N": (-5, 0, 0), "RS": (30, 0, -10), "RE": (60, 0, 0), "RW": (-10, 0, 0), "LS": (30, 0, 10), "LE": (60, 0, 0)}
# Rising: the blade swept up as the body leaves the ground
RISING = {"W": (22, 0, 0), "N": (16, 0, 0), "RS": (150, 0, -15), "RE": (40, 0, 0), "RW": (-40, 0, 0), "LS": (150, 0, 15), "LE": (40, 0, 0)}
TOP = 5.0  # studs: the hips' lift at the top of the jump


def _air_feet(f, t, lift, tuck, ease=kit.HOLD, back=0.0):
    """Both feet in the air: `tuck` studs up towards the hips, `back` studs behind (the arched jump sweeps them back)."""
    for side, sx in (("Right", -0.5), ("Left", 0.5)):
        _foot(side, f, t, (sx, (-0.2 if side == "Left" else 0.2) + back, FOOT_Z + lift - tuck), ease)


def _skill(rig, f):
    """Sunfall Cleave: crouch, jump, hang charging, cleave in the air, fall, land low, recover."""
    _pose(rig, f, 0, READY, 0)
    _pose(rig, f, 0.12, CROUCH, -1.0)
    _pose(rig, f, 0.18, CROUCH, -1.05, kit.SNAP)
    _pose(rig, f, 0.30, RISING, 3.5, kit.HOLD)
    # The hang arched back like a drawn bow (owner 2026-11-07: "arch the body more on jump"), deepening as it charges
    _pose(rig, f, 0.42, dict(OVERHEAD, W=(30, 0, 0), N=(20, 0, 0)), TOP)
    _pose(rig, f, 0.75, dict(OVERHEAD, W=(34, 0, 0), N=(22, 0, 0)), TOP + 0.2)
    _pose(rig, f, 1.05, dict(OVERHEAD, W=(38, 0, 0), N=(24, 0, 0)), TOP + 0.1, kit.SNAP)
    _pose(rig, f, HIT, STRIKE, TOP - 0.6, kit.SNAP)
    _pose(rig, f, 1.26, LOW, 3.0, ("EXPO", "EASE_IN"))
    _pose(rig, f, 1.40, LOW, -0.9, kit.SNAP)
    _pose(rig, f, 1.60, dict(LOW, W=(-28, 0, 0)), -0.8)
    _pose(rig, f, LENGTH, READY, 0)
    kit.two_hands(rig, lambda t: kit.frame_at(f, t), 0.05, 0.25, 1.55, 1.7)
    kit.key_root(rig, kit.frame_at(f, 0), 0)
    _feet(f, 0, 0, 0)
    _feet(f, 0.12, -0.3, 0.3)
    _feet(f, 0.18, -0.3, 0.3, kit.SNAP)
    _air_feet(f, 0.30, 3.5, 0.8, kit.HOLD, 0.4)
    _air_feet(f, 0.42, TOP, 1.25, kit.SOFT, 0.9)
    _air_feet(f, 1.05, TOP + 0.1, 1.3, kit.SNAP, 1.1)
    _air_feet(f, HIT, TOP - 0.6, 0.9, ("EXPO", "EASE_IN"))
    _air_feet(f, 1.26, 3.0, 0.3, ("EXPO", "EASE_IN"))
    _foot("Left", f, 1.40, (0.55, -1.2, FOOT_Z), kit.SNAP)
    _foot("Right", f, 1.40, (-0.5, 0.6, FOOT_Z), kit.SNAP)
    _feet(f, 1.60, -0.6, 1.2)
    _feet(f, LENGTH, 0, 0)


# name -> (keying function, length in seconds, loop, markers, upper body only, priority), as anim_starter_sword
MOVES = {"skill": (_skill, LENGTH, False, [{"name": "Hit", "t": HIT}], False, "Action")}
# Preview cameras (front and side) for run_sword_moves.py: the move stays in place, the wave would run ahead (-Y)
PREVIEW_VIEWS = {"skill": {"front": ((13.0, -21.0, 10.5), (0, -1.0, 6.0)), "side": ((24.0, -1.0, 9.0), (0, -1.0, 6.0))}}


def make(name, json_dir, render_dir=None):
    """Builds, keys and exports one move (in place, every frame)."""
    fn, length, loop, markers, upper, priority = MOVES[name]
    rig = kit.build()
    first = 1
    fn(rig, first)
    kit.apply_eases(rig)
    last = kit.frame_at(first, length)
    kit.bpy.context.scene.frame_start, kit.bpy.context.scene.frame_end = first, last
    return kit.export_move(rig, os.path.join(json_dir, name + ".json"), name, first, last, loop, kit.UPPER_BODY if upper else None, markers, priority,
                           in_place=True, step=1)
