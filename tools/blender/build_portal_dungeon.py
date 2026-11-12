"""Builds the Frontier's way into the Dungeon (spec docs/superpowers/specs/2026-11-12-dungeon-world-design.md: the
Crystal Abyss's entrance, the gates concept's left one): a cave mouth split open in the ground, a broken temple arch of
indigo stone round it, five hydra heads carved along its top, the Hydra's crystals growing out of its stones, steps
going down into a violet swirl.

Separate objects so the game can find and dress them (Server/Util/PortalBuild, Config/Town PORTAL_LOOKS.Dungeon):
  Frame     the rock, the arch, the heads and the steps (palette texture)
  Crystals  the crystals (the game makes them glow violet)
  Eye1..5   each dragon head's pair of eyes, left to right (white; the Frontier lights them, the Hydra's castle gate
            keeps them dark until its lock is solved, then lights them one by one: Config/Dungeon HYDRA_EYES)
  Opening   a flat disc filling the arch (hidden; the game's vortex fills it)
  Fx_Base   the steps' foot, where dust drifts (hidden marker)

Blender: Z up, 1 unit = 1 stud, origin at the bottom centre, the front faces -Y. About 26 studs tall, the opening 14
across. Run inside Blender (MCP execute: exec(open(path).read())) or in a background Blender:
  blender -b --factory-startup --python tools/blender/build_portal_dungeon.py
Writes assets/blender/PortalDungeon/ (EXPORT=0: build without saving).
"""
import math
import os
import random
import sys

from mathutils import Matrix, Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)) if "__file__" in globals() else
                os.path.join(os.environ.get("CARD_SHOP_REPO", r"C:\Users\Ben\Documents\roblox-project\card-shop-tycoon"), "tools", "blender"))
import voxel_kit  # noqa: E402
import portal_kit  # noqa: E402

NAME = "PortalDungeon"
BONE = portal_kit.BONE
COLORS = {
    "rock_dark": (30, 26, 44),
    "rock": (52, 46, 72),
    "stone": (96, 104, 136),
    "stone_light": (124, 132, 164),
    "gold": (214, 176, 92),
    "bone": (228, 220, 196),
    "crystal": (255, 255, 255),  # the game recolours it
    "marker": (255, 0, 255),
}
OPENING = {"z": 10.0, "width": 14.0, "height": 16.0}
SEED = 31


def spin(radians):
    return Matrix.Rotation(radians, 3, "Z")


def tilt(degrees, axis="Y"):
    return Matrix.Rotation(math.radians(degrees), 3, axis)


def build_frame():
    rng = random.Random(SEED)
    b = voxel_kit.Builder(COLORS)
    # the ground split open: dark rock heaped round a hole, the steps going down into it
    for centre, radii, color in (((0, 1.6, 0.6), (15.0, 6.0, 2.4), "rock"), ((-11.5, -0.6, 1.4), (5.0, 4.6, 3.0), "rock_dark"),
                                 ((11.5, 0.6, 1.4), (5.0, 4.6, 3.0), "rock_dark"), ((-15.0, 2.4, 0.6), (3.6, 3.2, 1.6), "rock"),
                                 ((15.0, -1.0, 0.6), (3.6, 3.2, 1.6), "rock")):
        b.blob(centre, radii, color, BONE, segments=9, rings=4)
    for k in range(4):
        b.round_box((0, -3.6 + k * 1.6, 1.6 - k * 0.5), (10.0 - k * 0.8, 1.7, 0.6), "stone" if k % 2 else "stone_light", BONE, bevel=0.15, segments=1)
    # the arch: two thick posts and a curved top of stone blocks, one block slipped
    half = OPENING["width"] / 2
    for side in (-1, 1):
        b.round_box((side * (half + 1.8), 0, 1.4), (4.6, 4.0, 2.8), "stone", BONE, bevel=0.35, segments=1)
        b.round_box((side * (half + 1.6), 0, 8.6), (3.4, 3.2, 12.4), "stone_light" if side < 0 else "stone", BONE, bevel=0.35, segments=1)
    blocks = 9
    for k in range(blocks):
        a = math.pi * (k + 0.5) / blocks
        x = math.cos(a) * (half + 1.6)
        z = OPENING["z"] + 4.6 + math.sin(a) * (half * 0.75)
        slip = 0.6 if k == 6 else 0.0
        b.round_box((x, 0, z - slip), (3.0, 3.4, 2.6), "stone" if k % 2 else "stone_light", BONE, rot=tilt(math.degrees(a) - 90), bevel=0.3, segments=1)
    # five dragon heads rising from the top (owner 2026-11-12: "it looks like a duck rather than dragon heads")
    for k in range(5):
        dragon_head(b, None, k)
    return b.to_object("Frame")


