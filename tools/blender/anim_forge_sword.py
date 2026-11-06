"""The Forge Sword's skill, Elemental Spin (Config/Swords forgeSword, all five elements; spec
docs/superpowers/specs/2026-11-06-sword-skills-design.md 5), keyed on anim_kit's rig like the starter sword's moves.

Its cuts are the starter sword's (shared); only the skill is its own. Export and previews in a background Blender:
    "C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" -b --factory-startup --python tools/blender/run_sword_moves.py -- --sword forge_sword [--preview <dir>]
then `lune run tools/anim/build_kfs assets/blender/Animations/ForgeSword assets/animations/ForgeSword`.
The "Hit" marker is the ring wave bursting out (Config/Swords forgeSword.skill.hitAt).

Beats (storyboard approved 2026-11-07, option B: a double spin whipping up an element tornado): a low crouch wound back,
two fast full turns on the spot with the blade held out at waist height (the tornado), a crouched finish as the ring
wave bursts out, back to ready. The character doesn't move across the ground in the game.
"""
import importlib
import math
import os

import anim_kit as kit

importlib.reload(kit)
READY = kit.READY
FOOT_Z = kit.FOOT_Z
FOLDER = "ForgeSword"
NATURAL = ("skill",)
SPIN_FROM = 0.25  # the turns start
SPIN_TO = 0.75  # two full turns done
HIT = 0.8  # the ring wave bursts out
LENGTH = 1.1
TURNS = 2


def _pose(rig, f, t, p, lift, ease=kit.SOFT):
    kit.key_pose(rig, kit.frame_at(f, t), p, lift, ease, kit.LAG_SWORD)


def _foot(side, f, t, pos, ease=kit.SOFT):
    kit.key_foot(side, kit.frame_at(f, t), pos, ease)


def _feet_turned(f, t, yaw, ease=kit.HOLD, spread=0.55, lift=0.0):
    """Both feet turned with the body by `yaw` degrees round the spot (a pivot on the spot)."""
    a = math.radians(yaw)
    for side, sx in (("Right", -spread), ("Left", spread)):
        _foot(side, f, t, (sx * math.cos(a), sx * math.sin(a), FOOT_Z + lift), ease)


# The blade held out to the side at waist height (the spin), the free arm tucked in for speed
OUT = {"W": (-6, 0, 0), "N": (-4, 0, 0), "RS": (15, 0, 75), "RE": (10, 0, 0), "RW": (0, 0, 0), "LS": (30, 0, -20), "LE": (90, 0, 0)}
# Wound back: crouched, twisted the other way, the blade drawn back low
WOUND = {"R": (0, 45, 0), "W": (-14, 30, 0), "N": (0, -30, 0), "RS": (10, 0, 70), "RE": (15, 0, 0), "RW": (0, 0, 0), "LS": (35, 0, -30), "LE": (70, 0, 0)}
# The finish: crouched low, the blade swept out and down as the ring wave bursts
FINISH = {"W": (-18, 0, 0), "N": (-10, 0, 0), "RS": (5, 0, 85), "RE": (5, 0, 0), "RW": (0, 0, 0), "LS": (20, 0, -60), "LE": (20, 0, 0)}


def _skill(rig, f):
    """Elemental Spin: wind up, two turns with the blade out (the tornado), the ring wave, back to ready."""
    _pose(rig, f, 0, READY, 0)
    _pose(rig, f, 0.12, WOUND, -0.9)
    _pose(rig, f, 0.2, dict(WOUND, R=(0, 55, 0)), -0.95, kit.SNAP)
    # the turns: a key every quarter turn (the quaternions stay on their side), steady through
    steps = TURNS * 4
    for step in range(steps + 1):
        t = SPIN_FROM + (SPIN_TO - SPIN_FROM) * step / steps
        yaw = -90 * step
        lift = -0.55 + 0.15 * math.sin(step / steps * math.pi)
        _pose(rig, f, t, dict(OUT, R=(0, yaw, 0)), lift, kit.HOLD)
        _feet_turned(f, t, yaw, kit.HOLD, 0.55, 0.12 if step % 2 == 1 else 0.0)
    _pose(rig, f, HIT, dict(FINISH, R=(0, -360 * TURNS - 25, 0)), -1.0, kit.SNAP)
    _pose(rig, f, HIT + 0.12, dict(FINISH, R=(0, -360 * TURNS - 20, 0), W=(-20, 0, 0)), -1.0)
    _pose(rig, f, LENGTH, dict(READY, R=(0, -360 * TURNS, 0)), 0)
    kit.key_root(rig, kit.frame_at(f, 0), 0)
    _feet_turned(f, 0, 0, kit.SOFT, 0.5)
    _feet_turned(f, 0.12, 30, kit.SOFT, 0.7)
    _feet_turned(f, HIT, -360 * TURNS - 20, kit.SNAP, 0.75)
    _feet_turned(f, LENGTH, -360 * TURNS, kit.SOFT, 0.5)


# name -> (keying function, length in seconds, loop, markers, upper body only, priority), as anim_starter_sword
MOVES = {"skill": (_skill, LENGTH, False, [{"name": "Hit", "t": HIT}], False, "Action")}
# Preview cameras (front and side) for run_sword_moves.py
PREVIEW_VIEWS = {"skill": {"front": ((9.0, -14.0, 7.0), (0, 0, 2.8)), "side": ((15.0, -1.0, 6.0), (0, 0, 2.8))}}


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
