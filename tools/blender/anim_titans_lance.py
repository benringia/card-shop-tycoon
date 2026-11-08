"""The Titan's Lance's skill, Titan's Wrath (Config/Swords titansLance; spec
docs/superpowers/specs/2026-11-08-forge-relayout-and-titans-wrath-design.md 3), keyed on anim_kit's rig with the spear
prop, on the spear moveset's helpers (anim_spear).

Its cuts and moves are the spear's (shared); only the skill is its own. Export and previews in a background Blender:
    "C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" -b --factory-startup --python tools/blender/run_sword_moves.py -- --sword titans_lance [--preview <dir>]
then `lune run tools/anim/build_kfs assets/blender/Animations/TitansLance assets/animations/TitansLance`.
The "Hit" marker is the thrust and matches Config/Swords titansLance.skill.hitAt (the beam and the fissure leave then).

Beats (the owner's storyboard, 2026-11-08: "charging stance before the spear thrust", exaggerated): swung down into
both hands and a step out into a low, wide stance with the lance drawn far back; a long charge (to CHARGED) trembling
harder and harder while sinking lower and coiling further; the deepest coil at PEAK (the tip's flash); one huge thrust
(the Hit) with the front foot driving forward; the thrust held while the fissure tears; back up to the upright guard.
The character doesn't move across the ground (no lunge in its config): the beam and the fissure carry the reach.
"""
import importlib
import os

import anim_kit as kit
import anim_spear as sp

importlib.reload(kit)
importlib.reload(sp)
PROP = sp.PROP
FOLDER = "TitansLance"
NATURAL = ("skill",)
FOOT_Z = kit.FOOT_Z
CHARGE_FROM = 0.26  # in the stance, the lance drawn back: the charge starts
PEAK = 1.22  # the deepest coil (the tip's white flash)
HIT = 1.35  # the thrust
LENGTH = 2.2
TREMBLE_STEP = 0.07  # seconds between the tremble's keys (it grows through the charge)


def _coil(k, s=0):
    """The charging pose, `k` from 0 (just drawn back) to 1 (the deepest coil), trembling to side `s` (-1, 0 or 1)."""
    amp = (1.0 + 3.5 * k) * s
    body = sp._body((0, 38 + 6 * k, 0), (16 + 6 * k + 0.6 * amp, 32 + 6 * k, 0.5 * amp), (-8 * k, -32 - 4 * k, 0))
    return dict(body, **sp.arm((-58 - 8 * k + amp, 0, 8), 46 + 2 * k, 4 + 0.5 * amp))


STRIKE = dict(sp._body((0, -12, 0), (-18, -14, 0), (8, 14, 0)), **sp.arm((88, 0, 3), 0, -2))
PUSH = dict(sp._body((0, -14, 0), (-22, -16, 0), (8, 16, 0)), **sp.arm((92, 0, 3), 0, -4))


def _skill(rig, f):
    """Titan's Wrath: into both hands and a low wide stance, the long trembling charge, the deepest coil, one huge
    thrust (the Hit), held while the fissure tears, then back up to upright."""
    sp._pose(rig, f, 0, sp.READY, 0)
    sp._pose(rig, f, 0.14, dict(sp._body((0, 20, 0), (10, 18, 0), (0, -18, 0)), **sp.arm((-30, 0, 8), 40, 4)), -0.5)
    sp._pose(rig, f, CHARGE_FROM, _coil(0), -0.72)
    t, side = CHARGE_FROM + TREMBLE_STEP, 1
    while t < PEAK - 0.06:
        k = (t - CHARGE_FROM) / (PEAK - CHARGE_FROM)
        sp._pose(rig, f, t, _coil(k, side), -0.72 - 0.16 * k)
        t += TREMBLE_STEP
        side = -side
    sp._pose(rig, f, PEAK, _coil(1.0), -0.92, kit.SNAP)
    sp._pose(rig, f, HIT, STRIKE, -0.68, kit.SNAP)
    sp._pose(rig, f, 1.55, PUSH, -0.72)
    sp._pose(rig, f, 1.75, PUSH, -0.7)
    sp._pose(rig, f, 1.95, dict(sp._body((0, -4, 0), (-4, -4, 0), (0, 4, 0)), **sp.arm((24, 0, 10), 44, 55)), -0.25)
    sp._pose(rig, f, LENGTH, sp.READY, 0)
    sp._both(rig, f, 0.04, 0.12, 1.78, 1.95)
    sp._root(rig, f, 0, 0)
    sp._root(rig, f, PEAK, -0.3, kit.SNAP)
    sp._root(rig, f, HIT, 0.6)
    sp._root(rig, f, LENGTH, 0)
    sp._feet(f, 0, 0, 0)
    sp._foot("Right", f, 0.14, (-0.9, 1.2, FOOT_Z))
    sp._foot("Left", f, 0.14, (0.9, -1.4, FOOT_Z))
    sp._foot("Right", f, PEAK, (-1.0, 1.5, FOOT_Z), kit.SNAP)
    sp._foot("Left", f, PEAK, (0.9, -1.5, FOOT_Z), kit.SNAP)
    sp._foot("Left", f, HIT, (0.8, -2.6, FOOT_Z), kit.SNAP)
    sp._foot("Right", f, HIT, (-0.9, 1.1, FOOT_Z), kit.SNAP)
    sp._foot("Left", f, 1.75, (0.8, -2.6, FOOT_Z))
    sp._foot("Right", f, 1.75, (-0.9, 1.1, FOOT_Z))
    sp._feet(f, LENGTH, 0, 0)


# name -> (keying function, length in seconds, loop, markers, upper body only, priority)
MOVES = {"skill": (_skill, LENGTH, False, [{"name": "Hit", "t": HIT}], False, "Action")}
# The preview frames you and the 14-stud reach ahead
PREVIEW_VIEWS = {"skill": {"front": ((12.0, -20.0, 7.0), (0, -4.0, 2.6)), "side": ((22.0, -4.0, 4.5), (0, -4.0, 2.6))}}


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
        views = PREVIEW_VIEWS[name]
        kit.render_frames(os.path.join(render_dir, name, "front"), frames, *views["front"])
        kit.render_frames(os.path.join(render_dir, name, "side"), frames, *views["side"])
    return count