def head_frame(k):
    """Dragon head k's (0-4, left to right) centre, its axes (side, forward, up), its scale and its neck's base."""
    half = OPENING["width"] / 2
    a = math.pi * (0.82 - k * 0.16)
    out = math.cos(a)
    base = Vector((out * (half + 1.2), 0.6, OPENING["z"] + 5.6 + math.sin(a) * (half * 0.75)))
    scale = 1.9 if k == 2 else 1.55
    centre = base + Vector((out * 3.0, -2.2, 5.2 + (1.4 if k == 2 else 0.0)))
    forward = Vector((out * 0.5, -1.0, -0.3)).normalized()
    side = forward.cross(Vector((0, 0, 1))).normalized()
    up = side.cross(forward).normalized()
    return centre, (side, forward, up), scale, base, out


def dragon_head(frame, eyes, k):
    """A carved stone dragon head on its serpentine neck: a long snout over an open jaw with fangs, brow ridges over
    deep eye sockets, swept-back gold horns, cheek spikes, spines down its neck. `eyes` (a Builder) takes the eyes;
    None: only the stone."""
    centre, (side, forward, up), scale, base, out = head_frame(k)
    rot = Matrix((side, forward, up)).transposed()

    def at(dx, dy, dz):
        return centre + side * dx * scale + forward * dy * scale + up * dz * scale

    if eyes is not None:
        for sign in (-1, 1):
            # narrow slits slanting down to the snout: angry
            slant = rot @ tilt(-sign * 22, "Y")
            eyes.blob(tuple(at(sign * 0.56, 0.8, 0.36)), (0.26 * scale, 0.22 * scale, 0.1 * scale), "crystal", BONE, rot=slant, segments=6, rings=4)
        return
    # the neck: a thick S-curve out of the arch's top, spines along its back
    neck = [base + Vector((0, 0.9, -1.2)), base + Vector((out * 0.8, 0.3, 1.6)), base + Vector((out * 2.0, -1.0, 3.6)), at(0, -0.9, -0.1)]
    portal_kit.tube(frame, neck, [1.7, 1.5, 1.3, 0.85 * scale], "stone", sides=7)
    for t in (0.35, 0.7):
        i = min(int(t * 3), 2)
        f = t * 3 - i
        point = neck[i].lerp(neck[i + 1], f)
        frame.spike(tuple(point + Vector((0, 0.9, 0.8))), (0, 0.8, 1.0), 0.6, 1.2, "stone_light", BONE)
    # the skull, its long snout and nose
    frame.blob(tuple(at(0, 0, 0.15)), (0.95 * scale, 1.05 * scale, 0.85 * scale), "stone_light", BONE, rot=rot, segments=8, rings=5)
    frame.blob(tuple(at(0, 1.5, -0.05)), (0.62 * scale, 1.3 * scale, 0.42 * scale), "stone_light", BONE, rot=rot, segments=8, rings=5)
    frame.blob(tuple(at(0, 2.45, 0.1)), (0.44 * scale, 0.42 * scale, 0.3 * scale), "stone_light", BONE, rot=rot, segments=6, rings=4)
    for sign in (-1, 1):
        portal_kit.disc(frame, tuple(at(sign * 0.22, 2.84, 0.18)), 0.09 * scale, "rock_dark", normal=tuple(forward), sides=6)
    # the open jaw: the lower jaw tipped down, the mouth dark inside, fangs above and below
    jaw_forward = (forward * math.cos(math.radians(24)) - up * math.sin(math.radians(24))).normalized()
    jaw_up = side.cross(jaw_forward).normalized()
    jaw_rot = Matrix((side, jaw_forward, jaw_up)).transposed()
    frame.blob(tuple(at(0, 0.95, -0.42)), (0.48 * scale, 0.95 * scale, 0.24 * scale), "rock_dark", BONE, rot=rot, segments=6, rings=3)
    frame.blob(tuple(at(0, 1.25, -0.82)), (0.5 * scale, 1.2 * scale, 0.24 * scale), "stone", BONE, rot=jaw_rot, segments=8, rings=4)
    for sign in (-1, 1):
        for dy, length in ((1.35, 0.5), (2.15, 0.36)):
            frame.spike(tuple(at(sign * 0.4, dy, -0.36)), tuple(-up + forward * 0.15), 0.17 * scale, length * scale, "bone", BONE)
        frame.spike(tuple(at(sign * 0.34, 1.9, -0.95)), tuple(jaw_up), 0.14 * scale, 0.3 * scale, "bone", BONE)
    # deep eye sockets under heavy brow ridges
    for sign in (-1, 1):
        frame.blob(tuple(at(sign * 0.5, 0.74, 0.38)), (0.27 * scale, 0.32 * scale, 0.21 * scale), "rock_dark", BONE, rot=rot, segments=6, rings=3)
        brow = rot @ tilt(-sign * 24, "Y")  # the inner end low: a scowl
        frame.box(tuple(at(sign * 0.52, 0.74, 0.6)), (0.68 * scale, 0.8 * scale, 0.24 * scale), "stone", BONE, rot=brow)
        # gold horns swept back, cheek spikes out to the side
        frame.spike(tuple(at(sign * 0.5, -0.45, 0.62)), tuple(-forward * 0.85 + up * 0.5 + side * sign * 0.35), 0.42 * scale, 2.3 * scale, "gold", BONE)
        frame.spike(tuple(at(sign * 0.82, -0.15, -0.15)), tuple(side * sign * 0.85 - forward * 0.55), 0.3 * scale, 0.95 * scale, "stone", BONE)
    # a crest of two small spikes down the top of the skull
    for dy in (0.1, -0.6):
        frame.spike(tuple(at(0, dy, 0.85)), tuple(up * 0.8 - forward * 0.6), 0.28 * scale, 0.6 * scale, "stone_light", BONE)


