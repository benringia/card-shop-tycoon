"""Exports the starter sword's moves and, optionally, renders 60 fps MP4 previews, in a background Blender.

    "C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" -b --factory-startup --python tools/blender/run_sword_moves.py -- [--preview <dir>] [move ...]

With no moves it exports the sword moves (anim_starter_sword.NATURAL). JSON goes to
assets/blender/Animations/StarterSword (then `lune run tools/anim/build_kfs`). --preview <dir> also writes
<dir>/moves-<move>-<front|side>.mp4 (the travel shows in the preview; the export is in place). Never run this in the
owner's open Blender: anim_kit.build() empties the scene.
"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import anim_kit as kit  # noqa: E402
import anim_starter_sword as moves  # noqa: E402

REPO = os.path.dirname(os.path.dirname(HERE))
JSON_DIR = os.path.join(REPO, "assets", "blender", "Animations", "StarterSword")
VIEWS = {
    "default": {"front": ((9.0, -14.0, 5.6), (0, -1.5, 2.5)), "side": ((16.0, -1.5, 4.6), (0, -1.5, 2.5))},
    "skill": {"front": ((13.0, -24.0, 7.5), (0, -5.0, 2.5)), "side": ((24.0, -5.0, 5.0), (0, -5.0, 2.5))},
    "cut3": {"front": ((14.0, -21.0, 9.0), (0, -2.0, 4.6)), "side": ((26.0, -2.0, 7.5), (0, -2.0, 4.6))},  # the big jump
}
LEAD, TAIL = 12, 24  # preview frames of standing still before and after, so the loop reads

args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
preview = None
if "--preview" in args:
    i = args.index("--preview")
    preview = args[i + 1]
    del args[i:i + 2]
names = args or list(moves.NATURAL)

for name in names:
    count = moves.make(name, JSON_DIR)
    print("EXPORTED", name, count)
    if preview:
        fn, length = moves.MOVES[name][0], moves.MOVES[name][1]
        rig = kit.build()
        first = 1 + LEAD
        fn(rig, first)
        if name in moves.NATURAL:
            kit.apply_eases(rig)
        last = kit.frame_at(first, length) + TAIL
        for view, (cam, target) in VIEWS.get(name, VIEWS["default"]).items():
            kit.render_video(os.path.join(preview, f"moves-{name}-{view}.mp4"), 1, last, cam, target)
        print("PREVIEW", name)
