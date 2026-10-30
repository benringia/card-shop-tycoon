"""Builds the Forest Falls portal to the Wild (spec 2026-10-30-town-portals-design, the user's pick A: grown from its
world): an arch of thick roots rising from both sides and twisting over to meet at the top, wrapped in moss, with
vines hanging off it carrying small flowers, and a little pool at the foot of its right side that a trickle of water
(the game's beam, from Fx_Trickle) runs down into.

Separate objects so the game can find and dress them (Server/Util/PortalBuild, Config/Town PORTAL_LOOKS.Wild):
  Frame       the roots, moss and vines (palette texture)
  Flowers     the flower heads (the game makes them glow gold)
  Pool        the pool's water (the game makes it glowing water)
  Opening     a flat disc filling the arch (hidden; the game's vortex fills it)
  Fx_Trickle  where the water leaves a root; Fx_Pool  the pool's middle (hidden markers)

Blender: Z up, 1 unit = 1 stud, origin at the bottom centre, the front faces -Y. About 28 studs tall, the opening
16 wide. Run inside Blender (MCP execute: exec(open(path).read())). Writes assets/blender/PortalWild/.
"""
import math
import os
import sys

from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)) if "__file__" in globals() else
                os.path.join(os.environ.get("CARD_SHOP_REPO", r"C:\Users\Ben\Documents\roblox-project\card-shop-tycoon"), "tools", "blender"))
import voxel_kit  # noqa: E402
import portal_kit  # noqa: E402

NAME = "PortalWild"
BONE = portal_kit.BONE
COLORS = {
    "bark_dark": (84, 50, 28),
    "bark": (124, 78, 42),
    "bark_light": (164, 108, 58),
    "moss": (60, 152, 44),
    "moss_bright": (112, 196, 52),
    "vine": (46, 122, 52),
    "flower_gold": (255, 196, 52),
    "flower_pink": (236, 92, 168),
    "water": (64, 186, 220),
    "marker": (255, 0, 255),
}
# The roots' centre line: legs straight up to LEG_TOP, then half an ellipse over the top RISE higher
HALF_WIDTH = 9.6
LEG_TOP = 10.0
RISE = 12.5
ROOTS = [  # per side: depth (y), twist phase, how far past the top it reaches (radians), bark colour
    (-1.5, 0.0, 0.85, "bark"),
    (-0.3, 1.7, 0.62, "bark_dark"),
    (0.9, 3.3, 0.95, "bark_light"),
    (1.9, 4.6, 0.70, "bark"),
]
TWIST = 0.95  # studs: how far each root winds round the bundle's centre line
FEET = [  # short roots spreading over the ground from each leg's foot: (outward, depth) direction, length
    ((1.0, -0.6), 4.5), ((1.0, 0.7), 4.0), ((0.25, -1.0), 3.2), ((0.3, 1.0), 3.0),
]
OPENING = {"z": 11.0, "width": 16.0, "height": 18.0}
TRICKLE = (9.9, -1.2, 16.4)
POOL = (12.4, -2.8, 0.1)
POOL_RADIUS = 3.0


def centre_line(side, theta_end, steps=7):
    """Points up one leg and over the top (side -1 left, +1 right), the foot splayed outward like a tree root."""
    points = [
        Vector((side * (HALF_WIDTH + 1.8), 0, -0.4)),
        Vector((side * (HALF_WIDTH + 0.7), 0, 2.4)),
        Vector((side * HALF_WIDTH, 0, 5.2)),
        Vector((side * HALF_WIDTH, 0, 8.0)),
    ]
    start = 0.0 if side > 0 else math.pi
    for i in range(steps + 1):
        theta = start + (theta_end - start) * i / steps
        points.append(Vector((HALF_WIDTH * math.cos(theta), 0, LEG_TOP + RISE * math.sin(theta))))
    return points


def on_arch(theta, out, depth):
    """A point on the arch's centre line at theta, pushed `out` studs away from the opening (negative: into it)."""
    normal = Vector((math.cos(theta) / HALF_WIDTH, 0, math.sin(theta) / RISE)).normalized()
    return Vector((HALF_WIDTH * math.cos(theta), depth, LEG_TOP + RISE * math.sin(theta))) + normal * out


def wound(points, depth, phase):
    """The centre line with a root winding round it: offsets along the line's in-plane normal and in depth."""
    out = []
    n = len(points)
    for i, p in enumerate(points):
        tangent = (points[min(i + 1, n - 1)] - points[max(i - 1, 0)]).normalized()
        normal = Vector((-tangent.z, 0, tangent.x))
        a = phase + i / (n - 1) * math.pi * 2.4
        out.append(p + normal * math.cos(a) * TWIST + Vector((0, depth + math.sin(a) * TWIST, 0)))
    return out


