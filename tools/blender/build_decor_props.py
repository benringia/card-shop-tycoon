"""Builds ten of shop decor's twelve placeable pieces (spec docs/superpowers/specs/2026-11-14-shop-decor-design.md, Config/Shelves
kind "Decor") in the concept sheet's chunky cartoon style: smooth rounded shapes, flat bright colours (voxel_kit's
palette, portal_kit's tubes and discs).

All pieces go into ONE pack so the owner imports once: each piece is an Empty named <Name> (its Config/Shelves id and
prop slot) holding <Name>__Frame (palette texture) and the parts the game finishes by name (Util/DecorLooks.finish):
Glow / Bulb (turned Neon in Config/Decor GLOW_COLORS; the lamp's Bulb also gets its light), Spin (the Card Pedestal's
card: the card back on both faces, turning), Picture (a flat panel that gets a picture: Config/Decor PICTURES). The pieces stand apart along X in assets/blender/DecorProps/DecorProps.{blend,fbx}. Import the
FBX in Studio with default settings, save the imported model as assets/props-import/DecorProps.rbxm, then
`lune run tools/props/split_pack assets/props-import/DecorProps.rbxm` writes assets/props/<Name>.rbxm per piece. Until
then the game draws code-built stand-ins (Util/DecorLooks). Blender: Z up, 1 unit = 1 stud, each piece's origin at its
bottom centre, its front facing -Y, inside its footprint (Config/Shelves size). The Beanbag and the Potted Plant are
free Creator Store models kept in the place file instead (ReplicatedStorage.PlaceProps; docs/props.md "Decor props").
Run in a background Blender (it clears the scene):
  blender -b --factory-startup --python tools/blender/build_decor_props.py
PROPS="A,B" builds only those, EXPORT=0 builds without saving. Each piece stays under 1500 triangles.
"""
import math
import os
import sys

import bpy
from mathutils import Matrix, Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)) if "__file__" in globals() else
                os.path.join(os.environ.get("CARD_SHOP_REPO", r"C:\Users\Ben\Documents\roblox-project\card-shop-tycoon"), "tools", "blender"))
import voxel_kit  # noqa: E402
import portal_kit  # noqa: E402

BONE = portal_kit.BONE
PIECE_CAP = 1500
PACK = "DecorProps"
SPACING = 10  # studs between pieces in the pack file
WHITE = (255, 255, 255)  # parts the game recolours (Glow, Bulb) or pictures (Picture)

# Footprints (x across, y deep, z tall), matching Config/Shelves sizes
SIZES = {
    "StarRug": (6, 6, 0.2), "FloorLamp": (2, 2, 6),
    "BalloonBunch": (2, 2, 7), "BoosterTower": (2, 2, 6), "ElementPennants": (6, 2, 5), "PlayTable": (4, 4, 3),
    "CardFrame": (4, 2, 6), "DogStandee": (4, 2, 6), "CardPedestal": (2, 2, 5), "PackStatue": (4, 4, 8),
}


def turn(degrees, axis="Z"):
    return Matrix.Rotation(math.radians(degrees), 3, axis)


def cylinder(b, bottom, top, radius, color, sides=12, top_radius=None):
    """An upright capped cylinder (or a cone frustum with top_radius) from z=bottom to z=top at the origin's x, y."""
    x, y = bottom[0], bottom[1]
    portal_kit.tube(b, [(x, y, bottom[2]), (x, y, top)], [radius, top_radius if top_radius is not None else radius], color, sides=sides)


# ---------------------------------------------------------------------------------------------------- the pieces

def star_rug():
    """A round cream rug with a sky-blue ring and a big golden five-pointed star. 0.15 tall."""
    colors = {"rug": (250, 232, 204), "ring": (150, 205, 235), "star": (255, 205, 80)}
    b = voxel_kit.Builder(colors)
    cylinder(b, (0, 0, 0), 0.12, 2.9, "rug", sides=28)
    cylinder(b, (0, 0, 0.11), 0.13, 2.5, "ring", sides=28)
    cylinder(b, (0, 0, 0.12), 0.14, 2.25, "rug", sides=28)
    z = 0.15
    outer = [Vector((math.cos(math.radians(90 + 72 * i)) * 1.9, math.sin(math.radians(90 + 72 * i)) * 1.9, z)) for i in range(5)]
    inner = [Vector((math.cos(math.radians(126 + 72 * i)) * 0.78, math.sin(math.radians(126 + 72 * i)) * 0.78, z)) for i in range(5)]
    centre = b._verts([(0, 0, z)], BONE)[0]
    # Counter-clockwise seen from above, so the faces point up: each point, then the middle pentagon in wedges
    for i in range(5):
        left, tip, right = b._verts([inner[(i - 1) % 5], outer[i], inner[i]], BONE)
        b._face([left, tip, right], "star")
        b._face([centre] + b._verts([inner[(i - 1) % 5], inner[i]], BONE), "star")
    return colors, [b.to_object("Frame")]


