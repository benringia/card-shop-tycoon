"""Builds the seven boss trophies (owner 2026-11-23: "we need a model for the trophies. draw from blender"), each after
its Bag picture (assets/ui/icons/Trophy<Boss>.png) on the same stone plinth with a gold cap and a gem on its front:

  TrophyWarden    Meadow Warden: a green cup wrapped in leafy vines, vine handles, antlers, glowing teal water
  TrophyBrood     Brood Queen: a purple tulip cup with a web and a spider on its front, four spider legs a side
  TrophyColossus  Ember Colossus: a cup of dark rock plates with glowing lava cracks, fire leaping out of it
  TrophyFrost     Frost Tyrant: a faceted ice cup, snow on its rim, icicles, a glowing snowflake standing in it
  TrophyStorm     Storm Sovereign: a gold cup with lightning cracks, a storm cloud over it, bolts round it
  TrophyRift      Rift Devourer: a dark violet cup with a glowing rift swirling on its front
  TrophyHydra     Prism Hydra: a rainbow crystal cup with three little dragon heads peeking out of it

ONE pack so the owner imports once: each trophy is an Empty named for its Town.SLOTS slot holding <Name>__Frame (the
plinth and the cup, palette texture), <Name>__Gem (the plinth's gem: the game lights it Neon in the boss's colour,
Config/Shelves propColors) and its glowing bits as <Name>__Glow / <Name>__GlowCore (Neon in Town.TROPHY_LOOK GLOWS'
colours). Import assets/blender/Trophies/Trophies.fbx in Studio with default settings, save the imported model as
assets/props-import/Trophies.rbxm, then `lune run tools/props/split_pack assets/props-import/Trophies.rbxm` writes
assets/props/Trophy<Boss>.rbxm (docs/props.md "Trophies"). Until then Util/Props builds the code stand-in (a stone
plinth and a gold cup).

Blender: Z up, 1 unit = 1 stud, fronts face -Y, each trophy stands on z = 0 inside 4 x 4 x 5 (Config/Shelves size).
Run in a background Blender (it clears the scene):
  blender -b --factory-startup --python tools/blender/build_trophies.py
PROPS="TrophyWarden,TrophyRift" builds only those; EXPORT=0 builds without saving; PREVIEW_DIR=<folder> renders a
lineup and a close look at each (backface culling on, as Roblox draws).
"""
import math
import os
import random
import sys

import bpy
from mathutils import Matrix, Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)) if "__file__" in globals() else
                os.path.join(os.environ.get("CARD_SHOP_REPO", r"C:\Users\Ben\Documents\roblox-project\card-shop-tycoon"), "tools", "blender"))
import voxel_kit  # noqa: E402
import portal_kit  # noqa: E402

BONE = portal_kit.BONE
PACK = "Trophies"
OUT = "Trophies"  # assets/blender/Trophies
SPACING = 6
CAP = 2600  # triangles a trophy (a placed shop piece; DESIGN 10.5)
BOX = (4.0, 4.0, 5.0)  # Config/Shelves size (Blender x, y, z)

PLINTH_TOP = 1.48  # the cups are drawn standing on this height...
CUP_BASE = 1.04  # ...then grown CUP_SCALE times and set on the plinth's real top (cup_space), so the cup is the trophy
CUP_SCALE = 1.12
FRONT = -math.pi / 2  # the angle round the cup that faces the front (-Y)

# The plinth's colours, in every palette
STONE = {"stone": (52, 54, 64), "stone_dark": (38, 40, 48), "gold": (232, 186, 70), "gold_dark": (190, 140, 40)}

# The cup's outside (r, z) from the foot to the rim: foot, stem, knot, bowl
CUP = [
    (0.00, 0.00), (0.78, 0.00), (0.82, 0.06), (0.76, 0.15), (0.46, 0.22), (0.26, 0.34), (0.20, 0.58),
    (0.31, 0.68), (0.20, 0.79), (0.30, 0.90), (0.66, 1.08), (0.92, 1.38), (1.04, 1.74), (1.08, 2.05), (1.10, 2.22),
]
BOWL_FROM = 9  # CUP's bowl starts at this point (decorations follow it)


# ---------------------------------------------------------------------------------------------------- shapes

def smooth_since(b, before):
    for face in b.bm.faces:
        if face not in before:
            face.smooth = True


def scaled(profile, sr=1.0, sz=1.0):
    return [(r * sr, z * sz) for r, z in profile]


def with_inside(outer, depth=0.07):
    """The outer profile over a rounded lip and down inside to the liquid: the whole lathe profile."""
    r, z = outer[-1]
    return outer + [(r + 0.05, z + 0.05), (r, z + 0.11), (r - 0.1, z + 0.08), (r - 0.15, z - depth), (0.0, z - depth)]


