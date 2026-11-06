"""The Verdant Blade's skill, Thornline (Config/Swords verdantBlade; spec
docs/superpowers/specs/2026-11-06-sword-skills-design.md 5), keyed on anim_kit's rig like the starter sword's moves.

Its cuts are the starter sword's (shared); only the skill is its own. Export and previews in a background Blender:
    "C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" -b --factory-startup --python tools/blender/run_sword_moves.py -- --sword verdant_blade [--preview <dir>]
then `lune run tools/anim/build_kfs assets/blender/Animations/VerdantBlade assets/animations/VerdantBlade`.
The "Hit" marker is when the vines leave the blade (Config/Swords verdantBlade.skill.hitAt); "Hold" is where the game
freezes the move until the vines reach the foe (skill.hold.at), and the key after it (skill.hold.snap) plays as they
snap shut there (SwordRules.holdFor).

Beats (storyboard approved 2026-11-07, the vines racing out from the blade; owner: the blade vertical from the hop to
the pierce, held in the ground until the vines reach the foe): a short hop with the blade hanging point-down, plunged
into the ground in front (STAB), held leaning on it, a shove on the hilt as the vines snap shut, wrenched free, back to
ready. The character doesn't move across the ground in the game.
"""
import importlib
import os

import anim_kit as kit

importlib.reload(kit)
READY = kit.READY
FOOT_Z = kit.FOOT_Z
FOLDER = "VerdantBlade"
NATURAL = ("skill",)
STAB_AT = 0.42  # the blade meets the ground
HIT = 0.45  # the vines leave
HOLD = 0.5  # the game holds the move here until the vines reach the foe
SNAP = 0.58  # the shove on the hilt as they snap shut
LENGTH = 0.95
PREVIEW_HOLD = 0.0  # seconds of hold keyed in for the previews only (run_sword_moves sets PREVIEW_HOLD_SHOWN)
PREVIEW_HOLD_SHOWN = 0.5  # a foe about 12 studs away


def _pose(rig, f, t, p, lift, ease=kit.SOFT, lag=None):
    kit.key_pose(rig, kit.frame_at(f, t), p, lift, ease, kit.LAG_SWORD if lag is None else lag)


def _foot(side, f, t, pos, ease=kit.SOFT):
    kit.key_foot(side, kit.frame_at(f, t), pos, ease)


def _feet(f, t, right, left, ease=kit.SOFT):
    _foot("Right", f, t, (-0.5, -right, FOOT_Z), ease)
    _foot("Left", f, t, (0.5, -left, FOOT_Z), ease)


# Owner 2026-11-07: the blade vertical, point down, from the hop to the pierce. With this grip the blade points straight
# down with the wrist bent well down (more the higher the hands: checked on the side preview frames), keyed without the
# arm's overlap lag (a trailing wrist would tip the blade)
VERTICAL = {}
# Gathering: hands up in front of the chest, the blade hanging point-down
GATHER = {"W": (-8, 0, 0), "N": (-4, 0, 0), "RS": (95, 0, -12), "RE": (20, 0, 0), "RW": (-135, 0, 0), "LS": (95, 0, 12), "LE": (20, 0, 0)}
# The hop's top: hands raised overhead, the blade hanging point-down in front of you
RAISED = {"W": (8, 0, 0), "N": (6, 0, 0), "RS": (150, 0, -12), "RE": (5, 0, 0), "RW": (-195, 0, 0), "LS": (150, 0, 12), "LE": (5, 0, 0)}
# Plunging: the hands coming straight down, the blade still vertical
DRIVING = {"W": (-10, 0, 0), "N": (-8, 0, 0), "RS": (105, 0, -12), "RE": (10, 0, 0), "RW": (-140, 0, 0), "LS": (105, 0, 12), "LE": (10, 0, 0)}
# Planted: both hands on the hilt over the blade stabbed point-down into the ground in front (the finisher's stab)
STAB = {"W": (-18, 0, 0), "N": (-18, 0, 0), "RS": (60, 0, -12), "RE": (20, 0, 0), "RW": (-75, 0, 0), "LS": (60, 0, 12), "LE": (24, 0, 0)}
# Wrenching it free
PULL = {"W": (-6, 0, 0), "N": (-4, 0, 0), "RS": (85, 0, -12), "RE": (40, 0, 0), "RW": (-25, 0, 0), "LS": (85, 0, 12), "LE": (40, 0, 0)}


def _skill(rig, f):
    """Thornline: hop, stab the blade into the ground, hold while the vines race out and snap shut, pull free."""
    _pose(rig, f, 0, READY, 0)
    _pose(rig, f, 0.10, GATHER, -0.5, kit.SNAP, VERTICAL)
    _pose(rig, f, 0.22, RAISED, 1.5, kit.SOFT, VERTICAL)
    _pose(rig, f, 0.36, DRIVING, 0.4, ("EXPO", "EASE_IN"), VERTICAL)
    _pose(rig, f, STAB_AT, STAB, -1.1, kit.SNAP, VERTICAL)
    hold = dict(STAB, W=(-22, 0, 0), N=(-24, 0, 0))
    _pose(rig, f, HOLD, hold, -1.2)
    late = PREVIEW_HOLD  # (the previews' stand-in for the game's hold)
    if late > 0:
        _pose(rig, f, HOLD + late, hold, -1.2)
    _pose(rig, f, SNAP + late, dict(STAB, W=(-26, 0, 0), N=(-20, 0, 0)), -1.3, kit.SNAP)
    _pose(rig, f, 0.72 + late, PULL, -0.6)
    _pose(rig, f, LENGTH + late, READY, 0)
    kit.two_hands(rig, lambda t: kit.frame_at(f, t), 0.04, 0.16, 0.74 + late, 0.86 + late)
    kit.key_root(rig, kit.frame_at(f, 0), 0)
    _feet(f, 0, 0, 0)
    _feet(f, 0.10, -0.1, 0.1, kit.SNAP)
    for side, sx in (("Right", -0.5), ("Left", 0.5)):
        _foot(side, f, 0.22, (sx, 0.1, FOOT_Z + 1.5 - 0.5), kit.SOFT)
    _foot("Left", f, STAB_AT, (0.55, -0.7, FOOT_Z), kit.SNAP)
    _foot("Right", f, STAB_AT, (-0.5, 0.5, FOOT_Z), kit.SNAP)
    _feet(f, SNAP + late, -0.5, 0.7)
    _feet(f, 0.72 + late, -0.4, 0.5)
    _feet(f, LENGTH + late, 0, 0)


# name -> (keying function, length in seconds, loop, markers, upper body only, priority), as anim_starter_sword
MOVES = {"skill": (_skill, LENGTH, False, [{"name": "Hit", "t": HIT}, {"name": "Hold", "t": HOLD}], False, "Action")}
# Preview cameras (front and side) for run_sword_moves.py: the move stays in place, the vines would run ahead (-Y)
PREVIEW_VIEWS = {"skill": {"front": ((9.0, -14.0, 6.0), (0, -1.0, 3.0)), "side": ((15.0, -1.0, 5.0), (0, -1.0, 3.0))}}


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