def floor_lamp():
    """A slim dark lamp on a round foot with a warm fabric shade and a glowing bulb (Bulb) under it. About 6 tall."""
    colors = {"metal": (62, 62, 74), "shade": (255, 236, 200), "trim": (240, 200, 120), "bulb": WHITE}
    frame, bulb = voxel_kit.Builder(colors), voxel_kit.Builder(colors)
    cylinder(frame, (0, 0, 0), 0.18, 0.62, "metal", sides=16)
    cylinder(frame, (0, 0, 0.18), 4.75, 0.08, "metal", sides=8)
    portal_kit.tube(frame, [(0, 0, 4.55), (0, 0, 5.8)], [0.82, 0.5], "shade", sides=16)
    cylinder(frame, (0, 0, 4.5), 4.62, 0.84, "trim", sides=16)
    bulb.blob((0, 0, 4.72), (0.28, 0.28, 0.3), "bulb", BONE, segments=10, rings=6)
    return colors, [frame.to_object("Frame"), bulb.to_object("Bulb")]


def balloon_bunch():
    """Five shiny balloons (pink, blue, yellow, green, lilac) on white strings tied to a little weight. About 7 tall."""
    colors = {"weight": (140, 140, 160), "string": (245, 245, 245), "pink": (255, 110, 140), "blue": (110, 180, 255),
              "yellow": (255, 215, 90), "green": (140, 220, 130), "lilac": (190, 130, 255)}
    b = voxel_kit.Builder(colors)
    b.round_box((0, 0, 0.22), (0.6, 0.6, 0.44), "weight", BONE, bevel=0.4)
    for color, (x, y, z) in (("pink", (0, 0.05, 6.1)), ("blue", (-0.55, -0.1, 5.5)), ("yellow", (0.55, 0.1, 5.6)),
                             ("green", (-0.2, -0.45, 4.9)), ("lilac", (0.3, 0.45, 4.95))):
        b.blob((x, y, z), (0.48, 0.48, 0.6), color, BONE, segments=10, rings=7)
        b.spike((x, y, z - 0.58), (0, 0, -1), 0.14, 0.14, color, BONE)
        portal_kit.tube(b, [(0, 0, 0.44), (x * 0.4, y * 0.4, z * 0.5), (x, y, z - 0.7)], [0.025, 0.025, 0.025], "string", sides=4)
    return colors, [b.to_object("Frame")]


def booster_tower():
    """A tall tower of colourful booster boxes stacked like building blocks, each a little turned, a glowing star
    (Glow) on top. About 6 tall."""
    colors = {"red": (240, 90, 90), "blue": (90, 160, 240), "yellow": (250, 200, 70), "green": (110, 200, 120),
              "purple": (170, 110, 230), "lid": (250, 246, 236), "glow": WHITE}
    frame, glow = voxel_kit.Builder(colors), voxel_kit.Builder(colors)
    box = 0.95
    for level, color in enumerate(("red", "blue", "yellow", "green", "purple")):
        z = box * level + box / 2
        rot = turn(12 if level % 2 else -10)
        frame.round_box((0, 0, z), (1.55, 1.05, box * 0.92), color, BONE, rot=rot, bevel=0.15)
        frame.round_box((0, 0, z + box * 0.38), (1.6, 1.1, 0.12), "lid", BONE, rot=rot, bevel=0.3)
    top = box * 5
    points = []
    for k in range(10):
        a = math.radians(90 + 36 * k)
        r = 0.62 if k % 2 == 0 else 0.27
        points.append(Vector((math.cos(a) * r, 0, top + 0.75 + math.sin(a) * r)))
    for depth in (-0.12, 0.12):
        centre = glow._verts([(0, depth, top + 0.75)], BONE)[0]
        ring = glow._verts([p + Vector((0, depth, 0)) for p in points], BONE)
        for k in range(10):
            tri = [centre, ring[k], ring[(k + 1) % 10]]
            glow._face(tri if depth > 0 else tri[::-1], "glow")
    for k in range(10):
        a, b = points[k], points[(k + 1) % 10]
        quad = glow._verts([a + Vector((0, -0.12, 0)), b + Vector((0, -0.12, 0)), b + Vector((0, 0.12, 0)), a + Vector((0, 0.12, 0))], BONE)
        glow._face(quad, "glow")
    return colors, [frame.to_object("Frame"), glow.to_object("Glow")]


