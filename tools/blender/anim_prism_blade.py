"""The Prism Blade's skill, Prism Judgment (Config/Swords prismBlade; spec
docs/superpowers/specs/2026-11-06-sword-skills-design.md 5), keyed on anim_kit's rig like the starter sword's moves.

Its cuts are the starter sword's (shared); only the skill is its own. Export and previews in a background Blender:
    "C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" -b --factory-startup --python tools/blender/run_sword_moves.py -- --sword prism_blade [--preview <dir>]
then `lune run tools/anim/build_kfs assets/blender/Animations/PrismBlade assets/animations/PrismBlade`.
The "Hit" marker is the first ghost blade's strike (Config/Swords prismBlade.skill.hitAt); the other four follow it
`gap` seconds apart (its shape's), each with a small thrust of the pointing arm.

Beats (storyboard approved 2026-11-07, the ring spinning and each blade diving in turn; owner: "make everything
exaggerated ... DO NOT MAKE BORING PLAIN ANIMATIONS"): a crouch drawing the blade low behind, the blade swept up to the
sky arched back on the toes (the summon), snapped down into the command pose pointing the blade at the boss with the
free arm flung out, a thrust on each strike, the blade swept up again as the rainbow pillar erupts, back to ready.
"""
import importlib
import os

import anim_kit as kit

importlib.reload(kit)
READY = kit.READY
FOOT_Z = kit.FOOT_Z
FOLDER = "PrismBlade"
NATURAL = ("skill",)
HIT = 0.6  # the first ghost blade strikes
GAP = 0.15  # then one every GAP (Config/Swords prismBlade.skill.shape.gap)
STRIKES = 5
PILLAR = 1.28  # the rainbow pillar erupts
LENGTH = 1.75


def _pose(rig, f, t, p, lift, ease=kit.SOFT):
    kit.key_pose(rig, kit.frame_at(f, t), p, lift, ease, kit.LAG_SWORD)


def _foot(side, f, t, pos, ease=kit.SOFT):
    kit.key_foot(side, kit.frame_at(f, t), pos, ease)


def _feet(f, t, right, left, ease=kit.SOFT):
    _foot("Right", f, t, (-0.5, -right, FOOT_Z), ease)
    _foot("Left", f, t, (0.5, -left, FOOT_Z), ease)


# Drawn low behind, crouched, ready to sweep
LOW = {"R": (0, -25, 0), "W": (-10, -30, 0), "N": (0, 25, 0), "RS": (-30, 0, 25), "RE": (20, 0, 0), "RW": (10, 0, 0), "LS": (35, 0, -25), "LE": (40, 0, 0)}
# The summon: the blade raised to the sky (pointing up), arched back, the free arm reaching up too
SKY = {"W": (24, 0, 0), "N": (26, 0, 0), "RS": (178, 0, -10), "RE": (8, 0, 0), "RW": (-70, 0, 0), "LS": (150, 0, 35), "LE": (20, 0, 0)}
# The command: the blade pointed straight at the boss along the arm, the free arm flung out behind, a wide stance
COMMAND = {"R": (0, 18, 0), "W": (-6, 10, 0), "N": (0, -18, 0), "RS": (90, 0, -8), "RE": (0, 0, 0), "RW": (-15, 0, 0), "LS": (40, 0, -75), "LE": (15, 0, 0)}


def _skill(rig, f):
    """Prism Judgment: crouch, sweep to the sky (summon), point at the boss (command), a thrust per strike, sweep up as
    the pillar erupts, back to ready."""
    _pose(rig, f, 0, READY, 0)
    _pose(rig, f, 0.12, LOW, -0.7, kit.SNAP)
    _pose(rig, f, 0.3, SKY, 0.35)
    _pose(rig, f, 0.45, dict(SKY, W=(30, 0, 0), N=(30, 0, 0)), 0.45)
    _pose(rig, f, 0.55, COMMAND, -0.35, kit.SNAP)
    for index in range(STRIKES):
        at = HIT + index * GAP
        # each strike: the pointing arm punches forward and the body leans in, then eases back
        _pose(rig, f, at, dict(COMMAND, RS=(94, 0, -8), W=(-12, 10, 0)), -0.45, kit.SNAP)
        _pose(rig, f, at + GAP * 0.6, dict(COMMAND, RS=(88, 0, -8)), -0.38)
    _pose(rig, f, PILLAR, dict(SKY, RS=(170, 0, -14), LS=(165, 0, 30)), 0.4, kit.SNAP)
    _pose(rig, f, PILLAR + 0.22, dict(SKY, W=(28, 0, 0), N=(30, 0, 0)), 0.45)
    _pose(rig, f, LENGTH, READY, 0)
    kit.key_root(rig, kit.frame_at(f, 0), 0)
    _feet(f, 0, 0, 0)
    _feet(f, 0.12, 0.4, -0.3, kit.SNAP)
    _feet(f, 0.3, 0.1, -0.1)
    _foot("Left", f, 0.55, (0.6, -1.1, FOOT_Z), kit.SNAP)
    _foot("Right", f, 0.55, (-0.55, 0.6, FOOT_Z), kit.SNAP)
    _feet(f, PILLAR, -0.4, 0.8)
    _feet(f, LENGTH, 0, 0)


# name -> (keying function, length in seconds, loop, markers, upper body only, priority), as anim_starter_sword
MOVES = {"skill": (_skill, LENGTH, False, [{"name": "Hit", "t": HIT}], False, "Action")}
# Preview cameras (front and side) for run_sword_moves.py
PREVIEW_VIEWS = {"skill": {"front": ((9.0, -14.0, 6.5), (0, -1.0, 3.5)), "side": ((15.0, -1.0, 5.5), (0, -1.0, 3.5))}}


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