def lathe(b, profile, sides, color, z0=0.0, phase=0.0, paint=None, smooth=True):
    """A surface of revolution round the vertical axis: profile [(r, z)] from the bottom; a point with r 0 closes it.
    paint(segment, k) gives each face's colour (else `color`); flat facets unless smooth."""
    rings = []
    for r, z in profile:
        if r <= 1e-6:
            rings.append(b._verts([(0.0, 0.0, z0 + z)], BONE))
        else:
            rings.append(b._verts([(r * math.cos(phase + 2 * math.pi * k / sides), r * math.sin(phase + 2 * math.pi * k / sides), z0 + z)
                                   for k in range(sides)], BONE))
    for s in range(len(rings) - 1):
        a, c = rings[s], rings[s + 1]
        if len(a) == 1 and len(c) == 1:
            continue
        for k in range(sides):
            k2 = (k + 1) % sides
            name = paint(s, k) if paint else color
            if len(a) == 1:
                face = b._face([a[0], c[k2], c[k]], name)
            elif len(c) == 1:
                face = b._face([a[k], a[k2], c[0]], name)
            else:
                face = b._face([a[k], a[k2], c[k2], c[k]], name)
            face.smooth = smooth


class Surface:
    """Points on a cup's outside: radius at a height (from the profile's bowl), a point at an angle and height."""

    def __init__(self, outer, z0):
        self.bowl = outer[BOWL_FROM:]
        self.z0 = z0

    def radius(self, z):
        pts = self.bowl
        if z <= pts[0][1]:
            return pts[0][0]
        for (r0, z0), (r1, z1) in zip(pts, pts[1:]):
            if z <= z1:
                t = (z - z0) / (z1 - z0)
                return r0 + (r1 - r0) * t
        return pts[-1][0]

    def low(self):
        return self.bowl[0][1]

    def high(self):
        return self.bowl[-1][1]

    def point(self, theta, z, lift=0.0):
        z = max(self.low(), min(self.high(), z))
        r = self.radius(z) + lift
        return Vector((r * math.cos(theta), r * math.sin(theta), self.z0 + z))

    def normal(self, theta, z):
        # the outward normal: across, tipped by the bowl's slope
        dz = 0.02
        slope = (self.radius(z + dz) - self.radius(z - dz)) / (2 * dz)
        out = Vector((math.cos(theta), math.sin(theta), 0))
        return (out - Vector((0, 0, slope))).normalized()

    def patch(self, theta0, z0, rho, phi, lift=0.0):
        """A point `rho` from (theta0, z0) along the surface in direction `phi` (0 across to the right, 90 up)."""
        z = z0 + rho * math.sin(phi)
        theta = theta0 + rho * math.cos(phi) / max(self.radius(z), 0.2)
        return self.point(theta, z, lift)


def line(b, points, radius, color, sides=4, smooth=True):
    """A thin round line through points (a vine, a crack, a web thread, a bolt)."""
    if len(points) < 2:
        return
    before = set(b.bm.faces)
    radii = radius if isinstance(radius, (list, tuple)) else [radius] * len(points)
    portal_kit.tube(b, points, radii, color, sides=sides)
    if smooth:
        smooth_since(b, before)


def frame_from(tangent, normal):
    """3x3 matrix whose columns are along (tangent), across and out (normal)."""
    t = tangent.normalized()
    n = (normal - t * normal.dot(t)).normalized()
    a = n.cross(t).normalized()
    return Matrix((t, a, n)).transposed()


CUP_XFORM = Matrix.Translation((0, 0, CUP_BASE)) @ Matrix.Scale(CUP_SCALE, 4) @ Matrix.Translation((0, 0, -PLINTH_TOP))
PLINTH_FRONT = 1.075  # the plinth's front face, off the middle
GEM_Z = 0.54
DIAMOND = Matrix.Rotation(math.radians(45), 3, "Y")  # a square turned on its corner, facing the front


def cup_space(*builders):
    """What these builders draw next (a cup and its decorations, in the cup's design space round PLINTH_TOP) is grown
    CUP_SCALE times and set on the plinth."""
    for builder in builders:
        builder.xform = CUP_XFORM


def plinth(b, gem_color):
    """The stone plinth with a gold cap and a gold diamond on its front (the gem itself is its own part); then b draws
    in cup space."""
    b.round_box((0, 0, 0.09), (2.5, 2.5, 0.18), "stone_dark", BONE, bevel=0.25, segments=1)
    b.round_box((0, 0, 0.54), (2.15, 2.15, 0.72), "stone", BONE, bevel=0.12, segments=1)
    b.round_box((0, 0, 0.97), (2.34, 2.34, 0.14), "gold", BONE, bevel=0.3, segments=1)
    b.box((0, 0, 0.25), (2.2, 2.2, 0.05), "gold_dark", BONE)  # a thin gold line round its foot
    b.box((0, -PLINTH_FRONT - 0.03, GEM_Z), (0.5, 0.06, 0.5), "gold", BONE, rot=DIAMOND)
    cup_space(b)


