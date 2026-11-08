"""The Magma Halberd's skill, Magma Cleave (Config/Swords magmaHalberd; spec
docs/superpowers/specs/2026-11-09-halberd-and-trident-skills-design.md 3), keyed on anim_kit's rig with the spear
prop, on the spear moveset's helpers (anim_spear).

Its cuts and moves are the spear's (shared); only the skill is its own. Export and previews in a background Blender:
    "C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" -b --factory-startup --python tools/blender/run_sword_moves.py -- --sword magma_halberd [--preview <dir>]
then `lune run tools/anim/build_kfs assets/blender/Animations/MagmaHalberd assets/animations/MagmaHalberd`.
The "Hit" marker is the swipe passing your front and matches Config/Swords magmaHalberd.skill.hitAt (the fire crescent
leaves then).

Beats (owner 2026-11-09: "one big swipe. with flaming horizontal slash effects"): swung into both hands and pulled back
over the right shoulder with the body wound right (the wind-up), coiled a little tighter, then one huge horizontal swing
right to left across the front (the Hit), the blade carried on round to low on the left, held a moment, back up to the
upright guard. The character doesn't move across the ground: the fire carries the reach.
"""
import importlib
import os

import anim_kit as kit
import anim_spear as sp

importlib.reload(kit)
importlib.reload(sp)
PROP = sp.PROP
FOLDER = "MagmaHalberd"
NATURAL = ("skill",)
FOOT_Z = kit.FOOT_Z
WOUND = 0.4  # pulled back over the right shoulder
COILED = 0.5  # the tightest wind
HIT = 0.6  # the swipe across your front
LENGTH = 1.2


def _skill(rig, f):
    """Magma Cleave: into both hands and back over the right shoulder, one huge swing right to left (the Hit), carried
    round to low on the left, then back up to upright."""
    sp._pose(rig, f, 0, sp.READY, 0)
    sp._pose(rig, f, 0.10, dict(sp._body((0, 30, 0), (8, 24, 0), (0, -24, 0)), **sp.arm((30, 0, 16), 40, 70)), -0.3)
    sp._pose(rig, f, WOUND, dict(sp._body((0, 62, 0), (14, 46, 0), (0, -46, 0)), **sp.arm((40, 0, 36), 40, 30)), -0.55)
    sp._pose(rig, f, COILED, dict(sp._body((0, 70, 0), (16, 52, 0), (0, -52, 0)), **sp.arm((44, 0, 38), 42, 28)), -0.6, kit.SNAP)
    sp._pose(rig, f, HIT, dict(sp._body((0, -10, 0), (6, -14, 0), (0, 10, 0)), **sp.arm((60, 0, 30), 8, 2)), -0.7, kit.SNAP)
    sp._pose(rig, f, 0.72, dict(sp._body((0, -70, 0), (10, -46, 0), (0, 40, 0)), **sp.arm((30, 0, 30), 10, -30)), -0.75)
    sp._pose(rig, f, 0.90, dict(sp._body((0, -74, 0), (12, -48, 0), (0, 42, 0)), **sp.arm((28, 0, 30), 12, -32)), -0.72)
    sp._pose(rig, f, 1.05, dict(sp._body((0, -20, 0), (-4, -10, 0), (0, 10, 0)), **sp.arm((24, 0, 10), 44, 55)), -0.25)
    sp._pose(rig, f, LENGTH, sp.READY, 0)
    sp._both(rig, f, 0.04, 0.12, 0.92, 1.05)
    sp._root(rig, f, 0, 0)
    sp._root(rig, f, LENGTH, 0)
    sp._feet(f, 0, 0, 0)
    sp._foot("Right", f, 0.10, (-0.9, 0.8, FOOT_Z))
    sp._foot("Left", f, 0.10, (0.9, -1.0, FOOT_Z))
    sp._foot("Right", f, 1.05, (-0.9, 0.8, FOOT_Z))
    sp._foot("Left", f, 1.05, (0.9, -1.0, FOOT_Z))
    sp._feet(f, LENGTH, 0, 0)


# name -> (keying function, length in seconds, loop, markers, upper body only, priority)
MOVES = {"skill": (_skill, LENGTH, False, [{"name": "Hit", "t": HIT}], False, "Action")}
# The preview frames you and the half circle in front
PREVIEW_VIEWS = {"skill": {"front": ((12.0, -18.0, 7.0), (0, -2.0, 2.6)), "side": ((20.0, -2.0, 4.5), (0, -2.0, 2.6))}}


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
