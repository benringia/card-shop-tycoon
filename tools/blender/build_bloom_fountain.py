"""Builds the healing spring's Elemental Bloom fountain (plaza round 2, the user's pick B; remodelled in Blender on
2026-10-30 to be bigger and much more colourful than the part-built lotus).

A lotus on a deep teal two-step base with gold bands: five big cupped outer petals, one per card element (Ember,
Tide, Bloom, Volt, Shade), each in three bands from a deep shade at its foot to a bright tip; five magenta inner
petals between them; lily pads with little pink flowers round the lower step; a gold stem with a cup in the middle.
Bold mid-tone colours only: pale ones wash out to white in the town's sun.

Separate objects so the game can find and dress them (Server/Util/BloomFountain):
  Body           the stone, petals, pads, stem and cup (palette texture)
  Water          the pool in the flower's heart (the game makes it glowing water)
  Crystal        the card that floats and turns over the cup (the game makes it glowing gold)
  Gem_<Element>  the crystal at each outer petal's tip (the game makes it glow its element's colour and spray water)

Blender: Z up, 1 unit = 1 stud, origin at the base's bottom centre. The first petal (Ember) points along +X.
Run inside Blender (MCP execute: exec(open(path).read())). Writes assets/blender/BloomFountain/{.blend,.fbx,palette}.
"""
import math
import os
import sys

import bpy
from mathutils import Matrix, Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)) if "__file__" in globals() else
                os.path.join(os.environ.get("CARD_SHOP_REPO", r"C:\Users\Ben\Documents\roblox-project\card-shop-tycoon"), "tools", "blender"))
import voxel_kit  # noqa: E402

NAME = "BloomFountain"
BONE = "Root"  # the kit weights every vertex to a bone; this prop has no rig, so one name for all

ELEMENTS = ["Ember", "Tide", "Bloom", "Volt", "Shade"]
COLORS = {
    "stone_dark": (22, 78, 104),
    "stone": (34, 116, 146),
    "stone_light": (64, 156, 182),
    "gold": (255, 188, 48),
    "gold_dark": (206, 136, 28),
    "Ember_0": (176, 40, 28), "Ember_1": (240, 84, 44), "Ember_2": (255, 156, 66),
    "Tide_0": (22, 74, 196), "Tide_1": (44, 136, 255), "Tide_2": (104, 196, 255),
    "Bloom_0": (28, 132, 56), "Bloom_1": (58, 190, 82), "Bloom_2": (146, 230, 104),
    "Volt_0": (214, 142, 10), "Volt_1": (255, 196, 28), "Volt_2": (255, 230, 104),
    "Shade_0": (92, 36, 164), "Shade_1": (146, 78, 226), "Shade_2": (196, 138, 255),
    "inner_0": (190, 44, 124), "inner_1": (236, 96, 170), "inner_2": (255, 160, 206),
    "pad": (40, 148, 68),
    "pad_light": (74, 188, 92),
    "flower": (255, 116, 178),
    "flower_core": (255, 214, 80),
    "water": (60, 210, 230),
    "card": (255, 196, 60),
    "gem": (255, 255, 255),
}

# Sizes in studs
STEP = [(7.0, 0.0), (7.0, 0.55), (6.75, 0.62), (6.75, 0.78)]  # lower step: (radius, height) going up
STEP2 = [(6.0, 0.78), (6.0, 1.25), (5.8, 1.3)]
BOWL = [(5.1, 1.3), (4.9, 1.5), (4.8, 2.3), (5.2, 2.7), (5.35, 2.85), (5.1, 2.95), (4.6, 2.95), (4.5, 2.6)]
POOL = (4.5, 2.62)  # the water's radius and top
OUTER = {"ring": 3.6, "z": 2.2, "lean": 32, "length": 5.6, "width": 5.4, "thick": 0.55, "cup": 0.38, "curl": 0.45}
INNER = {"ring": 2.2, "z": 2.3, "lean": 18, "length": 4.6, "width": 3.8, "thick": 0.45, "cup": 0.32, "curl": 0.3}
STEM = {"radius": 0.5, "top": 7.2, "cup": 1.05}
CARD = {"width": 2.4, "height": 3.4, "thick": 0.24, "z": 10.4}
GEM = {"radius": 0.36, "length": 0.9}
SEGMENTS = 40