def gem(colors, color):
    g = voxel_kit.Builder(colors)
    g.box((0, -PLINTH_FRONT - 0.08, GEM_Z), (0.36, 0.07, 0.36), color, BONE, rot=DIAMOND)
    return g.to_object("Gem")


def flame(b, base, height, width, lean, color, phase):
    """A tongue of fire: a tube wavering up from `base` and narrowing to a point."""
    base = Vector(base)
    pts, radii = [], []
    for t, share in ((0.0, 0.7), (0.16, 1.0), (0.36, 0.9), (0.56, 0.62), (0.76, 0.32), (1.0, 0.02)):
        sway = math.sin(t * math.pi * 2.0 + phase) * 0.16 * height * t
        pts.append(base + Vector((lean[0] * t * height + sway * math.cos(phase), lean[1] * t * height + sway * math.sin(phase), t * height)))
        radii.append(width * share)
    line(b, pts, radii, color, sides=6)


def c_handle(b, side, z0, color, top=2.02, low=1.30, reach=0.58, radius=0.09, curl=False):
    """A C-shaped handle on the left (-1) or right (+1): out of the bowl near the rim, round and back in lower down."""
    s = Surface(CUP, z0)
    a = s.radius(top) - 0.04
    c = s.radius(low) - 0.04
    pts = [(side * a, 0, z0 + top), (side * (a + reach * 0.62), 0, z0 + top + 0.06), (side * (a + reach), 0, z0 + top - 0.22),
           (side * (a + reach * 0.95), 0, z0 + (top + low) / 2 - 0.05), (side * (c + reach * 0.55), 0, z0 + low + 0.04), (side * c, 0, z0 + low)]
    line(b, pts, radius, color, sides=7)
    if curl:
        end = Vector(pts[2])
        line(b, [end, end + Vector((side * 0.12, 0, 0.1)), end + Vector((side * 0.02, 0, 0.2))], [radius * 0.8, radius * 0.6, radius * 0.4], color, sides=6)


# ---------------------------------------------------------------------------------------------------- the trophies

def warden():
    colors = dict(STONE, leaf=(96, 186, 82), leaf_light=(150, 214, 110), vine=(45, 118, 52), wood=(128, 80, 44),
                  wood_dark=(92, 56, 30), water=(90, 226, 200), gem=(70, 175, 85))
    b, glow = voxel_kit.Builder(colors), voxel_kit.Builder(colors)
    plinth(b, "gem")
    cup_space(glow)
    z0 = PLINTH_TOP
    outer = scaled(CUP, 1.04, 1.0)
    lathe(b, with_inside(outer), 22, "leaf", z0, paint=lambda s, k: "leaf_light" if s >= len(outer) - 1 else "leaf")
    surf = Surface(outer, z0)
    # glowing magic water in the cup
    r, z = outer[-1]
    lathe(glow, [(r - 0.14, z - 0.05), (0.0, z - 0.05)], 22, "water", z0)
    # two vines winding up the bowl, leaves along them
    for start in (0.3, math.pi + 0.3):
        pts = [surf.point(start + t * 1.7 * math.pi, surf.low() + 0.08 + t * (surf.high() - surf.low() - 0.12), 0.045) for t in [i / 15 for i in range(16)]]
        line(b, pts, 0.07, "vine", sides=5)
        for t in (0.12, 0.3, 0.48, 0.66, 0.84):
            theta = start + t * 1.7 * math.pi
            zz = surf.low() + 0.08 + t * (surf.high() - surf.low() - 0.12)
            ahead = surf.point(theta + 0.05, zz + 0.01, 0.06) - surf.point(theta, zz, 0.06)
            side = 1 if int(t * 10) % 2 == 0 else -1
            normal = surf.normal(theta, zz)
            leaf_dir = (ahead.normalized() + Vector((0, 0, side * 0.6))).normalized()
            at = surf.point(theta, zz, 0.09) + leaf_dir * 0.12
            b.blob(at, (0.26, 0.14, 0.04), "leaf_light" if side > 0 else "leaf", BONE, rot=frame_from(leaf_dir, normal), segments=8, rings=4)
    # vine handles, a leaf on each, and antlers rising from them
    for side in (-1, 1):
        c_handle(b, side, z0, "vine", radius=0.085)
        b.blob((side * 1.52, -0.08, z0 + 1.62), (0.2, 0.11, 0.04), "leaf_light", BONE,
               rot=frame_from(Vector((side * 0.3, 0, -1)), Vector((0, -1, 0))), segments=8, rings=4)
        base = Vector((side * 0.82, 0.32, z0 + 2.12))
        beam = [base, base + Vector((side * 0.3, 0.0, 0.46)), base + Vector((side * 0.62, -0.02, 0.86)), base + Vector((side * 0.8, -0.04, 1.18))]
        line(b, beam, [0.1, 0.085, 0.065, 0.04], "wood", sides=6)
        for at, to, r0 in ((beam[1], Vector((-side * 0.08, 0, 0.42)), 0.06), (beam[2], Vector((side * 0.04, 0, 0.36)), 0.05),
                           (beam[2], Vector((side * 0.26, 0.02, 0.08)), 0.045)):
            mid = at + to * 0.55 + Vector((0, 0, 0.04))
            line(b, [at, mid, at + to], [r0, r0 * 0.75, r0 * 0.4], "wood_dark", sides=5)
    return colors, [b.to_object("Frame"), gem(colors, "gem"), glow.to_object("Glow")]