def build_eyes(k):
    b = voxel_kit.Builder(COLORS)
    dragon_head(None, b, k)
    return b.to_object(f"Eye{k + 1}")


def build_crystals():
    rng = random.Random(SEED + 1)
    b = voxel_kit.Builder(COLORS)
    half = OPENING["width"] / 2
    for side in (-1, 1):
        for out, lean, length, radius in ((half + 4.4, 0.35, 8.0, 1.4), (half + 6.6, 0.55, 5.6, 1.1), (half + 2.6, 0.15, 4.2, 0.9)):
            base = Vector((side * out, rng.uniform(-1.4, 1.4), 1.2))
            portal_kit.crystal(b, base, (side * lean, rng.uniform(-0.3, 0.3), 1), radius, length, "crystal", sides=6, tip=0.3)
        # a few growing out of the arch's post
        for z in (6.0, 11.0):
            base = Vector((side * (half + 3.0), -0.6, z))
            portal_kit.crystal(b, base, (side * 0.8, -0.4, 0.5), 0.6, 2.4, "crystal", sides=5, tip=0.4)
    for x in (-3.0, 2.4):
        portal_kit.crystal(b, (x, -4.6, 0.6), (x * 0.08, -0.3, 1), 0.5, 1.8, "crystal", sides=5, tip=0.4)
    return b.to_object("Crystals")


def build_opening():
    b = voxel_kit.Builder(COLORS)
    portal_kit.disc(b, (0, 0, OPENING["z"]), OPENING["width"] / 2, "rock_dark", normal=(0, -1, 0), sides=16,
                    radius_y=OPENING["height"] / 2)
    return b.to_object("Opening")


def run():
    portal_kit.begin(NAME)
    objects = [
        build_frame(),
        build_crystals(),
        build_opening(),
        portal_kit.marker("Fx_Base", (0, -4.6, 0.6), COLORS, "marker"),
    ] + [build_eyes(k) for k in range(5)]
    return portal_kit.export(NAME, objects, COLORS)


# For the preview renderer: MODULE=build_portal_dungeon blender -b --python tools/blender/render_valley_props.py -- <out>
PROPS = {"PortalDungeon": lambda: (COLORS, [build_frame(), build_crystals(), build_opening()] + [build_eyes(k) for k in range(5)])}

if __name__ == "__main__":
    run()