def build_frame():
    b = voxel_kit.Builder(COLORS)
    for side in (-1, 1):
        for index, (depth, phase, past, color) in enumerate(ROOTS):
            end = math.pi / 2 + side * past  # past the top, onto the other side
            points = wound(centre_line(side, end), depth, phase + (0.9 if side > 0 else 0))
            n = len(points)
            # thick up the leg and over the crown, tapering only in its last third
            radii = [1.3, 1.7] + [1.85 - 1.25 * max(0.0, (i / (n - 3) - 0.66) / 0.34) for i in range(n - 2)]
            portal_kit.tube(b, points, radii, color, sides=7)
        # Short roots spreading over the ground round the foot
        for (out, depth), length in FEET:
            start = Vector((side * HALF_WIDTH, 0, 1.2))
            heading = Vector((side * out, depth, 0)).normalized()
            points = [start, start + heading * length * 0.5 + Vector((0, 0, -0.6)), start + heading * length + Vector((0, 0, -1.0))]
            portal_kit.tube(b, points, [1.3, 0.8, 0.35], "bark_dark", sides=6)
    # Moss draped over the crown and down the legs, brighter on top
    for theta, depth, size in ((1.62, -1.0, 1.8), (1.15, 1.1, 1.6), (2.0, 0.8, 1.7), (0.8, -1.5, 1.4),
                               (2.35, -1.3, 1.4), (0.45, 1.5, 1.3), (2.7, 1.4, 1.3), (1.4, -2.1, 1.1), (1.8, 2.1, 1.2),
                               (1.0, -2.2, 1.0), (2.15, 2.2, 1.0)):
        centre = on_arch(theta, 2.3, depth)
        color = "moss_bright" if 1.0 < theta < 2.1 else "moss"
        b.blob(centre, (size, size * 0.85, size * 0.65), color, BONE, segments=8, rings=4)
    for side in (-1, 1):
        for z, depth in ((3.0, -2.0), (6.5, 1.9), (9.5, -1.9)):
            b.blob((side * (HALF_WIDTH + 2.4), depth * 1.3, z), (1.2, 0.9, 1.5), "moss", BONE, segments=7, rings=4)
    # Moss round the pool so it sits in the roots, not on bare ground
    for k in range(6):
        a = k / 6 * math.pi * 2 + 0.3
        b.blob((POOL[0] + math.cos(a) * (POOL_RADIUS + 0.3), POOL[1] + math.sin(a) * (POOL_RADIUS + 0.3), 0.2),
               (1.0, 0.8, 0.45), "moss", BONE, segments=6, rings=4)
    return b, vines(b)


def vines(b):
    """Vines hanging off the arch (thin tubes); returns where each flower sits."""
    flowers = []
    for theta, depth, length, sway in ((0.4, -2.2, 6.5, 0.6), (0.8, -2.3, 4.0, -0.4), (1.25, -2.4, 2.8, 0.3),
                                       (1.9, -2.3, 3.2, -0.3), (2.35, -2.2, 4.6, 0.5), (2.75, -2.1, 6.0, -0.5),
                                       (0.6, 2.2, 5.0, 0.4), (2.55, 2.2, 5.5, -0.4)):
        top = on_arch(theta, -1.6, -3.4 if depth < 0 else 3.4)
        points = [top + Vector((sway * math.sin(t * 2.2), -0.1 * t, -length * t)) for t in (0, 0.35, 0.7, 1.0)]
        portal_kit.tube(b, points, [0.26, 0.22, 0.18, 0.14], "vine", sides=5)
        flowers.append((points[2], "flower_pink" if theta > 1.6 else "flower_gold"))
        flowers.append((points[3], "flower_gold"))
    return flowers


def build_flowers(spots):
    b = voxel_kit.Builder(COLORS)
    for spot, color in spots:
        b.blob(spot + Vector((0, -0.2, 0)), (0.6, 0.4, 0.6), color, BONE, segments=6, rings=4)
    return b.to_object("Flowers")


def build_pool():
    b = voxel_kit.Builder(COLORS)
    portal_kit.disc(b, (POOL[0], POOL[1], POOL[2] + 0.05), POOL_RADIUS, "water", sides=12)
    return b.to_object("Pool")


def build_opening():
    b = voxel_kit.Builder(COLORS)
    portal_kit.disc(b, (0, 0, OPENING["z"]), OPENING["width"] / 2, "water", normal=(0, -1, 0), sides=12,
                    radius_y=OPENING["height"] / 2)
    return b.to_object("Opening")


def run():
    portal_kit.begin(NAME)
    frame_builder, flower_spots = build_frame()
    objects = [
        frame_builder.to_object("Frame"),
        build_flowers(flower_spots),
        build_pool(),
        build_opening(),
        portal_kit.marker("Fx_Trickle", TRICKLE, COLORS, "marker"),
        portal_kit.marker("Fx_Pool", (POOL[0], POOL[1], POOL[2] + 0.3), COLORS, "marker"),
    ]
    return portal_kit.export(NAME, objects, COLORS)


run()