def lathe(b, profile, colors, segments=SEGMENTS):
    """Turns a (radius, height) profile round Z; colors[i] colours the band between profile points i and i + 1."""
    rings = []
    for r, z in profile:
        rings.append(b._verts([(r * math.cos(2 * math.pi * k / segments), r * math.sin(2 * math.pi * k / segments), z)
                               for k in range(segments)], BONE))
    for i in range(len(rings) - 1):
        lower, upper = rings[i], rings[i + 1]
        for k in range(segments):
            n = (k + 1) % segments
            face = b._face([lower[k], lower[n], upper[n], upper[k]], colors[i])
            face.smooth = True
    return rings


def disc(b, radius, z, color, segments=SEGMENTS, up=True):
    centre = b._verts([(0, 0, z)], BONE)[0]
    ring = b._verts([(radius * math.cos(2 * math.pi * k / segments), radius * math.sin(2 * math.pi * k / segments), z)
                     for k in range(segments)], BONE)
    for k in range(segments):
        n = (k + 1) % segments
        b._face([centre, ring[k], ring[n]] if up else [centre, ring[n], ring[k]], color)


def petal(b, angle, spec, bands, steps=12, around=14):
    """A cupped, pointed lotus petal: a thin lens-shaped tube along its length, its hollow facing the middle, the
    tip curling outward a little. Leans spec.lean degrees out from upright from a foot spec.ring out, turned `angle`
    degrees round Z. bands: three colours from foot to tip."""
    length, width, thick = spec["length"], spec["width"], spec["thick"]
    lean = math.radians(spec["lean"])
    place = Matrix.Translation((spec["ring"] * math.cos(math.radians(angle)), spec["ring"] * math.sin(math.radians(angle)), spec["z"])) \
        @ Matrix.Rotation(math.radians(angle), 4, "Z") @ Matrix.Rotation(lean, 4, "Y")
    # Local: length along +Z, width along Y, outward along +X (the hollow faces -X, the middle)
    loops = []
    for i in range(steps + 1):
        u = i / steps
        half = width / 2 * (0.32 + 0.68 * math.sin(math.pi * min(u / 0.92, 1.0)) ** 0.8) if u < 1 else 0.0
        t = thick * (1 - u) ** 0.6 + 0.02
        curl = spec["curl"] * u ** 3
        ring = []
        for k in range(around):
            th = 2 * math.pi * k / around
            v = math.cos(th)
            y = half * v
            x = -spec["cup"] * (v * v) * (half / (width / 2)) + t / 2 * math.sin(th) + curl
            ring.append(place @ Vector((x, y, u * length)))
        loops.append(b._verts(ring, BONE) if i < steps else b._verts([place @ Vector((spec["curl"], 0, length))], BONE))
    for i in range(steps):
        band = bands[0] if i < steps * 0.35 else bands[1] if i < steps * 0.72 else bands[2]
        lower, upper = loops[i], loops[i + 1]
        for k in range(around):
            n = (k + 1) % around
            # The loops run clockwise seen from the tip, so this order faces out
            if len(upper) == 1:
                face = b._face([lower[k], upper[0], lower[n]], band)
            else:
                face = b._face([lower[k], upper[k], upper[n], lower[n]], band)
            face.smooth = True
    # Close the foot (it sits inside the bowl)
    b._face(list(loops[0]), bands[0])
    return place @ Vector((spec["curl"], 0, length)), (place.to_3x3() @ Vector((0, 0, 1))).normalized()


def lily_pad(b, centre, radius, turn):
    """A flat round pad with a notch cut out, a small pink flower on it."""
    segments = 18
    notch = 0.45
    z = centre[2]
    middle = b._verts([centre], BONE)[0]
    points = []
    for k in range(segments + 1):
        a = turn + notch / 2 + (2 * math.pi - notch) * k / segments
        points.append((centre[0] + radius * math.cos(a), centre[1] + radius * math.sin(a), z))
    ring = b._verts(points, BONE)
    for k in range(segments):
        b._face([middle, ring[k], ring[k + 1]], "pad" if k % 2 == 0 else "pad_light")
    fx, fy = centre[0] + radius * 0.35 * math.cos(turn + math.pi), centre[1] + radius * 0.35 * math.sin(turn + math.pi)
    for k in range(5):
        a = 2 * math.pi * k / 5
        b.blob((fx + 0.22 * math.cos(a), fy + 0.22 * math.sin(a), z + 0.14), (0.22, 0.13, 0.12), "flower", BONE,
               rot=Matrix.Rotation(a, 3, "Z"), segments=8, rings=5)
    b.blob((fx, fy, z + 0.2), (0.12, 0.12, 0.1), "flower_core", BONE, segments=8, rings=5)


