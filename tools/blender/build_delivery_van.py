"""Builds the packenship.co delivery van (owner 2026-11-23: "make the van in blender"; Config/Delivery VAN, DESIGN.md 4.2
"The packenship.co van") in the props' chunky cartoon style: a rounded loaf of a van, white over a lilac skirt with a
mint pinstripe along its sides, a sloped windscreen, round headlights either side of a little parcel badge, a parcel
on the roof, a sliding door on its right side with parcels stacked inside, and four wheels.

ONE pack holding one piece, so the owner imports once: an Empty named DeliveryVan holding
  DeliveryVan__Frame                      the body, glass, bumpers, mirrors, wheel wells, the roof parcel
  DeliveryVan__Door                       the sliding door (Util/DeliveryVan slides it back along the side)
  DeliveryVan__WheelFL / FR / RL / RR     each wheel round its own axle (the game turns them)
  DeliveryVan__BandLeft / BandRight       the mint panels the game writes "packenship.co" on (a SurfaceGui)
  DeliveryVan__Headlights / Taillights    the lamps (the game makes them glow)
all with one palette texture. Import assets/blender/DeliveryVan/DeliveryVan.fbx in Studio with default settings, save
the imported model as assets/props-import/DeliveryVan.rbxm, then `lune run tools/props/split_pack
assets/props-import/DeliveryVan.rbxm` writes assets/props/DeliveryVan.rbxm (docs/props.md "The delivery van"). Until
then Util/DeliveryVan builds the van from parts.

Blender: Z up, 1 unit = 1 stud, the van's front faces -Y, the wheels stand on z = 0. It imports facing -Z with
Blender's +X on Roblox's -X (checked on the delivery boxes' stickers), so the van's right side, the door's, the one
that faces the pad, is Blender -X.
Run in a background Blender (it clears the scene):
  blender -b --factory-startup --python tools/blender/build_delivery_van.py
EXPORT=0 builds without saving; PREVIEW_DIR=<folder> also renders a few views (door shut and open) into that folder.
"""
import math
import os
import sys

import bmesh
import bpy
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)) if "__file__" in globals() else
                os.path.join(os.environ.get("CARD_SHOP_REPO", r"C:\Users\Ben\Documents\roblox-project\card-shop-tycoon"), "tools", "blender"))
import voxel_kit  # noqa: E402
import portal_kit  # noqa: E402

BONE = portal_kit.BONE
PACK = "DeliveryVan"
OUT = "DeliveryVan"  # assets/blender/DeliveryVan
CAP = 3000  # triangles for the whole van: one moving prop, only ever one on a screen (DESIGN 10.5)

# Config/Delivery VAN's colours, plus the parcels' cardboard and the badge's ink
COLORS = {
    "body": (255, 255, 255),
    "skirt": (220, 203, 255),
    "stripe": (63, 214, 160),
    "glass": (180, 224, 255),
    "glint": (240, 250, 255),
    "tyre": (43, 34, 56),
    "hub": (156, 143, 176),
    "dark": (58, 42, 74),  # the doorway, wheel wells, seams and handles
    "ink": (91, 61, 110),  # the grille
    "light": (255, 244, 214),
    "tail": (255, 110, 120),
    "card": (206, 160, 108),
    "card_dark": (172, 128, 82),
}

# The body: two side profiles (y, z; front at -y), each pushed across the van and rounded off: the cab and cargo box,
# and the short nose in front of it (two convex shapes: one profile with the hood in it rounded into a dent)
HALF_W = 2.65  # the body's half width (Config/Delivery VAN.width 5.5 counts the wheels)
NOSE_W = 2.6  # the nose's, a touch narrower
BOTTOM = 0.9
ROOF = 5.2
NOSE = -5.35  # the nose's front
TAIL = 5.35  # the rear doors
SCREEN_FOOT = (-4.3, 3.0)  # where the windscreen meets the cab's front
SCREEN_TOP = (-3.3, ROOF)  # and the roof
HOOD = 2.75  # the nose's top
PROFILE = [(TAIL, BOTTOM), (TAIL, ROOF), SCREEN_TOP, SCREEN_FOOT, (SCREEN_FOOT[0], BOTTOM)]
NOSE_PROFILE = [(-4.0, BOTTOM), (-4.0, HOOD), (NOSE, HOOD), (NOSE, BOTTOM)]
BEVEL = 0.38  # how round its edges are
SKIRT = 1.6  # lilac below this
STRIPE = 1.8  # a mint pinstripe up to this, along the sides

