"""The Tidal Trident's skill, Torrent Strike (Config/Swords tidalTrident; spec
docs/superpowers/specs/2026-11-09-halberd-and-trident-skills-design.md 4), keyed on anim_kit's rig with the spear
prop, on the spear moveset's helpers (anim_spear).

Its cuts and moves are the spear's (shared); only the skill is its own. Export and previews in a background Blender:
    "C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" -b --factory-startup --python tools/blender/run_sword_moves.py -- --sword tidal_trident [--preview <dir>]
then `lune run tools/anim/build_kfs assets/blender/Animations/TidalTrident assets/animations/TidalTrident`.
The "Slam" marker is the prongs hitting the ground (the splash ring and cracks); the "Hit" marker is the torrents
bursting up and matches Config/Swords tidalTrident.skill.hitAt.

Beats (owner 2026-11-09: "the player strike the ground with the trident, while the trident is stuck to the ground,
torrents of water appears from the ground"): swung up into both hands and raised high overhead (Sky Pierce's raised
poses, without the leap), whipped down tip-first into the ground just ahead (the Slam), crouched low leaning on the stuck
shaft as the torrents burst (the Hit) and held there while they rise and fall back, then pulled free and back up to the
upright guard. The character doesn't move across the ground.
"""
import importlib
import os

import anim_kit as kit
import anim_spear as sp

importlib.reload(kit)
importlib.reload(sp)
PROP = sp.PROP
FOLDER = "TidalTrident"
NATURAL = ("skill",)
FOOT_Z = kit.FOOT_Z
RAISED_AT = 0.4  # high overhead
PEAK = 0.45  # arched back, about to whip down
SLAM = 0.55  # the prongs into the ground
HIT = 0.75  # the torrents
FALL = 1.5  # the water falls back: the trident comes out
LENGTH = 1.9


def _stuck(w, n):
    """Crouched over the stuck trident, both hands on it, the waist bent `w` and the neck `n` degrees; the shaft leans
    out ahead about 37 degrees down (the waist's bend adds to the arm's pitch): a stake of shaft shows between your
    hands and the ground, the prongs buried."""
    return dict(sp.PLUNGE, W=(w, 0, 0), N=(n, 0, 0), **sp.arm((74, 0, 4), 8, -2))


def _skill(rig, f):
    """Torrent Strike: up into both hands and high overhead, whipped down tip-first into the ground (the Slam),
    leaning on it as the torrents burst (the Hit), held, then pulled free and back up to upright."""
    sp._pose(rig, f, 0, sp.READY, 0)
    sp._pose(rig, f, 0.12, dict(sp._body((0, 8, 0), (-6, 6, 0), (0, -6, 0)), **sp.arm((90, 0, -4), 40, 95)), -0.1)
    sp._pose(rig, f, RAISED_AT, sp.RAISED, 0.15)
    sp._pose(rig, f, PEAK, sp.HANG, 0.2, kit.SNAP)
    sp._pose(rig, f, SLAM, _stuck(-34, -26), -1.0, kit.SNAP)
    sp._pose(rig, f, 0.62, _stuck(-30, -24), -0.85)
    sp._pose(rig, f, HIT, _stuck(-38, -30), -1.1, kit.SNAP)
    sp._pose(rig, f, 1.0, _stuck(-34, -28), -1.05)
    sp._pose(rig, f, FALL, _stuck(-30, -24), -0.95)
    sp._pose(rig, f, 1.65, dict({"W": (-10, 0, 0), "N": (-6, 0, 0)}, **sp.arm((50, 0, 8), 30, 30)), -0.6)
    sp._pose(rig, f, LENGTH, sp.READY, 0)
    sp._both(rig, f, 0.04, 0.12, 1.6, 1.72)
    sp._root(rig, f, 0, 0)
    sp._root(rig, f, LENGTH, 0)
    sp._feet(f, 0, 0, 0)
    sp._foot("Right", f, 0.12, (-0.6, 0.4, FOOT_Z))
    sp._foot("Left", f, 0.12, (0.6, -0.6, FOOT_Z))
    sp._foot("Right", f, SLAM, (-0.8, 0.9, FOOT_Z), kit.SNAP)
    sp._foot("Left", f, SLAM, (0.7, -1.6, FOOT_Z), kit.SNAP)
    sp._foot("Right", f, FALL, (-0.8, 0.9, FOOT_Z))
    sp._foot("Left", f, FALL, (0.7, -1.6, FOOT_Z))
    sp._feet(f, LENGTH, 0, 0)


# name -> (keying function, length in seconds, loop, markers, upper body only, priority)
MOVES = {"skill": (_skill, LENGTH, False, [{"name": "Slam", "t": SLAM}, {"name": "Hit", "t": HIT}], False, "Action")}
# The preview frames you and the ground round you
PREVIEW_VIEWS = {"skill": {"front": ((12.0, -18.0, 6.0), (0, -2.0, 2.0)), "side": ((20.0, -2.0, 4.0), (0, -2.0, 2.0))}}


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
