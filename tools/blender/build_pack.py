"""Builds the 3D booster pack (UI project 3, spec 2026-10-29-cards-in-world-and-pack-opening section 1).

A puffy foil pouch: it bulges in the middle and flattens to folded sides, with ridged crimp seals top and bottom
(a zig-zag outer edge on the detailed one) and soft foil wrinkles. Three meshes on assets/blender/Pack/Pack.png
(front | back):
  Body      the detailed pack under the tear line (the opening stage, menus), open at the top
  Strip     the detailed tear strip: the top seal and a thin band, cut along a jagged line ~10% down
  BodyLow   a light closed pack (~400 tris) for anywhere small
  PackMini  a lighter one still (~190 tris) that the display box's packs are made of (build_displaybox.py)
Run inside Blender (MCP execute or Text Editor). Writes Pack.fbx (Body, Strip, BodyLow) and saves Pack.blend.
"""
import math
import os
import random
import sys

from mathutils import Vector, noise

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import pack_kit  # noqa: E402

W, H = 0.64, 1.0  # the pack's face; the texture's face is 1024 x 1600
CRIMP = 112 / 1600  # share of the height that is crimped seal, top and bottom
PUFF = 0.045  # how far each face bulges at the middle
CUT = 0.895  # the tear line's height (share of H), jagged around it, just under the top seal (texture CUT = 0.105)


def smooth(t):
    t = max(0.0, min(1.0, t))
    return t * t * (3 - 2 * t)


def bulge(u, v):
    across = (1 - (2 * u - 1) ** 2) ** 0.55
    along = smooth((v - CRIMP) / 0.07) * smooth(((1 - CRIMP) - v) / 0.07)
    return across * along


def wrinkle(u, v):
    p = Vector((u * 6, v * 9, 0.3))
    return 0.006 * noise.noise(p) + 0.003 * noise.noise(p * 2.7)


def pouch(name, nu, rows_of, mat, zigzag, wrinkles):
    """rows_of(i) gives column i's v values bottom to top; the outer seal edges close, an open cut edge stays open."""
    rows = len(rows_of(0))
    verts, faces, uvs, grid = [], [], [], {}
    for side in (1, -1):
        for i in range(nu + 1):
            u = i / nu
            for j, v in enumerate(rows_of(i)):
                y = v * H
                if zigzag and (i % 2):
                    if j == rows - 1 and v > 0.99:
                        y -= 0.012
                    if j == 0 and v < 0.01:
                        y += 0.012
                b = bulge(u, v)
                z = side * (0.0012 + PUFF * b + (side * wrinkle(u + (0 if side > 0 else 3), v) * b if wrinkles else 0))
                grid[(side, i, j)] = len(verts)
                verts.append(((u - 0.5) * W, -z, y))  # the front (side 1) faces -Y
                uvs.append((u * 0.5 if side > 0 else 0.5 + (1 - u) * 0.5, y / H))
    for side in (1, -1):
        for i in range(nu):
            for j in range(rows - 1):
                a, b, c, d = grid[(side, i, j)], grid[(side, i + 1, j)], grid[(side, i + 1, j + 1)], grid[(side, i, j + 1)]
                faces.append((a, b, c, d) if side > 0 else (a, d, c, b))
    for j in range(rows - 1):  # the folded sides
        faces.append((grid[(-1, 0, j)], grid[(1, 0, j)], grid[(1, 0, j + 1)], grid[(-1, 0, j + 1)]))
        faces.append((grid[(1, nu, j)], grid[(-1, nu, j)], grid[(-1, nu, j + 1)], grid[(1, nu, j + 1)]))
    for j, closes in ((0, rows_of(0)[0] < 0.01), (rows - 1, rows_of(0)[-1] > 0.99)):
        if not closes:
            continue
        for i in range(nu):
            f = (grid[(1, i, j)], grid[(1, i + 1, j)], grid[(-1, i + 1, j)], grid[(-1, i, j)])
            faces.append(f[::-1] if j == 0 else f)
    return pack_kit.mesh_object(name, verts, faces, uvs, mat)


def build():
    random.seed(11)
    mat = pack_kit.material("PackFoil", "Pack.png", metal=0.12, rough=0.38, seal_metal=CRIMP)
    bsdf = next(n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Coat Weight"].default_value = 0.35
    bsdf.inputs["Coat Roughness"].default_value = 0.08
    nu = 24
    cut, level = [], 0.0
    for _ in range(nu + 1):
        level = max(-1.0, min(1.0, level + random.uniform(-0.9, 0.9)))
        cut.append(CUT + 0.006 * level)
    body = pouch("Body", nu, lambda i: [cut[i] * j / 40 for j in range(41)], mat, True, True)
    strip = pouch("Strip", nu, lambda i: [cut[i] + (1 - cut[i]) * j / 8 for j in range(9)], mat, True, False)
    low = pouch("BodyLow", 8, lambda i: [j / 10 for j in range(11)], mat, False, False)
    mini = pouch("PackMini", 6, lambda i: [j / 6 for j in range(7)], mat, False, False)
    mini.hide_render = True
    mini.hide_set(True)
    return body, strip, low


pack_kit.open_file()
build()
if os.environ.get("EXPORT", "1") == "1":
    pack_kit.export("Pack.fbx", ["Body", "Strip", "BodyLow"])
    pack_kit.save()