WHEEL_R = 1.0  # Config/Delivery VAN.wheel / 2
WHEEL_X = 2.3  # each tyre's middle
AXLE_Y = 3.55  # the front and rear axles
WELL_R = 1.25

DOOR = (-1.7, 0.5, 1.2, 4.7)  # y from, y to, z from, z to: the sliding door on the right (-X)
DOOR_OUT = (2.70, 2.78)  # its inside and outside, off the middle
BAND_Z = (2.75, 4.05)  # the name panels' height
BAND_LEFT = (-1.55, 4.75)  # y along the left side
BAND_RIGHT = (0.75, 4.75)  # and the right, behind the door


# ---------------------------------------------------------------------------------------------------- shapes

def fillet(points, radius, segments=2):
    """A convex outline with its corners rounded (each a quadratic curve through the old corner); radius per corner
    or one for all, 0 keeps a corner sharp."""
    radii = radius if isinstance(radius, (list, tuple)) else [radius] * len(points)
    out = []
    count = len(points)
    for i, corner in enumerate(points):
        p = Vector(corner)
        r = radii[i]
        if r <= 0:
            out.append(p)
            continue
        a, c = Vector(points[i - 1]), Vector(points[(i + 1) % count])
        t = min(r, (a - p).length * 0.45, (c - p).length * 0.45)
        t1 = p + (a - p).normalized() * t
        t2 = p + (c - p).normalized() * t
        for k in range(segments + 1):
            s = k / segments
            out.append(t1 * (1 - s) ** 2 + p * 2 * (1 - s) * s + t2 * s * s)
    return out


def rrect(a0, a1, b0, b1, radius, segments=2):
    """A rounded rectangle's outline in 2D (a across, b up), corners bottom-left, bottom-right, top-right, top-left."""
    return fillet([(a0, b0), (a1, b0), (a1, b1), (a0, b1)], radius, segments)


def newell(points):
    n = Vector((0, 0, 0))
    for i, p in enumerate(points):
        q = points[(i + 1) % len(points)]
        n.x += (p.y - q.y) * (p.z + q.z)
        n.y += (p.z - q.z) * (p.x + q.x)
        n.z += (p.x - q.x) * (p.y + q.y)
    return n


def panel(b, points, normal, thick, color, back=False):
    """A flat slab: the outline `points` (3D, on one plane) pushed `thick` along `normal`, its face toward normal. Its
    back stays open unless `back`: every slab lies on the body, where nobody sees behind it."""
    n = Vector(normal).normalized()
    back = [Vector(p) for p in points]
    if newell(back).dot(n) < 0:
        back.reverse()
    front = [p + n * thick for p in back]
    vb = b._verts(back, BONE)
    vf = b._verts(front, BONE)
    b._face(vf, color)
    if back:
        b._face(list(reversed(vb)), color)
    for i in range(len(vb)):
        j = (i + 1) % len(vb)
        b._face([vb[i], vb[j], vf[j], vf[i]], color)


def on_side(side, x, outline):
    """2D (y, z) points on the plane x = side * x."""
    return [(side * x, y, z) for y, z in outline]


def on_face(y, outline):
    """2D (x, z) points on the plane y = y."""
    return [(x, y, z) for x, z in outline]


def on_plane(origin, u, v, outline):
    o, u, v = Vector(origin), Vector(u), Vector(v)
    return [o + u * a + v * c for a, c in outline]