def build_body():
    b = voxel_kit.Builder(COLORS)
    lathe(b, STEP, ["stone_dark", "gold", "stone"])
    disc(b, STEP[0][0], 0.0, "stone_dark", up=False)
    disc(b, STEP[-1][0], STEP[-1][1], "stone")
    lathe(b, STEP2, ["stone", "gold"])
    disc(b, STEP2[-1][0], STEP2[-1][1], "stone_light")
    lathe(b, BOWL, ["stone_dark", "stone", "stone_light", "gold", "gold", "gold_dark", "stone_dark"])
    disc(b, BOWL[-1][0], BOWL[-1][1] - 0.4, "stone_dark")
    tips = []
    for index, element in enumerate(ELEMENTS):
        angle = index * 72
        tips.append(petal(b, angle, OUTER, [f"{element}_0", f"{element}_1", f"{element}_2"]))
        petal(b, angle + 36, INNER, ["inner_0", "inner_1", "inner_2"])
    for index in range(10):
        a = math.radians(index * 36 + 18)
        lily_pad(b, (6.35 * math.cos(a), 6.35 * math.sin(a), STEP[-1][1] + 0.03), 0.62 if index % 2 else 0.5, a + 1.2)
    lathe(b, [(STEM["radius"], POOL[1] - 0.3), (STEM["radius"], STEM["top"] - 0.5), (STEM["radius"] * 1.6, STEM["top"] - 0.25),
              (STEM["cup"], STEM["top"]), (STEM["cup"] * 0.8, STEM["top"]), (STEM["radius"], STEM["top"] - 0.35)],
          ["gold_dark", "gold", "gold", "gold", "gold_dark"], segments=20)
    return b.to_object("Body"), tips


def build_water():
    b = voxel_kit.Builder(COLORS)
    disc(b, POOL[0], POOL[1], "water")
    return b.to_object("Water")


def build_card():
    b = voxel_kit.Builder(COLORS)
    b.round_box((0, 0, CARD["z"]), (CARD["width"], CARD["thick"], CARD["height"]), "card", BONE, bevel=0.9, segments=2)
    return b.to_object("Crystal")


def build_gem(element, tip, along):
    b = voxel_kit.Builder(COLORS)
    rot = along.to_track_quat("Z", "Y").to_matrix()
    base = tip + along * 0.05
    r, h = GEM["radius"], GEM["length"]
    ring = b._verts([base + rot @ Vector((r * math.cos(2 * math.pi * k / 6), r * math.sin(2 * math.pi * k / 6), h * 0.35)) for k in range(6)], BONE)
    top = b._verts([base + rot @ Vector((0, 0, h))], BONE)[0]
    bottom = b._verts([base], BONE)[0]
    for k in range(6):
        n = (k + 1) % 6
        b._face([ring[k], ring[n], top], "gem")
        b._face([ring[n], ring[k], bottom], "gem")
    return b.to_object(f"Gem_{element}")


def run():
    os.makedirs(voxel_kit.out_dir(NAME), exist_ok=True)
    if bpy.context.object and bpy.context.object.mode != "OBJECT":
        bpy.ops.object.mode_set(mode="OBJECT")
    for obj in list(bpy.data.objects):
        bpy.data.objects.remove(obj, do_unlink=True)
    bpy.data.orphans_purge(do_recursive=True)
    material = voxel_kit.make_material(NAME, voxel_kit.make_palette(NAME, COLORS))
    body, tips = build_body()
    objects = [body, build_water(), build_card()] + [build_gem(element, tip, along) for element, (tip, along) in zip(ELEMENTS, tips)]
    scene = bpy.context.scene
    for obj in objects:
        scene.collection.objects.link(obj)
        obj.data.materials.append(material)
        obj.vertex_groups.clear()
    print("tris:", ", ".join(f"{o.name} {sum(len(p.vertices) - 2 for p in o.data.polygons)}" for o in objects))
    if os.environ.get("EXPORT", "1") == "1":
        bpy.ops.object.select_all(action="DESELECT")
        for obj in objects:
            obj.select_set(True)
        bpy.context.view_layer.objects.active = body
        bpy.ops.wm.save_as_mainfile(filepath=os.path.join(voxel_kit.out_dir(NAME), f"{NAME}.blend"))
        bpy.ops.export_scene.fbx(
            filepath=os.path.join(voxel_kit.out_dir(NAME), f"{NAME}.fbx"),
            use_selection=True,
            object_types={"MESH"},
            path_mode="COPY",
            embed_textures=True,
            mesh_smooth_type="FACE",
            apply_scale_options="FBX_SCALE_ALL",
        )
        print("exported to", voxel_kit.out_dir(NAME))
    return objects


run()