def brood():
    colors = dict(STONE, shell=(118, 66, 178), shell_dark=(76, 40, 126), lip=(168, 118, 218), inner=(58, 28, 92),
                  web=(228, 210, 250), spider=(48, 24, 78), leg=(88, 46, 142), joint=(150, 100, 205), gem=(135, 70, 200),
                  shine=(226, 170, 255))
    b, glow = voxel_kit.Builder(colors), voxel_kit.Builder(colors)
    plinth(b, "gem")
    cup_space(glow)
    z0 = PLINTH_TOP
    # a tulip: a narrower bowl that opens out at the rim
    outer = CUP[:BOWL_FROM] + [(0.30, 0.90), (0.58, 1.08), (0.80, 1.38), (0.90, 1.70), (1.00, 2.00), (1.14, 2.24)]
    full = with_inside(outer)
    lathe(b, full, 22, "shell", z0, paint=lambda s, k: "lip" if s >= len(outer) - 1 and s < len(full) - 2 else ("inner" if s >= len(full) - 2 else ("shell_dark" if s < BOWL_FROM else "shell")))
    surf = Surface(outer, z0)
    # the web on its front: eight threads out from the middle, three rings sagging between them
    zc = 1.6
    spokes = 8
    for j in range(spokes):
        phi = 2 * math.pi * j / spokes
        line(b, [surf.patch(FRONT, zc, rho, phi, 0.025) for rho in (0.05, 0.25, 0.45, 0.64)], 0.02, "web", sides=3)
    for rho in (0.24, 0.43, 0.62):
        pts = []
        for j in range(spokes + 1):
            phi = 2 * math.pi * j / spokes
            pts.append(surf.patch(FRONT, zc, rho, phi, 0.025))
            if j < spokes:
                pts.append(surf.patch(FRONT, zc, rho * 0.88, phi + math.pi / spokes, 0.025))
        line(b, pts, 0.018, "web", sides=3)
    # the spider in the middle, its back gem glowing
    normal = surf.normal(FRONT, zc)
    body = surf.point(FRONT, zc - 0.05, 0.07)
    b.blob(body, (0.15, 0.08, 0.18), "spider", BONE, rot=frame_from(Vector((1, 0, 0)), normal), segments=10, rings=6)
    b.blob(surf.point(FRONT, zc + 0.17, 0.06), (0.09, 0.06, 0.09), "spider", BONE, segments=8, rings=5)
    for side in (-1, 1):
        out = 0.0 if side > 0 else math.pi  # across to that side
        for rise, reach in ((0.16, 0.30), (0.06, 0.34), (-0.06, 0.33), (-0.16, 0.28)):
            root = surf.patch(FRONT, zc - 0.02 + rise * 0.3, 0.06, out, 0.07)
            knee = surf.patch(FRONT, zc + rise + 0.08, reach * 0.6, out + side * 0.5, 0.07)
            tip = surf.patch(FRONT, zc + rise - 0.06, reach, out + side * 0.2, 0.03)
            line(b, [root, knee, tip], [0.025, 0.022, 0.012], "spider", sides=4)
    glow.blob(surf.point(FRONT, zc - 0.07, 0.15), (0.07, 0.04, 0.08), "shine", BONE, rot=frame_from(Vector((1, 0, 0)), normal), segments=8, rings=5)
    # four spider legs a side instead of handles: up to a knee, down to a point
    for side_theta in (0.0, math.pi):
        for j, zz in enumerate((1.98, 1.78, 1.56, 1.34)):
            theta = side_theta + (j - 1.5) * 0.44
            out = Vector((math.cos(theta), math.sin(theta), 0))
            a = surf.point(theta, zz, -0.02)
            knee = a + out * 0.5 + Vector((0, 0, 0.42 - j * 0.04))
            tip = a + out * 0.86 + Vector((0, 0, -0.38 - j * 0.06))
            line(b, [a, a + out * 0.22 + Vector((0, 0, 0.2)), knee, knee + out * 0.16 + Vector((0, 0, -0.12)), tip],
                 [0.085, 0.075, 0.065, 0.05, 0.022], "leg", sides=6)
            b.blob(knee, (0.075, 0.075, 0.075), "joint", BONE, segments=6, rings=4)
    return colors, [b.to_object("Frame"), gem(colors, "gem"), glow.to_object("Glow")]


