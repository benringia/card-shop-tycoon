"""Builds the delivery boxes (owner 2026-11-14; Config/Products boxProp: BoxPacks, BoxSleeves, BoxDecks, BoxBooster,
and the Frontier Pack's BoxFrontier, 2026-11-23) in the decor pack's chunky cartoon style: cardboard shipping boxes
2.5 x 1.5 x 2 (Config/Stock BOX_SIZE), packing tape in the product's colour over the top and down the faces, a sticker
in that colour on the front and back. The Frontier's box has snow on its lid and an aurora stripe down its tape.

The first four went into ONE pack so the owner imported once: each box is an Empty named <Name> (its Town.SLOTS slot)
holding <Name>__Frame (palette texture), <Name>__Picture and <Name>__PictureBack (the white sticker panels on the front
and the back, each its own part since a decal covers its part's whole face: the game puts the product's picture on them,
Util/DeliveryLooks.finishBox). Import assets/blender/Delivery/<PACK>.fbx in Studio with default settings, save the
imported model as assets/props-import/<PACK>.rbxm, then `lune run tools/props/split_pack assets/props-import/<PACK>.rbxm`
writes assets/props/<Name>.rbxm per box. Until then the boxes are branded cases (Util/BrandBox). Blender: Z up, front
-Y, origin at the bottom centre.
Run in a background Blender (it clears the scene):
  blender -b --factory-startup --python tools/blender/build_delivery_props.py
PROPS="A,B" builds only those, EXPORT=0 builds without saving, PACK=<name> names the pack's files (default
DeliveryProps; the Frontier's box alone: PROPS=BoxFrontier PACK=DeliveryFrontier, so the first four aren't imported
again), PREVIEW_DIR=<folder> renders a lineup and a close look at each (backface culling on, as Roblox draws).
"""
import math
import os
import sys

import bpy
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)) if "__file__" in globals() else
                os.path.join(os.environ.get("CARD_SHOP_REPO", r"C:\Users\Ben\Documents\roblox-project\card-shop-tycoon"), "tools", "blender"))
import voxel_kit  # noqa: E402
import portal_kit  # noqa: E402

BONE = portal_kit.BONE
PACK = os.environ.get("PACK", "DeliveryProps")
OUT = "Delivery"  # assets/blender/Delivery
SPACING = 12
WHITE = (255, 255, 255)

CAP = 600  # triangles a box
CAPS = {"BoxFrontier": 900}  # its snow cap costs about 430
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


def rim_point(t, half_x, half_y, radius):
    """A point `t` (0-1) of the way round a rounded rectangle (half sizes half_x, half_y, corner radius), counter-
    clockwise from the middle of its +X side, and the outward normal there: (x, y, nx, ny)."""
    straight_x, straight_y = 2 * (half_x - radius), 2 * (half_y - radius)
    arc = math.pi / 2 * radius
    walk = t % 1 * (2 * straight_x + 2 * straight_y + 4 * arc)
    cx, cy = half_x - radius, half_y - radius

    def corner(x, y, angle):
        return (x + math.cos(angle) * radius, y + math.sin(angle) * radius, math.cos(angle), math.sin(angle))

    # (length, point and normal along it) for each piece, starting half way up the +X side
    pieces = [
        (straight_y / 2, lambda s: (half_x, s, 1, 0)),
        (arc, lambda s: corner(cx, cy, s / radius)),
        (straight_x, lambda s: (cx - s, half_y, 0, 1)),
        (arc, lambda s: corner(-cx, cy, math.pi / 2 + s / radius)),
        (straight_y, lambda s: (-half_x, cy - s, -1, 0)),
        (arc, lambda s: corner(-cx, -cy, math.pi + s / radius)),
        (straight_x, lambda s: (-cx + s, -half_y, 0, -1)),
        (arc, lambda s: corner(cx, -cy, 1.5 * math.pi + s / radius)),
        (straight_y / 2, lambda s: (half_x, -cy + s, 1, 0)),
    ]
    for length, at in pieces:
        if walk <= length:
            return at(walk)
        walk -= length
    return pieces[-1][1](pieces[-1][0])


# Drips round the Frontier box's lid: (where round the rim 0-1, how far below the lid, how wide in rim fractions)
SNOW_DRIPS = [(0.03, 0.17, 0.03), (0.15, 0.1, 0.026), (0.24, 0.23, 0.034), (0.34, 0.12, 0.028), (0.47, 0.2, 0.034),
              (0.6, 0.11, 0.026), (0.69, 0.24, 0.036), (0.8, 0.13, 0.028), (0.9, 0.2, 0.032)]


