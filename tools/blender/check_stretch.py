"""Finds stretching in a rigged model's clips (owner 2026-11-09: "check all animations make sure nothing is
stretching"): plays each clip of an anim_<model>.py module, compares every mesh edge's length with its rest length,
and prints the worst stretches (ratio, the clip and frame, where on the model at rest, the bones that move it).
Run in a background Blender with the rigged .blend open:

  blender -b assets/blender/Pish/Pish.blend --python tools/blender/check_stretch.py -- anim_pish
  (STEP=2 samples every second frame; LIMIT=1.6 lists edges stretched past 1.6 times their rest length)
"""
import importlib
import os
import sys

import bpy
import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

module = importlib.import_module(sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else "anim_pish")
STEP = int(os.environ.get("STEP", "2"))
LIMIT = float(os.environ.get("LIMIT", "1.6"))

mesh = next(o for o in bpy.data.objects if o.type == "MESH" and o.find_armature())
edges = np.array([e.vertices[:] for e in mesh.data.edges])
rest = np.array([tuple(mesh.matrix_world @ v.co) for v in mesh.data.vertices])
rest_length = np.linalg.norm(rest[edges[:, 0]] - rest[edges[:, 1]], axis=1)
names = {g.index: g.name for g in mesh.vertex_groups}


def bones_of(index):
    v = mesh.data.vertices[index]
    return ", ".join(f"{names[g.group]} {g.weight:.2f}" for g in sorted(v.groups, key=lambda g: -g.weight)[:3])


def posed():
    depsgraph = bpy.context.evaluated_depsgraph_get()
    evaluated = mesh.evaluated_get(depsgraph)
    data = evaluated.to_mesh()
    co = np.array([tuple(evaluated.matrix_world @ v.co) for v in data.vertices])
    evaluated.to_mesh_clear()
    return co


worst_all = []
for name, (_, last, _) in module.CLIPS.items():
    module.key(name)
    worst = (0, 0, 0)
    found = {}
    for frame in range(1, last + 1, STEP):
        bpy.context.scene.frame_set(frame)
        co = posed()
        length = np.linalg.norm(co[edges[:, 0]] - co[edges[:, 1]], axis=1)
        ratio = length / np.maximum(rest_length, 1e-5)
        # only edges long enough to show (tiny ones near merged points can't be seen)
        ratio[rest_length < 0.004] = 1
        i = int(ratio.argmax())
        if ratio[i] > worst[0]:
            worst = (float(ratio[i]), frame, i)
        for k in np.nonzero(ratio > LIMIT)[0]:
            if ratio[k] > found.get(int(k), (0, 0))[0]:
                found[int(k)] = (float(ratio[k]), frame)
    ratio, frame, i = worst
    a, b = edges[i]
    print(f"{name}: worst x{ratio:.2f} at frame {frame}, rest {np.round((rest[a] + rest[b]) / 2, 3).tolist()}"
          f" ({bones_of(int(a))} | {bones_of(int(b))}); {len(found)} edges past x{LIMIT}")
    # group the edges past the limit by place (5 cm cells) so each stretched spot prints once
    spots = {}
    for k, (r, f) in found.items():
        mid = (rest[edges[k, 0]] + rest[edges[k, 1]]) / 2
        cell = tuple(np.round(mid / 0.05).astype(int))
        if r > spots.get(cell, (0,))[0]:
            spots[cell] = (r, f, k)
    for cell, (r, f, k) in sorted(spots.items(), key=lambda kv: -kv[1][0])[:6]:
        a, b = edges[k]
        print(f"   x{r:.2f} frame {f} at {np.round((rest[a] + rest[b]) / 2, 3).tolist()} ({bones_of(int(a))})")
    worst_all.append((name, ratio))
print("summary:", ", ".join(f"{n} x{r:.2f}" for n, r in worst_all))