def colossus():
    colors = dict(STONE, rock=(96, 46, 32), rock_dark=(64, 30, 22), rock_light=(128, 64, 42), ember=(255, 140, 40),
                  core=(255, 222, 90), gem=(235, 95, 45))
    b, glow, core = voxel_kit.Builder(colors), voxel_kit.Builder(colors), voxel_kit.Builder(colors)
    plinth(b, "gem")
    cup_space(glow, core)
    z0 = PLINTH_TOP
    rng = random.Random(7)
    outer = scaled(CUP, 1.06, 0.98)
    mottle = {}

    def rock(s, k):
        key = (s, k)
        if key not in mottle:
            mottle[key] = rng.choice(("rock", "rock", "rock_dark", "rock_light"))
        return mottle[key]

    full = with_inside(outer)
    lathe(b, full, 16, "rock", z0, paint=lambda s, k: "rock_dark" if s >= len(full) - 2 else rock(s, k), smooth=False)
    surf = Surface(outer, z0)
    # glowing seams between the rock plates: jagged rings round the bowl, joined by short seams like bricks
    rows = [surf.low() + 0.1 + i * (surf.high() - surf.low() - 0.25) / 3 for i in range(4)]
    for i, zz in enumerate(rows):
        steps = 18
        ring = [surf.point(2 * math.pi * j / steps, zz + rng.uniform(-0.05, 0.05), 0.012) for j in range(steps)]
        line(glow, ring + [ring[0]], 0.028, "ember", sides=3, smooth=False)
        if i + 1 < len(rows):
            above = rows[i + 1]
            for j in range(6):
                theta = 2 * math.pi * (j + 0.5 * (i % 2)) / 6 + rng.uniform(-0.15, 0.15)
                seam = [surf.point(theta, zz, 0.012), surf.point(theta + rng.uniform(-0.12, 0.12), (zz + above) / 2, 0.012),
                        surf.point(theta + rng.uniform(-0.1, 0.1), above, 0.012)]
                line(glow, seam, 0.026, "ember", sides=3, smooth=False)
    # chunky rock handles with a crack along each
    for side in (-1, 1):
        c_handle(b, side, z0, "rock_dark", radius=0.12)
    # fire leaping out: orange tongues round a tall middle one, small yellow ones in front at the rim
    r, z = outer[-1]
    top = z0 + z
    for i in range(7):
        theta = 2 * math.pi * i / 7 + 0.2
        base = (0.55 * math.cos(theta), 0.55 * math.sin(theta), top - 0.2)
        flame(glow, base, rng.uniform(0.7, 0.98), 0.24, (0.18 * math.cos(theta), 0.18 * math.sin(theta)), "ember", theta)
    flame(glow, (0, 0.05, top - 0.25), 1.28, 0.36, (0.04, 0.0), "ember", 0.6)
    for i, theta in enumerate((FRONT - 0.55, FRONT, FRONT + 0.55, FRONT + math.pi)):
        base = (0.72 * math.cos(theta), 0.72 * math.sin(theta), top - 0.1)
        flame(core, base, rng.uniform(0.42, 0.58), 0.15, (0.12 * math.cos(theta), 0.12 * math.sin(theta)), "core", theta + i)
    return colors, [b.to_object("Frame"), gem(colors, "gem"), glow.to_object("Glow"), core.to_object("GlowCore")]


def frost():
    colors = dict(STONE, ice=(150, 210, 250), ice_light=(205, 238, 255), ice_dark=(98, 164, 230), snow=(246, 250, 255),
                  flake=(195, 240, 255), gem=(120, 200, 255))
    b, glow = voxel_kit.Builder(colors), voxel_kit.Builder(colors)
    plinth(b, "gem")
    cup_space(glow)
    z0 = PLINTH_TOP
    rng = random.Random(11)
    outer = scaled(CUP, 1.0, 0.94)
    full = with_inside(outer)
    lathe(b, full, 8, "ice", z0, phase=math.pi / 8, smooth=False,
          paint=lambda s, k: "ice_dark" if s < BOWL_FROM - 1 else ("snow" if s >= len(full) - 2 else ("ice_light" if (s + k) % 2 else "ice")))
    surf = Surface(outer, z0)
    r, z = outer[-1]
    # snow heaped round the rim, dripping down in places
    for i in range(16):
        theta = 2 * math.pi * i / 16
        b.blob(Vector((r * math.cos(theta), r * math.sin(theta), z0 + z + 0.08)), (0.23, 0.23, 0.16), "snow", BONE, segments=8, rings=5)
    for i in range(6):
        theta = 2 * math.pi * i / 6 + 0.3
        b.blob(surf.point(theta, z - 0.16, 0.02), (0.11, 0.11, 0.17), "snow", BONE, segments=6, rings=4)
    # icicles hanging under the snow
    for i in range(14):
        theta = 2 * math.pi * i / 14 + rng.uniform(-0.08, 0.08)
        base = surf.point(theta, z - 0.06, 0.04)
        b.spike(base, Vector((0.12 * math.cos(theta), 0.12 * math.sin(theta), -1)), 0.16, rng.uniform(0.34, 0.78), "ice_light", BONE)
    # a snowflake standing in the cup, facing the front, glowing
    centre = Vector((0, -0.05, z0 + z + 0.58))
    arm = 0.7
    for j in range(6):
        a = math.pi / 2 + j * math.pi / 3
        d = Vector((math.cos(a), 0, math.sin(a)))
        glow.span(centre, centre + d * arm, 0.1, "flake", BONE)
        for along, length in ((0.42, 0.24), (0.62, 0.14)):
            p = centre + d * along
            for turn in (-1, 1):
                side = Vector((math.cos(a + turn * math.radians(50)), 0, math.sin(a + turn * math.radians(50))))
                glow.span(p, p + side * length, 0.07, "flake", BONE)
        # a diamond at the arm's tip (turning about +Y takes +X toward -Z, so the arm's angle goes in negative)
        glow.box(centre + d * (arm + 0.04), (0.13, 0.08, 0.13), "flake", BONE, rot=Matrix.Rotation(-(a + math.pi / 4), 3, "Y"))
    line(glow, [centre + Vector((0, -0.06, 0)), centre + Vector((0, 0.06, 0))], 0.17, "flake", sides=6, smooth=False)
    return colors, [b.to_object("Frame"), gem(colors, "gem"), glow.to_object("Glow")]