def snow_cap(builder, w, d, h, color, samples=48):
    """Cartoon snow over a box lid, like icing on a cake: a gentle dome, a soft rounded lip, and a skirt hanging just
    off every face down to a wavy line of drips (SNOW_DRIPS), smooth-shaded; under the drips a flat strip back to the
    box (its own vertices, so its shading doesn't darken the skirt)."""
    off, radius = 0.03, 0.1  # how far the skirt stands off the faces; the rim's corners
    rings = {"top": [], "lip": [], "shoulder": [], "drip": [], "edge": [], "under": []}
    for i in range(samples):
        t = i / samples
        x, y, nx, ny = rim_point(t, w / 2 + off, d / 2 + off, radius)
        wave = 0.006 * math.sin(2 * math.pi * 5 * t + 0.7) + 0.004 * math.sin(2 * math.pi * 3 * t + 2.1)
        drop = 0.05 + sum(depth * math.exp(-((min(abs(t - at), 1 - abs(t - at))) / width) ** 2)
                          for at, depth, width in SNOW_DRIPS)
        rings["top"].append((x - nx * 0.09, y - ny * 0.09, h + 0.11 + wave))
        rings["lip"].append((x - nx * 0.012, y - ny * 0.012, h + 0.085 + wave / 2))
        rings["shoulder"].append((x, y, h + 0.03))
        rings["drip"].append((x, y, h - drop))
        rings["edge"].append((x, y, h - drop))  # the drip line again, for the flat strip under it
        rings["under"].append((x - nx * (off - 0.006), y - ny * (off - 0.006), h - drop + 0.02))
    verts = {name: builder._verts(points, BONE) for name, points in rings.items()}
    smooth = []
    middle = builder._verts([(0, 0, h + 0.125)], BONE)[0]
    for i in range(samples):
        j = (i + 1) % samples
        smooth.append(builder._face([middle, verts["top"][i], verts["top"][j]], color))
        for upper, lower in (("top", "lip"), ("lip", "shoulder"), ("shoulder", "drip")):
            smooth.append(builder._face([verts[upper][i], verts[lower][i], verts[lower][j], verts[upper][j]], color))
        builder._face([verts["edge"][i], verts["under"][i], verts["under"][j], verts["edge"][j]], color)
    for face in smooth:
        face.smooth = True


def frontier_box():
    """The Frontier Pack's box (owner 2026-11-23): the same cardboard box with the pack's purple tape (Products color)
    and an aurora stripe down it, under a cap of snow dripping over every edge, so it can't pass for the Deck Box's
    purple-taped one. The body is a little lower and narrower than the others' so the snow stays inside the box size."""
    colors = {"card": (206, 160, 108), "tape": (130, 90, 230), "stripe": (96, 226, 214), "snow": (250, 252, 255),
              "picture": WHITE}
    frame, front, back = voxel_kit.Builder(colors), voxel_kit.Builder(colors), voxel_kit.Builder(colors)
    w, d, h = 2.44, 1.9, 1.34  # the body; snow, tape and stickers stand proud of it, all inside 2.5 x 2 x 1.5
    frame.round_box((0, 0, h / 2), (w, d, h), "card", BONE, bevel=0.08)
    snow_cap(frame, w, d, h, "snow")  # over the whole lid: the top's tape and seam would be under it
    for side in (-1, 1):
        face = side * (d / 2)
        frame.box((0, face + side * 0.006, h - 0.25), (0.55, 0.025, 0.5), "tape", BONE)  # down the faces
        frame.box((0, face + side * 0.02, h - 0.25), (0.14, 0.008, 0.5), "stripe", BONE)  # the aurora stripe on it
        frame.round_box((0.55 if side < 0 else -0.55, face + side * 0.01, h * 0.45), (1.1, 0.04, 0.9), "tape", BONE, bevel=0.3)
        (front if side < 0 else back).box((0.55 if side < 0 else -0.55, face + side * 0.035, h * 0.45), (0.9, 0.02, 0.72), "picture", BONE)
    return colors, [frame.to_object("Frame"), front.to_object("Picture"), back.to_object("PictureBack")]


PROPS = {
    "BoxPacks": lambda: delivery_box((245, 150, 50)),
    "BoxSleeves": lambda: delivery_box((80, 150, 235)),
    "BoxDecks": lambda: delivery_box((150, 95, 210)),
    "BoxBooster": lambda: delivery_box((240, 200, 60)),
    "BoxFrontier": frontier_box,
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
    cap = CAPS.get(name, CAP)
    assert total <= cap, f"{name} has {total} triangles (cap {cap})"
    low, high = bounds(objects)
    span = high - low
    want = SIZE
    for axis, size in enumerate(want):
        assert span[axis] <= size + 0.02, f"{name} is {tuple(round(v, 2) for v in span)}, its box {want}"
    assert low.z >= -0.01, f"{name} dips below the floor ({low.z})"
    return objects, total, span


def preview(boxes, folder):
    """Workbench renders: the boxes in a row, then each close from its front three-quarter."""
    os.makedirs(folder, exist_ok=True)
    scene = bpy.context.scene
    try:
        scene.render.engine = "BLENDER_WORKBENCH"
    except TypeError:
        pass
    scene.display.shading.light = "STUDIO"
    scene.display.shading.color_type = "TEXTURE"
    scene.display.shading.show_cavity = True
    scene.display.shading.show_backface_culling = True
    cam = bpy.data.objects.new("PreviewCam", bpy.data.cameras.new("PreviewCam"))
    scene.collection.objects.link(cam)
    scene.camera = cam
    cam.data.lens = 40
    middle = Vector(((len(boxes) - 1) * SPACING / 2, 0, 0.75))
    scene.render.resolution_x, scene.render.resolution_y = 1400, 480
    cam.location = middle + Vector((0, -12 - len(boxes) * 6, 6))
    cam.rotation_euler = (middle - cam.location).to_track_quat("-Z", "Y").to_euler()
    scene.render.filepath = os.path.join(folder, f"{PACK}_lineup.png")
    bpy.ops.render.render(write_still=True)
    scene.render.resolution_x, scene.render.resolution_y = 800, 640
    for index, name in enumerate(boxes):
        target = Vector((index * SPACING, 0, 0.7))
        cam.location = target + Vector((-2.6, -4.4, 2.9))
        cam.rotation_euler = (target - cam.location).to_track_quat("-Z", "Y").to_euler()
        scene.render.filepath = os.path.join(folder, f"{name}.png")
        bpy.ops.render.render(write_still=True)
    bpy.data.objects.remove(cam)


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
    folder = os.environ.get("PREVIEW_DIR")
    if folder:
        preview(wanted, folder)
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