def play_table():
    """A round play table with a green play mat and four trading cards laid out on it, two little round stools
    beside it. About 2.4 tall."""
    colors = {"wood": (170, 120, 80), "wood_dark": (130, 90, 60), "mat": (70, 160, 100), "mat_edge": (240, 220, 160),
              "stool": (240, 140, 60), "stool_top": (250, 180, 110), "c1": (240, 90, 90), "c2": (90, 160, 240),
              "c3": (250, 200, 70), "c4": (170, 110, 230)}
    b = voxel_kit.Builder(colors)
    top = 1.85
    cylinder(b, (0, 0, 0), 0.14, 0.62, "wood_dark", sides=14)
    cylinder(b, (0, 0, 0.14), top - 0.14, 0.18, "wood", sides=10)
    cylinder(b, (0, 0, top - 0.14), top, 1.25, "wood", sides=24)
    cylinder(b, (0, 0, top), top + 0.03, 1.12, "mat_edge", sides=24)
    cylinder(b, (0, 0, top + 0.02), top + 0.05, 1.04, "mat", sides=24)
    for index, color in enumerate(("c1", "c2", "c3", "c4")):
        x, y = (index - 1.5) * 0.42, (0.22 if index % 2 else -0.18)
        b.round_box((x, y, top + 0.08), (0.36, 0.5, 0.04), color, BONE, rot=turn(index * 23 - 35), bevel=0.4)
    for side in (-1, 1):
        cylinder(b, (side * 1.6, 0, 0), 0.95, 0.3, "stool", sides=12, top_radius=0.36)
        cylinder(b, (side * 1.6, 0, 0.95), 1.1, 0.4, "stool_top", sides=14)
    return colors, [b.to_object("Frame")]


def card_frame():
    """A giant trading card in an ornate golden frame on a wooden easel, leaning back a little; its front (Picture)
    wears a card's painting. About 6 tall."""
    colors = {"wood": (150, 104, 70), "wood_dark": (118, 80, 54), "gold": (240, 190, 70), "gold_dark": (200, 150, 50),
              "picture": WHITE}
    frame, picture = voxel_kit.Builder(colors), voxel_kit.Builder(colors)
    lean = turn(10, "X")  # the top back toward +Y, so the card faces the front and a little up
    for side in (-1, 1):
        frame.span((side * 1.05, -0.05, 0.1), (side * 0.75, 0.4, 5.75), 0.16, "wood", BONE)  # behind the card
    frame.span((0, 1.0, 0.1), (0, 0.4, 5.2), 0.16, "wood_dark", BONE)
    frame.round_box((0, -0.3, 1.62), (3.0, 0.45, 0.14), "wood", BONE, bevel=0.3)  # the ledge the card stands on
    centre = Vector((0, 0, 3.45))
    frame.round_box(centre, (2.5, 0.18, 3.5), "gold", BONE, rot=lean, bevel=0.2)
    for corner_x in (-1, 1):
        for corner_z in (-1, 1):
            offset = lean @ Vector((corner_x * 1.25, -0.1, corner_z * 1.75))
            frame.blob(centre + offset, (0.18, 0.12, 0.18), "gold_dark", BONE, segments=8, rings=5)
    picture.box(centre + lean @ Vector((0, -0.11, 0)), (2.1, 0.04, 3.05), "picture", BONE, rot=lean)
    return colors, [frame.to_object("Frame"), picture.to_object("Picture")]