def zigzag(start, down, steps, step, wiggle, rng):
    pts = [Vector(start)]
    sign = 1
    for _ in range(steps):
        sign = -sign
        pts.append(pts[-1] + Vector(down) * step + Vector((sign * wiggle * rng.uniform(0.7, 1.2), 0, 0)))
    return pts


def storm():
    colors = dict(STONE, gold_light=(255, 222, 120), gold_mid=(236, 186, 62), cloud=(72, 92, 142), cloud_dark=(50, 64, 104),
                  cloud_light=(112, 136, 188), bolt=(175, 235, 255), gem=(255, 220, 70))
    b, glow = voxel_kit.Builder(colors), voxel_kit.Builder(colors)
    plinth(b, "gem")
    cup_space(glow)
    z0 = PLINTH_TOP
    rng = random.Random(23)
    outer = CUP
    full = with_inside(outer)
    lathe(b, full, 22, "gold_mid", z0, paint=lambda s, k: "gold_light" if BOWL_FROM + 2 <= s < len(outer) - 1 else ("gold_dark" if s >= len(full) - 2 else "gold_mid"))
    surf = Surface(outer, z0)
    for side in (-1, 1):
        c_handle(b, side, z0, "gold_mid", radius=0.095)
    # lightning cracking down the bowl
    for theta0 in (FRONT - 0.25, FRONT + 0.55, FRONT + math.pi * 0.9, FRONT - 1.4):
        theta, zz = theta0, surf.high() - 0.05
        pts = [surf.point(theta, zz, 0.012)]
        sign = 1
        while zz > surf.low() + 0.25:
            sign = -sign
            theta += sign * rng.uniform(0.1, 0.17)
            zz -= rng.uniform(0.15, 0.22)
            pts.append(surf.point(theta, zz, 0.012))
        line(glow, pts, 0.04, "bolt", sides=4, smooth=False)
        fork = len(pts) // 2
        branch = [pts[fork], surf.point(theta0 + 0.3, surf.high() - 0.05 - 0.2 * (fork + 1), 0.012)]
        line(glow, branch, 0.022, "bolt", sides=4, smooth=False)
    # the storm cloud over the cup, a bolt down into it
    r, z = outer[-1]
    c = Vector((0, 0.08, z0 + z + 0.78))
    for offset, radii, shade in (((0, 0, 0.16), (0.46, 0.4, 0.36), "cloud"), ((-0.46, 0, 0.0), (0.38, 0.34, 0.3), "cloud_light"),
                                 ((0.46, 0.02, 0.02), (0.4, 0.34, 0.31), "cloud"), ((-0.82, 0, -0.1), (0.28, 0.26, 0.23), "cloud_dark"),
                                 ((0.84, 0, -0.1), (0.3, 0.27, 0.24), "cloud_dark"), ((0, -0.26, -0.08), (0.36, 0.3, 0.27), "cloud_light"),
                                 ((0.05, 0.28, -0.04), (0.36, 0.3, 0.27), "cloud_dark")):
        b.blob(c + Vector(offset), radii, shade, BONE, segments=10, rings=6)
    line(glow, zigzag(c + Vector((0.08, -0.12, -0.3)), (0, 0, -1), 4, 0.16, 0.13, rng), [0.06, 0.05, 0.045, 0.035, 0.03], "bolt", sides=4, smooth=False)
    # little bolts round it
    for start in ((-1.52, -0.25, z0 + 1.5), (1.52, -0.25, z0 + 2.45), (-1.2, -0.3, z0 + 2.78)):
        line(glow, zigzag(start, (0.05, 0, -1), 3, 0.17, 0.08, rng), 0.045, "bolt", sides=4, smooth=False)
    return colors, [b.to_object("Frame"), gem(colors, "gem"), glow.to_object("Glow")]


