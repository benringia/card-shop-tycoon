"""Builds the open booster display box that packs stand in on shelves (UI project 3 spec section 2).

A cardboard tray, its front panel printed with the art and "FIRST SPARK · 24", its lid hinged at the back and flipped
up and back about 110 degrees so its inside shows the pack art. Packs stand in it one behind another, leaning back,
the front one showing its face over the front panel. Meshes:
  Tray            the tray and lid, on assets/blender/Pack/DisplayBox.png (regions as make_pack_textures DISPLAY)
  Packs1..Packs6  1..6 light packs (PackMini from build_pack.py) merged into one mesh each, filling from the front,
                  on Pack.png; the game shows the one matching how full the box is
Units: the pack is 0.64 x 1.0. Bottom centre at the origin. Run after build_pack.py. Writes DisplayBox.fbx.
"""
import math
import os
import sys

from mathutils import Matrix, Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import pack_kit  # noqa: E402

ATLAS = (1024, 1024)
DISPLAY = {"lid": (0, 0, 1024, 560), "front": (0, 560, 1024, 800), "cardboard": (0, 800, 512, 1024), "inside": (512, 800, 1024, 1024)}
INNER_W, INNER_D, WALL_H, T = 0.74, 0.96, 0.36, 0.025  # inside width and depth, wall height, cardboard thickness
LID_TURN = 110  # degrees the lid is flipped back from closed
PACK_SCALE = 0.95  # packs a touch smaller than the tray's width allows
PACK_STEP = 0.14  # front to back between packs
PACK_LEAN = 8  # degrees back


def build_tray(mat):
    verts, uvs, faces = [], [], []
    card, inside, front = DISPLAY["cardboard"], DISPLAY["inside"], DISPLAY["front"]
    ow, od = INNER_W + 2 * T, INNER_D + 2 * T
    plain = {"front": card, "back": card, "left": card, "right": card, "top": card, "bottom": card}
    # floor
    pack_kit.box_faces(verts, uvs, faces, (0, 0, T / 2), (ow, od, T), dict(plain, top=inside), ATLAS)
    # front wall: printed outside, plain inside
    pack_kit.box_faces(verts, uvs, faces, (0, -od / 2 + T / 2, WALL_H / 2), (ow, T, WALL_H), dict(plain, front=front, back=inside), ATLAS)
    # back wall
    pack_kit.box_faces(verts, uvs, faces, (0, od / 2 - T / 2, WALL_H / 2), (ow, T, WALL_H), dict(plain, front=inside), ATLAS)
    # side walls
    for side in (-1, 1):
        pack_kit.box_faces(verts, uvs, faces, (side * (ow / 2 - T / 2), 0, WALL_H / 2), (T, od - 2 * T, WALL_H),
            dict(plain, right=inside) if side < 0 else dict(plain, left=inside), ATLAS)
    # the lid: closed it would lie on top (its underside facing down); hinged at the back top edge and turned back,
    # its underside (the art) now faces the front
    turn = Matrix.Rotation(math.radians(-LID_TURN), 3, "X")  # negative about X: the front edge swings up and back
    hinge = Vector((0, od / 2, WALL_H))
    centre_closed = Vector((0, -od / 2, T / 2))  # relative to the hinge
    centre = hinge + turn @ centre_closed
    pack_kit.box_faces(verts, uvs, faces, tuple(centre), (ow, od, T), dict(plain, bottom=DISPLAY["lid"]), ATLAS, rotation=turn)
    return pack_kit.mesh_object("Tray", verts, faces, uvs, mat, smooth=False)


def build_packs(count, mat):
    import bpy

    mini = bpy.data.objects["PackMini"].data
    verts, uvs, faces = [], [], []
    layer = mini.uv_layers[0].data
    vuv = {}
    for poly in mini.polygons:
        for li in poly.loop_indices:
            vuv[mini.loops[li].vertex_index] = tuple(layer[li].uv)
    lean = Matrix.Rotation(math.radians(-PACK_LEAN), 3, "X")  # tops tip back (+Y)
    front = -INNER_D / 2 + 0.08
    for k in range(count):
        offset = len(verts)
        base = Vector((0, front + k * PACK_STEP, T))
        for index, v in enumerate(mini.vertices):
            p = lean @ (v.co * PACK_SCALE)
            verts.append(tuple(base + p))
            uvs.append(vuv.get(index, (0, 0)))
        for poly in mini.polygons:
            faces.append(tuple(offset + i for i in poly.vertices))
    return pack_kit.mesh_object(f"Packs{count}", verts, faces, uvs, mat)


def build():
    import bpy

    if "PackMini" not in bpy.data.objects:
        raise RuntimeError("Run build_pack.py first (it makes PackMini)")
    tray = build_tray(pack_kit.material("DisplayBox", "DisplayBox.png", metal=0.0, rough=0.8))
    foil = bpy.data.materials["PackFoil"]
    packs = [build_packs(count, foil) for count in range(1, 7)]
    return tray, packs


pack_kit.open_file()
build()
if os.environ.get("EXPORT", "1") == "1":
    pack_kit.export("DisplayBox.fbx", ["Tray"] + [f"Packs{n}" for n in range(1, 7)])
    pack_kit.save()