def element_pennants():
    """Two wooden posts with a sagging rope between them and five hanging pennants in the element colours (Ember red,
    Tide blue, Bloom green, Volt yellow, Shade purple). About 5 tall."""
    colors = {"wood": (150, 104, 70), "wood_top": (240, 200, 120), "rope": (240, 232, 214), "ember": (240, 90, 60),
              "tide": (70, 150, 240), "bloom": (90, 190, 90), "volt": (250, 210, 60), "shade": (150, 90, 220)}
    b = voxel_kit.Builder(colors)
    for x in (-2.75, 2.75):
        b.round_box((x, 0, 0.12), (0.7, 0.7, 0.24), "wood", BONE, bevel=0.3)
        cylinder(b, (x, 0, 0.2), 4.75, 0.14, "wood", sides=8)
        b.blob((x, 0, 4.82), (0.2, 0.2, 0.2), "wood_top", BONE, segments=8, rings=5)
    rope = [(x, 0, 4.4 - 0.45 * (1 - (x / 2.75) ** 2)) for x in (-2.75, -1.6, -0.55, 0.55, 1.6, 2.75)]
    portal_kit.tube(b, rope, [0.04] * len(rope), "rope", sides=4)
    for i, color in enumerate(("ember", "tide", "bloom", "volt", "shade")):
        x = -1.9 + i * 0.95
        top = 4.4 - 0.45 * (1 - (x / 2.75) ** 2) - 0.02
        a, c, tip = Vector((x - 0.36, 0, top)), Vector((x + 0.36, 0, top)), Vector((x, 0, top - 1.0))
        for depth in (-0.03, 0.03):
            d = Vector((0, depth, 0))
            verts = b._verts([a + d, c + d, tip + d], BONE)
            b._face(verts if depth < 0 else verts[::-1], color)
    return colors, [b.to_object("Frame")]


def dog_standee():
    """A cardboard standee of Pish and Chikin: a rounded board whose front panel (Picture) wears their picture, a
    folded brace behind it and a little foot. About 6 tall."""
    colors = {"card": (225, 190, 140), "card_dark": (196, 160, 116), "picture": WHITE}
    frame, picture = voxel_kit.Builder(colors), voxel_kit.Builder(colors)
    frame.round_box((0, 0.05, 2.95), (3.8, 0.16, 5.6), "card", BONE, bevel=0.25)
    picture.box((0, -0.05, 2.95), (3.5, 0.04, 5.3), "picture", BONE)
    frame.round_box((0, 0.55, 1.6), (1.1, 0.1, 3.2), "card_dark", BONE, rot=turn(-22, "X"), bevel=0.3)
    frame.round_box((0, 0.1, 0.08), (3.8, 1.2, 0.16), "card_dark", BONE, bevel=0.3)
    return colors, [frame.to_object("Frame"), picture.to_object("Picture")]


def card_pedestal():
    """A white marble pedestal with a gold band and a glowing ring (Glow) on top, a trading card (Spin) floating
    over it. About 5 tall."""
    colors = {"marble": (226, 226, 236), "marble_dark": (196, 196, 212), "gold": (240, 200, 90), "card": (95, 55, 185),
              "glow": WHITE}
    frame, glow, card = voxel_kit.Builder(colors), voxel_kit.Builder(colors), voxel_kit.Builder(colors)
    frame.round_box((0, 0, 0.18), (1.9, 1.9, 0.36), "marble_dark", BONE, bevel=0.3)
    frame.round_box((0, 0, 0.5), (1.5, 1.5, 0.3), "marble", BONE, bevel=0.3)
    cylinder(frame, (0, 0, 0.6), 2.6, 0.5, "marble", sides=12, top_radius=0.44)
    cylinder(frame, (0, 0, 2.55), 2.7, 0.56, "gold", sides=12)
    frame.round_box((0, 0, 2.85), (1.6, 1.6, 0.32), "marble", BONE, bevel=0.3)
    cylinder(glow, (0, 0, 3.0), 3.06, 0.62, "glow", sides=16)
    card.round_box((0, 0, 4.05), (1.05, 0.06, 1.45), "card", BONE, bevel=0.6)
    return colors, [frame.to_object("Frame"), glow.to_object("Glow"), card.to_object("Spin")]


