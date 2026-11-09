"""The Rift Reaper's skill, Thousand Cuts (Config/Swords riftReaper; spec
docs/superpowers/specs/2026-11-09-weapons-round3-scythes-design.md 5.4), keyed on anim_kit's rig with the scythe prop,
on the scythe moveset's helpers (anim_scythe).

Its cuts and moves are the scythe's (shared); only the skill is its own. Export and previews in a background Blender:
    "C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" -b --factory-startup --python tools/blender/run_sword_moves.py -- --sword rift_reaper [--preview <dir>]
then `lune run tools/anim/build_kfs assets/blender/Animations/RiftReaper assets/animations/RiftReaper`.
The "Hit" marker is the harvest and matches Config/Swords riftReaper.skill.hitAt.

Beats (the storyboard the owner approved, 2026-11-09: "flashy violent, exaggerated"): into both hands and raised high
overhead, arching back, through the charge (the ground cracking round you); at SLAM the butt driven down into the
ground in front, crouched (the rift opens, the Grim Reaper rises behind you); sunk to a kneel leaning on the scythe
through the cuts (you fade half into the rift, swaying); up and wound over the right shoulder, then the X: one
diagonal stroke down to the left at the Hit (the harvest) and a second down to the right right after it; held low,
back up to the guard. You never move across the ground.
"""
import importlib
import os

import anim_kit as kit
import anim_scythe as sc

importlib.reload(kit)
importlib.reload(sc)
PROP = sc.PROP
FOLDER = "RiftReaper"
NATURAL = ("skill",)
FOOT_Z = kit.FOOT_Z
SLAM = 0.7  # the butt driven into the ground: the rift opens
HIT = 1.8  # the harvest (the first stroke of the X)
LENGTH = 2.6

RAISED = dict(sc._body(0, 0, 0, -12), N=(-14, 0, 0), **sc.arm((160, 0, -6), 20, 96, -12 + sc.HOLD_TURN))
PLANTED = dict(sc._body(0, 0, 0, 18), **sc.arm((62, 0, 6), 8, 92, sc.HOLD_TURN))


def _kneel(sway):
    """Sunk low leaning on the planted scythe, swaying `sway` degrees."""
    return dict(sc._body(0, sway, -sway, 28), N=(-12, -sway, 0), **sc.arm((58, 0, 6), 12, 90, sc.HOLD_TURN))


def _skill(rig, f):
    """Thousand Cuts: raised overhead, the butt slammed down (the rift), the kneel through the cuts, then the X."""
    pose, root, foot, feet = sc._pose, sc._root, sc._foot, sc._feet
    pose(rig, f, 0, sc.READY, 0)
    pose(rig, f, 0.18, RAISED, 0.05)
    pose(rig, f, 0.55, dict(RAISED, W=(-16, 0, 0), N=(-18, 0, 0)), 0.15)
    pose(rig, f, SLAM, PLANTED, -0.6, kit.SNAP)
    pose(rig, f, 0.85, dict(PLANTED, W=(22, 0, 0)), -0.75)
    pose(rig, f, 1.05, _kneel(0), -1.25)
    pose(rig, f, 1.3, _kneel(6), -1.3)
    pose(rig, f, 1.5, _kneel(-6), -1.3)
    pose(rig, f, 1.62, _kneel(0), -1.25)
    pose(rig, f, 1.72, dict(sc._body(-40, -30, 30, 6), **sc.arm((152, 0, 30), 20, 112)), -0.3, kit.SNAP)
    pose(rig, f, HIT, dict(sc._body(30, 26, -24, 20), **sc.arm((42, 0, -22), 0, -30)), -0.75, kit.SNAP)
    pose(rig, f, 1.88, dict(sc._body(34, 26, -26, 4), **sc.arm((150, 0, -30), 20, 104)), -0.4, kit.SNAP)
    pose(rig, f, 1.98, dict(sc._body(-30, -26, 24, 20), **sc.arm((42, 0, 26), 0, -30)), -0.8, kit.SNAP)
    pose(rig, f, 2.25, dict(sc._body(-34, -28, 26, 16), **sc.arm((40, 0, 28), 6, -26)), -0.75)
    pose(rig, f, LENGTH, sc.READY, 0)
    sc._both(rig, f, 0.05, 0.15, 2.3, 2.45)
    root(rig, f, 0, 0)
    feet(f, 0, 0, 0)
    feet(f, 0.18, 0, 0)
    foot("Right", f, SLAM, (-0.9, 0.7, FOOT_Z), kit.SNAP)
    foot("Left", f, SLAM, (0.7, -0.6, FOOT_Z), kit.SNAP)
    foot("Right", f, 1.72, (-0.9, 0.7, FOOT_Z))
    foot("Left", f, 1.72, (0.7, -0.6, FOOT_Z))
    feet(f, LENGTH, 0, 0)


MOVES = {"skill": (_skill, LENGTH, False, [{"name": "Hit", "t": HIT}], False, "Action")}
# The preview frames you, the scythe raised high and the 14-stud harvest round you
PREVIEW_VIEWS = {"skill": {"front": ((10.0, -18.0, 7.0), (0, -1.0, 3.6)), "side": ((19.0, -1.0, 5.5), (0, -1.0, 3.6))}}


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
        views = PREVIEW_VIEWS[name]
        kit.render_frames(os.path.join(render_dir, name, "front"), frames, *views["front"])
        kit.render_frames(os.path.join(render_dir, name, "side"), frames, *views["side"])
    return count