def rift():
    colors = dict(STONE, void=(58, 30, 98), void_dark=(36, 18, 64), void_light=(98, 58, 152), hole=(14, 8, 24),
                  swirl=(200, 112, 255), gem=(150, 70, 220))
    b, glow = voxel_kit.Builder(colors), voxel_kit.Builder(colors)
    plinth(b, "gem")
    cup_space(glow)
    z0 = PLINTH_TOP
    rng = random.Random(31)
    outer = CUP
    full = with_inside(outer)
    lathe(b, full, 22, "void", z0, paint=lambda s, k: "hole" if s >= len(full) - 2 else ("void_light" if s == len(outer) - 1 or s == len(outer) else ("void_dark" if s < BOWL_FROM else "void")))
    surf = Surface(outer, z0)
    for side in (-1, 1):
        c_handle(b, side, z0, "void_light", reach=0.5, radius=0.09, curl=True)
    # the rift on its front: a black hole with glowing arms swirling into it
    zc = 1.62
    normal = surf.normal(FRONT, zc)
    b.blob(surf.point(FRONT, zc, 0.0), (0.4, 0.4, 0.06), "hole", BONE, rot=frame_from(Vector((1, 0, 0)), normal), segments=14, rings=6)
    for arm in range(3):
        phi0 = arm * 2 * math.pi / 3
        pts = [surf.patch(FRONT, zc, 0.1 + t * 0.46, phi0 + t * 2.3 * math.pi, 0.05) for t in [i / 14 for i in range(15)]]
        line(glow, pts, [0.018 + 0.03 * (i / 14) for i in range(15)], "swirl", sides=4)
    for i in range(6):
        phi = rng.uniform(0, 2 * math.pi)
        at = surf.patch(FRONT, zc, rng.uniform(0.55, 0.75), phi, 0.03)
        glow.box(at, (0.07, 0.03, 0.07), "swirl", BONE, rot=frame_from(Vector((1, 0, 1)), surf.normal(FRONT, zc)))
    # the inside a dark well with a glow ring
    r, z = outer[-1]
    lathe(glow, [(r - 0.16, z - 0.06), (r - 0.24, z - 0.06)], 22, "swirl", z0)
    return colors, [b.to_object("Frame"), gem(colors, "gem"), glow.to_object("Glow")]


RAINBOW = [(255, 92, 92), (255, 160, 72), (255, 224, 92), (124, 220, 112), (92, 210, 232), (94, 142, 240), (162, 112, 236), (240, 122, 200)]


def dragon(b, centre, scale, body, light, turn):
    """A little dragon head peeking out of the cup: round head, a snout, big eyes, horns, fins, a neck down into it."""
    rot = Matrix.Rotation(turn, 3, "Z")

    def at(x, y, z):
        return Vector(centre) + rot @ Vector((x * scale, y * scale, z * scale))

    b.blob(at(0, 0, 0), (0.3 * scale, 0.27 * scale, 0.27 * scale), body, BONE, rot=rot, segments=11, rings=7)
    b.blob(at(0, -0.24, -0.07), (0.18 * scale, 0.15 * scale, 0.13 * scale), light, BONE, rot=rot, segments=9, rings=5)
    for side in (-1, 1):
        b.blob(at(side * 0.07, -0.37, -0.03), (0.024 * scale,) * 3, "eye", BONE, segments=4, rings=3)
        b.blob(at(side * 0.125, -0.2, 0.06), (0.085 * scale, 0.06 * scale, 0.095 * scale), "white", BONE, rot=rot, segments=8, rings=5)
        b.blob(at(side * 0.125, -0.245, 0.055), (0.055 * scale, 0.03 * scale, 0.062 * scale), "eye", BONE, rot=rot, segments=6, rings=4)
        b.blob(at(side * 0.108, -0.272, 0.085), (0.02 * scale,) * 3, "white", BONE, segments=4, rings=3)
        b.spike(at(side * 0.12, 0.06, 0.18), rot @ Vector((side * 0.25, 0.35, 1)), 0.1 * scale, 0.3 * scale, "horn", BONE)
        b.spike(at(side * 0.25, 0.05, 0.04), rot @ Vector((side * 1, 0.3, 0.45)), 0.12 * scale, 0.2 * scale, light, BONE)
    before = set(b.bm.faces)
    portal_kit.tube(b, [at(0, 0.06, -0.16), at(0, 0.1, -0.5), Vector((centre[0] * 0.6, 0.05, centre[2] - 0.75 * scale))],
                    [0.17 * scale, 0.19 * scale, 0.2 * scale], body, sides=8)
    smooth_since(b, before)