def pack_statue():
    """A giant booster pack standing on a stone plinth: crimped silver ends, a gold trim, its front (Picture) wearing
    a pack's art. About 8 tall."""
    colors = {"stone": (120, 110, 140), "stone_light": (150, 140, 170), "pack": (255, 200, 70), "crimp": (225, 228, 240),
              "gold": (240, 190, 70), "picture": WHITE}
    frame, picture = voxel_kit.Builder(colors), voxel_kit.Builder(colors)
    frame.round_box((0, 0, 0.45), (3.9, 3.9, 0.9), "stone", BONE, bevel=0.2)
    frame.round_box((0, 0, 1.0), (3.3, 3.3, 0.2), "stone_light", BONE, bevel=0.3)
    frame.round_box((0, 0, 4.4), (2.8, 0.9, 6.4), "pack", BONE, bevel=0.12)
    for z in (1.4, 7.4):
        frame.round_box((0, 0, z), (2.9, 0.95, 0.5), "crimp", BONE, bevel=0.2)
        for k in range(9):
            x = -1.3 + k * 0.325
            frame.box((x, 0, z), (0.08, 1.0, 0.52), "gold", BONE)
    picture.box((0, -0.47, 4.4), (2.45, 0.04, 5.3), "picture", BONE)
    return colors, [frame.to_object("Frame"), picture.to_object("Picture")]


PROPS = {
    "StarRug": star_rug,
    "FloorLamp": floor_lamp,
    "BalloonBunch": balloon_bunch,
    "BoosterTower": booster_tower,
    "ElementPennants": element_pennants,
    "PlayTable": play_table,
    "CardFrame": card_frame,
    "DogStandee": dog_standee,
    "CardPedestal": card_pedestal,
    "PackStatue": pack_statue,
}


def bounds(objects):
    points = [obj.matrix_world @ Vector(corner) for obj in objects for corner in obj.bound_box]
    low = Vector((min(p.x for p in points), min(p.y for p in points), min(p.z for p in points)))
    high = Vector((max(p.x for p in points), max(p.y for p in points), max(p.z for p in points)))
    return low, high


def build(name):
    """One piece's meshes, named <Name>__<part>, with its palette material; returns them and its triangle count."""
    colors, objects = PROPS[name]()
    material = voxel_kit.make_material(name, voxel_kit.make_palette(name, colors))
    scene = bpy.context.scene
    for obj in objects:
        scene.collection.objects.link(obj)
        obj.data.materials.append(material)
        obj.vertex_groups.clear()
        obj.name = f"{name}__{obj.name}"
        obj.data.name = obj.name
    bpy.context.view_layer.update()
    total = sum(portal_kit.triangles(o) for o in objects)
    assert total <= PIECE_CAP, f"{name} has {total} triangles (cap {PIECE_CAP})"
    low, high = bounds(objects)
    width, depth, height = SIZES[name]
    # A piece that reaches past its footprint (or above its height) shrinks evenly about its base until it fits
    span = high - low
    fit = min(1.0, width / span.x, depth / span.y, height / span.z)
    if fit < 1.0:
        for obj in objects:
            obj.data.transform(Matrix.Scale(fit * 0.99, 4))
        bpy.context.view_layer.update()
        low, high = bounds(objects)
    assert high.x - low.x <= width + 0.01 and high.y - low.y <= depth + 0.01, f"{name} is {high - low}, footprint {SIZES[name]}"
    assert low.z >= -0.01, f"{name} dips below the floor ({low.z})"
    return objects, total, high - low


def run():
    wanted = [name for name in os.environ.get("PROPS", ",".join(PROPS)).split(",") if name]
    portal_kit.begin(PACK)
    scene = bpy.context.scene
    everything = []
    for index, name in enumerate(wanted):
        objects, total, size = build(name)
        holder = bpy.data.objects.new(name, None)  # an Empty: the piece's own Model in the import
        scene.collection.objects.link(holder)
        holder.location = (index * SPACING, 0, 0)
        for obj in objects:
            obj.parent = holder
        everything += [holder] + objects
        print(f"OK {name} {total} tris, {size.x:.2f} x {size.y:.2f} x {size.z:.2f}")
    if os.environ.get("EXPORT", "1") == "1":
        bpy.ops.object.select_all(action="DESELECT")
        for obj in everything:
            obj.select_set(True)
        bpy.context.view_layer.objects.active = everything[0]
        folder = voxel_kit.out_dir(PACK)
        bpy.ops.wm.save_as_mainfile(filepath=os.path.join(folder, f"{PACK}.blend"))
        bpy.ops.export_scene.fbx(
            filepath=os.path.join(folder, f"{PACK}.fbx"),
            use_selection=True,
            object_types={"EMPTY", "MESH"},
            path_mode="COPY",
            embed_textures=True,
            mesh_smooth_type="FACE",
            apply_scale_options="FBX_SCALE_ALL",
        )
        print("exported to", folder)


if __name__ == "__main__":
    run()
