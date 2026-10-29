"""Builds the 3D deck box (UI project 3 spec section 1): today's shelf look in 3D, a purple box with the set's art on
the front and a gold lid band, the lid a separate piece so the opening can lift it off.
Meshes on assets/blender/Pack/DeckBox.png (regions as tools/textures/make_pack_textures.py DECK):
  Box  0.55 x 0.40 x 0.64 (w x d x h), bottom centre at the origin
  Lid  0.57 x 0.42 x 0.16 sitting on top of it
Run inside Blender after build_pack.py (same Pack.blend). Writes DeckBox.fbx.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import pack_kit  # noqa: E402

ATLAS = (1024, 1024)
DECK = {"front": (0, 0, 512, 640), "back": (512, 0, 1024, 640), "side": (0, 640, 512, 1024), "lid": (512, 640, 1024, 1024)}
WIDTH, DEPTH, HEIGHT, LID = 0.55, 0.40, 0.80, 0.16


def build():
    mat = pack_kit.material("DeckBox", "DeckBox.png", metal=0.0, rough=0.45)
    body = HEIGHT - LID
    verts, uvs, faces = [], [], []
    regions = {"front": DECK["front"], "back": DECK["back"], "left": DECK["side"], "right": DECK["side"], "top": DECK["side"], "bottom": DECK["side"]}
    pack_kit.box_faces(verts, uvs, faces, (0, 0, body / 2), (WIDTH, DEPTH, body), regions, ATLAS)
    box = pack_kit.mesh_object("Box", verts, faces, uvs, mat, smooth=False)
    verts, uvs, faces = [], [], []
    lid_regions = {face: DECK["lid"] for face in ("front", "back", "left", "right", "top", "bottom")}
    pack_kit.box_faces(verts, uvs, faces, (0, 0, body + LID / 2), (WIDTH + 0.02, DEPTH + 0.02, LID), lid_regions, ATLAS)
    lid = pack_kit.mesh_object("Lid", verts, faces, uvs, mat, smooth=False)
    return box, lid


pack_kit.open_file()
build()
if os.environ.get("EXPORT", "1") == "1":
    pack_kit.export("DeckBox.fbx", ["Box", "Lid"])
    pack_kit.save()