def hydra():
    colors = dict(STONE, prism=(232, 242, 255), white=(255, 255, 255), eye=(30, 24, 42), horn=(255, 240, 200),
                  red=(232, 82, 72), red_light=(255, 172, 152), blue=(72, 142, 236), blue_light=(172, 212, 255),
                  purple=(156, 92, 216), purple_light=(216, 182, 250), gem=(215, 240, 255))
    for i, rgb in enumerate(RAINBOW):
        colors[f"r{i}"] = rgb
        colors[f"r{i}l"] = tuple(int(c + (255 - c) * 0.45) for c in rgb)
    b = voxel_kit.Builder(colors)
    plinth(b, "gem")
    z0 = PLINTH_TOP
    outer = scaled(CUP, 1.04, 0.96)
    full = with_inside(outer)
    lathe(b, full, 8, "prism", z0, phase=math.pi / 8, smooth=False,
          paint=lambda s, k: "prism" if s >= len(full) - 2 else (f"r{k % 8}" if (s % 2 == 0) else f"r{k % 8}l"))
    for side in (-1, 1):
        c_handle(b, side, z0, "prism", radius=0.08)
    r, z = outer[-1]
    top = z0 + z
    dragon(b, (-0.56, 0.04, top + 0.4), 1.12, "red", "red_light", math.radians(-24))
    dragon(b, (0.56, 0.04, top + 0.4), 1.12, "purple", "purple_light", math.radians(24))
    dragon(b, (0.0, -0.1, top + 0.58), 1.3, "blue", "blue_light", 0.0)
    return colors, [b.to_object("Frame"), gem(colors, "gem")]


PROPS = {
    "TrophyWarden": warden,
    "TrophyBrood": brood,
    "TrophyColossus": colossus,
    "TrophyFrost": frost,
    "TrophyStorm": storm,
    "TrophyRift": rift,
    "TrophyHydra": hydra,
}


# ---------------------------------------------------------------------------------------------------- build, check, export

def bounds(objects):
    points = [obj.matrix_world @ Vector(corner) for obj in objects for corner in obj.bound_box]
    low = Vector((min(p.x for p in points), min(p.y for p in points), min(p.z for p in points)))
    high = Vector((max(p.x for p in points), max(p.y for p in points), max(p.z for p in points)))
    return low, high


def build(name):
    colors, objects = PROPS[name]()
    os.makedirs(voxel_kit.out_dir(name), exist_ok=True)
    material = voxel_kit.make_material(name, voxel_kit.make_palette(name, colors))
    scene = bpy.context.scene
    kept = []
    for obj in objects:
        if len(obj.data.polygons) == 0:
            bpy.data.objects.remove(obj)
            continue
        scene.collection.objects.link(obj)
        obj.data.materials.clear()
        obj.data.materials.append(material)
        obj.vertex_groups.clear()
        obj.name = f"{name}__{obj.name}"
        obj.data.name = obj.name
        kept.append(obj)
    bpy.context.view_layer.update()
    counts = {o.name.split("__")[1]: portal_kit.triangles(o) for o in kept}
    total = sum(counts.values())
    assert total <= CAP, f"{name} has {total} triangles (cap {CAP}): {counts}"
    low, high = bounds(kept)
    span = high - low
    for axis, size in enumerate(BOX):
        assert span[axis] <= size + 0.05, f"{name} is {tuple(round(v, 2) for v in span)}, its box {BOX}"
    assert abs(low.z) < 0.01, f"{name} should stand on z = 0 ({low.z})"
    return kept, total, span, counts


def preview(trophies, folder):
    """Workbench renders: all seven in a row, then each close from its front three-quarter."""
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
    count = len(trophies)
    middle = Vector(((count - 1) * SPACING / 2, 0, 2.4))
    scene.render.resolution_x, scene.render.resolution_y = 1600, 520
    cam.data.lens = 50
    cam.data.lens = 40
    cam.location = middle + Vector((0, -58, 10))
    cam.rotation_euler = (middle - cam.location).to_track_quat("-Z", "Y").to_euler()
    scene.render.filepath = os.path.join(folder, "Trophies_lineup.png")
    bpy.ops.render.render(write_still=True)
    scene.render.resolution_x, scene.render.resolution_y = 700, 800
    for index, name in enumerate(trophies):
        target = Vector((index * SPACING, 0, 2.6))
        cam.location = target + Vector((-5.5, -10.5, 3.2))
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
        objects, total, size, counts = build(name)
        holder = bpy.data.objects.new(name, None)  # an Empty: the trophy's own Model in the import
        scene.collection.objects.link(holder)
        holder.location = (index * SPACING, 0, 0)
        for obj in objects:
            obj.parent = holder
        everything += [holder] + objects
        print(f"OK {name} {total} tris {counts}, {size.x:.2f} x {size.y:.2f} x {size.z:.2f}")
    folder = os.environ.get("PREVIEW_DIR")
    if folder:
        preview(wanted, folder)
    if os.environ.get("EXPORT", "1") == "1":
        bpy.ops.object.select_all(action="DESELECT")
        for obj in everything:
            obj.select_set(True)
        bpy.context.view_layer.objects.active = everything[0]
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