def strip(a, c, width):
    """A thin 2D bar from a to c."""
    a, c = Vector(a), Vector(c)
    d = (c - a).normalized()
    side = Vector((-d.y, d.x)) * width / 2
    return [a - side, c - side, c + side, a + side]


def paint(b, faces, color):
    i = b.index[color]
    u, v = ((i % voxel_kit.CELLS) + 0.5) / voxel_kit.CELLS, ((i // voxel_kit.CELLS) + 0.5) / voxel_kit.CELLS
    for face in faces:
        for loop in face.loops:
            loop[b.uv].uv = (u, v)


# ---------------------------------------------------------------------------------------------------- the van

def loaf(b, profile, half_w):
    """A convex side profile (y, z, anticlockwise seen from +X) pushed across +-half_w, every edge rounded. Only the
    rounded edges shade smooth: the big flat sides stay flat (smoothed with their edges they'd shade crumpled)."""
    bm = b.bm
    before = set(bm.faces)
    left = b._verts([(half_w, y, z) for y, z in profile], BONE)
    right = b._verts([(-half_w, y, z) for y, z in profile], BONE)
    b._face(left, "body")
    b._face(list(reversed(right)), "body")
    for i in range(len(profile)):
        j = (i + 1) % len(profile)
        b._face([left[i], right[i], right[j], left[j]], "body")
    made = [f for f in bm.faces if f not in before]
    edges = list({e for f in made for e in f.edges})
    rounded = set(bmesh.ops.bevel(bm, geom=edges, offset=BEVEL, segments=2, profile=0.5, affect="EDGES", clamp_overlap=True)["faces"])
    for f in bm.faces:
        if f not in before:
            f.smooth = f in rounded


def body(b):
    """The cab and cargo box and the nose, then cut level at the skirt and the stripe and painted: lilac below, a mint
    pinstripe along the sides, white above."""
    bm = b.bm
    before = set(bm.faces)
    loaf(b, PROFILE, HALF_W)
    loaf(b, NOSE_PROFILE, NOSE_W)
    faces = [f for f in bm.faces if f not in before]
    for height in (SKIRT, STRIPE):
        geom = list({v for f in faces for v in f.verts}) + list({e for f in faces for e in f.edges}) + faces
        bmesh.ops.bisect_plane(bm, geom=geom, plane_co=(0, 0, height), plane_no=(0, 0, 1))
        faces = [f for f in bm.faces if f not in before]
    for edge in {e for f in faces for e in f.edges}:
        linked = edge.link_faces
        if len(linked) == 2 and linked[0].smooth != linked[1].smooth:
            edge.smooth = False
    bm.normal_update()
    for f in faces:
        z = f.calc_center_median().z
        if z < SKIRT:
            paint(b, [f], "skirt")
        elif z < STRIPE and abs(f.normal.x) > 0.5:
            paint(b, [f], "stripe")
        else:
            paint(b, [f], "body")
    # the sides' n-gons as triangles, so every importer splits them the same way
    bmesh.ops.triangulate(bm, faces=faces, quad_method="BEAUTY", ngon_method="BEAUTY")


def windscreen_frame():
    """The windscreen's plane: its middle, across (+X), up the slope and its outward normal."""
    foot, top = Vector((0, *SCREEN_FOOT)), Vector((0, *SCREEN_TOP))
    up = (top - foot).normalized()
    out = Vector((0, -up.z, up.y))  # forward and up
    return (foot + top) / 2, Vector((1, 0, 0)), up, out


def front_y(z):
    """The body's front edge on the sides at height z (the windscreen's slope)."""
    (y0, z0), (y1, z1) = SCREEN_FOOT, SCREEN_TOP
    return y0 + (z - z0) / (z1 - z0) * (y1 - y0)


def glass(b):
    """Windscreen, cab windows, rear windows: sky-blue panes with a glint."""
    middle, across, up, out = windscreen_frame()
    length = (Vector(SCREEN_TOP) - Vector(SCREEN_FOOT)).length
    pane = rrect(-HALF_W + 0.5, HALF_W - 0.5, -length / 2 + 0.42, length / 2 - 0.42, 0.3)
    panel(b, on_plane(middle - out * 0.01, across, up, pane), out, 0.05, "glass")
    for a, c, w in (((-1.75, -0.2), (-1.15, 0.45), 0.16), ((-1.3, -0.35), (-0.95, 0.05), 0.09)):
        panel(b, on_plane(middle + out * 0.03, across, up, strip(a, c, w)), out, 0.02, "glint")
    for side in (-1, 1):
        low, high = 3.35, 4.62
        window = fillet([(front_y(low) + 0.5, low), (-1.95, low), (-1.95, high), (front_y(high) + 0.5, high)], 0.2)
        panel(b, on_side(side, HALF_W - 0.01, window), (side, 0, 0), 0.05, "glass")
        panel(b, on_side(side, HALF_W + 0.03, strip((-3.25, 3.65), (-2.85, 4.3), 0.12)), (side, 0, 0), 0.02, "glint")
        # the rear doors' windows, either side of the seam
        a0, a1 = sorted((side * 0.22, side * 1.7))
        panel(b, on_face(TAIL - 0.01, rrect(a0, a1, 3.45, 4.55, 0.2)), (0, 1, 0), 0.05, "glass")


def front(b):
    """Headlight rims, the grille, the parcel badge, the bumper and its plate."""
    for side in (-1, 1):
        portal_kit.tube(b, [(side * 1.6, NOSE + 0.02, 1.88), (side * 1.6, NOSE - 0.04, 1.88)], [0.46, 0.46], "hub", sides=14)
    panel(b, on_face(NOSE + 0.01, rrect(-0.72, 0.72, 1.5, 1.86, 0.16)), (0, -1, 0), 0.04, "ink")
    for z in (1.62, 1.74):
        panel(b, on_face(NOSE - 0.02, [(-0.55, z - 0.025), (0.55, z - 0.025), (0.55, z + 0.025), (-0.55, z + 0.025)]), (0, -1, 0), 0.02, "dark")
    # the badge: a little mint parcel taped white
    panel(b, on_face(NOSE + 0.01, rrect(-0.26, 0.26, 1.98, 2.34, 0.06)), (0, -1, 0), 0.04, "stripe")
    panel(b, on_face(NOSE - 0.02, [(-0.05, 1.98), (0.05, 1.98), (0.05, 2.34), (-0.05, 2.34)]), (0, -1, 0), 0.02, "body")
    panel(b, on_face(NOSE - 0.02, [(-0.26, 2.12), (0.26, 2.12), (0.26, 2.2), (-0.26, 2.2)]), (0, -1, 0), 0.02, "body")
    for y in (NOSE - 0.03, TAIL + 0.03):
        b.round_box((0, y, 1.12), (5.0, 0.36, 0.42), "hub", BONE, bevel=0.4, segments=1)
        face = -1 if y < 0 else 1
        plate_y = y + face * 0.18
        panel(b, on_face(plate_y, rrect(-0.45, 0.45, 1.0, 1.24, 0.05)), (0, face, 0), 0.02, "body")


def rear(b):
    """The rear doors' seam and handles."""
    panel(b, on_face(TAIL - 0.01, [(-0.03, 1.45), (0.03, 1.45), (0.03, 4.75), (-0.03, 4.75)]), (0, 1, 0), 0.04, "dark")
    for side in (-1, 1):
        a0, a1 = sorted((side * 0.18, side * 0.55))
        panel(b, on_face(TAIL - 0.01, rrect(a0, a1, 2.8, 2.92, 0.05)), (0, 1, 0), 0.06, "dark")


def sides(b):
    """Wheel wells, the doorway with parcels inside (behind the sliding door), and the mirrors."""
    for side in (-1, 1):
        for axle in (-AXLE_Y, AXLE_Y):
            arc = [(axle + math.cos(math.pi * k / 8) * WELL_R, WHEEL_R + math.sin(math.pi * k / 8) * WELL_R) for k in range(9)]
            panel(b, on_side(side, HALF_W - 0.01, arc), (side, 0, 0), 0.035, "dark")
        # the mirror: an arm off the cab's front corner and a rounded head, its glass toward the back
        b.box((side * (HALF_W + 0.12), -3.45, 3.45), (0.3, 0.1, 0.1), "hub", BONE)
        b.round_box((side * (HALF_W + 0.33), -3.45, 3.6), (0.18, 0.32, 0.5), "body", BONE, bevel=0.5, segments=1)
        panel(b, on_face(-3.45 + 0.16, rrect(side * (HALF_W + 0.33) - 0.06, side * (HALF_W + 0.33) + 0.06, 3.42, 3.78, 0.04)), (0, 1, 0), 0.015, "glass")
    y0, y1, z0, z1 = DOOR
    panel(b, on_side(-1, HALF_W - 0.005, rrect(y0, y1, z0, z1, 0.18)), (-1, 0, 0), 0.03, "dark")
    # parcels stacked inside, seen once the door slides open
    for a, c, top in ((-1.4, -0.45, 2.15), (-0.3, 0.3, 1.85), (-1.2, -0.6, 2.7)):
        bottom = 2.2 if top > 2.5 else 1.3
        panel(b, on_side(-1, HALF_W + 0.025, [(a, bottom), (c, bottom), (c, top), (a, top)]), (-1, 0, 0), 0.01, "card")
        mid = (a + c) / 2
        panel(b, on_side(-1, HALF_W + 0.035, [(mid - 0.08, bottom), (mid + 0.08, bottom), (mid + 0.08, top), (mid - 0.08, top)]), (-1, 0, 0), 0.006, "stripe")


def roof_parcel(b):
    """A cardboard parcel on the roof, taped mint: the supplier's sign."""
    y, size = -1.2, (2.0, 1.6, 1.0)
    b.round_box((0, y, ROOF + size[2] / 2 - 0.02), size, "card", BONE, bevel=0.18, segments=1)
    top = ROOF + size[2] - 0.02
    b.box((0, y, top + 0.004), (size[0] - 0.12, 0.05, 0.02), "card_dark", BONE)  # where the flaps meet
    b.box((0, y, top + 0.012), (0.42, size[1] + 0.02, 0.025), "stripe", BONE)
    for face in (-1, 1):
        b.box((0, y + face * (size[1] / 2 + 0.006), top - 0.3), (0.42, 0.025, 0.6), "stripe", BONE)


def frame():
    b = voxel_kit.Builder(COLORS)
    body(b)
    glass(b)
    front(b)
    rear(b)
    sides(b)
    roof_parcel(b)
    return b.to_object("Frame")


def door():
    """The sliding door: white over a lilac skirt and the mint pinstripe like the body, a window, a handle."""
    b = voxel_kit.Builder(COLORS)
    y0, y1, z0, z1 = DOOR
    inner, outer = DOOR_OUT
    panel(b, on_side(-1, inner, rrect(y0, y1, z0, z1, 0.18)), (-1, 0, 0), outer - inner, "body")
    skin = outer + 0.002
    panel(b, on_side(-1, skin, fillet([(y0, z0), (y1, z0), (y1, SKIRT), (y0, SKIRT)], [0.18, 0.18, 0, 0])), (-1, 0, 0), 0.012, "skirt")
    panel(b, on_side(-1, skin, [(y0, SKIRT), (y1, SKIRT), (y1, STRIPE), (y0, STRIPE)]), (-1, 0, 0), 0.012, "stripe")
    panel(b, on_side(-1, skin, rrect(y0 + 0.25, y1 - 0.25, 3.35, 4.45, 0.2)), (-1, 0, 0), 0.012, "glass")
    panel(b, on_side(-1, skin + 0.01, strip((y0 + 0.5, 3.6), (y0 + 0.9, 4.2), 0.12)), (-1, 0, 0), 0.01, "glint")
    panel(b, on_side(-1, skin, rrect(y0 + 0.12, y0 + 0.24, 2.6, 3.05, 0.05)), (-1, 0, 0), 0.06, "dark")
    return b.to_object("Door")


def wheel(name, side, axle):
    """A tyre round its axle (along X), its edges rounded, a hub and a white cap on its outside."""
    b = voxel_kit.Builder(COLORS)
    xs = [WHEEL_X - 0.4, WHEEL_X - 0.32, WHEEL_X + 0.32, WHEEL_X + 0.4]
    portal_kit.tube(b, [(side * x, axle, WHEEL_R) for x in xs], [0.84, 1.0, 1.0, 0.84], "tyre", sides=16)  # 16: a vertex right under the axle
    hub = WHEEL_X + 0.38
    portal_kit.tube(b, [(side * hub, axle, WHEEL_R), (side * (hub + 0.05), axle, WHEEL_R)], [0.55, 0.55], "hub", sides=10)
    portal_kit.tube(b, [(side * (hub + 0.05), axle, WHEEL_R), (side * (hub + 0.1), axle, WHEEL_R)], [0.22, 0.22], "body", sides=8)
    return b.to_object(name)


def band(name, side, along):
    """A mint name panel on one side (the game writes on its outer face)."""
    b = voxel_kit.Builder(COLORS)
    y0, y1 = along
    z0, z1 = BAND_Z
    panel(b, on_side(side, HALF_W - 0.005, rrect(y0, y1, z0, z1, 0.22)), (side, 0, 0), 0.05, "stripe")
    return b.to_object(name)


def lamps():
    """The headlights (round, on the nose) and the taillights (tall, on the rear corners)."""
    head, tail = voxel_kit.Builder(COLORS), voxel_kit.Builder(COLORS)
    for side in (-1, 1):
        portal_kit.tube(head, [(side * 1.6, NOSE - 0.02, 1.88), (side * 1.6, NOSE - 0.1, 1.88)], [0.36, 0.34], "light", sides=14)
        a0, a1 = sorted((side * 1.78, side * 2.12))
        panel(tail, on_face(TAIL - 0.01, rrect(a0, a1, 2.2, 3.2, 0.14)), (0, 1, 0), 0.06, "tail")
    return head.to_object("Headlights"), tail.to_object("Taillights")


def parts():
    headlights, taillights = lamps()
    return [
        frame(),
        door(),
        wheel("WheelFL", 1, -AXLE_Y),
        wheel("WheelFR", -1, -AXLE_Y),
        wheel("WheelRL", 1, AXLE_Y),
        wheel("WheelRR", -1, AXLE_Y),
        band("BandLeft", 1, BAND_LEFT),
        band("BandRight", -1, BAND_RIGHT),
        headlights,
        taillights,
    ]


# ---------------------------------------------------------------------------------------------------- build, check, export

def bounds(objects):
    points = [obj.matrix_world @ Vector(corner) for obj in objects for corner in obj.bound_box]
    low = Vector((min(p.x for p in points), min(p.y for p in points), min(p.z for p in points)))
    high = Vector((max(p.x for p in points), max(p.y for p in points), max(p.z for p in points)))
    return low, high


def build():
    objects = parts()
    material = voxel_kit.make_material(PACK, voxel_kit.make_palette(PACK, COLORS))
    scene = bpy.context.scene
    for obj in objects:
        scene.collection.objects.link(obj)
        obj.data.materials.clear()
        obj.data.materials.append(material)
        obj.vertex_groups.clear()
        obj.name = f"{PACK}__{obj.name}"
        obj.data.name = obj.name
    bpy.context.view_layer.update()
    counts = {o.name.split("__")[1]: portal_kit.triangles(o) for o in objects}
    total = sum(counts.values())
    print("tris:", ", ".join(f"{k} {v}" for k, v in counts.items()), "| total", total)
    assert total <= CAP, f"{PACK} has {total} triangles (cap {CAP})"
    low, high = bounds(objects)
    span = high - low
    print(f"size {span.x:.2f} x {span.y:.2f} x {span.z:.2f}, low {tuple(round(v, 3) for v in low)}")
    assert abs(low.z) < 0.01, f"the wheels should stand on z = 0 ({low.z})"
    assert abs(low.y + high.y) < 0.02, "front and back should reach as far from the middle (the pivot)"
    for name in ("WheelFL", "WheelFR", "WheelRL", "WheelRR"):
        wheel_obj = next(o for o in objects if o.name.endswith(name))
        w_low, w_high = bounds([wheel_obj])
        middle = (w_low + w_high) / 2
        assert abs(middle.z - WHEEL_R) < 0.01 and abs(abs(middle.y) - AXLE_Y) < 0.01, f"{name}'s box isn't round its axle"
    return objects


def preview(objects, folder):
    """Workbench renders: the door side from the front, the other side, the back, the door side with the door open."""
    os.makedirs(folder, exist_ok=True)
    scene = bpy.context.scene
    try:
        scene.render.engine = "BLENDER_WORKBENCH"
    except TypeError:
        pass
    scene.display.shading.light = "STUDIO"
    scene.display.shading.color_type = "TEXTURE"
    scene.display.shading.show_cavity = True
    scene.display.shading.show_backface_culling = True  # as Roblox draws: a face turned the wrong way vanishes
    scene.render.resolution_x, scene.render.resolution_y = 900, 650
    scene.render.film_transparent = False
    world = scene.world or bpy.data.worlds.new("World")
    scene.world = world
    cam = bpy.data.objects.new("PreviewCam", bpy.data.cameras.new("PreviewCam"))
    cam.data.lens = 50
    scene.collection.objects.link(cam)
    scene.camera = cam
    door_obj = next(o for o in objects if o.name.endswith("__Door"))
    target = Vector((0, 0, 2.6))
    views = [
        ("front_door_side", Vector((-17, -18, 9)), 0),
        ("left_side", Vector((21, 6, 6)), 0),
        ("rear", Vector((-12, 20, 8)), 0),
        ("door_open", Vector((-19, -6, 6)), 1),
        ("front", Vector((0, -24, 5)), 0),
    ]
    y0, y1 = DOOR[0], DOOR[1]
    for name, position, opened in views:
        door_obj.location = (-0.16 * opened, (y1 - y0 + 0.1) * opened, 0)
        cam.location = position
        cam.rotation_euler = (target - position).to_track_quat("-Z", "Y").to_euler()
        scene.render.filepath = os.path.join(folder, f"DeliveryVan_{name}.png")
        bpy.ops.render.render(write_still=True)
    door_obj.location = (0, 0, 0)
    bpy.data.objects.remove(cam)


def run():
    portal_kit.begin(OUT)
    objects = build()
    scene = bpy.context.scene
    holder = bpy.data.objects.new(PACK, None)  # an Empty: the van's own Model in the import
    scene.collection.objects.link(holder)
    for obj in objects:
        obj.parent = holder
    folder = os.environ.get("PREVIEW_DIR")
    if folder:
        preview(objects, folder)
    if os.environ.get("EXPORT", "1") == "1":
        bpy.ops.object.select_all(action="DESELECT")
        for obj in [holder] + objects:
            obj.select_set(True)
        bpy.context.view_layer.objects.active = holder
        out = voxel_kit.out_dir(OUT)
        bpy.ops.wm.save_as_mainfile(filepath=os.path.join(out, f"{PACK}.blend"))
        bpy.ops.export_scene.fbx(
            filepath=os.path.join(out, f"{PACK}.fbx"),
            use_selection=True,
            object_types={"EMPTY", "MESH"},
            path_mode="COPY",
            embed_textures=True,
            mesh_smooth_type="FACE",
            apply_scale_options="FBX_SCALE_ALL",
        )
        print("exported to", out)


if __name__ == "__main__":
    run()
