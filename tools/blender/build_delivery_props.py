"""Builds the four delivery boxes (owner 2026-11-14; Config/Products boxProp: BoxPacks, BoxSleeves, BoxDecks,
BoxBooster) in the decor pack's chunky cartoon style: cardboard shipping boxes 2.5 x 1.5 x 2 (Config/Stock BOX_SIZE),
packing tape in the product's colour over the top and down the faces, a sticker in that colour on the front and back.

All four go into ONE pack so the owner imports once: each box is an Empty named <Name> (its Town.SLOTS slot) holding
<Name>__Frame (palette texture), <Name>__Picture and <Name>__PictureBack (the white sticker panels on the front and the
back, each its own part since a decal covers its part's whole face: the game puts the product's icon on them,
Util/DeliveryLooks.finishBox). Import assets/blender/Delivery/DeliveryProps.fbx in Studio with default settings, save the
imported model as assets/props-import/DeliveryProps.rbxm, then `lune run tools/props/split_pack
assets/props-import/DeliveryProps.rbxm` writes assets/props/<Name>.rbxm per box. Until then the boxes are branded cases
(Util/BrandBox). Blender: Z up, front -Y, origin at the bottom centre.
Run in a background Blender (it clears the scene):
  blender -b --factory-startup --python tools/blender/build_delivery_props.py
PROPS="A,B" builds only those, EXPORT=0 builds without saving.
"""
import os
import sys

import bpy
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)) if "__file__" in globals() else
                os.path.join(os.environ.get("CARD_SHOP_REPO", r"C:\Users\Ben\Documents\roblox-project\card-shop-tycoon"), "tools", "blender"))
import voxel_kit  # noqa: E402
import portal_kit  # noqa: E402

BONE = portal_kit.BONE
PACK = "DeliveryProps"
OUT = "Delivery"  # assets/blender/Delivery
SPACING = 12
WHITE = (255, 255, 255)

CAP = 600  # triangles a box
SIZE = (2.5, 2, 1.5)  # Config/Stock BOX_SIZE (Blender x, y, z)


# ---------------------------------------------------------------------------------------------------- the boxes

def delivery_box(tape):
    """A cardboard shipping box 2.5 x 2 x 1.5: flaps meeting on top, packing tape in the product's colour across the
    top and down both sides, a sticker in that colour framing a white Picture panel front and back."""
    colors = {"card": (206, 160, 108), "card_dark": (172, 128, 82), "tape": tape, "picture": WHITE}
    frame, front, back = voxel_kit.Builder(colors), voxel_kit.Builder(colors), voxel_kit.Builder(colors)
    w, d, h = 2.5, 1.9, 1.47  # the body; tape and stickers stand proud of it, all inside 2.5 x 2 x 1.5
    frame.round_box((0, 0, h / 2), (w, d, h), "card", BONE, bevel=0.08)
    frame.box((0, 0, h + 0.005), (w - 0.1, 0.05, 0.02), "card_dark", BONE)  # where the flaps meet
    frame.box((0, 0, h + 0.012), (0.55, d + 0.02, 0.025), "tape", BONE)  # tape over the seam, front to back
    for side in (-1, 1):
        frame.box((0, side * (d / 2 + 0.006), h - 0.25), (0.55, 0.025, 0.5), "tape", BONE)  # and down the faces
        frame.round_box((0.55 if side < 0 else -0.55, side * (d / 2 + 0.01), h * 0.45), (1.1, 0.04, 0.9), "tape", BONE, bevel=0.3)
        # each sticker its own part: a decal covers its part's whole face, so one part for both would split the icon
        (front if side < 0 else back).box((0.55 if side < 0 else -0.55, side * (d / 2 + 0.035), h * 0.45), (0.9, 0.02, 0.72), "picture", BONE)
    return colors, [frame.to_object("Frame"), front.to_object("Picture"), back.to_object("PictureBack")]


PROPS = {
    "BoxPacks": lambda: delivery_box((245, 150, 50)),
    "BoxSleeves": lambda: delivery_box((80, 150, 235)),
    "BoxDecks": lambda: delivery_box((150, 95, 210)),
    "BoxBooster": lambda: delivery_box((240, 200, 60)),
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
        obj.data.materials.clear()
        obj.data.materials.append(material)
        obj.vertex_groups.clear()
        obj.name = f"{name}__{obj.name}"
        obj.data.name = obj.name
    bpy.context.view_layer.update()
    total = sum(portal_kit.triangles(o) for o in objects)
    assert total <= CAP, f"{name} has {total} triangles (cap {CAP})"
    low, high = bounds(objects)
    span = high - low
    want = SIZE
    for axis, size in enumerate(want):
        assert span[axis] <= size + 0.02, f"{name} is {tuple(round(v, 2) for v in span)}, its box {want}"
    assert low.z >= -0.01, f"{name} dips below the floor ({low.z})"
    return objects, total, span


def run():
    wanted = [name for name in os.environ.get("PROPS", ",".join(PROPS)).split(",") if name]
    portal_kit.begin(OUT)
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
        folder = voxel_kit.out_dir(OUT)
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
